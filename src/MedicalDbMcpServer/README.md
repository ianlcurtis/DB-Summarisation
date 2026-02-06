# MedicalDbMcpServer

.NET 8 MCP server exposing patient medical history data to AI assistants.

## Configuration

Set connection string via:
- `ConnectionStrings:MedicalDb` in appsettings.json
- `MEDICAL_DB_CONNECTION_STRING` environment variable

## Microsoft Entra ID Authentication (Optional)

The HTTP transport mode can be protected with Microsoft Entra ID (Azure AD) authentication. **Authentication is only enabled when the `AzureAd:ClientId` configuration value is set.**

### Local Development (No Authentication)

By default, `appsettings.json` has empty AzureAd values, so authentication is disabled for local development and testing:

```json
{
  "AzureAd": {
    "Instance": "",
    "TenantId": "",
    "ClientId": "",
    "Audience": ""
  }
}
```

### Production (With Authentication)

To enable Entra authentication:

1. **Register an application in Microsoft Entra ID:**
   ```bash
   az ad app create --display-name "MedicalDbMcpServer" --sign-in-audience AzureADMyOrg
   ```

2. **Note the Application (client) ID** from the output and configure:
   ```json
   {
     "AzureAd": {
       "Instance": "https://login.microsoftonline.com/",
       "TenantId": "YOUR_TENANT_ID",
       "ClientId": "YOUR_CLIENT_ID",
       "Audience": "api://YOUR_CLIENT_ID"
     }
   }
   ```

3. **Expose an API scope:**
   ```bash
   az ad app update --id YOUR_CLIENT_ID --identifier-uris "api://YOUR_CLIENT_ID"
   ```

4. **For Azure deployment**, use the `-EnableEntraAuth` flag with the deployment script, or configure these environment variables:
   - `AzureAd__TenantId`
   - `AzureAd__ClientId`
   - `AzureAd__Audience`

### Client Authentication

When authentication is enabled, clients must:
1. Acquire a token for the `api://YOUR_CLIENT_ID` audience
2. Include the token in the Authorization header: `Authorization: Bearer <access_token>`

## Transport Modes

- **Stdio** (VS Code): `dotnet run -- --stdio` (no authentication)
- **HTTP/SSE** (local): `dotnet run` → `http://localhost:5100/` (no authentication by default)
- **HTTP/SSE** (cloud): Deploy with `-EnableEntraAuth` flag (requires Entra authentication)

## Tools

| Tool | Description |
|------|-------------|
| `GetPatientMedicalHistory` | Complete patient history by ID |
| `GetPatientMedicalHistoryBetweenDates` | History filtered by date range |

## Docker

```bash
docker build -t medical-mcp-server .
docker run -p 8080:8080 \
  -e ConnectionStrings__MedicalDb='...' \
  -e AzureAd__TenantId='YOUR_TENANT_ID' \
  -e AzureAd__ClientId='YOUR_CLIENT_ID' \
  -e AzureAd__Audience='api://YOUR_CLIENT_ID' \
  medical-mcp-server
```
