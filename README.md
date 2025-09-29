# MCP Registry to Azure API Center Sync

A PowerShell-based solution for selectively replicating approved MCP (Model Context Protocol) servers from the public registry into Azure API Center instances.

## 🎯 Overview

This project enables organizations to:
- **Discover** all MCP servers from the public registry
- **Curate** and approve servers based on organizational criteria
- **Replicate** approved servers to Azure API Center
- **Govern** MCP server usage across the enterprise
- **Enable discovery** through Azure API Center Portal and VS Code Extension

## 📋 Prerequisites

- **PowerShell 7.0+**
- **Azure Subscription** with API Center instance
- **GitHub Personal Access Token** (optional, for higher rate limits)
- **Azure PowerShell Modules**:
  - `Az.Accounts`
  - `Az.ApiCenter`
  - `Az.Resources`

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/mcp-api-center-sync.git
cd mcp-api-center-sync
```

### 2. Configure Settings

Edit `config/config.json` with your Azure details:

```json
{
  "apiCenter": {
    "subscriptionId": "your-subscription-id",
    "resourceGroupName": "your-resource-group",
    "apiCenterName": "your-api-center-name"
  }
}
```

### 3. Run the Scraper

```powershell
# Basic usage
./scripts/Get-MCPServers.ps1

# With GitHub token for higher rate limits
./scripts/Get-MCPServers.ps1 -GitHubToken $env:GITHUB_TOKEN

# Enrich with repository metadata
./scripts/Get-MCPServers.ps1 -EnrichWithRepoData -GitHubToken $env:GITHUB_TOKEN

# Only official integrations
./scripts/Get-MCPServers.ps1 -Categories "Official Integrations"
```

### 4. Review Discovered Servers

Check the output file:

```powershell
Get-Content ./output/discovered-servers.json | ConvertFrom-Json | Format-List
```

### 5. Approve Servers

(Manual approval process - see [Approval Workflow](#approval-workflow))

### 6. Sync to Azure API Center

```powershell
./scripts/Sync-ToAPICenter.ps1 -ApprovedServersFile ./output/approved-servers.json
```

## 📁 Project Structure

```
mcp-api-center-sync/
├── config/
│   └── config.json              # Configuration settings
├── docs/
│   ├── ARCHITECTURE.md          # Architecture design document
│   └── APPROVAL-WORKFLOW.md     # Approval process guide
├── scripts/
│   ├── Get-MCPServers.ps1       # Scraper script
│   ├── Sync-ToAPICenter.ps1     # Azure API Center sync script
│   └── helpers/
│       ├── GitHubHelper.ps1     # GitHub API utilities
│       └── APICenter.ps1        # API Center utilities
├── output/
│   ├── discovered-servers.json  # All discovered servers
│   └── approved-servers.json    # Approved servers only
├── tests/
│   └── Get-MCPServers.Tests.ps1 # Pester tests
└── README.md
```

## 🔧 Scripts

### Get-MCPServers.ps1

Discovers MCP servers from the public GitHub registry.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `OutputPath` | string | `../output/discovered-servers.json` | Output file path |
| `GitHubToken` | string | `null` | GitHub PAT for API calls |
| `IncludeCommunity` | bool | `true` | Include community servers |
| `EnrichWithRepoData` | bool | `false` | Fetch additional repo metadata |
| `Categories` | string[] | All | Categories to include |

**Examples:**

```powershell
# Discover all servers
./Get-MCPServers.ps1

# Official integrations only with enrichment
./Get-MCPServers.ps1 -Categories "Official Integrations" -EnrichWithRepoData -GitHubToken $token

# Custom output path
./Get-MCPServers.ps1 -OutputPath "C:\data\mcp-servers.json"
```

### Sync-ToAPICenter.ps1

*(Coming soon)* Syncs approved servers to Azure API Center.

## 📊 Output Format

The scraper generates a JSON file with the following structure:

```json
{
  "GeneratedDate": "2025-09-29T10:30:00Z",
  "TotalServers": 450,
  "Categories": {
    "OfficialIntegrations": 45,
    "CommunityServers": 405
  },
  "Servers": [
    {
      "ServerId": "unique-guid",
      "Name": "Slack MCP Server",
      "Description": "Official Slack integration",
      "Category": "Official Integrations",
      "RepositoryUrl": "https://github.com/slack/mcp-server",
      "Owner": "slack",
      "Repository": "mcp-server",
      "LogoUrl": "https://...",
      "DiscoveredDate": "2025-09-29",
      "Language": "TypeScript",
      "License": "MIT",
      "Stars": 150,
      "LastUpdated": "2025-09-28T12:00:00Z",
      "Topics": ["mcp", "slack", "integration"],
      "ApprovalStatus": "Pending Review"
    }
  ]
}
```

## 🔐 Security

### GitHub Token

For higher rate limits, provide a GitHub Personal Access Token:

```powershell
# Set as environment variable
$env:GITHUB_TOKEN = "your-github-token"

# Use in script
./Get-MCPServers.ps1 -GitHubToken $env:GITHUB_TOKEN
```

### Azure Authentication

```powershell
# Connect to Azure
Connect-AzAccount -Subscription "your-subscription-id"

# Or use Service Principal
$credential = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant "your-tenant-id"
```

## 🎨 Approval Workflow

1. **Discovery**: Run `Get-MCPServers.ps1` to discover all servers
2. **Review**: Examine `discovered-servers.json`
3. **Approve**: Copy approved servers to `approved-servers.json`
4. **Enrich**: Add custom metadata (owner, security review, etc.)
5. **Sync**: Run `Sync-ToAPICenter.ps1` to push to Azure API Center

See [APPROVAL-WORKFLOW.md](docs/APPROVAL-WORKFLOW.md) for detailed process.

## 🧪 Testing

Run Pester tests:

```powershell
# Install Pester (if needed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester -Path ./tests/
```

## 📈 Roadmap

- [x] POC scraper for MCP registry
- [ ] Sync script for Azure API Center
- [ ] Automated approval workflows
- [ ] Azure Automation runbook deployment
- [ ] Azure DevOps pipeline integration
- [ ] Security scanning integration
- [ ] Multi-instance support
- [ ] Web UI for approval management

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit PRs.

## 📄 License

MIT License - see LICENSE file for details.

## 📞 Support

For issues and questions:
- Create an issue in this repository
- Contact: your-team@example.com

## 🔗 Resources

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Servers Registry](https://github.com/modelcontextprotocol/servers)
- [Azure API Center Documentation](https://learn.microsoft.com/en-us/azure/api-center/)
- [Architecture Design](docs/ARCHITECTURE.md)
