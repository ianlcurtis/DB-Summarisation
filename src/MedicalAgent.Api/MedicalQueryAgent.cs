using Azure.AI.OpenAI;
using Microsoft.Extensions.AI;
using ModelContextProtocol.Client;

namespace MedicalAgent.Api;

/// <summary>
/// Agent that orchestrates Azure OpenAI with MCP tools for medical queries.
/// Uses automatic function invocation to call MCP tools transparently.
/// </summary>
public sealed class MedicalQueryAgent
{
    private readonly IChatClient _chatClient;
    private readonly MedicalMcpClientFactory _mcpFactory;

    // System prompt guiding the AI to use medical database tools
    private const string SystemPrompt = """
        You are a helpful medical records assistant with access to a patient database.
        When users ask about patient information, use the available tools to query the database.
        Always be accurate and cite specific data from the records.
        If a patient ID is needed but not provided, ask the user for it.
        Format responses clearly with relevant medical information organized by category.
        """;

    public MedicalQueryAgent(AzureOpenAIClient openAiClient, IConfiguration config, MedicalMcpClientFactory mcpFactory)
    {
        _mcpFactory = mcpFactory;

        // Get deployment name from config (defaults to "gpt-4o")
        var deploymentName = config["Azure:OpenAI:DeploymentName"] ?? "gpt-4o";

        // Build chat client with function invocation and telemetry
        // GetChatClient + AsIChatClient converts OpenAI ChatClient to Microsoft.Extensions.AI.IChatClient
        _chatClient = new ChatClientBuilder(
            openAiClient.GetChatClient(deploymentName).AsIChatClient())
            .UseFunctionInvocation()  // Enable automatic tool calling
            .UseOpenTelemetry()       // Add observability
            .Build();
    }

    /// <summary>
    /// Processes a natural language query using AI with MCP database tools.
    /// </summary>
    public async Task<string> QueryAsync(string userMessage, CancellationToken ct = default)
    {
        // Get shared MCP client connection (singleton with reconnection support)
        var mcpClient = await _mcpFactory.GetClientAsync(ct).ConfigureAwait(false);

        // Fetch available tools from MCP server - McpClientTool extends AIFunction
        var mcpTools = await mcpClient.ListToolsAsync(cancellationToken: ct).ConfigureAwait(false);

        // Configure chat with MCP tools (they implement AITool)
        var options = new ChatOptions
        {
            Tools = mcpTools.Cast<AITool>().ToList()
        };

        // Build conversation with system context (using Microsoft.Extensions.AI types)
        var messages = new List<Microsoft.Extensions.AI.ChatMessage>
        {
            new(ChatRole.System, SystemPrompt),
            new(ChatRole.User, userMessage)
        };

        // Execute chat - function invocation middleware handles tool calls automatically
        var response = await _chatClient.GetResponseAsync(messages, options, ct).ConfigureAwait(false);

        return response.Text ?? "I couldn't generate a response.";
    }
}
