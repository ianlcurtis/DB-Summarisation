using './aspire-main.bicep'

// ============================================================================
// Environment configuration
// ============================================================================
param environmentName = 'dev'
param location = 'swedencentral'
param baseName = 'medmcp'
param imageTag = 'latest'

// ============================================================================
// Container Registry (must exist - deploy acr.bicep first)
// ============================================================================
param acrName = '<your-acr-name>'
param acrLoginServer = '<your-acr-name>.azurecr.io'

// ============================================================================
// SQL Database Configuration
// ============================================================================
param sqlServerFqdn = '<your-sql-server>.database.windows.net'
param sqlDatabaseName = 'PatientMedicalHistory'

// ============================================================================
// Microsoft Entra ID Configuration
// 
// To set up Entra authentication:
// 1. Create an App Registration in Azure Portal for the MCP Server
// 2. Set "Application ID URI" (e.g., api://<client-id>)
// 3. Add an "app" role for client applications
// 4. Grant the Agent API's managed identity permission to call the MCP Server
// ============================================================================
param entraTenantId = '<your-tenant-id>'
param mcpServerClientId = '<mcp-server-app-client-id>'
param mcpServerAudience = '' // Leave empty to use api://<client-id>

// ============================================================================
// Azure OpenAI Configuration
// ============================================================================
param azureOpenAiEndpoint = 'https://<your-openai>.openai.azure.com/'
param azureOpenAiDeploymentName = 'gpt-4o'

// ============================================================================
// Tags
// ============================================================================
param tags = {
  project: 'medical-aspire'
  environment: 'dev'
  deployedBy: 'bicep'
}
