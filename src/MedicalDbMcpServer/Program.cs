// ============================================================================
// MCP (Model Context Protocol) Server - Entry Point
// ============================================================================
//
// This is the main entry point for the MCP server. It configures and starts
// the server which exposes tools that AI applications can call.
//
// Transport Modes:
// ----------------
// MCP supports different "transports" (communication methods):
//
// 1. STDIO (Standard Input/Output):
//    - Used for local development and desktop AI apps
//    - The AI host launches this process and communicates via stdin/stdout
//    - Examples: VS Code Copilot, Claude Desktop, local development
//    - Configured in mcp.json or settings.json
//
// 2. HTTP (Streamable HTTP):
//    - Used for cloud/container deployment
//    - The server runs as a web service, AI clients connect via HTTP
//    - Better for production, scaling, and remote access
//    - Can be deployed to Azure App Service, containers, etc.
//
// Reference: https://learn.microsoft.com/en-us/dotnet/ai/get-started-mcp
// ============================================================================

using MedicalDbMcpServer.Data;
using MedicalDbMcpServer.Tools;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

// ============================================================================
// TRANSPORT SELECTION
// ============================================================================
// Determine which transport mode to use based on command-line args or environment.
// When VS Code or Claude Desktop launches the server, they typically pass --stdio
// to indicate they want to communicate via standard input/output streams.
var useStdio = args.Contains("--stdio") || 
    Environment.GetEnvironmentVariable("MCP_TRANSPORT")?.Equals("stdio", StringComparison.OrdinalIgnoreCase) == true;

if (useStdio)
{
    // ========================================================================
    // STDIO TRANSPORT MODE
    // ========================================================================
    // Used when AI hosts like VS Code Copilot or Claude Desktop launch this 
    // process directly. Communication happens through stdin (receiving requests)
    // and stdout (sending responses).
    //
    // IMPORTANT: In stdio mode, stdout is reserved for MCP protocol messages.
    // Any console logging would corrupt the protocol, so we disable it.
    // ========================================================================
    
    var builder = Host.CreateApplicationBuilder(args);
    
    // CRITICAL: Disable all console logging in stdio mode
    // The stdout stream is used exclusively for MCP JSON-RPC messages.
    // If we log anything to stdout, it would corrupt the protocol communication.
    builder.Logging.ClearProviders();
    
    // Explicitly configure where to find configuration files
    // In stdio mode, the working directory may not be where the app is located
    builder.Configuration
        .SetBasePath(AppContext.BaseDirectory)
        .AddJsonFile("appsettings.json", optional: true)
        .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
        .AddEnvironmentVariables();
    
    // Get the database connection string from configuration or environment
    var connectionString = builder.Configuration.GetConnectionString("MedicalDb")
        ?? Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
        ?? throw new InvalidOperationException("Connection string not configured. Set 'ConnectionStrings:MedicalDb' or 'MEDICAL_DB_CONNECTION_STRING' environment variable.");

    // Register our database connection factory for dependency injection
    builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

    // ========================================================================
    // MCP SERVER REGISTRATION (STDIO)
    // ========================================================================
    // This is where the MCP magic happens:
    //
    // AddMcpServer() - Registers the MCP server infrastructure with DI
    //
    // WithStdioServerTransport() - Configures stdio transport:
    //   - Reads JSON-RPC requests from stdin
    //   - Writes JSON-RPC responses to stdout
    //   - Used by desktop AI apps that launch this process
    //
    // WithTools<PatientHistoryTools>() - Registers our tool class:
    //   - Scans the class for [McpServerTool] methods
    //   - Exposes them as callable tools to AI clients
    //   - Handles tool discovery (ListToolsRequest) and invocation (CallToolRequest)
    // ========================================================================
    builder.Services
        .AddMcpServer()
        .WithStdioServerTransport()
        .WithTools<PatientHistoryTools>();

    // Build and run the host - it will listen for MCP messages on stdin
    await builder.Build().RunAsync();
}
else
{
    // ========================================================================
    // HTTP TRANSPORT MODE
    // ========================================================================
    // Used for cloud/container deployment where the server runs as a web service.
    // AI clients connect via HTTP to the /mcp endpoint.
    //
    // Benefits of HTTP transport:
    // - Can be deployed to Azure App Service, Kubernetes, containers
    // - Supports multiple concurrent clients
    // - Easier to monitor and debug
    // - Can add authentication, rate limiting, etc.
    // ========================================================================
    
    var builder = WebApplication.CreateBuilder(args);

    // Add .NET Aspire service defaults (optional but recommended)
    // This adds telemetry, health checks, and service discovery features
    builder.AddServiceDefaults();

    // Get the database connection string
    var connectionString = builder.Configuration.GetConnectionString("MedicalDb")
        ?? Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
        ?? throw new InvalidOperationException("Connection string not configured. Set 'ConnectionStrings:MedicalDb' or 'MEDICAL_DB_CONNECTION_STRING' environment variable.");

    builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

    // ========================================================================
    // MCP SERVER REGISTRATION (HTTP)
    // ========================================================================
    // Similar to stdio mode, but uses HTTP transport:
    //
    // WithHttpTransport() - Configures streamable HTTP transport:
    //   - Listens for HTTP requests on the /mcp endpoint
    //   - Uses Server-Sent Events (SSE) for streaming responses
    //   - Better suited for cloud deployment
    //
    // Note: When using HTTP transport, you may need to configure CORS
    // if the AI client is browser-based (e.g., web-based AI tools).
    // ========================================================================
    builder.Services
        .AddMcpServer()
        .WithHttpTransport()
        .WithTools<PatientHistoryTools>();

    var app = builder.Build();

    // Map Aspire health check endpoints (/health, /alive, etc.)
    app.MapDefaultEndpoints();

    // ========================================================================
    // MAP THE MCP ENDPOINT
    // ========================================================================
    // This exposes the MCP server at the default /mcp endpoint.
    // AI clients will send HTTP requests to: https://your-server/mcp
    //
    // You can customise the path: app.MapMcp("/api/mcp");
    // ========================================================================
    app.MapMcp();

    await app.RunAsync();
}
