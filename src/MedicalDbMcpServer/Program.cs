using MedicalDbMcpServer.Data;
using MedicalDbMcpServer.Tools;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

// Determine transport mode from command-line args or environment variable
var useStdio = args.Contains("--stdio") || 
    Environment.GetEnvironmentVariable("MCP_TRANSPORT")?.Equals("stdio", StringComparison.OrdinalIgnoreCase) == true;

if (useStdio)
{
    // Stdio transport for local development (VS Code, Claude Desktop, etc.)
    var builder = Host.CreateApplicationBuilder(args);
    
    // Disable console logging for stdio mode (stdout is reserved for MCP protocol)
    builder.Logging.ClearProviders();
    
    // Explicitly add configuration files for stdio mode
    builder.Configuration
        .SetBasePath(AppContext.BaseDirectory)
        .AddJsonFile("appsettings.json", optional: true)
        .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
        .AddEnvironmentVariables();
    
    var connectionString = builder.Configuration.GetConnectionString("MedicalDb")
        ?? Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
        ?? throw new InvalidOperationException("Connection string not configured. Set 'ConnectionStrings:MedicalDb' or 'MEDICAL_DB_CONNECTION_STRING' environment variable.");

    builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

    builder.Services
        .AddMcpServer()
        .WithStdioServerTransport()
        .WithTools<PatientHistoryTools>();

    await builder.Build().RunAsync();
}
else
{
    // HTTP transport for cloud/container deployment
    var builder = WebApplication.CreateBuilder(args);

    // Add Aspire service defaults (telemetry, health checks, service discovery)
    builder.AddServiceDefaults();

    var connectionString = builder.Configuration.GetConnectionString("MedicalDb")
        ?? Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
        ?? throw new InvalidOperationException("Connection string not configured. Set 'ConnectionStrings:MedicalDb' or 'MEDICAL_DB_CONNECTION_STRING' environment variable.");

    builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

    builder.Services
        .AddMcpServer()
        .WithHttpTransport()
        .WithTools<PatientHistoryTools>();

    var app = builder.Build();

    // Map Aspire health check endpoints
    app.MapDefaultEndpoints();

    app.MapMcp();

    await app.RunAsync();
}
