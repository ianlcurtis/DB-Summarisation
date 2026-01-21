using MedicalDbMcpServer.Data;
using MedicalDbMcpServer.Tools;

var builder = WebApplication.CreateBuilder(args);

// Get connection string from configuration or environment variable
var connectionString = builder.Configuration.GetConnectionString("MedicalDb")
    ?? Environment.GetEnvironmentVariable("MEDICAL_DB_CONNECTION_STRING")
    ?? throw new InvalidOperationException("Connection string not configured. Set 'ConnectionStrings:MedicalDb' or 'MEDICAL_DB_CONNECTION_STRING' environment variable.");

// Register database connection factory
builder.Services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));

// Configure MCP server with HTTP transport and tools
builder.Services
    .AddMcpServer()
    .WithHttpTransport()
    .WithTools<PatientHistoryTools>();

var app = builder.Build();

app.MapMcp();

await app.RunAsync();
