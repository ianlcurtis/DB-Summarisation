# MedicalDbMcpServer

.NET 8 MCP server exposing patient medical history data to AI assistants.

## Configuration

Set connection string via:
- `ConnectionStrings:MedicalDb` in appsettings.json
- `MEDICAL_DB_CONNECTION_STRING` environment variable

## Transport Modes

- **Stdio** (VS Code): `dotnet run -- --stdio`
- **HTTP/SSE** (cloud): `dotnet run` → `http://localhost:8080/mcp`

## Tools

| Tool | Description |
|------|-------------|
| `GetPatientMedicalHistory` | Complete patient history by ID |
| `GetPatientMedicalHistoryBetweenDates` | History filtered by date range |

## Docker

```bash
docker build -t medical-mcp-server .
docker run -p 8080:8080 -e ConnectionStrings__MedicalDb='...' medical-mcp-server
```
