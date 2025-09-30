<#
.SYNOPSIS
    Syncs approved MCP servers to Azure API Center.

.DESCRIPTION
    Reads approved server metadata files from the approved-servers directory
    and synchronizes them to Azure API Center. Creates or updates APIs in
    API Center based on the metadata.
    
    Authentication uses Azure OIDC (Workload Identity Federation) when running
    in GitHub Actions, or interactive login for local development.

.PARAMETER SubscriptionId
    Azure subscription ID where the API Center is located.

.PARAMETER ResourceGroupName
    Name of the resource group containing the API Center.

.PARAMETER ApiCenterName
    Name of the API Center instance.

.PARAMETER DryRun
    If specified, performs a dry run without making any changes to Azure.

.PARAMETER Path
    Path to the approved-servers directory. Defaults to ../approved-servers
    relative to the script location.

.EXAMPLE
    ./Sync-ToAPICenter.ps1 -SubscriptionId "xxx" -ResourceGroupName "rg-api-center" -ApiCenterName "my-api-center"

.EXAMPLE
    ./Sync-ToAPICenter.ps1 -SubscriptionId "xxx" -ResourceGroupName "rg-api-center" -ApiCenterName "my-api-center" -DryRun

.NOTES
    Requires Az.Accounts and Az.Resources modules.
    Authentication is handled automatically via OIDC in GitHub Actions.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiCenterName,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [string]$Path
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Function to write formatted output
function Write-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $emoji = switch ($Level) {
        'Info'    { '📋' }
        'Success' { '✅' }
        'Warning' { '⚠️' }
        'Error'   { '❌' }
    }
    
    Write-Host "$emoji $Message"
}

# Function to get or create API Center workspace
function Get-OrCreateWorkspace {
    param(
        [string]$WorkspaceName = 'default'
    )
    
    try {
        $workspace = Get-AzResource `
            -ResourceGroupName $ResourceGroupName `
            -ResourceType "Microsoft.ApiCenter/services/workspaces" `
            -ResourceName "$ApiCenterName/$WorkspaceName" `
            -ApiVersion "2024-03-01" `
            -ErrorAction SilentlyContinue
        
        if ($workspace) {
            Write-Status "Workspace '$WorkspaceName' found" -Level Success
            return $workspace
        }
        
        if ($DryRun) {
            Write-Status "Would create workspace '$WorkspaceName'" -Level Info
            return $null
        }
        
        Write-Status "Creating workspace '$WorkspaceName'..." -Level Info
        
        $workspaceProperties = @{
            properties = @{
                title = $WorkspaceName
                description = "MCP Servers workspace"
            }
        }
        
        $workspace = New-AzResource `
            -ResourceGroupName $ResourceGroupName `
            -ResourceType "Microsoft.ApiCenter/services/workspaces" `
            -ResourceName "$ApiCenterName/$WorkspaceName" `
            -ApiVersion "2024-03-01" `
            -Properties $workspaceProperties.properties `
            -Force
        
        Write-Status "Workspace created successfully" -Level Success
        return $workspace
    }
    catch {
        Write-Status "Failed to get/create workspace: $($_.Exception.Message)" -Level Error
        throw
    }
}

# Function to sync a server to API Center
function Sync-Server {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Metadata,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $serverName = $Metadata.name
    $apiName = "mcp-$serverName"
    
    Write-Status "Processing: $serverName" -Level Info
    
    # Prepare API properties
    $apiProperties = @{
        title = $Metadata.name
        description = $Metadata.description
        kind = 'rest'
        type = 'rest'
        contacts = @()
        externalDocumentation = @(
            @{
                title = 'Homepage'
                url = $Metadata.homepage
            }
        )
        customProperties = @{
            source = $Metadata.source
            approved_by = $Metadata.approved_by
            approved_date = $Metadata.approved_date
        }
    }
    
    # Add tags if present
    if ($Metadata.tags) {
        $apiProperties.customProperties.tags = ($Metadata.tags -join ',')
    }
    
    # Add security review if present
    if ($Metadata.security_review) {
        $apiProperties.customProperties.security_reviewed = $Metadata.security_review.approved
        $apiProperties.customProperties.security_reviewer = $Metadata.security_review.reviewed_by
        $apiProperties.customProperties.security_review_date = $Metadata.security_review.review_date
    }
    
    # Add custom metadata if present
    if ($Metadata.custom_metadata) {
        foreach ($key in $Metadata.custom_metadata.PSObject.Properties.Name) {
            $apiProperties.customProperties[$key] = $Metadata.custom_metadata.$key
        }
    }
    
    if ($DryRun) {
        Write-Status "  [DRY RUN] Would create/update API: $apiName" -Level Warning
        Write-Status "    Title: $($apiProperties.title)" -Level Info
        Write-Status "    Description: $($apiProperties.description)" -Level Info
        Write-Status "    Source: $($Metadata.source)" -Level Info
        return @{ Action = 'DryRun'; Name = $apiName }
    }
    
    try {
        # Check if API exists
        $existingApi = Get-AzResource `
            -ResourceGroupName $ResourceGroupName `
            -ResourceType "Microsoft.ApiCenter/services/workspaces/apis" `
            -ResourceName "$ApiCenterName/default/$apiName" `
            -ApiVersion "2024-03-01" `
            -ErrorAction SilentlyContinue
        
        if ($existingApi) {
            Write-Status "  Updating existing API: $apiName" -Level Info
            
            $api = Set-AzResource `
                -ResourceGroupName $ResourceGroupName `
                -ResourceType "Microsoft.ApiCenter/services/workspaces/apis" `
                -ResourceName "$ApiCenterName/default/$apiName" `
                -ApiVersion "2024-03-01" `
                -Properties $apiProperties `
                -Force
            
            Write-Status "  API updated successfully" -Level Success
            return @{ Action = 'Updated'; Name = $apiName; Resource = $api }
        }
        else {
            Write-Status "  Creating new API: $apiName" -Level Info
            
            $api = New-AzResource `
                -ResourceGroupName $ResourceGroupName `
                -ResourceType "Microsoft.ApiCenter/services/workspaces/apis" `
                -ResourceName "$ApiCenterName/default/$apiName" `
                -ApiVersion "2024-03-01" `
                -Properties $apiProperties `
                -Force
            
            Write-Status "  API created successfully" -Level Success
            return @{ Action = 'Created'; Name = $apiName; Resource = $api }
        }
    }
    catch {
        Write-Status "  Failed to sync API: $($_.Exception.Message)" -Level Error
        return @{ Action = 'Failed'; Name = $apiName; Error = $_.Exception.Message }
    }
}

#
# Main Script
#

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host "║      MCP Server Sync to Azure API Center                  ║"
Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host ""

# Determine approved-servers path
if (-not $Path) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $Path = Join-Path (Split-Path -Parent $scriptDir) "approved-servers"
}

$Path = Resolve-Path $Path -ErrorAction SilentlyContinue
if (-not $Path -or -not (Test-Path $Path)) {
    Write-Status "Approved servers directory not found: $Path" -Level Error
    exit 1
}

Write-Status "Approved servers path: $Path" -Level Info
Write-Status "Azure Subscription: $SubscriptionId" -Level Info
Write-Status "Resource Group: $ResourceGroupName" -Level Info
Write-Status "API Center: $ApiCenterName" -Level Info

if ($DryRun) {
    Write-Host ""
    Write-Status "🔍 DRY RUN MODE - No changes will be made to Azure" -Level Warning
    Write-Host ""
}

# Verify Azure connection
Write-Host ""
Write-Status "Verifying Azure connection..." -Level Info

try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Status "Not connected to Azure. Attempting interactive login..." -Level Warning
        Connect-AzAccount -SubscriptionId $SubscriptionId
        $context = Get-AzContext
    }
    
    if ($context.Subscription.Id -ne $SubscriptionId) {
        Write-Status "Switching to subscription: $SubscriptionId" -Level Info
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    Write-Status "Connected to Azure" -Level Success
    Write-Status "  Subscription: $($context.Subscription.Name)" -Level Info
    Write-Status "  Account: $($context.Account.Id)" -Level Info
}
catch {
    Write-Status "Failed to connect to Azure: $($_.Exception.Message)" -Level Error
    exit 1
}

# Verify API Center exists
Write-Host ""
Write-Status "Verifying API Center exists..." -Level Info

try {
    $apiCenter = Get-AzResource `
        -ResourceGroupName $ResourceGroupName `
        -ResourceType "Microsoft.ApiCenter/services" `
        -ResourceName $ApiCenterName `
        -ApiVersion "2024-03-01" `
        -ErrorAction Stop
    
    Write-Status "API Center found: $($apiCenter.Name)" -Level Success
}
catch {
    Write-Status "API Center not found: $ApiCenterName" -Level Error
    Write-Status "Please ensure the API Center exists in the specified resource group" -Level Error
    exit 1
}

# Ensure workspace exists
Write-Host ""
Write-Status "Setting up workspace..." -Level Info
$workspace = Get-OrCreateWorkspace -WorkspaceName "default"

# Find all approved server files
Write-Host ""
Write-Status "Scanning for approved servers..." -Level Info

$officialServers = Get-ChildItem -Path (Join-Path $Path "official") -Filter "*.json" -File -ErrorAction SilentlyContinue
$communityServers = Get-ChildItem -Path (Join-Path $Path "community") -Filter "*.json" -File -ErrorAction SilentlyContinue

$totalServers = ($officialServers.Count + $communityServers.Count)

Write-Status "Found $($officialServers.Count) official servers" -Level Info
Write-Status "Found $($communityServers.Count) community servers" -Level Info
Write-Status "Total: $totalServers servers to sync" -Level Info

if ($totalServers -eq 0) {
    Write-Status "No approved servers found. Nothing to sync." -Level Warning
    exit 0
}

# Sync servers
Write-Host ""
Write-Status "Starting sync process..." -Level Info
Write-Host ""

$results = @{
    Created = @()
    Updated = @()
    Failed = @()
    DryRun = @()
}

# Process official servers
foreach ($file in $officialServers) {
    try {
        $metadata = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $result = Sync-Server -Metadata $metadata -FilePath $file.FullName
        
        $results[$result.Action] += $result
    }
    catch {
        Write-Status "Failed to process $($file.Name): $($_.Exception.Message)" -Level Error
        $results.Failed += @{ Name = $file.Name; Error = $_.Exception.Message }
    }
    Write-Host ""
}

# Process community servers
foreach ($file in $communityServers) {
    try {
        $metadata = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $result = Sync-Server -Metadata $metadata -FilePath $file.FullName
        
        $results[$result.Action] += $result
    }
    catch {
        Write-Status "Failed to process $($file.Name): $($_.Exception.Message)" -Level Error
        $results.Failed += @{ Name = $file.Name; Error = $_.Exception.Message }
    }
    Write-Host ""
}

# Display summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host "║                    Sync Summary                            ║"
Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host ""

if ($DryRun) {
    Write-Status "Dry Run Results:" -Level Info
    Write-Status "  Would process: $($results.DryRun.Count) servers" -Level Info
}
else {
    Write-Status "Created: $($results.Created.Count) new APIs" -Level Success
    Write-Status "Updated: $($results.Updated.Count) existing APIs" -Level Success
    if ($results.Failed.Count -gt 0) {
        Write-Status "Failed: $($results.Failed.Count) servers" -Level Error
        foreach ($failure in $results.Failed) {
            Write-Status "  - $($failure.Name): $($failure.Error)" -Level Error
        }
    }
}

Write-Host ""
Write-Status "Sync completed!" -Level Success
Write-Host ""

# Exit with error code if any failures
if ($results.Failed.Count -gt 0) {
    exit 1
}

exit 0
