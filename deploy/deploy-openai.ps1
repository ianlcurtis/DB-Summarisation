<#
.SYNOPSIS
    Deploys Azure OpenAI GPT-4o for use by the Medical Aspire application.

.DESCRIPTION
    This script:
    1. Authenticates to Azure (if not already logged in)
    2. Creates the resource group if it doesn't exist
    3. Deploys Azure OpenAI account with GPT-4o model
    4. Outputs the connection string for use with Aspire

.PARAMETER EnvironmentName
    The environment name suffix (e.g., dev, staging, prod). Default: dev

.PARAMETER Location
    The Azure region. Default: swedencentral
    Note: Azure OpenAI is only available in certain regions. Check availability at:
    https://learn.microsoft.com/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability

.PARAMETER ResourceGroupName
    Optional. Override the default resource group name.

.PARAMETER Gpt4oDeploymentName
    The name for the GPT-4o model deployment. Default: gpt-4o

.PARAMETER Gpt4oCapacity
    Capacity for GPT-4o deployment in tokens per minute (thousands). Default: 10

.PARAMETER SkipInfrastructure
    Skip infrastructure deployment (use existing OpenAI resource)

.EXAMPLE
    .\deploy-openai.ps1
    
.EXAMPLE
    .\deploy-openai.ps1 -EnvironmentName prod -Location swedencentral

.EXAMPLE
    .\deploy-openai.ps1 -Gpt4oCapacity 20
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
    [string]$Gpt4oDeploymentName = "gpt-4o",

    [Parameter()]
    [int]$Gpt4oCapacity = 10,

    [Parameter()]
    [switch]$SkipInfrastructure
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$BaseName = "medmcp"
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir
$InfraDir = Join-Path $RepoRoot "infra"

if (-not $ResourceGroupName) {
    $ResourceGroupName = "$BaseName-$EnvironmentName-rg"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure OpenAI Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:        $EnvironmentName"
Write-Host "Location:           $Location"
Write-Host "Resource Group:     $ResourceGroupName"
Write-Host "GPT-4o Deployment:  $Gpt4oDeploymentName"
Write-Host "GPT-4o Capacity:    $Gpt4oCapacity (K tokens/min)"
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

function Ensure-ResourceGroup {
    param([string]$Name, [string]$Location)
    
    Write-Host "`nChecking resource group '$Name'..." -ForegroundColor Yellow
    
    $rg = az group show --name $Name 2>$null | ConvertFrom-Json
    if (-not $rg) {
        Write-Host "Creating resource group '$Name' in '$Location'..." -ForegroundColor Yellow
        az group create --name $Name --location $Location | Out-Null
        Write-Host "Resource group created." -ForegroundColor Green
    }
    else {
        Write-Host "Resource group already exists." -ForegroundColor Green
    }
}

function Deploy-OpenAI {
    param(
        [string]$ResourceGroupName,
        [string]$Location,
        [string]$EnvironmentName,
        [string]$Gpt4oDeploymentName,
        [int]$Gpt4oCapacity
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Deploying Azure OpenAI..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $bicepFile = Join-Path $InfraDir "openai.bicep"
    
    if (-not (Test-Path $bicepFile)) {
        Write-Error "Bicep file not found: $bicepFile"
        exit 1
    }
    
    $deploymentName = "openai-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "Starting Bicep deployment: $deploymentName" -ForegroundColor Yellow
    
    $result = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters environmentName=$EnvironmentName `
        --parameters location=$Location `
        --parameters baseName=$BaseName `
        --parameters gpt4oDeploymentName=$Gpt4oDeploymentName `
        --parameters gpt4oCapacity=$Gpt4oCapacity `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Bicep deployment failed!"
        exit 1
    }
    
    Write-Host "Azure OpenAI deployed successfully!" -ForegroundColor Green
    
    return $result.properties.outputs
}

function Get-OpenAIConnectionString {
    param(
        [string]$ResourceGroupName,
        [string]$AccountName
    )
    
    Write-Host "`nRetrieving Azure OpenAI connection details..." -ForegroundColor Yellow
    
    # Get the endpoint
    $account = az cognitiveservices account show `
        --name $AccountName `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json
    
    $endpoint = $account.properties.endpoint
    
    # Get the primary key
    $keys = az cognitiveservices account keys list `
        --name $AccountName `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json
    
    $primaryKey = $keys.key1
    
    # Build connection string in the format expected by Azure SDK
    $connectionString = "Endpoint=$endpoint;Key=$primaryKey"
    
    return @{
        Endpoint = $endpoint
        Key = $primaryKey
        ConnectionString = $connectionString
        AccountName = $AccountName
    }
}

# ============================================================================
# Main Execution
# ============================================================================

# Check Azure login
Write-Host "`nChecking Azure authentication..." -ForegroundColor Yellow
$account = Test-AzureLogin
if (-not $account) {
    Write-Host "Not logged in to Azure. Running 'az login'..." -ForegroundColor Yellow
    az login | Out-Null
    $account = Test-AzureLogin
    if (-not $account) {
        Write-Error "Failed to authenticate to Azure."
        exit 1
    }
}

# Ensure resource group exists
Ensure-ResourceGroup -Name $ResourceGroupName -Location $Location

# Deploy OpenAI infrastructure
$outputs = $null
if (-not $SkipInfrastructure) {
    $outputs = Deploy-OpenAI `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -EnvironmentName $EnvironmentName `
        -Gpt4oDeploymentName $Gpt4oDeploymentName `
        -Gpt4oCapacity $Gpt4oCapacity
    
    $accountName = $outputs.openAiAccountName.value
}
else {
    Write-Host "`nSkipping infrastructure deployment (using existing resource)..." -ForegroundColor Yellow
    $accountName = "$BaseName-$EnvironmentName-openai"
}

# Get connection details
$connectionInfo = Get-OpenAIConnectionString `
    -ResourceGroupName $ResourceGroupName `
    -AccountName $accountName

# ============================================================================
# Output Summary
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Azure OpenAI Account:    $($connectionInfo.AccountName)" -ForegroundColor White
Write-Host "Endpoint:                $($connectionInfo.Endpoint)" -ForegroundColor White
Write-Host "GPT-4o Deployment:       $Gpt4oDeploymentName" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration for Aspire" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add the following to your appsettings.json or user secrets:" -ForegroundColor Yellow
Write-Host ""
Write-Host "{" -ForegroundColor White
Write-Host "  `"ConnectionStrings`": {" -ForegroundColor White
Write-Host "    `"openai`": `"$($connectionInfo.ConnectionString)`"" -ForegroundColor Cyan
Write-Host "  }" -ForegroundColor White
Write-Host "}" -ForegroundColor White
Write-Host ""
Write-Host "Or set as environment variable:" -ForegroundColor Yellow
Write-Host ""
Write-Host "ConnectionStrings__openai=$($connectionInfo.ConnectionString)" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "For deploy-aspire.ps1 script:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "-AzureOpenAiEndpoint `"$($connectionInfo.Endpoint)`"" -ForegroundColor Cyan
Write-Host "-AzureOpenAiResourceGroup `"$ResourceGroupName`"" -ForegroundColor Cyan
Write-Host "-AzureOpenAiResourceName `"$($connectionInfo.AccountName)`"" -ForegroundColor Cyan
Write-Host ""

# Output for scripting
$output = @{
    AccountName = $connectionInfo.AccountName
    Endpoint = $connectionInfo.Endpoint
    ConnectionString = $connectionInfo.ConnectionString
    DeploymentName = $Gpt4oDeploymentName
    ResourceGroup = $ResourceGroupName
}

return $output
