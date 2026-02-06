// ============================================================================
// Azure SQL Database with Entra-only Authentication
// ============================================================================
// This template deploys:
// - Azure SQL Server with Entra-only authentication (no SQL auth)
// - Azure SQL Database (Free/Developer tier)
// ============================================================================

@description('Environment name suffix (dev, staging, prod)')
param environmentName string = 'dev'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Base name for resources')
param baseName string = 'medmcp'

@description('Object ID of the Entra user/group to be SQL admin')
param sqlAdminObjectId string

@description('Display name of the Entra user/group to be SQL admin')
param sqlAdminDisplayName string

@description('Type of the Entra identity (User or Group)')
@allowed(['User', 'Group'])
param sqlAdminType string = 'User'

// ============================================================================
// Variables
// ============================================================================

// SQL Server name must be globally unique
var uniqueSuffix = uniqueString(resourceGroup().id)
var sqlServerName = '${baseName}-${environmentName}-sql-${uniqueSuffix}'
var databaseName = 'MedicalDb'

// ============================================================================
// SQL Server
// ============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    // Entra-only authentication - no SQL admin username/password
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
  tags: {
    environment: environmentName
    project: 'medical-mcp-server'
  }
}

// ============================================================================
// SQL Database - Free/Developer Tier
// ============================================================================
// Using the Free tier (32 GB storage, limited DTUs) for development
// For production, consider Basic, Standard, or Premium tiers

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: 'GP_S_Gen5'    // General Purpose Serverless
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1           // 1 vCore
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368  // 32 GB
    autoPauseDelay: 60         // Auto-pause after 60 minutes of inactivity
    minCapacity: json('0.5')   // Minimum 0.5 vCores when paused
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
  tags: {
    environment: environmentName
    project: 'medical-mcp-server'
  }
}

// ============================================================================
// Firewall Rules
// ============================================================================

// Allow Azure services to access the SQL server
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('SQL Server fully qualified domain name')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Server name')
output sqlServerName string = sqlServer.name

@description('Database name')
output databaseName string = sqlDatabase.name

@description('Connection string for Entra authentication')
output connectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'
