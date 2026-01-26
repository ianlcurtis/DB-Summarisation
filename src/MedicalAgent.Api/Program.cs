using MedicalAgent.Api;

var builder = WebApplication.CreateBuilder(args);

// Add Aspire service defaults (telemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Register Azure OpenAI chat client from Aspire configuration
builder.AddAzureOpenAIClient("openai");

// Configure HttpClient for MCP server with Aspire service discovery
builder.Services.AddHttpClient("mcp-server", client =>
{
    // Aspire service discovery resolves "http://mcp-server" to the actual endpoint
    client.BaseAddress = new Uri("http://mcp-server");
});

// Register MCP client manager as singleton (manages shared connection with reconnection logic)
builder.Services.AddSingleton<MedicalMcpClientFactory>();

// Register agent as scoped (uses shared MCP connection)
builder.Services.AddScoped<MedicalQueryAgent>();

// Add health check for MCP server dependency
builder.Services.AddHealthChecks()
    .AddCheck<McpServerHealthCheck>("mcp-server", tags: ["ready"]);

var app = builder.Build();

// Map Aspire health check endpoints
app.MapDefaultEndpoints();

// Chat endpoint for natural language medical queries
app.MapPost("/api/chat", async (ChatRequest request, MedicalQueryAgent agent) =>
{
    var response = await agent.QueryAsync(request.Message).ConfigureAwait(false);
    return Results.Ok(new ChatResponse(response));
});

await app.RunAsync();

/// <summary>
/// Request model for chat endpoint.
/// </summary>
public sealed record ChatRequest(string Message);

/// <summary>
/// Response model for chat endpoint.
/// </summary>
public sealed record ChatResponse(string Response);
