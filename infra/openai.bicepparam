using './openai.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'swedencentral'
param baseName = 'medmcp'

// Model deployment configuration
param gpt4oDeploymentName = 'gpt-4o'
param gpt4oModelVersion = '2024-11-20'
param gpt4oCapacity = 10

param tags = {
  project: 'medical-mcp-server'
  environment: 'dev'
  deployedBy: 'bicep'
}
