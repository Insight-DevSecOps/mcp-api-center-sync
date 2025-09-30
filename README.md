# MCP Registry to Azure API Center Sync

A **GitOps-powered solution** for selectively replicating approved MCP (Model Context Protocol) servers from the public registry into Azure API Center instances using GitHub Actions and Pull Request workflows.

## 🎯 Overview

This project enables organizations to:

- **Discover** all MCP servers from the public registry automatically
- **Review & Approve** servers through GitHub Pull Requests
- **Govern** MCP server usage with Git-based audit trails
- **Sync** approved servers to Azure API Center automatically
- **Enable discovery** through Azure API Center Portal and VS Code Extension

### 🌟 GitOps Workflow

```
Weekly Discovery → Pull Request → Team Review → Approve & Merge → Auto-Sync to Azure
```

**Key Benefits:**
- ✅ Pull Request-based approval workflow
- ✅ Complete audit trail via Git history
- ✅ Automated sync with GitHub Actions
- ✅ Passwordless Azure authentication (OIDC)
- ✅ No infrastructure to manage

## 📋 Prerequisites

- **GitHub Account** with access to this repository
- **Azure Subscription** with API Center instance
- **PowerShell 7.0+** (for local script testing)
- **GitHub Actions** enabled in repository
- **Azure OIDC Configuration** for passwordless authentication
- **GitHub Secrets** configured:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `API_CENTER_RG`
  - `API_CENTER_NAME`

### Optional

- **GitHub Personal Access Token** (for higher API rate limits during discovery)
- **Azure PowerShell Modules** (for local development):
  - `Az.Accounts`
  - `Az.ApiCenter`
  - `Az.Resources`

## 🚀 Quick Start

### 1. Fork or Clone the Repository

```bash
git clone https://github.com/Insight-DevSecOps/mcp-api-center-sync.git
cd mcp-api-center-sync
```

### 2. Set Up Azure OIDC Authentication

Configure federated credentials for GitHub Actions to authenticate to Azure:

```bash
# See docs/SETUP-AZURE-OIDC.md for detailed instructions
```

### 3. Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `AZURE_CLIENT_ID` - Application (client) ID
- `AZURE_TENANT_ID` - Directory (tenant) ID
- `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID
- `API_CENTER_RG` - Resource group name for API Center
- `API_CENTER_NAME` - API Center instance name

### 4. Enable GitHub Actions

The repository includes three automated workflows:

- **`discover-servers.yml`** - Weekly discovery of MCP servers (runs Mondays)
- **`validate-servers.yml`** - Validates PRs with new/updated servers
- **`sync-to-api-center.yml`** - Syncs approved servers to Azure (on merge to main)

### 5. GitOps Workflow

#### Automated Discovery

Every Monday (or on manual trigger), GitHub Actions:
1. Runs `Get-MCPServers.ps1` to discover MCP servers
2. Compares results with existing `approved-servers/` directory
3. Creates a Pull Request if new servers are found

#### Review & Approval

When a PR is created:
1. Review the discovered servers
2. Run validation checks automatically
3. Security team reviews and approves
4. Add custom metadata to server JSON files
5. Merge PR to approve

#### Automatic Sync

When PR is merged to `main`:
1. GitHub Actions triggers `sync-to-api-center.yml`
2. Authenticates to Azure via OIDC (passwordless)
3. Syncs all approved servers to Azure API Center
4. Posts sync results as comment

### 6. Manual Discovery (Optional)

You can also run discovery manually:

```powershell
# Basic usage
./scripts/Get-MCPServers.ps1

# With GitHub token for higher rate limits
./scripts/Get-MCPServers.ps1 -GitHubToken $env:GITHUB_TOKEN

# Custom output path
./scripts/Get-MCPServers.ps1 -OutputPath ./output/discovered-servers.json
```

## 📁 Project Structure

```text
mcp-api-center-sync/
├── .github/
│   └── workflows/
│       ├── discover-servers.yml      # Scheduled MCP server discovery
│       ├── validate-servers.yml      # PR validation checks
│       └── sync-to-api-center.yml    # Sync to Azure on merge
├── approved-servers/
│   ├── official/                     # Approved official integrations
│   │   ├── paragon-mcp.json
│   │   └── slack-mcp.json
│   └── community/                    # Approved community servers
│       ├── wordpress-mcp.json
│       └── atlassian-mcp.json
├── config/
│   └── config.json                   # Configuration settings
├── docs/
│   ├── ARCHITECTURE.md               # GitOps architecture design
│   ├── SETUP-AZURE-OIDC.md          # Azure authentication setup
│   └── APPROVAL-PROCESS.md          # PR review guidelines
├── scripts/
│   ├── Get-MCPServers.ps1           # Discovery script
│   └── Sync-ToAPICenter.ps1         # Azure sync script
├── output/
│   └── discovered-servers.json       # Latest discovery results
├── tests/
│   └── Get-MCPServers.Tests.ps1     # Pester tests
└── README.md
```

## 🔧 Scripts & Tools

### Get-MCPServers.ps1

Discovers MCP servers from the public GitHub registry.

**Usage in GitHub Actions:**

Automatically runs weekly via `discover-servers.yml` workflow.

**Manual Usage:**

```powershell
./scripts/Get-MCPServers.ps1 [options]
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `OutputPath` | string | `./output/discovered-servers.json` | Output file path |
| `GitHubToken` | string | `null` | GitHub PAT for API calls (higher rate limits) |
| `IncludeCommunity` | bool | `true` | Include community servers |
| `EnrichWithRepoData` | bool | `false` | Fetch additional repo metadata |
| `Categories` | string[] | All | Categories to include |

**Examples:**

```powershell
# Discover all servers
./scripts/Get-MCPServers.ps1

# Official integrations only with enrichment
./scripts/Get-MCPServers.ps1 -Categories "Official Integrations" -EnrichWithRepoData -GitHubToken $token
```

### Sync-ToAPICenter.ps1

Syncs approved servers from `approved-servers/` directory to Azure API Center.

**Usage in GitHub Actions:**

Automatically runs on merge to `main` via `sync-to-api-center.yml` workflow.

**Manual Usage:**

```powershell
./scripts/Sync-ToAPICenter.ps1 `
  -ApprovedServersPath ./approved-servers `
  -SubscriptionId "your-sub-id" `
  -ResourceGroupName "your-rg" `
  -ApiCenterName "your-api-center"
```

**Note:** Manual sync requires Azure authentication via `Connect-AzAccount`.

## 📊 Server Metadata Format

Approved servers are stored as individual JSON files in `approved-servers/official/` or `approved-servers/community/`:

```json
{
  "serverId": "unique-guid",
  "name": "Slack MCP Server",
  "description": "Official Slack integration for MCP",
  "category": "Official Integrations",
  "repositoryUrl": "https://github.com/slack/mcp-server",
  "owner": "slack",
  "repository": "mcp-server",
  "logoUrl": "https://...",
  "discoveredDate": "2025-09-29",
  "approvedDate": "2025-09-30",
  "approvedBy": "security-team@example.com",
  "approvalStatus": "Approved",
  "securityReview": {
    "status": "Passed",
    "reviewedBy": "infosec@example.com",
    "reviewedDate": "2025-09-30",
    "notes": "No critical vulnerabilities"
  },
  "customMetadata": {
    "owner": "Platform Team",
    "supportLevel": "Community",
    "useCases": ["messaging", "notifications"],
    "tags": ["communication", "official"]
  },
  "language": "TypeScript",
  "license": "MIT",
  "stars": 150,
  "lastUpdated": "2025-09-28T12:00:00Z",
  "topics": ["mcp", "slack", "integration"],
  "versions": [
    {
      "version": "1.0.0",
      "approvalStatus": "Approved",
      "approvedDate": "2025-09-30"
    }
  ]
}
```

### Discovery Output Format

The scraper generates `output/discovered-servers.json` with this structure:

```json
{
  "GeneratedDate": "2025-09-29T10:30:00Z",
  "TotalServers": 1177,
  "Categories": {
    "OfficialIntegrations": 356,
    "CommunityServers": 821
  },
  "Servers": [ /* array of server objects */ ]
}
```

## 🔐 Security & Authentication

### Azure OIDC Authentication (Recommended)

GitHub Actions uses **passwordless authentication** via Azure Workload Identity Federation:

**Benefits:**
- No secrets or keys to manage
- Automatic credential rotation
- More secure than service principal keys

**Setup:**

See [docs/SETUP-AZURE-OIDC.md](docs/SETUP-AZURE-OIDC.md) for detailed configuration steps.

### GitHub Secrets

Configure these secrets in GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `AZURE_CLIENT_ID` | Application (client) ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Directory (tenant) ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdef12-3456-7890-abcd-ef1234567890` |
| `API_CENTER_RG` | Resource group name | `rg-api-center-prod` |
| `API_CENTER_NAME` | API Center name | `apic-mcp-registry` |

### GitHub Personal Access Token (Optional)

For local development and higher GitHub API rate limits:

```powershell
# Set as environment variable
$env:GITHUB_TOKEN = "ghp_your_token_here"

# Use in discovery script
./scripts/Get-MCPServers.ps1 -GitHubToken $env:GITHUB_TOKEN
```

## 🎨 GitOps Approval Workflow

### Overview

This project uses **Pull Requests** as the approval mechanism for MCP servers.

### Process

1. **Automated Discovery** (Weekly on Mondays)
   - GitHub Actions runs `discover-servers.yml`
   - Scraper fetches latest MCP registry
   - Compares with existing approved servers
   - Creates PR if new servers found

2. **Review & Validation**
   - PR created with new/updated server JSON files
   - Automated validation checks run:
     - JSON schema validation
     - Required fields verification
     - Repository URL validation
   - Security team reviews:
     - Repository activity and maintenance
     - License compatibility
     - Security posture
     - Documentation quality

3. **Add Custom Metadata**
   - Reviewers update server JSON files in PR
   - Add organizational metadata:
     - Internal owner/team
     - Support level
     - Use cases
     - Security review status
     - Custom tags

4. **Approval & Merge**
   - Required approvals: 1-2 reviewers (configurable via branch protection)
   - All validation checks must pass
   - Merge PR to `main` branch
   - Git commit = permanent audit record

5. **Automated Sync**
   - Merge triggers `sync-to-api-center.yml` workflow
   - Authenticates to Azure via OIDC
   - Syncs all approved servers to API Center
   - Posts sync results as comment

### Approval Criteria

- [ ] Security review completed
- [ ] License compatible with organization
- [ ] Repository actively maintained (recent commits)
- [ ] Documentation quality acceptable
- [ ] Fits organizational use cases
- [ ] No known critical vulnerabilities
- [ ] Custom metadata assigned (owner, tags, etc.)

### Branch Protection

Recommended settings for `main` branch:

- Require pull request before merging
- Require 1-2 approvals
- Require status checks to pass (validation workflow)
- Require conversation resolution before merging
- Include administrators in restrictions

## 🧪 Testing

Run Pester tests:

```powershell
# Install Pester (if needed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester -Path ./tests/
```

## 📈 Roadmap

### ✅ Phase 1: Core GitOps (Current)

- [x] POC scraper for MCP registry
- [x] GitOps architecture design
- [ ] GitHub Actions workflows (discover, validate, sync)
- [ ] Azure OIDC authentication setup
- [ ] Sync script for Azure API Center
- [ ] Branch protection and approval workflow
- [ ] Initial documentation

### 🚧 Phase 2: Automation & Enhancement

- [ ] Automated GitHub repository enrichment
- [ ] Enhanced PR validation (security checks)
- [ ] Notification integrations (Teams/Slack)
- [ ] Multi-environment support (dev/test/prod)
- [ ] Comprehensive testing suite
- [ ] Deployment to production

### 🔮 Phase 3: Advanced Features

- [ ] OpenAPI spec generation from MCP schemas
- [ ] Automated security scanning (Dependabot/Snyk)
- [ ] Usage analytics and reporting
- [ ] Self-service approval portal (web UI)
- [ ] Bidirectional sync (internal → public)
- [ ] Multi-instance API Center support

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit PRs.

## 📄 License

MIT License - see LICENSE file for details.

## 📞 Support

For issues and questions:

- Create an issue in this repository
- Contact: `your-team@example.com`

## 🔗 Resources

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Servers Registry](https://github.com/modelcontextprotocol/servers)
- [Azure API Center Documentation](https://learn.microsoft.com/en-us/azure/api-center/)
- [Architecture Design](docs/ARCHITECTURE.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure OIDC with GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
