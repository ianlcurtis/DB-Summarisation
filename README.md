# DB-Summarisation

.NET Aspire application featuring an MCP server that exposes patient medical history from SQL Server to AI assistants like GitHub Copilot, with an Agent Framework-based API for querying medical data.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fianlcurtis%2FDB-Summarisation%2Fmain%2Finfra%2Fazuredeploy.bicep)

## Deploy to Azure

The button above deploys all required Azure infrastructure and applications automatically:

| Resource | Description |
|----------|-------------|
| Azure Container Registry | Hosts container images |
| Azure SQL Server + Database | Patient medical history data (Entra-only auth) |
| Azure OpenAI + GPT-4o | AI model for the agent |
| Container Apps Environment | Hosts the application containers |
| Log Analytics Workspace | Monitoring and diagnostics |
| MCP Server Container App | Exposes patient data via MCP protocol |
| Agent API Container App | AI agent endpoint for queries |
| Web Frontend Container App | React UI for interacting with the agent |

**Required parameters:**
- `sqlAdminObjectId` - Your Entra user/group Object ID (find via `az ad signed-in-user show --query id`)
- `sqlAdminDisplayName` - Your Entra display name

**After deployment**, complete these manual steps:

1. **Initialize the database** - Connect to the SQL Server and run the scripts:
   ```bash
   # Using sqlcmd or Azure Data Studio, connect to your SQL Server and run:
   # db/patient_medical_history_database.sql
   # db/patient_medical_history_data.sql
   ```

2. **Grant SQL access to MCP Server** - Run this SQL command:
   ```sql
   CREATE USER [medmcp-{env}-mcp] FROM EXTERNAL PROVIDER;
   ALTER ROLE db_datareader ADD MEMBER [medmcp-{env}-mcp];
   ```

Access the web app at the URL shown in the deployment outputs (`webAppUrl`).

### Deploy with Azure Developer CLI (azd)

Alternatively, use `azd` for a streamlined CLI experience:

```bash
# Install azd if not already installed
# https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd

# Clone and deploy
git clone https://github.com/ianlcurtis/DB-Summarisation.git
cd DB-Summarisation
azd auth login
azd up
```

You'll be prompted for:
- Environment name (e.g., `dev`)
- Azure subscription
- Azure region
- SQL admin Object ID and display name

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

### 4. Run the Aspire App (Optional)

Configure your Azure OpenAI connection:

```bash
cd src/MedicalAgent.AppHost
dotnet user-secrets set "ConnectionStrings:openai" "Endpoint=https://<your-resource>.openai.azure.com/;Key=<your-key>"
```

Run the application:

```bash
dotnet run
```

The Aspire Dashboard URL appears in the console where you can view service status, logs, and traces.

## Available MCP Tools

| Tool | Description |
|------|-------------|
| `GetPatientMedicalHistory` | Complete medical history for a patient |
| `GetPatientMedicalHistoryBetweenDates` | Medical history filtered by date range |

## Configuration

### SQL Server Connection String

The database connection is pre-configured for the dev container:
- **AppHost**: Uses server name `db` (the container name)
- **MCP Server standalone**: Uses `localhost`

If running outside the dev container, update `ConnectionStrings:MedicalDb` in the appropriate `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "MedicalDb": "Server=<your-server>;Database=PatientMedicalHistory;User Id=sa;Password=<your-password>;TrustServerCertificate=True;"
  }
}
```

### Azure OpenAI Configuration (Aspire App Only)

The Aspire app requires Azure OpenAI. Configure via user secrets (see [Step 4](#4-run-the-aspire-app-optional)).

To change the deployment name (defaults to `gpt-4o`), edit `src/MedicalAgent.Api/appsettings.json`:

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

The MCP server is pre-configured in `.vscode/mcp.json`. Update `MEDICAL_DB_CONNECTION_STRING` if your database connection differs.

## Aspire Dashboard

When the Aspire app starts, the dashboard URL appears in the console. The dashboard provides:

- **Resources** - View status of all services (MedicalAgent.Api, MedicalDbMcpServer)
- **Console** - Live logs from each service
- **Traces** - Distributed tracing across services
- **Metrics** - Performance metrics and health status

### Service Endpoints

| Service | URL |
|---------|-----|
| Medical Agent API | `http://localhost:5000` |
| MCP Server | `http://localhost:8080/mcp` |

**Chat API**: `POST http://localhost:5000/api/chat` with `{"message": "your query"}`

For a quick test, use [api-tests.http](src/MedicalAgent.Api/api-tests.http) in VS Code with the REST Client extension.

## Running MCP Server Only

```bash
cd src/MedicalDbMcpServer
dotnet run
```

HTTP transport available at `http://localhost:8080/mcp`.

## License

See [LICENSE](LICENSE) for details.