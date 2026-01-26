## Plan: .NET Aspire App with MCP Server and Agent Framework

Create a .NET Aspire orchestrated application that enables natural language queries against the patient medical database. The app will use Microsoft.Extensions.AI Agent Framework to coordinate between an Azure OpenAI model and the existing MedicalDbMcpServer, exposing a REST API for chat-based medical record queries.

### Steps

1. **Create `MedicalAgent.AppHost` project** — Add Aspire orchestrator that references SQL Server, the existing MCP server (src/MedicalDbMcpServer/Program.cs), and a new agent API project with `WithReference()` dependencies.

2. **Create `MedicalAgent.ServiceDefaults` project** — Add shared configuration for OpenTelemetry, health checks, and service discovery following Aspire conventions.

3. **Create `MedicalAgent.Api` project** — Build an API service with `MedicalQueryAgent` class that uses `IChatClient` (Azure OpenAI) and `IMcpClient` to connect to the MCP server, retrieving `McpClientTool` objects as `AIFunction` for automatic tool invocation.

4. **Update MedicalDbMcpServer** — Reference ServiceDefaults project and switch to `Aspire.Microsoft.Data.SqlClient` for connection string injection from Aspire.

5. **Configure Azure OpenAI integration** — Use `Aspire.Azure.AI.OpenAI` package with `ChatClientBuilder` pipeline including `UseFunctionInvocation()` and `UseOpenTelemetry()`.

6. **Add chat endpoint** — Expose `POST /api/chat` in MedicalAgent.Api that accepts natural language queries and returns responses from the orchestrated agent.

### Configuration Decisions

- **Azure OpenAI** — Use existing Azure-hosted model resource (configure via connection string/endpoint in appsettings)
- **MCP transport** — Keep HTTP/SSE for Aspire service discovery compatibility
- **Frontend** — API-only (no web UI)
