// ============================================================================
// MICROSOFT AGENT FRAMEWORK - IMPORTANT NOTES
// ============================================================================
// 
// ⚠️  PRE-RELEASE WARNING: The Microsoft Agent Framework (Microsoft.Agents.AI)
//     is currently in PREVIEW status (v1.0.0-preview.x). This means:
//     - API signatures may change between versions without notice
//     - Breaking changes should be expected in future updates
//     - Not recommended for production workloads without careful consideration
//     - Always check https://learn.microsoft.com/en-us/agent-framework/ for updates
//
// 📦 Required NuGet Packages:
//     - Microsoft.Agents.AI (core agent abstractions and ChatClientAgent)
//     - Microsoft.Agents.AI.OpenAI (OpenAI/Azure OpenAI extensions)
//     - Microsoft.Extensions.AI.OpenAI (IChatClient adapters for OpenAI)
//
// 📚 Documentation:
//     - Agent Framework Overview: https://learn.microsoft.com/en-us/agent-framework/
//     - ChatClientAgent: https://learn.microsoft.com/en-us/agent-framework/user-guide/agents/agent-types/chat-client-agent
//     - Multi-turn Threading: https://learn.microsoft.com/en-us/agent-framework/user-guide/agents/multi-turn-conversation
//
// ============================================================================

using Azure.AI.OpenAI;
using Microsoft.Agents.AI;      // Core agent types: AIAgent, AgentThread, AgentRunResponse
using Microsoft.Extensions.AI;   // Microsoft.Extensions.AI: IChatClient, AITool, ChatMessage
using ModelContextProtocol.Client;

namespace MedicalAgent.Api;

/// <summary>
/// Agent that orchestrates Azure OpenAI with MCP (Model Context Protocol) tools for medical queries.
/// Uses Microsoft Agent Framework for multi-turn conversation support with automatic tool invocation.
/// 
/// <para><b>Architecture Overview:</b></para>
/// <para>
/// The Microsoft Agent Framework provides a unified abstraction for building AI agents that can:
/// - Maintain conversation context across multiple turns (via AgentThread)
/// - Automatically invoke tools/functions when the LLM requests them
/// - Work with any IChatClient implementation (Azure OpenAI, OpenAI, Ollama, etc.)
/// </para>
/// 
/// <para><b>Key Framework Concepts:</b></para>
/// <list type="bullet">
///   <item><description><see cref="AIAgent"/>: Base abstraction for all agents - wraps an IChatClient with agent capabilities</description></item>
///   <item><description><see cref="AgentThread"/>: Manages conversation state/history - agents are stateless, threads hold state</description></item>
///   <item><description><see cref="AITool"/>: Tool definitions that the agent can invoke (e.g., MCP tools, Semantic Kernel plugins)</description></item>
/// </list>
/// </summary>
/// <remarks>
/// ⚠️ This class uses preview APIs from Microsoft.Agents.AI which are subject to change.
/// The AsAIAgent() and AsIChatClient() extension methods may have different signatures in future versions.
/// </remarks>
public sealed class MedicalQueryAgent
{
    private readonly AzureOpenAIClient _openAiClient;
    private readonly string _deploymentName;
    private readonly MedicalMcpClientFactory _mcpFactory;
    
    // AIAgent is the core abstraction in Microsoft Agent Framework.
    // It wraps an IChatClient and adds agent capabilities like:
    // - Automatic tool/function calling
    // - Conversation threading
    // - System instructions management
    // ⚠️ Note: AIAgent API is in preview and may change.
    private AIAgent? _agent;

    // System prompt (instructions) that guides the AI's behavior.
    // These instructions are provided to the model with each invocation
    // to establish the agent's role and behavioral constraints.
    private const string Instructions = """
        You are a helpful medical records assistant with access to a patient database.
        When users ask about patient information, use the available tools to query the database.
        Always be accurate and cite specific data from the records.
        If a patient ID is needed but not provided, ask the user for it.
        Format responses clearly with relevant medical information organized by category.
        """;

    /// <summary>
    /// Initializes a new instance of the MedicalQueryAgent.
    /// Note: The actual AIAgent is created lazily in GetAgentAsync() because
    /// MCP tools must be loaded asynchronously from the MCP server.
    /// </summary>
    /// <param name="openAiClient">Azure OpenAI client for LLM inference</param>
    /// <param name="config">Configuration containing Azure OpenAI settings</param>
    /// <param name="mcpFactory">Factory for creating MCP client connections</param>
    public MedicalQueryAgent(AzureOpenAIClient openAiClient, IConfiguration config, MedicalMcpClientFactory mcpFactory)
    {
        _openAiClient = openAiClient;
        _mcpFactory = mcpFactory;

        // Get deployment name from config (defaults to "gpt-4o")
        // This should be a model that supports function/tool calling
        _deploymentName = config["Azure:OpenAI:DeploymentName"] ?? "gpt-4o";
    }

    /// <summary>
    /// Lazily creates the agent with MCP tools loaded.
    /// Tools are passed at agent creation time per Microsoft Agent Framework pattern.
    /// </summary>
    /// <remarks>
    /// <para><b>Agent Creation Flow (Microsoft Agent Framework):</b></para>
    /// <para>
    /// 1. Get the OpenAI ChatClient from AzureOpenAIClient.GetChatClient()
    /// 2. Convert to IChatClient using AsIChatClient() extension method
    /// 3. Create an AIAgent using AsAIAgent() extension method with tools
    /// </para>
    /// 
    /// <para><b>⚠️ API Stability Warning:</b></para>
    /// <para>
    /// The extension methods used here are from preview packages and may change:
    /// - AsIChatClient(): From Microsoft.Extensions.AI.OpenAI - converts OpenAI ChatClient to IChatClient
    /// - AsAIAgent(): From Microsoft.Agents.AI - creates a ChatClientAgent that implements AIAgent
    /// Future versions may rename these methods or change their signatures.
    /// </para>
    /// </remarks>
    private async Task<AIAgent> GetAgentAsync(CancellationToken ct = default)
    {
        // Return cached agent if already created
        // AIAgent instances are designed to be reused across multiple conversations.
        // Each conversation uses a separate AgentThread to maintain isolation.
        if (_agent is not null)
        {
            return _agent;
        }

        // ============================================================================
        // STEP 1: Load MCP Tools from the MCP Server
        // ============================================================================
        // MCP (Model Context Protocol) tools are external functions that the agent
        // can invoke. In this case, they're database query tools served by our
        // MedicalDbMcpServer project.
        var mcpClient = await _mcpFactory.GetClientAsync(ct).ConfigureAwait(false);
        var mcpTools = await mcpClient.ListToolsAsync(cancellationToken: ct).ConfigureAwait(false);

        // ============================================================================
        // STEP 2: Create the AIAgent using Extension Method Chain
        // ============================================================================
        // This creates a ChatClientAgent (which implements AIAgent) through a fluent
        // extension method chain. The ChatClientAgent wraps an IChatClient and adds:
        // - Tool/function calling with automatic invocation
        // - Conversation thread management
        // - System instruction injection
        // 
        // Extension Method Breakdown:
        // 
        // GetChatClient(_deploymentName)
        //   └─> Returns OpenAI.Chat.ChatClient (OpenAI SDK type)
        //       This is the Azure OpenAI chat completion client for the specified deployment
        //
        // .AsIChatClient()  [Microsoft.Extensions.AI.OpenAI package]
        //   └─> Returns Microsoft.Extensions.AI.IChatClient
        //       This adapts the OpenAI ChatClient to the M.E.AI abstraction layer,
        //       enabling framework-agnostic AI operations
        //
        // .AsAIAgent(...)   [Microsoft.Agents.AI package]
        //   └─> Returns Microsoft.Agents.AI.AIAgent (specifically ChatClientAgent)
        //       This wraps the IChatClient in an agent that can:
        //       - Execute tools automatically when the LLM requests them
        //       - Manage conversation context via AgentThread
        //       - Apply system instructions to each inference call
        //
        // ⚠️ Note: AsAIAgent() may be renamed to CreateAIAgent() in future versions.
        //    Check the latest Microsoft.Agents.AI documentation for current API.
        _agent = _openAiClient
            .GetChatClient(_deploymentName)     // OpenAI ChatClient for Azure OpenAI
            .AsIChatClient()                    // Adapt to M.E.AI IChatClient interface
            .AsAIAgent(                         // Create AIAgent with agent capabilities
                instructions: Instructions,     // System prompt for agent behavior
                name: "MedicalRecordsAgent",    // Agent name for logging/identification
                tools: [.. mcpTools.Cast<AITool>()]); // Tools the agent can invoke
        // Note: The spread operator [.. collection] creates a new collection from mcpTools.
        // MCP tools implement AITool, making them compatible with the Agent Framework.

        return _agent;
    }

    /// <summary>
    /// Processes a natural language query using AI with MCP database tools.
    /// Creates a new conversation thread for each request (stateless/single-turn).
    /// </summary>
    /// <param name="userMessage">The user's natural language query about patient data</param>
    /// <param name="ct">Cancellation token for async operations</param>
    /// <returns>The agent's text response after processing tools and generating output</returns>
    /// <remarks>
    /// <para><b>How Agent Execution Works:</b></para>
    /// <para>
    /// When RunAsync is called, the Agent Framework:
    /// 1. Creates a ChatMessage with the user's input
    /// 2. Sends it to the LLM with available tools and system instructions
    /// 3. If the LLM requests tool calls, automatically invokes them
    /// 4. Feeds tool results back to the LLM
    /// 5. Repeats steps 3-4 until the LLM produces a final response
    /// 6. Returns the final response in AgentRunResponse
    /// </para>
    /// 
    /// <para><b>Single-turn vs Multi-turn:</b></para>
    /// <para>
    /// This method creates a new AgentThread for each call, meaning no conversation
    /// history is preserved between calls. For multi-turn conversations where
    /// context should be maintained, use <see cref="QueryWithThreadAsync"/>.
    /// </para>
    /// </remarks>
    public async Task<string> QueryAsync(string userMessage, CancellationToken ct = default)
    {
        var agent = await GetAgentAsync(ct).ConfigureAwait(false);

        // ============================================================================
        // AgentThread - Conversation State Management
        // ============================================================================
        // AgentThread is the abstraction for conversation state in Agent Framework.
        // Key concepts:
        // - AIAgent instances are STATELESS - they don't remember past conversations
        // - AgentThread holds ALL state: message history, context, tool call results
        // - The same agent can be used with multiple threads simultaneously
        // - Thread can store messages in-memory or reference remote storage
        //
        // GetNewThreadAsync() creates a fresh thread with no history.
        // For services like Azure AI Foundry agents, this may create server-side state.
        var thread = await agent.GetNewThreadAsync(ct).ConfigureAwait(false);

        // ============================================================================
        // RunAsync - Execute the Agent
        // ============================================================================
        // RunAsync is the primary method for agent invocation. It:
        // 1. Wraps the user message as a ChatMessage with User role
        // 2. Adds it to the thread's message history
        // 3. Calls the underlying IChatClient with tools and instructions
        // 4. Handles tool calls automatically (invoke tool → feed result → repeat)
        // 5. Adds the assistant's response to the thread
        // 6. Returns AgentRunResponse with the final output
        //
        // ⚠️ RunAsync has multiple overloads accepting:
        //    - string message (convenience - shown here)
        //    - ChatMessage (for custom message properties)
        //    - IEnumerable<ChatMessage> (for multi-message input)
        var response = await agent.RunAsync(
            userMessage,            // User input - wrapped as ChatMessage internally
            thread,                 // Conversation state - updated with input/output
            cancellationToken: ct).ConfigureAwait(false);

        // AgentRunResponse.Text contains the final text output from the agent.
        // For structured output, use RunAsync<T> with a response schema.
        return response.Text ?? "I couldn't generate a response.";
    }

    /// <summary>
    /// Processes a query with an existing conversation thread for multi-turn conversations.
    /// This enables context-aware conversations where the agent remembers previous exchanges.
    /// </summary>
    /// <param name="userMessage">The user's natural language query</param>
    /// <param name="existingThread">
    /// An existing AgentThread to continue the conversation, or null to start fresh.
    /// Pass the thread returned from a previous call to maintain context.
    /// </param>
    /// <param name="ct">Cancellation token</param>
    /// <returns>
    /// A tuple containing:
    /// - Response: The agent's text response
    /// - Thread: The updated AgentThread (pass this to subsequent calls)
    /// </returns>
    /// <remarks>
    /// <para><b>Multi-turn Conversation Pattern:</b></para>
    /// <code>
    /// // First turn - creates new thread
    /// var (response1, thread) = await agent.QueryWithThreadAsync("What conditions does patient 1 have?");
    /// 
    /// // Second turn - continues conversation with context
    /// var (response2, thread) = await agent.QueryWithThreadAsync("What medications are they on?", thread);
    /// // Agent knows "they" refers to patient 1 from the previous turn
    /// </code>
    /// 
    /// <para><b>Thread Persistence:</b></para>
    /// <para>
    /// AgentThread can be serialized and stored for later use, enabling:
    /// - Session persistence across service restarts
    /// - Conversation handoff between agents
    /// - Audit logging of conversation history
    /// </para>
    /// 
    /// <para><b>⚠️ Memory Considerations:</b></para>
    /// <para>
    /// The thread accumulates all messages and tool results. For very long conversations,
    /// consider implementing conversation summarization or message pruning strategies.
    /// </para>
    /// </remarks>
    public async Task<(string Response, AgentThread Thread)> QueryWithThreadAsync(
        string userMessage,
        AgentThread? existingThread = null,
        CancellationToken ct = default)
    {
        var agent = await GetAgentAsync(ct).ConfigureAwait(false);

        // Use existing thread or create new one.
        // When reusing a thread, all previous messages are included in the context
        // sent to the LLM, enabling contextual understanding of follow-up questions.
        var thread = existingThread ?? await agent.GetNewThreadAsync(ct).ConfigureAwait(false);

        // Run the agent with MCP tools.
        // The thread is mutated (updated in-place) with:
        // - The user's input message
        // - Any tool calls and their results
        // - The assistant's final response
        var response = await agent.RunAsync(
            userMessage,
            thread,
            cancellationToken: ct).ConfigureAwait(false);

        // Return both the response text and the thread.
        // The caller should store the thread if they want to continue the conversation.
        return (response.Text ?? "I couldn't generate a response.", thread);
    }
}
