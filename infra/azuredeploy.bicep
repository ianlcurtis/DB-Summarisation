// ============================================================================
// Unified Azure Deployment Template for Medical MCP Server
// ============================================================================
// This template deploys all infrastructure and applications:
// - Azure Container Registry (ACR)
// - Azure SQL Server with Entra-only authentication
// - Azure SQL Database with schema and sample data
// - Azure OpenAI with GPT-4o deployment
// - Container Apps Environment with Log Analytics
// - MCP Server and Agent API Container Apps
// 
// Post-deployment scripts automatically:
// - Create database schema and load sample data
// - Build and push container images from GitHub
// - Deploy the container applications
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

@description('GitHub repository URL for source code')
param gitHubRepoUrl string = 'https://github.com/ianlcurtis/DB-Summarisation.git'

@description('GitHub branch to build from')
param gitHubBranch string = 'main'

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
var acrName = '${baseName}${environmentName}acr${take(resourceToken, 6)}'
var sqlServerName = '${baseName}-${environmentName}-sql-${take(resourceToken, 6)}'
var databaseName = 'PatientMedicalHistory'
var openAiAccountName = '${baseName}-${environmentName}-openai'
var customSubDomainName = '${baseName}${environmentName}openai${take(resourceToken, 4)}'
var containerAppsEnvName = '${baseName}-${environmentName}-env'
var logAnalyticsName = '${baseName}-${environmentName}-logs'
var deploymentScriptIdentityName = '${baseName}-${environmentName}-deploy-id'
var mcpServerAppName = '${baseName}-${environmentName}-mcp'
var agentApiAppName = '${baseName}-${environmentName}-api'

// Connection string for Entra authentication (Managed Identity)
var sqlConnectionString = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'

// ============================================================================
// User-Assigned Managed Identity for Deployment Scripts
// ============================================================================

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: deploymentScriptIdentityName
  location: location
  tags: tags
}

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

// ACR Push role for deployment script identity
resource acrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, deploymentScriptIdentity.id, 'acrpush')
  scope: containerRegistry
  properties: {
    principalId: deploymentScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush
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
// Deployment Script: Initialize Database Schema and Data
// ============================================================================

resource sqlInitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${baseName}-${environmentName}-sql-init'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'SQL_SERVER'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'SQL_DATABASE'
        value: databaseName
      }
      {
        name: 'GITHUB_REPO'
        value: gitHubRepoUrl
      }
      {
        name: 'GITHUB_BRANCH'
        value: gitHubBranch
      }
      {
        name: 'SQL_TOKEN_RESOURCE'
        #disable-next-line no-hardcoded-env-urls
        value: 'https://database.windows.net/'
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      echo "Installing sqlcmd..."
      curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
      curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
      apt-get update
      ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev git

      echo "Cloning repository..."
      git clone --branch $GITHUB_BRANCH --depth 1 $GITHUB_REPO /tmp/repo

      echo "Getting access token for SQL..."
      ACCESS_TOKEN=$(az account get-access-token --resource $SQL_TOKEN_RESOURCE --query accessToken -o tsv)

      echo "Running database schema script..."
      /opt/mssql-tools18/bin/sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G -C --access-token "$ACCESS_TOKEN" -i /tmp/repo/db/patient_medical_history_database.sql

      echo "Running database data script..."
      /opt/mssql-tools18/bin/sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G -C --access-token "$ACCESS_TOKEN" -i /tmp/repo/db/patient_medical_history_data.sql

      echo "Database initialization complete!"
    '''
  }
  dependsOn: [
    sqlDatabase
    sqlFirewallRule
  ]
}

// ============================================================================
// Deployment Script: Build and Push Container Images
// ============================================================================

resource acrBuildScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${baseName}-${environmentName}-acr-build'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: containerRegistry.name
      }
      {
        name: 'GITHUB_REPO'
        value: gitHubRepoUrl
      }
      {
        name: 'GITHUB_BRANCH'
        value: gitHubBranch
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      echo "Building MCP Server image in ACR..."
      az acr build \
        --registry $ACR_NAME \
        --image medical-mcp-server:latest \
        --file src/MedicalDbMcpServer/Dockerfile \
        $GITHUB_REPO#$GITHUB_BRANCH

      echo "Building Agent API image in ACR..."
      az acr build \
        --registry $ACR_NAME \
        --image medical-agent-api:latest \
        --file src/MedicalAgent.Api/Dockerfile \
        $GITHUB_REPO#$GITHUB_BRANCH

      echo "Container images built and pushed successfully!"
    '''
  }
  dependsOn: [
    acrPushRole
  ]
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
        external: false
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
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
          name: 'mcp-server'
          image: '${containerRegistry.properties.loginServer}/medical-mcp-server:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ConnectionStrings__MedicalDb'
              value: sqlConnectionString
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
  dependsOn: [
    acrBuildScript
    sqlInitScript
  ]
}

// ============================================================================
// Deployment Script: Grant SQL Access to MCP Server
// ============================================================================

resource sqlGrantScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${baseName}-${environmentName}-sql-grant'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'SQL_SERVER'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'SQL_DATABASE'
        value: databaseName
      }
      {
        name: 'MCP_SERVER_PRINCIPAL_ID'
        value: mcpServerApp.identity.principalId
      }
      {
        name: 'MCP_SERVER_APP_NAME'
        value: mcpServerAppName
      }
      {
        name: 'SQL_TOKEN_RESOURCE'
        #disable-next-line no-hardcoded-env-urls
        value: 'https://database.windows.net/'
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      echo "Installing sqlcmd..."
      curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
      curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
      apt-get update
      ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev

      echo "Getting access token for SQL..."
      ACCESS_TOKEN=$(az account get-access-token --resource $SQL_TOKEN_RESOURCE --query accessToken -o tsv)

      echo "Granting SQL access to MCP Server managed identity..."
      /opt/mssql-tools18/bin/sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G -C --access-token "$ACCESS_TOKEN" -Q "
        IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$MCP_SERVER_APP_NAME')
        BEGIN
          CREATE USER [$MCP_SERVER_APP_NAME] WITH SID = CONVERT(varbinary(16), '$MCP_SERVER_PRINCIPAL_ID', 1), TYPE = E;
        END
        ALTER ROLE db_datareader ADD MEMBER [$MCP_SERVER_APP_NAME];
      "

      echo "SQL access granted successfully!"
    '''
  }
}

// ============================================================================
// Agent API Container App
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
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
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
          image: '${containerRegistry.properties.loginServer}/medical-agent-api:latest'
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
              name: 'Azure__OpenAI__DeploymentName'
              value: gpt4oDeployment.name
            }
            {
              name: 'McpServer__Endpoint'
              value: 'https://${mcpServerApp.properties.configuration.ingress.fqdn}'
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

// Cognitive Services OpenAI User role for Agent API
resource openAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiAccount.id, agentApiApp.id, 'openaiuser')
  scope: openAiAccount
  properties: {
    principalId: agentApiApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
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

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabase.name

@description('Azure OpenAI endpoint')
output openAiEndpoint string = openAiAccount.properties.endpoint

@description('Azure OpenAI deployment name')
output openAiDeploymentName string = gpt4oDeployment.name

@description('Container Apps Environment name')
output containerAppsEnvName string = containerAppsEnvironment.name

@description('MCP Server internal FQDN')
output mcpServerFqdn string = mcpServerApp.properties.configuration.ingress.fqdn

@description('Agent API external FQDN')
output agentApiFqdn string = agentApiApp.properties.configuration.ingress.fqdn

@description('Agent API URL')
output agentApiUrl string = 'https://${agentApiApp.properties.configuration.ingress.fqdn}'

@description('MCP Server principal ID (grant SQL access)')
output mcpServerPrincipalId string = mcpServerApp.identity.principalId

@description('Deployment status')
output deploymentStatus string = 'Complete! Access the Agent API at https://${agentApiApp.properties.configuration.ingress.fqdn}'
