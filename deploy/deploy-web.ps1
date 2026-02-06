<#
.SYNOPSIS
    Deploys the Medical Agent React Web Frontend to Azure Container Apps.

.DESCRIPTION
    This script:
    1. Builds the React application Docker image
    2. Pushes the image to Azure Container Registry
    3. Creates/updates the Container App for the web frontend
    4. Configures the frontend to connect to the Agent API

.PARAMETER ResourceGroupName
    The Azure resource group name where resources will be deployed.

.PARAMETER AcrName
    The name of the Azure Container Registry (must already exist).

.PARAMETER AgentApiUrl
    The URL of the Agent API (e.g., https://your-api.your-environment.your-region.azurecontainerapps.io).

.PARAMETER ImageTag
    The tag to use for Docker images (default: latest).

.PARAMETER Location
    The Azure region for deployment (default: swedencentral).

.PARAMETER EnvironmentName
    The Container Apps Environment name (must already exist).

.PARAMETER BaseName
    The base name for resources (default: medmcp).

.EXAMPLE
    .\deploy-web.ps1 -ResourceGroupName "my-rg" -AcrName "myacr" `
        -AgentApiUrl "https://your-api.your-environment.your-region.azurecontainerapps.io" `
        -EnvironmentName "my-env"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$AgentApiUrl,

    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,

    [string]$ImageTag = "latest",
    [string]$Location = "swedencentral",
    [string]$BaseName = "medmcp"
)

$ErrorActionPreference = "Stop"

# Get the repository root directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$webProjectDir = Join-Path $repoRoot "src/MedicalAgent.Web"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Medical Agent Web Frontend Deployment" -ForegroundColor Cyan
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

# Build and push Web Frontend image
Write-Host ""
Write-Host "Building Web Frontend Docker image..." -ForegroundColor Yellow
$webImageName = "medical-agent-web"
$webImageFull = "${acrLoginServer}/${webImageName}:${ImageTag}"

Push-Location $webProjectDir
try {
    docker build -t $webImageFull .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Web Frontend Docker image"
        exit 1
    }
    Write-Host "Web Frontend image built: $webImageFull" -ForegroundColor Green

    Write-Host "Pushing Web Frontend image to ACR..." -ForegroundColor Yellow
    docker push $webImageFull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push Web Frontend image"
        exit 1
    }
    Write-Host "Web Frontend image pushed" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Get ACR credentials for Container Apps
Write-Host ""
Write-Host "Getting ACR credentials..." -ForegroundColor Yellow
$acrCredentials = az acr credential show --name $AcrName | ConvertFrom-Json
$acrUsername = $acrCredentials.username
$acrPassword = $acrCredentials.passwords[0].value

# Check if Container App exists
$webAppName = "${BaseName}-test-web"
Write-Host ""
Write-Host "Checking if Container App '$webAppName' exists..." -ForegroundColor Yellow

$existingApp = az containerapp show --name $webAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -eq 0) {
    # Update existing Container App
    Write-Host "Updating existing Container App..." -ForegroundColor Yellow
    az containerapp update `
        --name $webAppName `
        --resource-group $ResourceGroupName `
        --image $webImageFull `
        --set-env-vars "API_URL=$AgentApiUrl"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update Container App"
        exit 1
    }
}
else {
    # Create new Container App
    Write-Host "Creating new Container App..." -ForegroundColor Yellow
    az containerapp create `
        --name $webAppName `
        --resource-group $ResourceGroupName `
        --environment $EnvironmentName `
        --image $webImageFull `
        --target-port 80 `
        --ingress external `
        --registry-server $acrLoginServer `
        --registry-username $acrUsername `
        --registry-password $acrPassword `
        --env-vars "API_URL=$AgentApiUrl" `
        --cpu 0.25 `
        --memory 0.5Gi `
        --min-replicas 1 `
        --max-replicas 3 `
        --tags "environment=test" "project=medical-aspire" "component=web-frontend"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Container App"
        exit 1
    }
}

Write-Host "Container App deployed successfully" -ForegroundColor Green

# Get the FQDN
Write-Host ""
Write-Host "Getting deployment URL..." -ForegroundColor Yellow
$webFqdn = az containerapp show --name $webAppName --resource-group $ResourceGroupName --query "properties.configuration.ingress.fqdn" -o tsv

# Test the web frontend is accessible
Write-Host ""
Write-Host "Testing web frontend..." -ForegroundColor Yellow
$webHealthy = $false
for ($i = 1; $i -le 3; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "https://$webFqdn" -Method GET -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $webHealthy = $true
            Write-Host "Web frontend is accessible!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  Attempt $i/3: Web frontend not ready yet..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

# Warm up the backend API connection
Write-Host ""
Write-Host "Warming up backend API connection..." -ForegroundColor Yellow
Write-Host "  (First request establishes MCP connection - may take up to 60 seconds)" -ForegroundColor DarkGray
$warmupSuccess = $false
try {
    $warmupBody = @{ message = "hello" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$AgentApiUrl/api/chat" -Method POST -Body $warmupBody -ContentType "application/json" -TimeoutSec 60
    $warmupSuccess = $true
    Write-Host "Backend API is warm and ready!" -ForegroundColor Green
} catch {
    Write-Host "  Warm-up request: $($_.Exception.Message)" -ForegroundColor DarkGray
    Write-Host "  The first user request may be slower as it initializes the connection." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Web Frontend URL: https://$webFqdn" -ForegroundColor Cyan
Write-Host "Agent API URL:    $AgentApiUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Status:" -ForegroundColor Yellow
Write-Host "  Web Frontend:   $(if ($webHealthy) { 'Accessible' } else { 'Check logs' })" -ForegroundColor $(if ($webHealthy) { 'Green' } else { 'Yellow' })
Write-Host "  API Connection: $(if ($warmupSuccess) { 'Ready' } else { 'Will initialize on first request' })" -ForegroundColor $(if ($warmupSuccess) { 'Green' } else { 'Yellow' })
Write-Host ""
Write-Host ""
