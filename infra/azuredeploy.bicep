// ============================================================================
// Azure Infrastructure Template for Medical MCP Server
// ============================================================================
// This template deploys the core infrastructure:
// - Azure Container Registry (ACR)
// - Azure SQL Server with Entra-only authentication
// - Azure SQL Database
// - Azure OpenAI with GPT-4o deployment
// - Container Apps Environment with Log Analytics
//
// Container Apps are created by azd during the deploy phase.
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name suffix (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name prefix for resources')
param baseName string = 'medmcp'

@description('Object ID of the Entra user/group to be SQL admin')
param sqlAdminObjectId string

@description('Display name of the Entra user/group to be SQL admin')
param sqlAdminDisplayName string

@description('Type of the Entra identity for SQL admin')
@allowed(['User', 'Group'])
param sqlAdminType string = 'User'

@description('GPT-4o model capacity (tokens per minute in thousands)')
@minValue(1)
@maxValue(100)
param gpt4oCapacity int = 10

@description('Tags to apply to all resources')
param tags object = {
  project: 'medical-mcp-server'
  environment: environmentName
}

// ============================================================================
// Variables
// ============================================================================

var resourceToken = toLower(uniqueString(resourceGroup().id, baseName, environmentName))
var envNameAlphanumeric = replace(environmentName, '-', '')
var acrName = '${baseName}${envNameAlphanumeric}acr${take(resourceToken, 6)}'
var sqlServerName = '${baseName}-${environmentName}-sql-${take(resourceToken, 6)}'
var databaseName = 'PatientMedicalHistory'
var openAiAccountName = '${baseName}-${environmentName}-openai'
var customSubDomainName = '${baseName}${envNameAlphanumeric}openai${take(resourceToken, 4)}'
var containerAppsEnvName = '${baseName}-${environmentName}-env'
var logAnalyticsName = '${baseName}-${environmentName}-logs'

// ============================================================================
// Azure Container Registry
// ============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// Azure SQL Server (Entra-only Authentication)
// ============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminDisplayName
      principalType: sqlAdminType
      sid: sqlAdminObjectId
      tenantId: subscription().tenantId
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    version: '12.0'
  }
}

// Allow Azure services to access SQL Server
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// Azure SQL Database (Serverless)
// ============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    autoPauseDelay: 60
    minCapacity: json('0.5')
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ============================================================================
// Azure OpenAI Account
// ============================================================================

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiAccountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
  }
}

// ============================================================================
// GPT-4o Model Deployment
// ============================================================================

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAiAccount
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: gpt4oCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// ============================================================================
// Log Analytics Workspace
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
// Container Apps
// ============================================================================

resource mcpServerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${baseName}-${environmentName}-mcp-server'
  location: location
  tags: union(tags, {
    'azd-service-name': 'mcp-server'
  })
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
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'sql-connection-string'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-server'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ConnectionStrings__MedicalDb'
              secretRef: 'sql-connection-string'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

resource agentApiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${baseName}-${environmentName}-agent-api'
  location: location
  tags: union(tags, {
    'azd-service-name': 'agent-api'
  })
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [mcpServerApp]
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
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'agent-api'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ConnectionStrings__openai'
              value: 'Endpoint=${openAiAccount.properties.endpoint}'
            }
            {
              name: 'OpenAi__Endpoint'
              value: openAiAccount.properties.endpoint
            }
            {
              name: 'OpenAi__DeploymentName'
              value: 'gpt-4o'
            }
            {
              name: 'McpServer__Endpoint'
              value: 'https://${mcpServerApp.properties.configuration.ingress.fqdn}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

resource webApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${baseName}-${environmentName}-web'
  location: location
  tags: union(tags, {
    'azd-service-name': 'web'
  })
  dependsOn: [agentApiApp]
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'API_URL'
              value: 'https://${agentApiApp.properties.configuration.ingress.fqdn}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

// ============================================================================
// Role Assignments
// ============================================================================

// Cognitive Services OpenAI User role for Agent API to access Azure OpenAI
resource agentApiOpenAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiAccount.id, agentApiApp.id, 'CognitiveServicesOpenAIUser')
  scope: openAiAccount
  properties: {
    principalId: agentApiApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Azure Container Registry name')
output acrName string = containerRegistry.name

@description('Azure Container Registry login server')
output acrLoginServer string = containerRegistry.properties.loginServer

@description('SQL Server fully qualified domain name')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Server name')
output sqlServerName string = sqlServer.name

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabase.name

@description('SQL connection string (Entra auth)')
output sqlConnectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'

@description('Azure OpenAI endpoint')
output openAiEndpoint string = openAiAccount.properties.endpoint

@description('Azure OpenAI deployment name')
output openAiDeploymentName string = gpt4oDeployment.name

@description('Container Apps Environment name')
output containerAppsEnvName string = containerAppsEnvironment.name

@description('Container Apps Environment ID')
output containerAppsEnvId string = containerAppsEnvironment.id

// azd-compatible outputs (AZURE_ prefix for environment variables)
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.id
output AZURE_OPENAI_ENDPOINT string = openAiAccount.properties.endpoint
output AZURE_SQL_SERVER string = sqlServer.properties.fullyQualifiedDomainName
output AZURE_SQL_DATABASE string = databaseName
output AZURE_WEB_URL string = 'https://${webApp.properties.configuration.ingress.fqdn}'
output AZURE_AGENT_API_URL string = 'https://${agentApiApp.properties.configuration.ingress.fqdn}'
output AZURE_MCP_SERVER_URL string = 'https://${mcpServerApp.properties.configuration.ingress.fqdn}'
output AZURE_MCP_SERVER_APP_NAME string = mcpServerApp.name
