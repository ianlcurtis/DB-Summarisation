# DB-Summarisation

A project for managing and summarising patient medical history data using SQL Server.

## Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine on Linux)

## Getting Started

### 1. Open in Dev Container

1. Clone the repository:
   ```bash
   git clone https://github.com/ianlcurtis/DB-Summarisation.git
   cd DB-Summarisation
   ```

2. Open the folder in VS Code:
   ```bash
   code .
   ```

3. When prompted, click **"Reopen in Container"**, or use the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and select **"Dev Containers: Reopen in Container"**.

4. Wait for the container to build. This will:
   - Start a .NET 8.0 development environment
   - Launch a SQL Server 2022 instance with the following credentials:
     - **Server**: `localhost`
     - **Port**: `1433`
     - **Username**: `sa`
     - **Password**: `YourStrong@Passw0rd`

### 2. Create the Database

Once the dev container is running, execute the SQL scripts to create the database and tables:

```bash
# Create the database
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -Q "CREATE DATABASE PatientMedicalHistory"

# Create tables and read-only user
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -d PatientMedicalHistory -i db/patient_medical_history_database.sql
```

This creates the following tables:
- **Patients** - Core patient information
- **MedicalConditions** - Patient diagnoses and conditions
- **Medications** - Prescribed medications
- **Allergies** - Patient allergies
- **MedicalVisits** - Medical appointments and visits
- **LabResults** - Laboratory test results

### 3. Load Sample Data

To populate the database with synthetic patient data for testing and development:

```bash
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -d PatientMedicalHistory -i db/patient_medical_history_data.sql
```

This inserts:
- **12 Patients** - Diverse demographics with UK addresses
- **32 Medical Conditions** - Including chronic diseases, mental health conditions, and autoimmune disorders
- **40 Medications** - Common prescriptions, specialty medications, and PRN drugs
- **14 Allergies** - Drug, food, and environmental allergies with severity levels
- **33 Medical Visits** - Routine, emergency, specialist, and follow-up visits
- **44 Lab Results** - Common labs and disease-specific tests with reference ranges

### 4. Verify the Setup

To confirm the tables were created successfully:

```bash
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "YourStrong@Passw0rd" -C -d PatientMedicalHistory -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
```

## MCP Server for Copilot Integration

This project includes a Model Context Protocol (MCP) server that allows GitHub Copilot to query patient medical history data.

### Building the MCP Server

```bash
cd src/MedicalDbMcpServer
dotnet build
```

### Available Tools

The MCP server exposes two read-only tools:

| Tool | Description |
|------|-------------|
| `GetPatientMedicalHistory` | Retrieves complete medical history for a patient including demographics, conditions, medications, allergies, visits, and lab results |
| `GetPatientMedicalHistoryBetweenDates` | Retrieves patient medical history filtered by date range |

### Testing with Copilot

1. **Reload VS Code** after opening the project (Ctrl+Shift+P → "Developer: Reload Window") to register the MCP server from `.vscode/mcp.json`

2. **Ask Copilot** to query patient data:
   - "Get the medical history for patient 1"
   - "What are patient 4's medical conditions?"
   - "Show me patient 2's records between 2015-01-01 and 2020-12-31"
   - "List all medications for patient 8"

### Security

The MCP server uses a dedicated read-only SQL user (`mcp_readonly_user`) with:
- **SELECT** permissions only on all tables
- **DENY** on INSERT, UPDATE, DELETE operations
- Parameterized queries to prevent SQL injection

## Database Schema

The database uses a relational model to track patient medical history:

```
Patients (1) ──────┬──── (N) MedicalConditions
                   ├──── (N) Medications
                   ├──── (N) Allergies
                   ├──── (N) MedicalVisits ──── (N) LabResults
                   └──── (N) LabResults
```

## License

See [LICENSE](LICENSE) for details.