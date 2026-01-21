## Plan: Implement Read-Only MCP Server for Patient Medical History

Build a C#/.NET MCP server using STDIO transport that exposes two read-only tools (`get_patient_medical_history` and `get_patient_medical_history_between_dates`) to query the existing PatientMedicalHistory database with parameterized queries for SQL injection prevention.

### Steps

1. **Create project structure** at `/src/MedicalDbMcpServer` with folders: `/Data`, `/Tools`, `/Models`, `/Queries` — add `MedicalDbMcpServer.csproj` referencing `ModelContextProtocol`, `Microsoft.Data.SqlClient`, and `Microsoft.Extensions.Hosting`.

2. **Define model records** in `/Models` for `Patient`, `MedicalCondition`, `Medication`, `Allergy`, `MedicalVisit`, `LabResult`, and a composite `PatientMedicalHistory` record aggregating all related data.

3. **Implement database layer** in `/Data` with `IDbConnectionFactory` interface and `SqlConnectionFactory` class using async connection opening with `ConfigureAwait(false)`.

4. **Create `PatientHistoryTools` class** in `/Tools` with `[McpServerToolType]` attribute containing:
   - `get_patient_medical_history(patientId: int)` — fetches complete patient history across all 6 tables
   - `get_patient_medical_history_between_dates(patientId: int, startDate: DateTime, endDate: DateTime)` — filters visits, conditions, medications, and lab results by date range

5. **Wire up Program.cs** with `Host.CreateApplicationBuilder`, register `IDbConnectionFactory`, configure MCP server with `.WithStdioServerTransport()` and `.WithTools<PatientHistoryTools>()`.

6. **Add VS Code integration** by creating `.vscode/mcp.json` to register the MCP server for local testing with Copilot.

### Design Decisions

1. **Date filtering scope**: Date range filter applies to all entities — `MedicalVisits.VisitDate`, `LabResults.TestDate`, `MedicalConditions.DiagnosisDate`, and `Medications.StartDate`.

2. **Response format**: Return as structured JSON object for programmatic consumption.

3. **Connection string configuration**: Use environment variable `MEDICAL_DB_CONNECTION_STRING` (not passed via args).

4. **Read-only enforcement**: Create a dedicated SQL login (`mcp_readonly_user`) with read-only permissions in the database creation script. This login should have `SELECT` permissions only on all tables, with no `INSERT`, `UPDATE`, or `DELETE` rights.

### Additional Step

7. **Update database creation script** (`db/patient_medical_history_database.sql`) to create a read-only SQL login and user with `SELECT`-only permissions on all tables.
