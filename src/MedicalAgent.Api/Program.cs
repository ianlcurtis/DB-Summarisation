// =============================================================================
// MEDICAL AGENT API - Aspire-Orchestrated Service
// =============================================================================
// This API is orchestrated by the AppHost project. Aspire provides:
//   - Automatic service discovery (finds MCP server by name)
//   - Connection string injection (Azure OpenAI configured automatically)
//   - OpenTelemetry integration (logs, metrics, traces to dashboard)
//   - Health check endpoints (used by orchestrators)
// =============================================================================

using System.Collections.Concurrent;
using MedicalAgent.Api;
using Microsoft.Agents.AI;

var builder = WebApplication.CreateBuilder(args);

// =============================================================================
// ASPIRE SERVICE DEFAULTS
// =============================================================================
// AddServiceDefaults() is the key integration point with Aspire. It configures:
//   - OpenTelemetry: Logs, metrics, and traces sent to Aspire dashboard
//   - Service Discovery: Resolve "http://mcp-server" to actual endpoint
//   - Health Checks: /health and /alive endpoints for orchestrators
//   - Resilient HTTP: Automatic retries and circuit breakers
// 
// This single call enables full observability in the Aspire dashboard.
builder.AddServiceDefaults();

// =============================================================================
// AZURE OPENAI INTEGRATION
// =============================================================================
// AddAzureOpenAIClient reads the connection string injected by Aspire AppHost.
// The AppHost declared: builder.AddConnectionString("openai")
// This injects the connection string as ConnectionStrings:openai in config.
// 
// The connection string format: Endpoint=https://xxx.openai.azure.com;Key=xxx
// This is automatically parsed and configured by the Azure SDK.
builder.AddAzureOpenAIClient("openai");

// =============================================================================
// HTTP CLIENT WITH SERVICE DISCOVERY
// =============================================================================
// Configure an HttpClient to communicate with the MCP server.
// Thanks to Aspire's service discovery (configured in AddServiceDefaults),
// we can use the logical service name "mcp-server" as the URL.
// 
// At runtime, Aspire resolves "http://mcp-server" to the actual endpoint
// (e.g., https://localhost:5001). This works in local dev and when deployed.
builder.Services.AddHttpClient("mcp-server", client =>
{
    // Use the service name from the AppHost: "mcp-server"
    // Aspire's service discovery resolves this to the actual URL
    client.BaseAddress = new Uri("http://mcp-server");
});

// =============================================================================
// APPLICATION SERVICES
// =============================================================================

// Register MCP client factory as singleton
// This manages the Model Context Protocol connection with reconnection logic
builder.Services.AddSingleton<MedicalMcpClientFactory>();

// Register the AI agent as scoped (one per request)
// Uses the shared MCP connection to query patient data
builder.Services.AddScoped<MedicalQueryAgent>();

// Thread store for multi-turn conversations
// ConcurrentDictionary provides thread-safe storage
// NOTE: In production, use a distributed cache (Redis) for scalability
builder.Services.AddSingleton<ConcurrentDictionary<string, AgentThread>>();

// =============================================================================
// HEALTH CHECKS
// =============================================================================
// Add a health check for the MCP server dependency.
// This check is used by the /health endpoint (readiness probe).
// If MCP server is down, this service reports as "not ready".
builder.Services.AddHealthChecks()
    .AddCheck<McpServerHealthCheck>("mcp-server", tags: ["ready"]);

var app = builder.Build();

// =============================================================================
// ASPIRE HEALTH ENDPOINTS
// =============================================================================
// MapDefaultEndpoints() adds the health check endpoints:
//   /health - Readiness probe (all checks must pass)
//   /alive  - Liveness probe (minimal check - is process alive?)
// 
// These are automatically monitored in the Aspire dashboard and used
// by Kubernetes or other orchestrators to manage container lifecycle.
app.MapDefaultEndpoints();

// =============================================================================
// API ENDPOINTS
// =============================================================================

// Single-turn chat endpoint for natural language medical queries
// Usage: POST /api/chat with { "message": "What medications is patient 1 on?" }
app.MapPost("/api/chat", async (ChatRequest request, MedicalQueryAgent agent) =>
{
    var response = await agent.QueryAsync(request.Message).ConfigureAwait(false);
    return Results.Ok(new ChatResponse(response));
});

// Multi-turn conversation endpoint using Microsoft Agent Framework
// Maintains conversation context across multiple requests via thread storage
// Usage: POST /api/chat/conversation with { "message": "...", "conversationId": "..." }
app.MapPost("/api/chat/conversation", async (
    ConversationRequest request,
    MedicalQueryAgent agent,
    ConcurrentDictionary<string, AgentThread> threadStore) =>
{
    AgentThread? existingThread = null;

    // Look up existing conversation thread if ID provided
    if (!string.IsNullOrEmpty(request.ConversationId))
    {
        threadStore.TryGetValue(request.ConversationId, out existingThread);
    }

    // Process query with conversation thread for context
    var (response, thread) = await agent.QueryWithThreadAsync(
        request.Message,
        existingThread).ConfigureAwait(false);

    // Generate or reuse conversation ID
    var conversationId = request.ConversationId ?? Guid.NewGuid().ToString();

    // Persist thread for future conversation turns
    threadStore[conversationId] = thread;

    return Results.Ok(new ConversationResponse(response, conversationId));
});

// =============================================================================
// RUN THE APPLICATION
// =============================================================================
// When run via the AppHost, Aspire orchestrates startup order:
// 1. SQL Server (from devcontainer) - already running
// 2. MCP Server - waits for database
// 3. Agent API - waits for MCP Server (due to WaitFor in AppHost)
await app.RunAsync();

// =============================================================================
// REQUEST/RESPONSE MODELS
// =============================================================================

/// <summary>
/// Request model for single-turn chat endpoint.
/// </summary>
public sealed record ChatRequest(string Message);

/// <summary>
/// Response model for single-turn chat endpoint.
/// </summary>
public sealed record ChatResponse(string Response);

/// <summary>
/// Request model for multi-turn conversation endpoint.
/// ConversationId is optional for the first message in a conversation.
/// </summary>
public sealed record ConversationRequest(string Message, string? ConversationId = null);

/// <summary>
/// Response model for multi-turn conversation endpoint.
/// Returns the ConversationId to use in subsequent requests.
/// </summary>
public sealed record ConversationResponse(string Response, string ConversationId);
