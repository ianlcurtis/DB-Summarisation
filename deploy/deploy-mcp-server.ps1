<#
.SYNOPSIS
    Deploys the MedicalDbMcpServer to Azure Container Apps.

.DESCRIPTION
    This script:
    1. Authenticates to Azure (if not already logged in)
    2. Creates the resource group if it doesn't exist
    3. Deploys ACR (Azure Container Registry)
    4. Builds and pushes the Docker image to ACR
    5. Deploys Container Apps Environment and Container App with the pushed image
    6. Optionally connects to Azure SQL Database with Managed Identity

.PARAMETER EnvironmentName
    The environment name suffix (e.g., dev, staging, prod). Default: dev

.PARAMETER Location
    The Azure region. Default: swedencentral

.PARAMETER ResourceGroupName
    Optional. Override the default resource group name.

.PARAMETER SkipAcr
    Skip ACR deployment (use existing ACR)

.PARAMETER SkipBuild
    Skip Docker build and push (use existing image)

.PARAMETER ImageTag
    The tag for the container image. Default: latest

.PARAMETER ConnectDatabase
    Connect the MCP server to the Azure SQL Database

.EXAMPLE
    .\deploy-mcp-server.ps1
    
.EXAMPLE
    .\deploy-mcp-server.ps1 -EnvironmentName prod -Location swedencentral

.EXAMPLE
    .\deploy-mcp-server.ps1 -SkipAcr -SkipBuild -ConnectDatabase
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
    [switch]$SkipAcr,

    [Parameter()]
    [switch]$SkipBuild,

    [Parameter()]
    [string]$ImageTag = "latest",

    [Parameter()]
    [switch]$ConnectDatabase,

    [Parameter()]
    [switch]$EnableEntraAuth
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$BaseName = "medmcp"
$ImageName = "medical-mcp-server"
$AppRegistrationName = "MedicalDbMcpServer-$EnvironmentName"
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir
$InfraDir = Join-Path $RepoRoot "infra"
$McpServerDir = Join-Path $RepoRoot "src" "MedicalDbMcpServer"

if (-not $ResourceGroupName) {
    $ResourceGroupName = "$BaseName-$EnvironmentName-rg"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MCP Server Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:     $EnvironmentName"
Write-Host "Location:        $Location"
Write-Host "Resource Group:  $ResourceGroupName"
Write-Host "Image Tag:       $ImageTag"
Write-Host "Entra Auth:      $(if ($EnableEntraAuth) { 'Enabled' } else { 'Disabled' })"
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
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
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

# ============================================================================
# Prerequisites Check
# ============================================================================

Write-Host "`n[1/7] Checking prerequisites..." -ForegroundColor Cyan

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
}

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is not installed. Please install Docker Desktop."
}

# ============================================================================
# Azure Authentication
# ============================================================================

Write-Host "`n[2/7] Checking Azure authentication..." -ForegroundColor Cyan

if (-not (Test-AzureLogin)) {
    Write-Host "Not logged in to Azure. Starting login..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        throw "Azure login failed"
    }
}

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
# Deploy ACR
# ============================================================================

if (-not $SkipAcr) {
    Write-Host "`n[4/7] Deploying Azure Container Registry..." -ForegroundColor Cyan
    
    $acrBicepFile = Join-Path $InfraDir "acr.bicep"
    
    if (-not (Test-Path $acrBicepFile)) {
        throw "ACR Bicep file not found: $acrBicepFile"
    }
    
    $acrDeploymentOutput = Invoke-AzCommand `
        -Command "az deployment group create --resource-group $ResourceGroupName --template-file `"$acrBicepFile`" --parameters environmentName=$EnvironmentName location=$Location baseName=$BaseName --query properties.outputs --output json" `
        -Description "Deploying ACR Bicep template"
    
    $acrOutputs = $acrDeploymentOutput | ConvertFrom-Json
    $acrName = $acrOutputs.acrName.value
    $acrLoginServer = $acrOutputs.acrLoginServer.value
    
    Write-Host "ACR deployed: $acrLoginServer" -ForegroundColor Green
}
else {
    Write-Host "`n[4/7] Skipping ACR deployment (using existing)..." -ForegroundColor Yellow
    
    # Find existing ACR
    $acrList = az acr list --resource-group $ResourceGroupName --query "[?starts_with(name, '${BaseName}${EnvironmentName}')].{name:name,loginServer:loginServer}" --output json | ConvertFrom-Json
    if ($acrList.Count -eq 0) {
        throw "No ACR found in resource group. Run without -SkipAcr first."
    }
    $acrName = $acrList[0].name
    $acrLoginServer = $acrList[0].loginServer
    
    Write-Host "Using existing ACR: $acrLoginServer" -ForegroundColor Green
}

# ============================================================================
# Build and Push Docker Image
# ============================================================================

$fullImageName = "${acrLoginServer}/${ImageName}:${ImageTag}"

if (-not $SkipBuild) {
    Write-Host "`n[5/7] Building and pushing Docker image..." -ForegroundColor Cyan
    
    # Use ACR Tasks to build in the cloud (no local Docker required)
    # Build from repo root since Dockerfile references ServiceDefaults project
    Push-Location $RepoRoot
    try {
        Invoke-AzCommand -Command "az acr build --registry $acrName --image ${ImageName}:${ImageTag} --file src/MedicalDbMcpServer/Dockerfile ." -Description "Building and pushing image using ACR Tasks"
    }
    finally {
        Pop-Location
    }
    
    Write-Host "Image pushed: $fullImageName" -ForegroundColor Green
}
else {
    Write-Host "`n[5/7] Skipping Docker build (using existing image)..." -ForegroundColor Yellow
    Write-Host "Expected image: $fullImageName"
}

# ============================================================================
# Deploy Container Apps Infrastructure
# ============================================================================

Write-Host "`n[6/7] Deploying Container Apps infrastructure..." -ForegroundColor Cyan

$mainBicepFile = Join-Path $InfraDir "main.bicep"

if (-not (Test-Path $mainBicepFile)) {
    throw "Main Bicep file not found: $mainBicepFile"
}

# Build deployment parameters
$deployParams = "environmentName=$EnvironmentName location=$Location baseName=$BaseName acrName=$acrName acrLoginServer=$acrLoginServer imageName=$ImageName imageTag=$ImageTag"

# ============================================================================
# Create/Update Entra App Registration
# ============================================================================

$entraAppClientId = ""
$entraAppAudience = ""
$tenantId = ""

if ($EnableEntraAuth) {
    Write-Host "`n[6.1/7] Configuring Microsoft Entra ID App Registration..." -ForegroundColor Cyan
    
    # Get tenant ID
    $tenantId = az account show --query tenantId --output tsv
    Write-Host "Tenant ID: $tenantId" -ForegroundColor DarkGray
    
    # Check if app registration already exists
    $existingApp = az ad app list --display-name $AppRegistrationName --query "[0]" --output json 2>$null | ConvertFrom-Json
    
    if ($existingApp) {
        $entraAppClientId = $existingApp.appId
        Write-Host "Using existing app registration: $AppRegistrationName ($entraAppClientId)" -ForegroundColor Green
    }
    else {
        # Create new app registration
        Write-Host "Creating app registration: $AppRegistrationName" -ForegroundColor Yellow
        
        $newApp = az ad app create `
            --display-name $AppRegistrationName `
            --sign-in-audience AzureADMyOrg `
            --query "{appId:appId, id:id}" `
            --output json | ConvertFrom-Json
        
        $entraAppClientId = $newApp.appId
        $entraAppObjectId = $newApp.id
        
        Write-Host "App registration created: $entraAppClientId" -ForegroundColor Green
        
        # Set the Application ID URI (audience)
        $identifierUri = "api://$entraAppClientId"
        az ad app update --id $entraAppClientId --identifier-uris $identifierUri
        Write-Host "Set identifier URI: $identifierUri" -ForegroundColor Green
        
        # Create a service principal for the app
        $spExists = az ad sp show --id $entraAppClientId 2>$null
        if (-not $spExists) {
            az ad sp create --id $entraAppClientId --output none
            Write-Host "Service principal created" -ForegroundColor Green
        }
    }
    
    $entraAppAudience = $entraAppClientId
    
    # Add app role for service-to-service authentication
    # This role allows other services (like Agent API) to call this MCP server
    Write-Host "Configuring app role for service-to-service auth..." -ForegroundColor Yellow
    
    $appRoleId = "e2e650a9-e097-4112-99cd-84c28e2951b9"
    $existingRoles = az ad app show --id $entraAppClientId --query "appRoles" -o json 2>$null | ConvertFrom-Json
    
    $roleExists = $false
    if ($existingRoles) {
        foreach ($role in $existingRoles) {
            if ($role.id -eq $appRoleId) {
                $roleExists = $true
                break
            }
        }
    }
    
    if (-not $roleExists) {
        $appRoleJson = @"
[{"allowedMemberTypes":["Application"],"description":"Allows the app to access the MCP Server API","displayName":"MCP Access","id":"$appRoleId","isEnabled":true,"value":"MCP.Access"}]
"@
        $tempFile = [System.IO.Path]::GetTempFileName()
        $appRoleJson | Set-Content $tempFile -Encoding UTF8
        
        try {
            az ad app update --id $entraAppClientId --app-roles "@$tempFile" --output none
            Write-Host "App role 'MCP.Access' added for service-to-service auth" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not add app role: $_" -ForegroundColor Yellow
        } finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "App role 'MCP.Access' already exists" -ForegroundColor Green
    }
    
    # Add Entra parameters to deployment
    $deployParams += " entraEnabled=true entraTenantId=$tenantId entraClientId=$entraAppClientId entraAudience=$entraAppAudience"
    
    Write-Host "Entra authentication configured!" -ForegroundColor Green
}
else {
    $deployParams += " entraEnabled=false"
}

# If connecting to database, find SQL server and add parameters
$sqlServerFqdn = ""
$sqlServerName = ""
$databaseName = "MedicalDb"

if ($ConnectDatabase) {
    Write-Host "Looking for SQL Server in resource group..." -ForegroundColor Yellow
    $sqlServers = az sql server list --resource-group $ResourceGroupName --query "[?contains(name, '$BaseName')].{name:name,fqdn:fullyQualifiedDomainName}" --output json | ConvertFrom-Json
    
    if ($sqlServers.Count -gt 0) {
        $sqlServerName = $sqlServers[0].name
        $sqlServerFqdn = $sqlServers[0].fqdn
        $deployParams += " sqlServerFqdn=$sqlServerFqdn sqlDatabaseName=$databaseName"
        Write-Host "Will connect to database: $sqlServerFqdn / $databaseName" -ForegroundColor Green
        
        # Ensure SQL Server allows connections from Azure services (Container Apps)
        Write-Host "Ensuring SQL Server network access for Container Apps..." -ForegroundColor Yellow
        
        # Enable public network access
        az sql server update --name $sqlServerName --resource-group $ResourceGroupName --enable-public-network true --output none 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Public network access enabled" -ForegroundColor Green
        }
        
        # Add firewall rule for Azure services
        $existingRule = az sql server firewall-rule show --resource-group $ResourceGroupName --server $sqlServerName --name "AllowAzureServices" 2>$null
        if (-not $existingRule) {
            az sql server firewall-rule create --resource-group $ResourceGroupName --server $sqlServerName --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
            Write-Host "  Azure services firewall rule created" -ForegroundColor Green
        } else {
            Write-Host "  Azure services firewall rule already exists" -ForegroundColor Green
        }
    }
    else {
        Write-Host "No SQL server found. Run deploy-database.ps1 first, or deploy without -ConnectDatabase" -ForegroundColor Yellow
    }
}

$deploymentOutput = Invoke-AzCommand `
    -Command "az deployment group create --resource-group $ResourceGroupName --template-file `"$mainBicepFile`" --parameters $deployParams --query properties.outputs --output json" `
    -Description "Deploying Container Apps Bicep template"

$outputs = $deploymentOutput | ConvertFrom-Json
$mcpServerAppName = $outputs.mcpServerAppName.value
$mcpServerFqdn = $outputs.mcpServerFqdn.value
$mcpEndpointUrl = $outputs.mcpEndpointUrl.value
$mcpServerPrincipalId = $outputs.mcpServerPrincipalId.value

Write-Host "Container Apps deployed successfully!" -ForegroundColor Green

# ============================================================================
# Grant SQL Database Access to Managed Identity
# ============================================================================

if ($ConnectDatabase -and $sqlServerFqdn -and $mcpServerPrincipalId) {
    Write-Host "`n[6.5/7] Granting database access to Managed Identity..." -ForegroundColor Cyan
    
    # Import SqlServer module
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Host "Installing SqlServer PowerShell module..." -ForegroundColor Yellow
        Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module SqlServer -ErrorAction SilentlyContinue
    
    # Get access token for SQL
    $accessToken = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
    
    # Create database user for the managed identity with read-only access
    $createUserSql = @"
-- Create Entra user from managed identity if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$mcpServerAppName')
BEGIN
    CREATE USER [$mcpServerAppName] FROM EXTERNAL PROVIDER;
    PRINT 'User created from external provider';
END
GO

-- Grant read-only access via db_datareader role
IF IS_ROLEMEMBER('db_datareader', '$mcpServerAppName') = 0
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [$mcpServerAppName];
    PRINT 'Granted db_datareader role';
END
"@
    
    try {
        Write-Host "Creating database user for managed identity: $mcpServerAppName" -ForegroundColor Yellow
        Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $databaseName -AccessToken $accessToken -Query $createUserSql -ErrorAction Stop
        Write-Host "Database access granted successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not grant database access: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "You may need to grant access manually using Azure Portal or SSMS" -ForegroundColor Yellow
    }
}

# ============================================================================
# Verify Deployment
# ============================================================================

Write-Host "`n[7/7] Verifying deployment..." -ForegroundColor Cyan

# Wait a moment for the app to start
Write-Host "Waiting for app to start..." -ForegroundColor DarkGray
Start-Sleep -Seconds 10

# Check health endpoint
$healthUrl = "https://$mcpServerFqdn/health/ready"
try {
    $response = Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec 30 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "Health check passed!" -ForegroundColor Green
    }
    else {
        Write-Host "Health check returned: $($response.StatusCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Health check not yet available (app may still be starting)" -ForegroundColor Yellow
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "MCP Server URL:     https://$mcpServerFqdn" -ForegroundColor Cyan
Write-Host "MCP SSE Endpoint:   $mcpEndpointUrl" -ForegroundColor Cyan
Write-Host "Health Check:       https://$mcpServerFqdn/health" -ForegroundColor Cyan
Write-Host "Status Endpoint:    https://$mcpServerFqdn/status" -ForegroundColor Cyan

if ($ConnectDatabase -and $sqlServerFqdn) {
    Write-Host ""
    Write-Host "Database Connection:" -ForegroundColor Cyan
    Write-Host "  SQL Server:       $sqlServerFqdn" -ForegroundColor Cyan
    Write-Host "  Database:         $databaseName" -ForegroundColor Cyan
    Write-Host "  Auth:             Managed Identity" -ForegroundColor Cyan
}

if ($EnableEntraAuth -and $entraAppClientId) {
    Write-Host ""
    Write-Host "Entra Authentication:" -ForegroundColor Cyan
    Write-Host "  Tenant ID:        $tenantId" -ForegroundColor Cyan
    Write-Host "  App Client ID:    $entraAppClientId" -ForegroundColor Cyan
    Write-Host "  Audience:         $entraAppAudience" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Clients must acquire a token with audience: $entraAppAudience" -ForegroundColor Yellow
    Write-Host "Include header: Authorization: Bearer <token>" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "To test the MCP endpoint:"
Write-Host "  curl https://$mcpServerFqdn/status" -ForegroundColor DarkGray
Write-Host ""
Write-Host "To view logs:"
Write-Host "  az containerapp logs show --name $mcpServerAppName --resource-group $ResourceGroupName --follow" -ForegroundColor DarkGray
Write-Host ""
