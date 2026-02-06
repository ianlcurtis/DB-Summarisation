using './main.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'swedencentral'
param baseName = 'medmcp'
param imageTag = 'latest'

param tags = {
  project: 'medical-mcp-server'
  environment: 'dev'
  deployedBy: 'bicep'
}
