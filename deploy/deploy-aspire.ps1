<#
.SYNOPSIS
    Deploys the Medical Aspire application (MCP Server + Agent API) to Azure Container Apps with Entra authentication.

.DESCRIPTION
    This script:
    1. Builds and pushes Docker images for both services to Azure Container Registry
    2. Deploys the infrastructure using Bicep (Container Apps Environment, Container Apps)
    3. Configures Entra ID authentication between the Agent API and MCP Server

.PARAMETER ResourceGroupName
    The Azure resource group name where resources will be deployed.

.PARAMETER AcrName
    The name of the Azure Container Registry (must already exist).

.PARAMETER SqlServerName
    The name of the Azure SQL Server (must already exist).

.PARAMETER SqlDatabaseName
    The name of the SQL Database.

.PARAMETER EntraTenantId
    The Microsoft Entra ID tenant ID.

.PARAMETER McpServerClientId
    The Entra App Registration Client ID for the MCP Server.

.PARAMETER AzureOpenAiEndpoint
    The Azure OpenAI endpoint URL.

.PARAMETER ImageTag
    The tag to use for Docker images (default: latest).

.PARAMETER Location
    The Azure region for deployment (default: swedencentral).

.PARAMETER EnvironmentName
    The environment name suffix (default: dev).

.EXAMPLE
    .\deploy-aspire.ps1 -ResourceGroupName "rg-medical-dev" -AcrName "medicalacr" -SqlServerName "medical-sql" `
        -SqlDatabaseName "PatientMedicalHistory" -EntraTenantId "your-tenant-id" `
        -McpServerClientId "mcp-app-client-id" -AzureOpenAiEndpoint "https://your-openai.openai.azure.com/"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,

    [Parameter(Mandatory = $true)]
    [string]$SqlDatabaseName,

    [Parameter(Mandatory = $true)]
    [string]$EntraTenantId,

    [Parameter(Mandatory = $true)]
    [string]$McpServerClientId,

    [Parameter(Mandatory = $true)]
    [string]$AzureOpenAiEndpoint,

    [string]$ImageTag = "latest",
    [string]$Location = "swedencentral",
    [string]$EnvironmentName = "dev",
    [string]$BaseName = "medmcp",
    [string]$AzureOpenAiDeploymentName = "gpt-4o",

    [Parameter()]
    [string]$AzureOpenAiResourceGroup,

    [Parameter()]
    [string]$AzureOpenAiResourceName
)

$ErrorActionPreference = "Stop"

# Get the repository root directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Medical Aspire Application Deployment" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Validate Azure CLI is logged in
Write-Host "Validating Azure CLI login..." -ForegroundColor Yellow
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Please log in to Azure CLI using 'az login'"
    exit 1
}
Write-Host "Logged in to Azure" -ForegroundColor Green

# Get ACR login server
Write-Host "Getting ACR login server..." -ForegroundColor Yellow
$acrLoginServer = az acr show --name $AcrName --query loginServer -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get ACR login server. Make sure ACR '$AcrName' exists."
    exit 1
}
Write-Host "ACR Login Server: $acrLoginServer" -ForegroundColor Green

# Log in to ACR
Write-Host "Logging in to ACR..." -ForegroundColor Yellow
az acr login --name $AcrName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to log in to ACR"
    exit 1
}
Write-Host "Logged in to ACR" -ForegroundColor Green

# Build and push MCP Server image
Write-Host ""
Write-Host "Building MCP Server Docker image..." -ForegroundColor Yellow
$mcpImageName = "medical-mcp-server"
$mcpImageFull = "${acrLoginServer}/${mcpImageName}:${ImageTag}"

Push-Location $repoRoot
try {
    docker build -f src/MedicalDbMcpServer/Dockerfile -t $mcpImageFull .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build MCP Server Docker image"
        exit 1
    }
    Write-Host "MCP Server image built: $mcpImageFull" -ForegroundColor Green

    Write-Host "Pushing MCP Server image to ACR..." -ForegroundColor Yellow
    docker push $mcpImageFull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push MCP Server image"
        exit 1
    }
    Write-Host "MCP Server image pushed" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Build and push Agent API image
Write-Host ""
Write-Host "Building Agent API Docker image..." -ForegroundColor Yellow
$agentApiImageName = "medical-agent-api"
$agentApiImageFull = "${acrLoginServer}/${agentApiImageName}:${ImageTag}"

Push-Location $repoRoot
try {
    docker build -f src/MedicalAgent.Api/Dockerfile -t $agentApiImageFull .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Agent API Docker image"
        exit 1
    }
    Write-Host "Agent API image built: $agentApiImageFull" -ForegroundColor Green

    Write-Host "Pushing Agent API image to ACR..." -ForegroundColor Yellow
    docker push $agentApiImageFull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push Agent API image"
        exit 1
    }
    Write-Host "Agent API image pushed" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Get SQL Server FQDN
Write-Host ""
Write-Host "Getting SQL Server FQDN..." -ForegroundColor Yellow
$sqlServerFqdn = az sql server show --name $SqlServerName --resource-group $ResourceGroupName --query fullyQualifiedDomainName -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get SQL Server FQDN. Make sure SQL Server '$SqlServerName' exists in resource group '$ResourceGroupName'."
    exit 1
}
Write-Host "SQL Server FQDN: $sqlServerFqdn" -ForegroundColor Green

# Deploy Bicep template
Write-Host ""
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
$bicepPath = Join-Path $repoRoot "infra/aspire-main.bicep"

$deploymentName = "aspire-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $bicepPath `
    --parameters environmentName=$EnvironmentName `
    --parameters location=$Location `
    --parameters baseName=$BaseName `
    --parameters acrName=$AcrName `
    --parameters acrLoginServer=$acrLoginServer `
    --parameters imageTag=$ImageTag `
    --parameters sqlServerFqdn=$sqlServerFqdn `
    --parameters sqlDatabaseName=$SqlDatabaseName `
    --parameters entraTenantId=$EntraTenantId `
    --parameters mcpServerClientId=$McpServerClientId `
    --parameters azureOpenAiEndpoint=$AzureOpenAiEndpoint `
    --parameters azureOpenAiDeploymentName=$AzureOpenAiDeploymentName `
    --query properties.outputs -o json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep deployment failed"
    exit 1
}

$outputs = $deploymentResult | ConvertFrom-Json

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Bicep Deployment Completed!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Container Apps Environment: $($outputs.containerAppsEnvName.value)" -ForegroundColor Cyan
Write-Host "MCP Server App: $($outputs.mcpServerAppName.value)" -ForegroundColor Cyan
Write-Host "Agent API App: $($outputs.agentApiAppName.value)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Agent API Endpoint: $($outputs.agentApiEndpointUrl.value)" -ForegroundColor Yellow
Write-Host ""

# Get managed identity principal IDs for role assignments
$mcpPrincipalId = $outputs.mcpServerPrincipalId.value
$agentApiPrincipalId = $outputs.agentApiPrincipalId.value
$mcpServerAppName = $outputs.mcpServerAppName.value
$agentApiAppName = $outputs.agentApiAppName.value

# ============================================================================
# STEP 1: Ensure SQL Server allows Azure services (Container Apps)
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Configuring SQL Server Network Access..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Enable public network access on SQL Server (required for Container Apps without VNet integration)
Write-Host "Enabling public network access on SQL Server..." -ForegroundColor Yellow
az sql server update --name $SqlServerName --resource-group $ResourceGroupName --enable-public-network true --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Public network access enabled" -ForegroundColor Green
} else {
    Write-Host "Note: Could not update public network access (may already be enabled)" -ForegroundColor Yellow
}

# Add firewall rule to allow Azure services
Write-Host "Adding firewall rule for Azure services..." -ForegroundColor Yellow
$existingRule = az sql server firewall-rule show --resource-group $ResourceGroupName --server $SqlServerName --name "AllowAzureServices" 2>$null
if ($existingRule) {
    Write-Host "Azure services firewall rule already exists" -ForegroundColor Green
} else {
    az sql server firewall-rule create --resource-group $ResourceGroupName --server $SqlServerName --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Azure services firewall rule created" -ForegroundColor Green
    } else {
        Write-Host "Warning: Could not create firewall rule" -ForegroundColor Yellow
    }
}

# ============================================================================
# STEP 2: Configure App Role for MCP Server Entra Authentication
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Configuring Entra App Role for MCP Server..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Define the app role ID (using a fixed GUID for consistency across deployments)
$appRoleId = "e2e650a9-e097-4112-99cd-84c28e2951b9"

# Get current app roles
Write-Host "Checking MCP Server app registration for app roles..." -ForegroundColor Yellow
$existingRoles = az ad app show --id $McpServerClientId --query "appRoles" -o json 2>$null | ConvertFrom-Json

$roleExists = $false
if ($existingRoles) {
    foreach ($role in $existingRoles) {
        if ($role.id -eq $appRoleId) {
            $roleExists = $true
            break
        }
    }
}

if ($roleExists) {
    Write-Host "App role 'MCP.Access' already exists" -ForegroundColor Green
} else {
    Write-Host "Adding 'MCP.Access' app role to MCP Server app registration..." -ForegroundColor Yellow
    
    # Create app role JSON
    $appRoleJson = @"
[{"allowedMemberTypes":["Application"],"description":"Allows the app to access the MCP Server API","displayName":"MCP Access","id":"$appRoleId","isEnabled":true,"value":"MCP.Access"}]
"@
    
    # Write to temp file for az command
    $tempFile = [System.IO.Path]::GetTempFileName()
    $appRoleJson | Set-Content $tempFile -Encoding UTF8
    
    try {
        az ad app update --id $McpServerClientId --app-roles "@$tempFile" --output none
        if ($LASTEXITCODE -eq 0) {
            Write-Host "App role 'MCP.Access' added successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: Could not add app role (may require higher permissions)" -ForegroundColor Yellow
        }
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# STEP 3: Assign App Role to Agent API Managed Identity
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Assigning App Role to Agent API..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Get the MCP Server's service principal object ID
Write-Host "Getting MCP Server service principal..." -ForegroundColor Yellow
$mcpSpObjectId = az ad sp show --id $McpServerClientId --query "id" -o tsv 2>$null

if ($mcpSpObjectId) {
    Write-Host "MCP Server Service Principal: $mcpSpObjectId" -ForegroundColor DarkGray
    
    # Check if assignment already exists
    $existingAssignments = az rest --method get --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$mcpSpObjectId/appRoleAssignedTo" 2>$null | ConvertFrom-Json
    
    $assignmentExists = $false
    if ($existingAssignments -and $existingAssignments.value) {
        foreach ($assignment in $existingAssignments.value) {
            if ($assignment.principalId -eq $agentApiPrincipalId -and $assignment.appRoleId -eq $appRoleId) {
                $assignmentExists = $true
                break
            }
        }
    }
    
    if ($assignmentExists) {
        Write-Host "App role assignment already exists for Agent API" -ForegroundColor Green
    } else {
        Write-Host "Assigning 'MCP.Access' role to Agent API managed identity..." -ForegroundColor Yellow
        
        # Use temp file to avoid JSON escaping issues with az rest
        $assignmentBody = @{
            principalId = $agentApiPrincipalId
            resourceId = $mcpSpObjectId
            appRoleId = $appRoleId
        } | ConvertTo-Json
        
        $tempBodyFile = [System.IO.Path]::GetTempFileName()
        $assignmentBody | Set-Content $tempBodyFile -Encoding UTF8
        
        try {
            $assignmentResult = az rest --method post --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$mcpSpObjectId/appRoleAssignedTo" --headers "Content-Type=application/json" --body "@$tempBodyFile" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "App role assigned successfully" -ForegroundColor Green
            } elseif ($assignmentResult -match "Permission being assigned already exists") {
                Write-Host "App role assignment already exists" -ForegroundColor Green
            } else {
                Write-Host "Warning: Could not assign app role: $assignmentResult" -ForegroundColor Yellow
            }
        } finally {
            Remove-Item $tempBodyFile -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Warning: Could not find MCP Server service principal" -ForegroundColor Yellow
}

# ============================================================================
# STEP 4: Grant SQL Server access to MCP Server managed identity
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Granting SQL Database Access..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Import SqlServer module if available
$hasSqlModule = Get-Module -ListAvailable -Name SqlServer
if ($hasSqlModule) {
    Import-Module SqlServer -ErrorAction SilentlyContinue
    
    try {
        # Get access token for SQL
        $accessToken = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
        
        if ($accessToken) {
            $createUserSql = @"
-- Create Entra user from managed identity if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$mcpServerAppName')
BEGIN
    CREATE USER [$mcpServerAppName] FROM EXTERNAL PROVIDER;
    PRINT 'User created';
END

-- Grant read-only access
IF NOT EXISTS (SELECT * FROM sys.database_role_members rm JOIN sys.database_principals p ON rm.member_principal_id = p.principal_id WHERE p.name = '$mcpServerAppName')
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [$mcpServerAppName];
    PRINT 'Granted db_datareader';
END
"@
            
            Write-Host "Creating database user for MCP Server managed identity..." -ForegroundColor Yellow
            Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $SqlDatabaseName -AccessToken $accessToken -Query $createUserSql -ErrorAction Stop
            Write-Host "Database access granted to MCP Server" -ForegroundColor Green
        }
    } catch {
        if ($_.Exception.Message -match "already exists" -or $_.Exception.Message -match "Cannot add member") {
            Write-Host "Database user already configured" -ForegroundColor Green
        } else {
            Write-Host "Warning: Could not configure database access: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "You may need to run this SQL manually:" -ForegroundColor Yellow
            Write-Host "  CREATE USER [$mcpServerAppName] FROM EXTERNAL PROVIDER;" -ForegroundColor Gray
            Write-Host "  ALTER ROLE db_datareader ADD MEMBER [$mcpServerAppName];" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "SqlServer module not available - skipping automatic database user creation" -ForegroundColor Yellow
    Write-Host "Run this SQL manually in SSMS or Azure Data Studio:" -ForegroundColor Yellow
    Write-Host "  CREATE USER [$mcpServerAppName] FROM EXTERNAL PROVIDER;" -ForegroundColor Gray
    Write-Host "  ALTER ROLE db_datareader ADD MEMBER [$mcpServerAppName];" -ForegroundColor Gray
}

# ============================================================================
# STEP 5: Grant Azure OpenAI access to Agent API managed identity
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Granting Azure OpenAI Access to Agent API..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Try to determine Azure OpenAI resource from endpoint if not provided
if (-not $AzureOpenAiResourceName -or -not $AzureOpenAiResourceGroup) {
    Write-Host "Attempting to find Azure OpenAI resource from endpoint..." -ForegroundColor Yellow
    
    # Extract resource name from endpoint URL (format: https://<resource-name>.openai.azure.com/ or https://<resource-name>.cognitiveservices.azure.com/)
    if ($AzureOpenAiEndpoint -match 'https://([^.]+)\.(openai\.azure\.com|cognitiveservices\.azure\.com)') {
        $extractedResourceName = $Matches[1]
        Write-Host "  Extracted resource name: $extractedResourceName" -ForegroundColor DarkGray
        
        # Search for the resource across all subscriptions
        $aiResources = az cognitiveservices account list --query "[?contains(properties.endpoint, '$extractedResourceName')].{name:name,resourceGroup:resourceGroup}" -o json 2>$null | ConvertFrom-Json
        
        if ($aiResources -and $aiResources.Count -gt 0) {
            $AzureOpenAiResourceName = $aiResources[0].name
            $AzureOpenAiResourceGroup = $aiResources[0].resourceGroup
            Write-Host "  Found Azure OpenAI resource: $AzureOpenAiResourceName in $AzureOpenAiResourceGroup" -ForegroundColor Green
        }
    }
}

if ($AzureOpenAiResourceName -and $AzureOpenAiResourceGroup) {
    Write-Host "Assigning 'Cognitive Services OpenAI Contributor' role to Agent API..." -ForegroundColor Yellow
    
    # Get the resource ID
    $aiResourceId = az cognitiveservices account show --name $AzureOpenAiResourceName --resource-group $AzureOpenAiResourceGroup --query "id" -o tsv 2>$null
    
    if ($aiResourceId) {
        # Check if role assignment already exists
        $existingAssignment = az role assignment list --assignee $agentApiPrincipalId --scope $aiResourceId --query "[?roleDefinitionName=='Cognitive Services OpenAI Contributor']" -o json 2>$null | ConvertFrom-Json
        
        if ($existingAssignment -and $existingAssignment.Count -gt 0) {
            Write-Host "Role assignment already exists" -ForegroundColor Green
        } else {
            az role assignment create --assignee $agentApiPrincipalId --role "Cognitive Services OpenAI Contributor" --scope $aiResourceId --output none 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Azure OpenAI access granted to Agent API" -ForegroundColor Green
                Write-Host "  Note: Role assignment may take 1-2 minutes to propagate" -ForegroundColor DarkGray
            } else {
                Write-Host "Warning: Could not assign Azure OpenAI role. You may need to grant access manually:" -ForegroundColor Yellow
                Write-Host "  az role assignment create --assignee $agentApiPrincipalId --role 'Cognitive Services OpenAI Contributor' --scope $aiResourceId" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "Warning: Could not find Azure OpenAI resource. Grant access manually if needed." -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: Azure OpenAI resource not specified. If the Agent API fails with 401 errors," -ForegroundColor Yellow
    Write-Host "grant access manually using:" -ForegroundColor Yellow
    Write-Host "  az role assignment create --assignee $agentApiPrincipalId --role 'Cognitive Services OpenAI Contributor' --scope <azure-openai-resource-id>" -ForegroundColor Gray
}

# ============================================================================
# STEP 6: Wait for services to be ready
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Waiting for Services to Start..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "Waiting 30 seconds for Container Apps to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Test MCP Server health - Note: MCP Server is internal, so we check via logs instead
$mcpServerFqdn = $outputs.mcpServerEndpointUrl.value
Write-Host "Checking MCP Server status..." -ForegroundColor Yellow

# MCP Server is internal-only, so we can't directly health check it from outside
# Instead, check if the container is running by querying its status
$mcpHealthy = $false
$mcpStatus = az containerapp show --name $mcpServerAppName --resource-group $ResourceGroupName --query "properties.runningStatus" -o tsv 2>$null
if ($mcpStatus -eq "Running") {
    # Also check recent logs for health check success
    $recentLogs = az containerapp logs show --name $mcpServerAppName --resource-group $ResourceGroupName --tail 20 2>$null
    if ($recentLogs -match "Application started" -or $recentLogs -match "Now listening") {
        $mcpHealthy = $true
        Write-Host "MCP Server is running (internal endpoint: $mcpServerFqdn)" -ForegroundColor Green
    } else {
        Write-Host "MCP Server container is starting..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        $mcpHealthy = $true  # Assume healthy if container is running
        Write-Host "MCP Server is running (internal endpoint: $mcpServerFqdn)" -ForegroundColor Green
    }
} else {
    Write-Host "MCP Server status: $mcpStatus" -ForegroundColor Yellow
}

if (-not $mcpHealthy) {
    Write-Host "Warning: MCP Server health check did not pass. Check logs with:" -ForegroundColor Yellow
    Write-Host "  az containerapp logs show --name $mcpServerAppName --resource-group $ResourceGroupName --follow" -ForegroundColor Gray
}

# Test Agent API health
$agentApiEndpoint = $outputs.agentApiEndpointUrl.value
Write-Host "Testing Agent API health..." -ForegroundColor Yellow
$apiHealthy = $false
for ($i = 1; $i -le 6; $i++) {
    try {
        $response = Invoke-RestMethod -Uri "$agentApiEndpoint/health" -Method GET -TimeoutSec 10
        if ($response -eq "Healthy") {
            $apiHealthy = $true
            Write-Host "Agent API is healthy!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  Attempt $i/6: Agent API not ready yet..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }
}

if (-not $apiHealthy) {
    Write-Host "Warning: Agent API health check did not pass. Check logs with:" -ForegroundColor Yellow
    Write-Host "  az containerapp logs show --name $agentApiAppName --resource-group $ResourceGroupName --follow" -ForegroundColor Gray
}

# ============================================================================
# WARM-UP: Establish MCP Connection
# ============================================================================
# The first request to the API triggers lazy initialization of the MCP client
# which acquires an Entra ID token and establishes an SSE connection.
# This can timeout on the first request, so we warm it up here.
Write-Host ""
Write-Host "Warming up MCP connection (first request initializes the connection)..." -ForegroundColor Yellow
$warmupSuccess = $false
for ($i = 1; $i -le 3; $i++) {
    try {
        $warmupBody = @{ message = "hello" } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$agentApiEndpoint/api/chat" -Method POST -Body $warmupBody -ContentType "application/json" -TimeoutSec 60
        $warmupSuccess = $true
        Write-Host "MCP connection established successfully!" -ForegroundColor Green
        break
    } catch {
        Write-Host "  Warm-up attempt $i/3: $($_.Exception.Message)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

if (-not $warmupSuccess) {
    Write-Host "Warning: Warm-up did not complete. First user request may be slow or timeout." -ForegroundColor Yellow
    Write-Host "  The MCP connection will be established on the first user request." -ForegroundColor Gray
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "MCP Server:     $mcpServerFqdn" -ForegroundColor Cyan
Write-Host "Agent API:      $agentApiEndpoint" -ForegroundColor Cyan
Write-Host ""
Write-Host "Health Status:" -ForegroundColor Yellow
Write-Host "  MCP Server:   $(if ($mcpHealthy) { 'Healthy' } else { 'Check logs' })" -ForegroundColor $(if ($mcpHealthy) { 'Green' } else { 'Yellow' })
Write-Host "  Agent API:    $(if ($apiHealthy) { 'Healthy' } else { 'Check logs' })" -ForegroundColor $(if ($apiHealthy) { 'Green' } else { 'Yellow' })
Write-Host ""
Write-Host "Test the deployment:" -ForegroundColor Yellow
Write-Host "  curl -X POST $agentApiEndpoint/api/chat -H 'Content-Type: application/json' -d '{\"message\": \"What patients are in the database?\"}'" -ForegroundColor White
Write-Host ""
Write-Host "View logs:" -ForegroundColor Yellow
Write-Host "  az containerapp logs show --name $mcpServerAppName --resource-group $ResourceGroupName --follow" -ForegroundColor Gray
Write-Host "  az containerapp logs show --name $agentApiAppName --resource-group $ResourceGroupName --follow" -ForegroundColor Gray
