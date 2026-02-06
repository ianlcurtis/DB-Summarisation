// ============================================================================
// Medical Agent Web Frontend - Azure Container App
// ============================================================================
// This Bicep template deploys the React web frontend as an Azure Container App.
// It serves static files via nginx and proxies API requests to the Agent API.
// ============================================================================

@description('The name of the Container Apps environment')
param environmentName string

@description('The location for resources')
param location string = resourceGroup().location

@description('Base name for resources')
param baseName string = 'medmcp'

@description('Environment suffix (dev, test, prod)')
param envSuffix string = 'test'

@description('The ACR login server')
param acrLoginServer string

@description('The web frontend image name with tag')
param webImageName string = 'medical-agent-web:latest'

@description('The Agent API URL for proxying requests')
param agentApiUrl string

// ============================================================================
// EXISTING RESOURCES
// ============================================================================

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

// ============================================================================
// WEB FRONTEND CONTAINER APP
// ============================================================================

resource webApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${baseName}-${envSuffix}-web'
  location: location
  tags: {
    environment: envSuffix
    project: 'medical-aspire'
    component: 'web-frontend'
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: acrLoginServer
          // Note: Credentials should be configured via Azure CLI or managed identity
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web-frontend'
          image: '${acrLoginServer}/${webImageName}'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'API_URL'
              value: agentApiUrl
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
// OUTPUTS
// ============================================================================

output webAppName string = webApp.name
output webAppFqdn string = webApp.properties.configuration.ingress.fqdn
output webAppUrl string = 'https://${webApp.properties.configuration.ingress.fqdn}'
