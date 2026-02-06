# Medical Agent - .NET Aspire Application

A .NET Aspire orchestrated application that enables natural language queries against the patient medical database using Azure OpenAI and MCP (Model Context Protocol).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MedicalAgent.AppHost                         │
│                    (Aspire Orchestrator)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
    ┌─────────────────────────┼─────────────────────────┐
    │              │          │          │              │
    ▼              ▼          ▼          ▼              ▼
┌─────────┐ ┌───────────┐ ┌─────────┐ ┌─────────┐ ┌───────────┐
│   SQL   │ │ MedicalDb │ │ Medical │ │  Azure  │ │  React    │
│ Server  │◄┤ McpServer │◄┤ Agent   │─┤ OpenAI  │ │  Web UI   │
│         │ │           │ │  .Api   │ │ (gpt-4o)│ │           │
└─────────┘ └───────────┘ └─────────┘ └─────────┘ └───────────┘
                 ▲              │                      │
                 │              │                      │
           HTTP/SSE         Chat API              Calls API
        (MCP Protocol)      Endpoint             (via CORS)
```

## Projects

| Project | Description |
|---------|-------------|
| `MedicalAgent.AppHost` | Aspire orchestrator - entry point that wires up all services |
| `MedicalAgent.ServiceDefaults` | Shared configuration for OpenTelemetry, health checks, resilience |
| `MedicalAgent.Api` | REST API with chat endpoint, AI agent using Azure OpenAI + MCP |
| `MedicalDbMcpServer` | MCP server exposing patient database tools via HTTP/SSE |
| `MedicalAgent.Web` | React frontend for the chat interface |

## Prerequisites

- .NET 8.0 SDK
- Node.js 20+ (for React frontend)
- Docker (for SQL Server container)
- Azure OpenAI resource with a deployed model (e.g., gpt-4o)
- .NET Aspire workload: `dotnet workload install aspire`

## Configuration

### Azure OpenAI Connection

Set up your Azure OpenAI connection string using user secrets:

```bash
cd src/MedicalAgent.AppHost
dotnet user-secrets set "ConnectionStrings:openai" "Endpoint=https://<your-resource>.openai.azure.com/;Key=<your-key>"
```

Or set the deployment name if different from `gpt-4o`:

```bash
dotnet user-secrets set "Azure:OpenAI:DeploymentName" "your-deployment-name"
```

## Running the Application

```bash
# From solution root
dotnet run --project src/MedicalAgent.AppHost
```

This will:
1. Start the Aspire dashboard (opens in browser)
2. Start SQL Server container with MedicalDb
3. Start the MCP server with patient data tools
4. Start the Agent API with chat endpoint

## API Usage

### POST /api/chat

Send natural language queries about patient medical records:

```bash
curl -X POST http://localhost:5000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What medications is patient 1 currently taking?"}'
```

**Response:**
```json
{
  "response": "Patient John Doe (ID: 1) is currently taking the following medications..."
}
```

### Example Queries

- "Get the complete medical history for patient 1"
- "What conditions was patient 2 diagnosed with in 2024?"
- "Show me the lab results for patient 3 between January and March 2024"
- "List all allergies for patient 1"

## Health Endpoints

- `/health` - Readiness probe (all health checks)
- `/alive` - Liveness probe

## Observability

The application uses OpenTelemetry for:
- **Metrics**: HTTP, ASP.NET Core, Runtime, SQL Client
- **Tracing**: Distributed traces across all services
- **Logging**: Structured logging with correlation

View telemetry in the Aspire Dashboard at `https://localhost:17178`.
