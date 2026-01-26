var builder = DistributedApplication.CreateBuilder(args);

// Use existing SQL Server from devcontainer (Server=db, SA password from env)
// Connection string configured via environment or appsettings
var medicalDbConnectionString = builder.AddConnectionString("MedicalDb");

// MCP Server - exposes patient data tools via HTTP/SSE
var mcpServer = builder.AddProject<Projects.MedicalDbMcpServer>("mcp-server")
    .WithReference(medicalDbConnectionString);

// Azure OpenAI connection (configured via user secrets or environment)
var openai = builder.AddConnectionString("openai");

// Agent API - orchestrates AI queries with MCP tools
builder.AddProject<Projects.MedicalAgent_Api>("agent-api")
    .WithReference(mcpServer)      // Service discovery for MCP server
    .WithReference(openai)         // Azure OpenAI connection
    .WaitFor(mcpServer);

builder.Build().Run();
