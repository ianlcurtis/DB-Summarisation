## Plan: Unified RBAC for MCP Server Supporting M365 Copilot & Semantic Kernel

Add a unified RBAC layer to the MedicalDbMcpServer that extracts user identity from Azure AD tokens (from either M365 Copilot or Semantic Kernel) and enforces role/permission-based access to patient data before queries execute.

### Steps

1. **Add HTTP transport and auth packages** in [MedicalDbMcpServer.csproj](src/MedicalDbMcpServer/MedicalDbMcpServer.csproj) — add `Microsoft.Identity.Web`, `Microsoft.AspNetCore.Authentication.JwtBearer`, and configure HTTP/SSE transport alongside existing STDIO.

2. **Create user context abstraction** — add `IUserContextProvider` interface and `AzureAdUserContextProvider` implementation under `src/MedicalDbMcpServer/Auth/` to extract `UserId`, `TenantId`, `Roles`, and `Groups` from validated JWT claims.

3. **Implement authorization service** — create `IAuthorizationService` with `RbacAuthorizationService` that checks role-to-resource mappings loaded from configuration (`appsettings.json`).

4. **Integrate authorization into tools** — inject `IUserContextProvider` and `IAuthorizationService` into [PatientHistoryTools](src/MedicalDbMcpServer/Tools/PatientHistoryTools.cs) and add authorization checks before each database query.

5. **Configure DI and middleware** — update [Program.cs](src/MedicalDbMcpServer/Program.cs) to register auth services, add JWT bearer authentication, and wire up RBAC options from configuration.

6. **Add RBAC configuration section** — create role/permission mappings in `appsettings.json` defining which roles can access which patient data entities.

### Decisions

1. **Transport mode:** Dual-mode with environment-based selection — STDIO for local dev, HTTP/SSE for M365 Copilot and Semantic Kernel.

2. **Access model:** Clinical staff only — RBAC based on existing staff roles (e.g., Doctor, Nurse, LabTechnician). No patient self-access required.

3. **Audit logging:** Follow-up phase — add structured logging of tool invocations with user identity after core RBAC is implemented.
