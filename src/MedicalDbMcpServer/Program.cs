using MedicalDbMcpServer.Data;
using MedicalDbMcpServer.Tools;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = Host.CreateApplicationBuilder(args);

// Get connection string from environment variable
var connectionString = Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
    ?? throw new InvalidOperationException("MEDICAL_DB_CONNECTION_STRING environment variable is not set.");

// Register database connection factory
builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

// Configure MCP server with STDIO transport and tools
builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithTools<PatientHistoryTools>();

var host = builder.Build();
await host.RunAsync();
