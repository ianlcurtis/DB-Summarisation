# DB-Summarisation

MCP server that exposes patient medical history from SQL Server to AI assistants like GitHub Copilot.

## Options
Below are a few options for achieving the goal, this repo demonstrates the Agent Framework option.
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

## Running Manually

```bash
cd src/MedicalDbMcpServer
dotnet run
```

For HTTP transport (cloud deployment), the server runs on `http://localhost:8080/mcp`.

## License

See [LICENSE](LICENSE) for details.