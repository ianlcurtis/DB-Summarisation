// Main Bicep template for Medical Aspire Application deployment
// Deploys: Container Apps Environment, MCP Server, and Agent API with Entra Authentication
// Prerequisites: 
//   - ACR must be deployed first using acr.bicep
//   - Images must be pushed before running this
//   - Entra App Registration must be created for MCP Server

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

@description('MCP Server container image name (without registry prefix)')
param mcpImageName string = 'medical-mcp-server'

@description('Agent API container image name (without registry prefix)')
param agentApiImageName string = 'medical-agent-api'

@description('Container image tag to deploy')
param imageTag string = 'latest'

@description('SQL Server fully qualified domain name')
param sqlServerFqdn string

@description('SQL Database name')
param sqlDatabaseName string

@description('Microsoft Entra ID Tenant ID')
param entraTenantId string

@description('Microsoft Entra ID Client ID for MCP Server (the app to be protected)')
param mcpServerClientId string

@description('Microsoft Entra ID Audience/App ID URI for MCP Server')
param mcpServerAudience string = ''

@description('Azure OpenAI endpoint URL')
param azureOpenAiEndpoint string

@description('Azure OpenAI deployment name')
param azureOpenAiDeploymentName string = 'gpt-4o'

@description('Tags to apply to all resources')
param tags object = {
  project: 'medical-aspire'
  environment: environmentName
}

// ============================================================================
// Variables
// ============================================================================

var containerAppsEnvName = '${baseName}-${environmentName}-env'
var mcpServerAppName = '${baseName}-${environmentName}-mcp'
var agentApiAppName = '${baseName}-${environmentName}-api'
var logAnalyticsName = '${baseName}-${environmentName}-logs'
var mcpServerImageFullName = '${acrLoginServer}/${mcpImageName}:${imageTag}'
var agentApiImageFullName = '${acrLoginServer}/${agentApiImageName}:${imageTag}'

// Connection string for Entra authentication (Managed Identity)
var sqlConnectionString = 'Server=tcp:${sqlServerFqdn},1433;Database=${sqlDatabaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'

// Entra audience - use the client ID if no specific audience is provided
var effectiveMcpAudience = !empty(mcpServerAudience) ? mcpServerAudience : 'api://${mcpServerClientId}'

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
// MCP Server Container App (with Entra Authentication)
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
        // Internal ingress - only accessible within the Container Apps environment
        external: false
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
          image: mcpServerImageFullName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ConnectionStrings__MedicalDb'
              value: sqlConnectionString
            }
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
              value: mcpServerClientId
            }
            {
              name: 'AzureAd__Audience'
              value: effectiveMcpAudience
            }
          ]
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
// Agent API Container App (Calling MCP Server with Managed Identity)
// ============================================================================

resource agentApiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: agentApiAppName
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
        // External ingress - publicly accessible
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
          name: 'agent-api'
          image: agentApiImageFullName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            // Azure OpenAI connection (using Managed Identity)
            {
              name: 'ConnectionStrings__openai'
              value: 'Endpoint=${azureOpenAiEndpoint}'
            }
            {
              name: 'Azure__OpenAI__DeploymentName'
              value: azureOpenAiDeploymentName
            }
            // MCP Server connection using internal Container Apps DNS
            {
              name: 'McpServer__Endpoint'
              value: 'https://${mcpServerApp.properties.configuration.ingress.fqdn}'
            }
            // Entra auth configuration for acquiring tokens to call MCP Server
            {
              name: 'McpServer__EntraAuth__Enabled'
              value: 'true'
            }
            {
              name: 'McpServer__EntraAuth__TenantId'
              value: entraTenantId
            }
            {
              name: 'McpServer__EntraAuth__Scope'
              value: '${effectiveMcpAudience}/.default'
            }
          ]
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
        maxReplicas: 5
        rules: [
          {
            name: 'http-scale'
            http: {
              metadata: {
                concurrentRequests: '50'
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

@description('The name of the Agent API Container App')
output agentApiAppName string = agentApiApp.name

@description('The internal FQDN of the MCP Server (for container-to-container communication)')
output mcpServerInternalFqdn string = mcpServerApp.properties.configuration.ingress.fqdn

@description('The external FQDN of the Agent API')
output agentApiFqdn string = agentApiApp.properties.configuration.ingress.fqdn

@description('The Agent API endpoint URL')
output agentApiEndpointUrl string = 'https://${agentApiApp.properties.configuration.ingress.fqdn}'

@description('The principal ID of the MCP Server managed identity')
output mcpServerPrincipalId string = mcpServerApp.identity.principalId

@description('The principal ID of the Agent API managed identity (needs SQL access)')
output agentApiPrincipalId string = agentApiApp.identity.principalId
