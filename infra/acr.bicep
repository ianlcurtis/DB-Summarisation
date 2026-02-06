// Azure Container Registry deployment
// Deploy this first, then push image, then deploy main.bicep

targetScope = 'resourceGroup'

@description('Environment name suffix (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = 'swedencentral'

@description('Base name prefix for resources')
param baseName string = 'medmcp'

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
// Outputs
// ============================================================================

@description('The name of the Container Registry')
output acrName string = containerRegistry.name

@description('The login server of the Container Registry')
output acrLoginServer string = containerRegistry.properties.loginServer
