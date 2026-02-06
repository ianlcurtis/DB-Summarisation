<#
.SYNOPSIS
    Deploys the Azure SQL Database for the Medical MCP Server.

.DESCRIPTION
    This script:
    1. Authenticates to Azure (if not already logged in)
    2. Creates the resource group if it doesn't exist
    3. Deploys Azure SQL Server with Entra-only authentication
    4. Adds firewall rule for current client IP
    5. Runs database schema scripts from /db folder
    6. Runs data seeding scripts from /db folder

.PARAMETER EnvironmentName
    The environment name suffix (e.g., dev, staging, prod). Default: dev

.PARAMETER Location
    The Azure region. Default: swedencentral

.PARAMETER ResourceGroupName
    Optional. Override the default resource group name.

.PARAMETER SkipInfrastructure
    Skip infrastructure deployment (use existing SQL server)

.PARAMETER SkipSchema
    Skip database schema creation

.PARAMETER SkipData
    Skip data seeding

.EXAMPLE
    .\deploy-database.ps1
    
.EXAMPLE
    .\deploy-database.ps1 -EnvironmentName prod -Location swedencentral

.EXAMPLE
    .\deploy-database.ps1 -SkipInfrastructure -SkipSchema
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$EnvironmentName = "dev",

    [Parameter()]
    [string]$Location = "swedencentral",

    [Parameter()]
    [string]$ResourceGroupName,

    [Parameter()]
    [switch]$SkipInfrastructure,

    [Parameter()]
    [switch]$SkipSchema,

    [Parameter()]
    [switch]$SkipData
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$BaseName = "medmcp"
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir
$InfraDir = Join-Path $RepoRoot "infra"
$DbDir = Join-Path $RepoRoot "db"

if (-not $ResourceGroupName) {
    $ResourceGroupName = "$BaseName-$EnvironmentName-rg"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Database Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:     $EnvironmentName"
Write-Host "Location:        $Location"
Write-Host "Resource Group:  $ResourceGroupName"
Write-Host "DB Scripts Dir:  $DbDir"
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# Functions
# ============================================================================

function Test-AzureLogin {
    try {
        $context = az account show 2>$null | ConvertFrom-Json
        if ($context) {
            Write-Host "Logged in as: $($context.user.name)" -ForegroundColor Green
            Write-Host "Subscription: $($context.name) ($($context.id))" -ForegroundColor Green
            return $context
        }
    }
    catch {
        return $null
    }
    return $null
}

function Invoke-AzCommand {
    param([string]$Command, [string]$Description)
    
    Write-Host "`n>> $Description" -ForegroundColor Yellow
    Write-Host "   $Command" -ForegroundColor DarkGray
    
    $result = Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
    return $result
}

function Get-CurrentUserInfo {
    # Get current user's Object ID and display name from Azure AD
    $userInfo = az ad signed-in-user show --query "{objectId:id,displayName:displayName,userPrincipalName:userPrincipalName}" --output json 2>$null | ConvertFrom-Json
    return $userInfo
}

function Get-ClientIpAddress {
    try {
        $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 10
        return $response.ip
    }
    catch {
        Write-Host "Could not determine client IP address" -ForegroundColor Yellow
        return $null
    }
}

# ============================================================================
# Prerequisites Check
# ============================================================================

Write-Host "`n[1/7] Checking prerequisites..." -ForegroundColor Cyan

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
}

# Check for SqlServer module (required for Entra authentication)
$hasSqlModule = Get-Module -ListAvailable -Name SqlServer
if (-not $hasSqlModule) {
    Write-Host "Installing SqlServer PowerShell module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer -ErrorAction SilentlyContinue
Write-Host "Using SqlServer PowerShell module for SQL operations" -ForegroundColor Green

# ============================================================================
# Azure Authentication
# ============================================================================

Write-Host "`n[2/7] Checking Azure authentication..." -ForegroundColor Cyan

$azContext = Test-AzureLogin
if (-not $azContext) {
    Write-Host "Not logged in to Azure. Starting login..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        throw "Azure login failed"
    }
    $azContext = Test-AzureLogin
}

# Get current user info for SQL Admin
$userInfo = Get-CurrentUserInfo
if (-not $userInfo) {
    throw "Could not get current user information from Azure AD"
}
Write-Host "SQL Admin will be: $($userInfo.displayName) ($($userInfo.userPrincipalName))" -ForegroundColor Green

# ============================================================================
# Resource Group
# ============================================================================

Write-Host "`n[3/7] Ensuring resource group exists..." -ForegroundColor Cyan

$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
if (-not $rgExists) {
    Invoke-AzCommand -Command "az group create --name $ResourceGroupName --location $Location --output json" `
                     -Description "Creating resource group"
    Write-Host "Resource group created: $ResourceGroupName" -ForegroundColor Green
}
else {
    Write-Host "Resource group already exists: $ResourceGroupName" -ForegroundColor Green
}

# ============================================================================
# Deploy SQL Infrastructure
# ============================================================================

if (-not $SkipInfrastructure) {
    Write-Host "`n[4/7] Deploying Azure SQL infrastructure..." -ForegroundColor Cyan
    
    $sqlBicepFile = Join-Path $InfraDir "sql.bicep"
    
    if (-not (Test-Path $sqlBicepFile)) {
        throw "SQL Bicep file not found: $sqlBicepFile"
    }
    
    $sqlDeploymentOutput = Invoke-AzCommand `
        -Command "az deployment group create --resource-group $ResourceGroupName --template-file `"$sqlBicepFile`" --parameters environmentName=$EnvironmentName location=$Location baseName=$BaseName sqlAdminObjectId=$($userInfo.objectId) sqlAdminDisplayName=`"$($userInfo.displayName)`" sqlAdminType=User --query properties.outputs --output json" `
        -Description "Deploying SQL Bicep template"
    
    $sqlOutputs = $sqlDeploymentOutput | ConvertFrom-Json
    $sqlServerName = $sqlOutputs.sqlServerName.value
    $sqlServerFqdn = $sqlOutputs.sqlServerFqdn.value
    $databaseName = $sqlOutputs.databaseName.value
    $connectionString = $sqlOutputs.connectionString.value
    
    Write-Host "SQL Server deployed: $sqlServerFqdn" -ForegroundColor Green
    Write-Host "Database: $databaseName" -ForegroundColor Green
}
else {
    Write-Host "`n[4/7] Skipping SQL infrastructure deployment (using existing)..." -ForegroundColor Yellow
    
    # Find existing SQL server
    $sqlServers = az sql server list --resource-group $ResourceGroupName --query "[?contains(name, '$BaseName')].{name:name,fqdn:fullyQualifiedDomainName}" --output json | ConvertFrom-Json
    if ($sqlServers.Count -eq 0) {
        throw "No SQL server found in resource group. Run without -SkipInfrastructure first."
    }
    $sqlServerName = $sqlServers[0].name
    $sqlServerFqdn = $sqlServers[0].fqdn
    $databaseName = "MedicalDb"
    $connectionString = "Server=tcp:${sqlServerFqdn},1433;Database=${databaseName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;"
    
    Write-Host "Using existing SQL Server: $sqlServerFqdn" -ForegroundColor Green
}

# ============================================================================
# Add Firewall Rule for Client IP
# ============================================================================

Write-Host "`n[5/7] Configuring firewall rules..." -ForegroundColor Cyan

# Add firewall rule for Azure services (required for Container Apps to connect)
Write-Host "Adding firewall rule for Azure services (Container Apps)..." -ForegroundColor Yellow
$azureServicesRule = az sql server firewall-rule show --resource-group $ResourceGroupName --server $sqlServerName --name "AllowAzureServices" 2>$null
if (-not $azureServicesRule) {
    az sql server firewall-rule create --resource-group $ResourceGroupName --server $sqlServerName --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
    Write-Host "Azure services firewall rule created" -ForegroundColor Green
} else {
    Write-Host "Azure services firewall rule already exists" -ForegroundColor Green
}

$clientIp = Get-ClientIpAddress
if ($clientIp) {
    Write-Host "Adding firewall rule for client IP: $clientIp" -ForegroundColor Yellow
    
    # Check if rule already exists
    $existingRule = az sql server firewall-rule show --resource-group $ResourceGroupName --server $sqlServerName --name "ClientIP" 2>$null
    if ($existingRule) {
        az sql server firewall-rule update --resource-group $ResourceGroupName --server $sqlServerName --name "ClientIP" --start-ip-address $clientIp --end-ip-address $clientIp --output none
    }
    else {
        az sql server firewall-rule create --resource-group $ResourceGroupName --server $sqlServerName --name "ClientIP" --start-ip-address $clientIp --end-ip-address $clientIp --output none
    }
    Write-Host "Firewall rule configured for $clientIp" -ForegroundColor Green
}

# ============================================================================
# Run Database Schema Scripts
# ============================================================================

if (-not $SkipSchema) {
    Write-Host "`n[6/7] Running database schema scripts..." -ForegroundColor Cyan
    
    $schemaFile = Join-Path $DbDir "patient_medical_history_database.sql"
    
    if (-not (Test-Path $schemaFile)) {
        throw "Schema file not found: $schemaFile"
    }
    
    Write-Host "Executing: $schemaFile" -ForegroundColor Yellow
    
    # Get access token for SQL using Azure CLI
    $accessToken = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
    if (-not $accessToken) {
        throw "Failed to get access token for Azure SQL"
    }
    
    # Read SQL schema file
    $sqlContent = Get-Content $schemaFile -Raw
    
    # Write SQL to temp file
    $tempFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.sql'
    $sqlContent | Set-Content $tempFile -Encoding UTF8
    
    try {
        Write-Host "  Connecting to $sqlServerFqdn..." -ForegroundColor DarkGray
        
        # Use Invoke-Sqlcmd with access token for Entra authentication
        Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $databaseName -AccessToken $accessToken -InputFile $tempFile -ErrorAction Stop
        
        Write-Host "Schema created successfully!" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -match "already exists" -or $_.Exception.Message -match "There is already an object") {
            Write-Host "Schema already exists (some objects may have been skipped)" -ForegroundColor Yellow
        }
        else {
            throw $_
        }
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host "`n[6/7] Skipping schema creation..." -ForegroundColor Yellow
}

# ============================================================================
# Run Data Seeding Scripts
# ============================================================================

if (-not $SkipData) {
    Write-Host "`n[7/7] Running data seeding scripts..." -ForegroundColor Cyan
    
    $dataFile = Join-Path $DbDir "patient_medical_history_data.sql"
    
    if (-not (Test-Path $dataFile)) {
        Write-Host "Data file not found, skipping: $dataFile" -ForegroundColor Yellow
    }
    else {
        Write-Host "Executing: $dataFile" -ForegroundColor Yellow
        
        # Get access token for SQL using Azure CLI
        $accessToken = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
        if (-not $accessToken) {
            throw "Failed to get access token for Azure SQL"
        }
        
        # Write SQL to temp file
        $tempFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.sql'
        Copy-Item $dataFile $tempFile
        
        try {
            Write-Host "  Inserting data..." -ForegroundColor DarkGray
            
            # Use Invoke-Sqlcmd with access token for Entra authentication
            Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $databaseName -AccessToken $accessToken -InputFile $tempFile -ErrorAction Stop
            
            Write-Host "Data seeded successfully!" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "Violation of PRIMARY KEY" -or $_.Exception.Message -match "duplicate key") {
                Write-Host "Data already exists (some rows may have been skipped)" -ForegroundColor Yellow
            }
            else {
                throw $_
            }
        }
        finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
}
else {
    Write-Host "`n[7/7] Skipping data seeding..." -ForegroundColor Yellow
}

# ============================================================================
# Verify Database
# ============================================================================

Write-Host "`n[Verify] Testing database connection..." -ForegroundColor Cyan

try {
    $accessToken = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
    
    # Count tables
    $tableResult = Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $databaseName -AccessToken $accessToken -Query "SELECT COUNT(*) as TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
    $tableCount = $tableResult.TableCount
    
    # Count patients (if table exists)
    try {
        $patientResult = Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $databaseName -AccessToken $accessToken -Query "SELECT COUNT(*) as PatientCount FROM Patients"
        $patientCount = $patientResult.PatientCount
        Write-Host "Database verified! Found $tableCount tables and $patientCount patients." -ForegroundColor Green
    }
    catch {
        Write-Host "Database verified! Found $tableCount tables (no data yet)." -ForegroundColor Green
    }
}
catch {
    Write-Host "Could not verify database: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Database Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "SQL Server:         $sqlServerFqdn" -ForegroundColor Cyan
Write-Host "Database:           $databaseName" -ForegroundColor Cyan
Write-Host "SQL Admin:          $($userInfo.displayName)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Connection String (Entra Auth):" -ForegroundColor Cyan
Write-Host "  $connectionString" -ForegroundColor DarkGray
Write-Host ""
Write-Host "To connect with Azure Data Studio or SSMS:" -ForegroundColor Yellow
Write-Host "  Server:   $sqlServerFqdn" -ForegroundColor DarkGray
Write-Host "  Database: $databaseName" -ForegroundColor DarkGray
Write-Host "  Auth:     Azure Active Directory - Universal with MFA" -ForegroundColor DarkGray
Write-Host ""
Write-Host "To test with Azure CLI:" -ForegroundColor Yellow
Write-Host "  az sql db query --resource-group $ResourceGroupName --server $sqlServerName --name $databaseName --query-text `"SELECT TOP 5 * FROM Patients`"" -ForegroundColor DarkGray
Write-Host ""

# Output connection string for use by other scripts
$connectionString
