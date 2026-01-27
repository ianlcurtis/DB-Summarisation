# DB-Summarisation

.NET Aspire application featuring an MCP server that exposes patient medical history from SQL Server to AI assistants like GitHub Copilot, with an Agent Framework-based API for querying medical data.

## Options
Below are a few options for achieving the goal, this repo demonstrates the Agent Framework option. Detailed comments about the Agent Framework implementation can be found in the code. 
> Note: This is a simple use case that could be achieved without the Agent Framework. I'm using it here as a demonstration.
![HLArch](img/HLArch.png)

## Prerequisites

- [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Quick Start

### 1. Open in Dev Container

```bash
git clone https://github.com/ianlcurtis/DB-Summarisation.git
code DB-Summarisation
```

When prompted, click **"Reopen in Container"** and wait for it to build.

### 2. Create Database

```bash
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -Q "CREATE DATABASE PatientMedicalHistory"
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -d PatientMedicalHistory -i db/patient_medical_history_database.sql
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -d PatientMedicalHistory -i db/patient_medical_history_data.sql
```

### 3. Use with Copilot

The MCP server is pre-configured in `.vscode/mcp.json`. Reload VS Code (`Ctrl+Shift+P` → **Developer: Reload Window**) and ask Copilot:

- "Get the medical history for patient 1"
- "Show patient 3's medications"
- "What are patient 5's lab results between 2020-01-01 and 2023-12-31?"

## Available MCP Tools

| Tool | Description |
|------|-------------|
| `GetPatientMedicalHistory` | Complete medical history for a patient |
| `GetPatientMedicalHistoryBetweenDates` | Medical history filtered by date range |

## Configuration

### Required Settings

| Setting | Location | Description |
|---------|----------|-------------|
| SQL Server Connection | `appsettings.json` | Database connection string (pre-configured for dev container) |
| Azure OpenAI Connection | User Secrets | Required for Aspire app - endpoint and API key |
| Azure OpenAI Deployment | `appsettings.json` | Model deployment name (default: `gpt-4o`) |

### SQL Server Connection String

The database connection is pre-configured for the dev container environment:

**Dev Container (default):**
- AppHost uses server name `db` (the container name)
- MCP Server standalone uses `localhost`

If running outside the dev container, update `ConnectionStrings:MedicalDb` in the appropriate `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "MedicalDb": "Server=<your-server>;Database=PatientMedicalHistory;User Id=sa;Password=<your-password>;TrustServerCertificate=True;"
  }
}
```

### Azure OpenAI Configuration (Required for Aspire App)

1. **Set the connection string** (includes endpoint and key):

```bash
cd src/MedicalAgent.AppHost
dotnet user-secrets set "ConnectionStrings:openai" "Endpoint=https://<your-resource>.openai.azure.com/;Key=<your-key>"
```

2. **Set the deployment name** (optional - defaults to `gpt-4o`):

Edit `src/MedicalAgent.Api/appsettings.json`:

```json
{
  "Azure": {
    "OpenAI": {
      "DeploymentName": "your-deployment-name"
    }
  }
}
```

### MCP Server Configuration for Copilot

The MCP server is pre-configured in `.vscode/mcp.json` for use with GitHub Copilot:

```jsonc
{
  "servers": {
    "medical-db-mcp-server": {
      "type": "stdio",
      "command": "dotnet",
      "args": ["run", "--project", "${workspaceFolder}/src/MedicalDbMcpServer/MedicalDbMcpServer.csproj", "--", "--stdio"],
      "env": {
        "MEDICAL_DB_CONNECTION_STRING": "Server=localhost;Database=PatientMedicalHistory;..."
      }
    }
  }
}
```

Update `MEDICAL_DB_CONNECTION_STRING` if your database connection differs from the default.

## Running the Aspire App

```bash
# Run (from solution root)
dotnet run --project src/MedicalAgent.AppHost
```

### Aspire Dashboard

When the app starts, the dashboard URL appears in the console (typically `https://localhost:17178`). The dashboard provides:

- **Resources** - View status of all services (MedicalAgent.Api, MedicalDbMcpServer)
- **Console** - Live logs from each service
- **Traces** - Distributed tracing across services
- **Metrics** - Performance metrics and health status

### Service URLs

| Service | URL |
|---------|-----|
| Aspire Dashboard | `https://localhost:17178` |
| Medical Agent API | `http://localhost:5000` |
| MCP Server | `http://localhost:8080/mcp` |

Chat API: `POST http://localhost:5000/api/chat` with `{"message": "your query"}`

For a quick test, use [api-tests.http](src/MedicalAgent.Api/api-tests.http) in VS Code with the REST Client extension.

## Running MCP Server Only

```bash
cd src/MedicalDbMcpServer
dotnet run
```

HTTP transport available at `http://localhost:8080/mcp`.

## License

See [LICENSE](LICENSE) for details.