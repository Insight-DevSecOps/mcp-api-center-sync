<#
.SYNOPSIS
    Fetches and parses MCP servers from the public GitHub registry.

.DESCRIPTION
    This script scrapes the Model Context Protocol servers repository README
    to discover all available MCP servers (both Official Integrations and Community).
    It extracts metadata, enriches it with additional repository information,
    and exports the results to JSON for further processing.

.PARAMETER OutputPath
    Path where the JSON output file will be saved. Default: ../output/discovered-servers.json

.PARAMETER GitHubToken
    GitHub Personal Access Token for API calls (increases rate limits). Optional.

.PARAMETER IncludeCommunity
    Include community servers in addition to official integrations. Default: $true

.PARAMETER EnrichWithRepoData
    Fetch additional metadata from each repository (stars, description, etc.). Default: $false

.PARAMETER Categories
    Array of categories to include. Default: all categories.
    Options: "Official Integrations", "Community Servers"

.EXAMPLE
    .\Get-MCPServers.ps1
    Basic usage - fetches all servers and saves to default output location

.EXAMPLE
    .\Get-MCPServers.ps1 -OutputPath "C:\data\mcp-servers.json" -GitHubToken $env:GITHUB_TOKEN
    Uses GitHub token for higher rate limits and custom output path

.EXAMPLE
    .\Get-MCPServers.ps1 -Categories "Official Integrations" -EnrichWithRepoData
    Only fetch official integrations and enrich with repository metadata

.NOTES
    Author: System Architecture Team
    Version: 1.0
    Date: 2025-09-29
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "../output/discovered-servers.json",

    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $null,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeCommunity = $true,

    [Parameter(Mandatory = $false)]
    [bool]$EnrichWithRepoData = $false,

    [Parameter(Mandatory = $false)]
    [string[]]$Categories = @("Official Integrations", "Community Servers")
)

#Requires -Version 7.0

# Configuration
$script:Config = @{
    RegistryUrl = "https://raw.githubusercontent.com/modelcontextprotocol/servers/main/README.md"
    GitHubApiBase = "https://api.github.com"
    UserAgent = "MCP-API-Center-Sync/1.0"
    RateLimitDelay = 1000 # milliseconds between API calls
}

#region Helper Functions

<#
.SYNOPSIS
    Makes an HTTP request with retry logic and rate limiting.
#>
function Invoke-SafeWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    $Headers['User-Agent'] = $script:Config.UserAgent
    
    if ($GitHubToken -and $Uri -like "*api.github.com*") {
        $Headers['Authorization'] = "token $GitHubToken"
    }

    $retryCount = 0
    $success = $false
    $response = $null

    while (-not $success -and $retryCount -lt $MaxRetries) {
        try {
            Write-Verbose "Fetching: $Uri (Attempt $($retryCount + 1)/$MaxRetries)"
            $response = Invoke-RestMethod -Uri $Uri -Headers $Headers -ErrorAction Stop
            $success = $true
        }
        catch {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                Write-Warning "Failed to fetch $Uri after $MaxRetries attempts: $_"
                return $null
            }
            Write-Verbose "Request failed, retrying in $($script:Config.RateLimitDelay)ms..."
            Start-Sleep -Milliseconds $script:Config.RateLimitDelay
        }
    }

    return $response
}

<#
.SYNOPSIS
    Parses the MCP servers README markdown to extract server information.
#>
function Get-MCPServersFromReadme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReadmeContent
    )

    $servers = @()
    $currentCategory = $null
    $lines = $ReadmeContent -split "`n"

    Write-Host "Parsing README content..." -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        # Detect category headers (Official Integrations and Community Servers)
        if ($line -match '^###\s+🎖️\s+Official Integrations') {
            $currentCategory = "Official Integrations"
            Write-Verbose "Found category: $currentCategory"
            continue
        }
        if ($line -match '^###\s+🌎\s+Community Servers') {
            $currentCategory = "Community Servers"
            Write-Verbose "Found category: $currentCategory"
            continue
        }
        # Also check without emoji (backup pattern)
        if ($line -match '^###?\s+Official Integrations') {
            $currentCategory = "Official Integrations"
            Write-Verbose "Found category: $currentCategory"
            continue
        }
        if ($line -match '^###?\s+Community Servers') {
            $currentCategory = "Community Servers"
            Write-Verbose "Found category: $currentCategory"
            continue
        }

        # Skip if not in a desired category
        if (-not $currentCategory -or $currentCategory -notin $Categories) {
            continue
        }

        # Parse server entries (format: - <img...> **[Name](url)** - Description)
        # Also handle format: - **[Name](url)** - Description (without logo)
        if ($line -match '^\s*-\s+(?:<img[^>]*>)?\s*\*\*\[(.+?)\]\((.+?)\)\*\*\s*(?:[-–]\s*(.+))?') {
            $name = $Matches[1]
            $url = $Matches[2]
            $description = if ($Matches[3]) { $Matches[3].Trim() } else { "" }
            
            # Try to extract logo URL from img tag if present
            $logoUrl = $null
            if ($line -match '<img[^>]+src="([^"]+)"') {
                $logoUrl = $Matches[1]
            }

            # Extract repository information from URL
            $repoInfo = Get-RepositoryInfoFromUrl -Url $url

            if ($repoInfo) {
                $server = [PSCustomObject]@{
                    ServerId = New-Guid | Select-Object -ExpandProperty Guid
                    Name = $name
                    Description = $description
                    Category = $currentCategory
                    RepositoryUrl = $url
                    Owner = $repoInfo.Owner
                    Repository = $repoInfo.Repository
                    LogoUrl = $logoUrl
                    DiscoveredDate = Get-Date -Format "yyyy-MM-dd"
                    Language = $null
                    License = $null
                    Stars = $null
                    LastUpdated = $null
                    Topics = @()
                    ApprovalStatus = "Pending Review"
                }

                $servers += $server
                Write-Verbose "Found server: $name ($($currentCategory))"
            }
        }
    }

    Write-Host "Found $($servers.Count) MCP servers" -ForegroundColor Green
    return $servers
}

<#
.SYNOPSIS
    Extracts owner and repository name from a GitHub URL.
#>
function Get-RepositoryInfoFromUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    # Handle various GitHub URL formats
    if ($Url -match 'github\.com[:/]([^/]+)/([^/\s#?]+)') {
        return @{
            Owner = $Matches[1]
            Repository = ($Matches[2] -replace '\.git$', '')
        }
    }

    Write-Verbose "Could not parse GitHub URL: $Url"
    return $null
}

<#
.SYNOPSIS
    Enriches server data with additional information from GitHub API.
#>
function Add-RepositoryMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Servers
    )

    Write-Host "`nEnriching servers with repository metadata..." -ForegroundColor Cyan
    $enrichedServers = @()
    $total = $Servers.Count
    $current = 0

    foreach ($server in $Servers) {
        $current++
        $percentComplete = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Enriching server metadata" `
                       -Status "$current of $total - $($server.Name)" `
                       -PercentComplete $percentComplete

        if ($server.Owner -and $server.Repository) {
            $repoUrl = "$($script:Config.GitHubApiBase)/repos/$($server.Owner)/$($server.Repository)"
            $repoData = Invoke-SafeWebRequest -Uri $repoUrl

            if ($repoData) {
                # Update server with repository data
                $server.Language = $repoData.language
                $server.License = if ($repoData.license) { $repoData.license.spdx_id } else { "Unknown" }
                $server.Stars = $repoData.stargazers_count
                $server.LastUpdated = $repoData.updated_at
                $server.Topics = $repoData.topics
                
                # If description is empty, use repo description
                if (-not $server.Description -and $repoData.description) {
                    $server.Description = $repoData.description
                }

                Write-Verbose "Enriched: $($server.Name) - $($server.Stars) stars, $($server.Language)"
                
                # Rate limiting
                Start-Sleep -Milliseconds $script:Config.RateLimitDelay
            }
        }

        $enrichedServers += $server
    }

    Write-Progress -Activity "Enriching server metadata" -Completed
    Write-Host "Enrichment complete!" -ForegroundColor Green
    return $enrichedServers
}

<#
.SYNOPSIS
    Exports servers to JSON file with pretty formatting.
#>
function Export-ServersToJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Servers,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Ensure output directory exists
    $outputDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Verbose "Created output directory: $outputDir"
    }

    # Create output structure
    $output = [PSCustomObject]@{
        GeneratedDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalServers = $Servers.Count
        Categories = @{
            OfficialIntegrations = ($Servers | Where-Object { $_.Category -eq "Official Integrations" }).Count
            CommunityServers = ($Servers | Where-Object { $_.Category -eq "Community Servers" }).Count
        }
        Servers = $Servers
    }

    # Export to JSON with pretty formatting
    $output | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    Write-Host "`nExported $($Servers.Count) servers to: $Path" -ForegroundColor Green
}

<#
.SYNOPSIS
    Displays summary statistics about discovered servers.
#>
function Show-ServerSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Servers
    )

    Write-Host "`n================================" -ForegroundColor Cyan
    Write-Host "MCP Server Discovery Summary" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan

    # Category breakdown
    $byCategory = $Servers | Group-Object -Property Category
    Write-Host "`nBy Category:" -ForegroundColor Yellow
    foreach ($group in $byCategory) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Language breakdown (if enriched)
    $withLanguage = $Servers | Where-Object { $_.Language }
    if ($withLanguage) {
        Write-Host "`nBy Language (Top 10):" -ForegroundColor Yellow
        $byLanguage = $withLanguage | Group-Object -Property Language | Sort-Object Count -Descending | Select-Object -First 10
        foreach ($group in $byLanguage) {
            Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
        }
    }

    # License breakdown (if enriched)
    $withLicense = $Servers | Where-Object { $_.License }
    if ($withLicense) {
        Write-Host "`nBy License (Top 5):" -ForegroundColor Yellow
        $byLicense = $withLicense | Group-Object -Property License | Sort-Object Count -Descending | Select-Object -First 5
        foreach ($group in $byLicense) {
            Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
        }
    }

    # Top starred repositories (if enriched)
    $withStars = $Servers | Where-Object { $_.Stars -ne $null } | Sort-Object Stars -Descending | Select-Object -First 5
    if ($withStars) {
        Write-Host "`nTop 5 Most Starred:" -ForegroundColor Yellow
        foreach ($server in $withStars) {
            Write-Host "  $($server.Name): $($server.Stars) ⭐" -ForegroundColor White
        }
    }

    Write-Host "`n================================`n" -ForegroundColor Cyan
}

#endregion

#region Main Execution

try {
    Write-Host "`n🚀 MCP Server Discovery Tool" -ForegroundColor Magenta
    Write-Host "================================`n" -ForegroundColor Magenta

    # Step 1: Fetch README from GitHub
    Write-Host "Step 1: Fetching MCP servers README from GitHub..." -ForegroundColor Cyan
    $readmeContent = Invoke-SafeWebRequest -Uri $script:Config.RegistryUrl

    if (-not $readmeContent) {
        throw "Failed to fetch README from $($script:Config.RegistryUrl)"
    }

    Write-Host "✓ README fetched successfully" -ForegroundColor Green

    # Step 2: Parse README to extract servers
    Write-Host "`nStep 2: Parsing server information..." -ForegroundColor Cyan
    $servers = Get-MCPServersFromReadme -ReadmeContent $readmeContent

    if ($servers.Count -eq 0) {
        throw "No servers found in README"
    }

    Write-Host "✓ Parsed $($servers.Count) servers" -ForegroundColor Green

    # Step 3: Enrich with repository data (optional)
    if ($EnrichWithRepoData) {
        $servers = Add-RepositoryMetadata -Servers $servers
    }
    else {
        Write-Host "`nSkipping repository enrichment (use -EnrichWithRepoData to enable)" -ForegroundColor Yellow
    }

    # Step 4: Export to JSON
    Write-Host "`nStep 3: Exporting to JSON..." -ForegroundColor Cyan
    $resolvedPath = Resolve-Path -Path $OutputPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        $resolvedPath = Join-Path -Path $PSScriptRoot -ChildPath $OutputPath
    }
    
    Export-ServersToJson -Servers $servers -Path $resolvedPath

    # Step 5: Show summary
    Show-ServerSummary -Servers $servers

    Write-Host "✅ Discovery complete! Output saved to: $resolvedPath`n" -ForegroundColor Green

    # Return servers for pipeline usage
    return $servers
}
catch {
    Write-Error "❌ Error during MCP server discovery: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}

#endregion
