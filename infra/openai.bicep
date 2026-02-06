// Azure OpenAI Service Bicep template for MedicalAgent application
// Deploys: Azure OpenAI account with GPT-4o model deployment
// This template creates an OpenAI resource that can be used by the Aspire app

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name suffix (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Azure region for the OpenAI resource')
param location string = 'swedencentral'

@description('Base name prefix for resources')
param baseName string = 'medmcp'

@description('SKU for the Cognitive Services account')
@allowed([
  'S0'
])
param sku string = 'S0'

@description('The name of the GPT-4o model deployment')
param gpt4oDeploymentName string = 'gpt-4o'

@description('The GPT-4o model version')
param gpt4oModelVersion string = '2024-11-20'

@description('Capacity for GPT-4o deployment (tokens per minute in thousands)')
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

var openAiAccountName = '${baseName}-${environmentName}-openai'
var customSubDomainName = '${baseName}${environmentName}openai'

// ============================================================================
// Azure OpenAI Account
// ============================================================================

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: openAiAccountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: sku
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
  tags: tags
}

// ============================================================================
// GPT-4o Model Deployment
// ============================================================================

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: openAiAccount
  name: gpt4oDeploymentName
  sku: {
    name: 'Standard'
    capacity: gpt4oCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: gpt4oModelVersion
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the Azure OpenAI account')
output openAiAccountName string = openAiAccount.name

@description('The resource ID of the Azure OpenAI account')
output openAiAccountId string = openAiAccount.id

@description('The endpoint URL for the Azure OpenAI service')
output openAiEndpoint string = openAiAccount.properties.endpoint

@description('The name of the GPT-4o deployment')
output gpt4oDeploymentName string = gpt4oDeployment.name

@description('The principal ID of the system-assigned managed identity')
output openAiPrincipalId string = openAiAccount.identity.principalId
