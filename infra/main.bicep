// Main Bicep template for MedicalDbMcpServer deployment
// Deploys: Container Apps Environment and MCP Server Container App
// NOTE: ACR must be deployed first using acr.bicep, and image pushed before running this

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name suffix (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = 'swedencentral'

@description('Base name prefix for resources')
param baseName string = 'medmcp'

@description('The name of the existing Azure Container Registry')
param acrName string

@description('The login server of the existing Azure Container Registry')
param acrLoginServer string

@description('Container image name (without registry prefix)')
param imageName string = 'medical-mcp-server'

@description('Container image tag to deploy')
param imageTag string = 'latest'

@description('SQL Server fully qualified domain name (optional - for database connectivity)')
param sqlServerFqdn string = ''

@description('SQL Database name (optional - for database connectivity)')
param sqlDatabaseName string = ''

@description('Enable Microsoft Entra ID authentication')
param entraEnabled bool = false

@description('Microsoft Entra ID Tenant ID (required if entraEnabled is true)')
param entraTenantId string = ''

@description('Microsoft Entra ID App Client ID (required if entraEnabled is true)')
param entraClientId string = ''

@description('Microsoft Entra ID Audience/App ID URI (required if entraEnabled is true)')
param entraAudience string = ''

@description('Tags to apply to all resources')
param tags object = {
  project: 'medical-mcp-server'
  environment: environmentName
}

// ============================================================================
// Variables
// ============================================================================

var containerAppsEnvName = '${baseName}-${environmentName}-env'
var mcpServerAppName = '${baseName}-${environmentName}-mcp'
var logAnalyticsName = '${baseName}-${environmentName}-logs'
var fullImageName = '${acrLoginServer}/${imageName}:${imageTag}'

// Connection string for Entra authentication (Managed Identity)
var sqlConnectionString = !empty(sqlServerFqdn) ? 'Server=tcp:${sqlServerFqdn},1433;Database=${sqlDatabaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;' : ''

// Build environment variables array
var baseEnvVars = []
var sqlEnvVars = !empty(sqlConnectionString) ? [
  {
    name: 'ConnectionStrings__MedicalDb'
    value: sqlConnectionString
  }
] : []
var entraEnvVars = entraEnabled ? [
  {
    name: 'AzureAd__Instance'
    value: environment().authentication.loginEndpoint
  }
  {
    name: 'AzureAd__TenantId'
    value: entraTenantId
  }
  {
    name: 'AzureAd__ClientId'
    value: entraClientId
  }
  {
    name: 'AzureAd__Audience'
    value: entraAudience
  }
] : []
var allEnvVars = concat(baseEnvVars, sqlEnvVars, entraEnvVars)

// ============================================================================
// Existing ACR reference (for credentials)
// ============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
  name: acrName
}

// ============================================================================
// Log Analytics Workspace (required for Container Apps Environment)
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ============================================================================
// Container Apps Environment
// ============================================================================

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// ============================================================================
// MCP Server Container App
// ============================================================================

resource mcpServerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: mcpServerAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          username: acrName
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-server'
          image: fullImageName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: allEnvVars
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/alive'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the Container Apps Environment')
output containerAppsEnvName string = containerAppsEnvironment.name

@description('The name of the MCP Server Container App')
output mcpServerAppName string = mcpServerApp.name

@description('The FQDN of the MCP Server')
output mcpServerFqdn string = mcpServerApp.properties.configuration.ingress.fqdn

@description('The MCP endpoint URL')
output mcpEndpointUrl string = 'https://${mcpServerApp.properties.configuration.ingress.fqdn}/sse'

@description('The principal ID of the MCP Server managed identity')
output mcpServerPrincipalId string = mcpServerApp.identity.principalId

@description('SQL connection string configured (empty if not configured)')
output sqlConnectionConfigured string = !empty(sqlConnectionString) ? 'Configured' : 'Not configured'

@description('Entra authentication configured')
output entraAuthConfigured string = entraEnabled ? 'Enabled' : 'Disabled'
