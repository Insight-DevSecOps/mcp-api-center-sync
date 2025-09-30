# MCP Registry to Azure API Center - Architecture Design

**Version:** 2.0  
**Date:** September 29, 2025  
**Author:** System Architecture Team

---

## Executive Summary

This document outlines the architecture for a **GitOps-based solution** that selectively replicates approved MCP (Model Context Protocol) servers from the public MCP registry into one or more Azure API Center instances. The solution leverages **GitHub Actions** for automation, **Pull Requests** for approval workflows, and **Git version control** for audit trails, providing centralized governance, discovery, and management of MCP servers within an enterprise context.

---

## Table of Contents

1. [Business Objectives](#business-objectives)
2. [Architecture Overview](#architecture-overview)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Data Models & Mappings](#data-models--mappings)
6. [Security & Compliance](#security--compliance)
7. [Deployment Options](#deployment-options)
8. [Future Enhancements](#future-enhancements)

---

## Business Objectives

### Primary Goals
1. **Centralized Governance** - Maintain a curated, approved catalog of MCP servers
2. **Security & Compliance** - Vet and approve MCP servers before organizational use
3. **Discovery** - Enable developers to find approved MCP servers easily
4. **Version Management** - Track approved versions and updates
5. **Metadata Enrichment** - Add organizational context (owner, security review status, etc.)

### Success Criteria
- Automated synchronization of approved MCP servers
- Full metadata preservation and enrichment
- Integration with existing Azure API Center workflows
- Auditability of approval decisions
- Scalable to multiple API Center instances

---

## Architecture Overview

### High-Level Architecture (GitOps Pattern)

```
┌─────────────────────────────────────────────────────────────────┐
│                     MCP PUBLIC REGISTRY                          │
│  (GitHub: modelcontextprotocol/servers)                         │
│  - README.md with server listings                               │
│  - Individual server repositories                               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (1) Scheduled Discovery
                 │     GitHub Actions: discover-servers.yml
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              DISCOVERY & ENRICHMENT LAYER                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GitHub Action Workflow                                  │  │
│  │  - Runs Get-MCPServers.ps1                               │  │
│  │  - Fetches MCP registry README                           │  │
│  │  - Parses server metadata                                │  │
│  │  - Enriches with GitHub repo data (optional)             │  │
│  │  - Generates discovered-servers.json                     │  │
│  │  - Creates PR with new/updated servers                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (2) Pull Request Created
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              APPROVAL & GOVERNANCE LAYER (Git)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GitHub Repository                                       │  │
│  │  ├── approved-servers/                                   │  │
│  │  │   ├── official/                                       │  │
│  │  │   │   └── server-name.json                            │  │
│  │  │   └── community/                                      │  │
│  │  │       └── server-name.json                            │  │
│  │  └── output/                                             │  │
│  │      └── discovered-servers.json (latest scan)           │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Pull Request Review Workflow                            │  │
│  │  - PR validation (GitHub Action)                         │  │
│  │  - Security team review                                  │  │
│  │  - Compliance checks                                     │  │
│  │  - Custom metadata assignment                            │  │
│  │  - Approval via PR review + merge                        │  │
│  │  - Complete audit trail in Git history                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (3) PR Merged to Main
                 │     Triggers: sync-to-api-center.yml
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              SYNC & DEPLOYMENT LAYER                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GitHub Action: Sync to API Center                       │  │
│  │  - Triggered on push to main                             │  │
│  │  - Runs Sync-ToAPICenter.ps1                             │  │
│  │  - Azure authentication via OIDC (passwordless)          │  │
│  │  - Reads approved-servers/ directory                     │  │
│  │  - Transforms to API Center schema                       │  │
│  │  - Creates/updates APIs, versions, definitions           │  │
│  │  - Assigns custom metadata                               │  │
│  │  - Posts sync results as PR comment                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (4) Store & Expose
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              AZURE API CENTER INSTANCE(S)                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Inventory                                           │  │
│  │  - MCP Server APIs                                       │  │
│  │  - Versions                                              │  │
│  │  - Definitions (OpenAPI where available)                 │  │
│  │  - Custom Metadata (Security, Owner, Tags)               │  │
│  │  - Deployments (GitHub repo links)                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Discovery & Access                                      │  │
│  │  - Azure Portal                                          │  │
│  │  - VS Code Extension                                     │  │
│  │  - API Center Portal                                     │  │
│  │  - REST API                                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### GitOps Workflow Diagram

```
┌─────────────────┐
│  Scheduled Run  │ (Weekly/Manual)
│  or Manual      │
│  Dispatch       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  GitHub Action:                 │
│  discover-servers.yml           │
│  - Runs scraper                 │
│  - Generates output             │
│  - Compares with existing       │
│  - Creates PR if changes found  │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Pull Request Created           │
│  - New servers highlighted      │
│  - Updated servers shown        │
│  - Validation checks run        │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Team Review                    │
│  - Security assessment          │
│  - License review               │
│  - Add custom metadata          │
│  - Update server JSON files     │
│  - Approve via PR review        │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  PR Merged to Main              │
│  - Git history updated          │
│  - Audit trail created          │
└────────┬────────────────────────┘
         │
         ▼ (Triggers)
┌─────────────────────────────────┐
│  GitHub Action:                 │
│  sync-to-api-center.yml         │
│  - Authenticates to Azure       │
│  - Syncs approved servers       │
│  - Updates API Center           │
│  - Posts results to PR          │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Azure API Center Updated       │
│  - Developers discover servers  │
└─────────────────────────────────┘
```

---

## Component Details

### 1. Data Aggregation Layer

#### **1.1 Registry Scraper (PowerShell)**

**Purpose:** Fetch and parse MCP server information from the public registry.

**Responsibilities:**
- Fetch the MCP servers README from GitHub
- Parse markdown to extract server listings
- Categorize servers (Official Integrations vs Community)
- Extract metadata:
  - Server name
  - Description
  - GitHub repository URL
  - Author/organization
  - Category
  - Logo/icon URL
  - Language/framework
- Optionally fetch additional details from each repository:
  - package.json (npm servers)
  - pyproject.toml/setup.py (Python servers)
  - README.md from individual repos
  - License information

**Key Technologies:**
- PowerShell 7+
- GitHub REST API
- Markdown parsing (regex or ConvertFrom-Markdown)

**Output:**
- Structured JSON/CSV with all discovered servers

---

### 2. Staging & Approval Layer

#### **2.1 GitHub Repository Structure**

**Purpose:** Version-controlled storage of approved MCP servers with Git-based approval workflow.

**Repository Structure:**
```
mcp-api-center-sync/
├── .github/
│   └── workflows/
│       ├── discover-servers.yml      # Scheduled discovery
│       ├── sync-to-api-center.yml    # Sync on merge
│       └── validate-servers.yml      # PR validation
├── approved-servers/
│   ├── official/                     # Approved official integrations
│   │   ├── paragon-mcp.json
│   │   ├── slack-mcp.json
│   │   └── ...
│   └── community/                    # Approved community servers
│       ├── wordpress-mcp.json
│       ├── atlassian-mcp.json
│       └── ...
├── output/
│   └── discovered-servers.json       # Latest discovery scan
└── scripts/
    ├── Get-MCPServers.ps1            # Discovery script
    └── Sync-ToAPICenter.ps1          # Sync script
```

**Server File Schema (approved-servers/):**
```json
{
  "serverId": "unique-identifier",
  "name": "Slack MCP Server",
  "description": "Official Slack MCP integration",
  "category": "Official Integrations",
  "repositoryUrl": "https://github.com/...",
  "author": "Slack",
  "language": "TypeScript",
  "license": "MIT",
  "discoveredDate": "2025-09-29",
  "approvedDate": "2025-09-30",
  "approvedBy": "security-team@example.com",
  "approvalStatus": "Approved",
  "securityReview": {
    "status": "Passed",
    "reviewedBy": "infosec@example.com",
    "reviewedDate": "2025-09-30",
    "notes": "No critical vulnerabilities found"
  },
  "customMetadata": {
    "owner": "Platform Team",
    "costCenter": "IT-001",
    "supportLevel": "Community",
    "useCases": ["messaging", "notifications"],
    "tags": ["communication", "official"]
  },
  "versions": [
    {
      "version": "1.0.0",
      "approvalStatus": "Approved",
      "approvedDate": "2025-09-30"
    }
  ]
}
```

#### **2.2 GitOps Approval Workflow**

**Process:**

1. **Discovery Phase (Automated)**
   - GitHub Action runs on schedule (e.g., weekly)
   - Scraper fetches latest MCP registry
   - Compares with existing `approved-servers/` directory
   - Identifies new or updated servers
   - Creates a Pull Request with changes

2. **Review Phase (Manual)**
   - PR is created with:
     - Summary of new servers discovered
     - Diff of updated servers
     - Validation check results
   - Security team reviews PR:
     - Checks repository activity
     - Reviews license compatibility
     - Assesses security posture
     - Verifies documentation quality
   - Reviewers add/update custom metadata in JSON files
   - PR validation workflow runs automated checks

3. **Approval Phase (PR Merge)**
   - Required approvals: 1-2 reviewers (configurable)
   - Branch protection enforces review requirements
   - PR merged to `main` branch
   - Git commit becomes audit record

4. **Sync Phase (Automated)**
   - Merge to `main` triggers sync workflow
   - GitHub Action authenticates to Azure via OIDC
   - Syncs approved servers to API Center
   - Posts sync results as PR comment

**Approval Criteria Checklist:**

- [ ] Security review completed
- [ ] License compatible with organization
- [ ] Repository actively maintained
- [ ] Documentation quality acceptable
- [ ] Fits organizational use cases
- [ ] No known critical vulnerabilities
- [ ] Custom metadata assigned (owner, tags, etc.)

---

### 3. Azure Integration Layer

#### **3.1 Azure API Center Sync Script**

**Purpose:** Transform approved MCP servers (from Git) into Azure API Center resources.

**Execution Context:** GitHub Actions workflow (triggered on push to `main`)

**Core Functions:**

```powershell
# Main sync workflow (runs in GitHub Actions)
function Sync-MCPServersToAPICenter {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$ApiCenterName,
        [string]$ApprovedServersPath  # Path to approved-servers/ directory
    )
    
    # 1. Enumerate all JSON files in approved-servers/
    # 2. For each approved server:
    #    - Read JSON file
    #    - Transform to API Center schema
    #    - Create/Update API (idempotent)
    #    - Create/Update Version
    #    - Upload Definition (if available)
    #    - Set custom metadata
    #    - Create deployment reference to GitHub repo
    # 3. Generate sync report
    # 4. Return results (posted as PR comment by workflow)
}
```

**Authentication:**
- Azure Login via OIDC (passwordless)
- GitHub Actions `azure/login@v2` action
- No secrets or service principal keys required

**PowerShell Modules Required:**

- `Az.Accounts` - Authentication
- `Az.ApiCenter` - API Center management
- `Az.Resources` - Resource management

**Alternative: REST API**

- Direct HTTP calls to Azure API Center REST API
- More control over API interactions
- Useful for advanced scenarios or non-PowerShell environments

---

### 4. Azure API Center Instance

#### **4.1 Resource Structure**

Each MCP Server maps to:

```
API Center
├── API: "Slack MCP Server"
│   ├── Version: "1.0.0"
│   │   ├── Definition: link to OpenAPI spec (if available)
│   │   └── Metadata:
│   │       ├── type: "MCP Server"
│   │       ├── language: "TypeScript"
│   │       ├── license: "MIT"
│   │       ├── approvedBy: "user@example.com"
│   │       ├── securityReview: "Passed"
│   │       └── customTags: ["messaging", "official"]
│   └── Deployment: "Production"
│       └── Environment: "GitHub Repository"
│           └── URL: https://github.com/...
```

#### **4.2 Custom Metadata Schema**

Define custom metadata fields in API Center:

```json
{
  "mcpServerType": {
    "type": "string",
    "choices": ["Official Integration", "Community", "Internal"]
  },
  "approvalStatus": {
    "type": "string",
    "choices": ["Approved", "Deprecated", "Under Review"]
  },
  "securityReview": {
    "type": "string",
    "choices": ["Passed", "Failed", "Pending", "Not Required"]
  },
  "owner": {
    "type": "string",
    "description": "Team responsible for this MCP server"
  },
  "supportLevel": {
    "type": "string",
    "choices": ["Official", "Community", "Internal", "None"]
  },
  "useCases": {
    "type": "array",
    "description": "Common use cases for this MCP server"
  }
}
```

---

## Data Flow

### GitOps Workflow

```
1. Scheduled Trigger (GitHub Actions Cron)
   ↓
2. Discovery Workflow Runs (discover-servers.yml)
   ↓
3. Fetch MCP servers from public registry
   ↓
4. Parse and extract metadata
   ↓
5. Compare with approved-servers/ directory
   ↓
6. Identify NEW servers OR UPDATED servers
   ↓
7. Create Pull Request with:
   - New server JSON files in approved-servers/
   - Updated discovered-servers.json in output/
   - Summary of changes
   ↓
8. PR Validation Workflow Runs (validate-servers.yml)
   - Validate JSON schema
   - Check for required fields
   - Run automated security checks
   ↓
9. Manual Review Process
   - Security team reviews PR
   - Adds custom metadata to JSON files
   - Requests changes or approves
   ↓
10. PR Approved & Merged to Main
    - Git commit = audit trail
    - Branch protection enforced
    ↓
11. Sync Workflow Triggered (sync-to-api-center.yml)
    - Runs on push to main
    - Authenticates to Azure via OIDC
    ↓
12. Sync Engine Processes approved-servers/
    - Transform to API Center schema
    - Create/Update APIs in Azure API Center
    - Assign custom metadata
    ↓
13. Post Sync Results
    - Comment on original PR with results
    - Update any tracking issues
    ↓
14. Azure API Center Updated
    - Developers discover via portal/VS Code
```

### Update Flow

```
Weekly Discovery Run
   ↓
Detect changes:
  - New servers → Add to PR
  - Version updates → Update existing JSON
  - Removed servers → Flag for review
   ↓
Create PR with changes
   ↓
Team reviews changes
   ↓
Merge → Auto-sync to API Center
   ↓
Version history maintained in Git
```

---

## Data Models & Mappings

### MCP Server → Azure API Center Mapping

| MCP Server Property | API Center Property | Notes |
|---------------------|---------------------|-------|
| Server Name | API Name | e.g., "Slack MCP Server" |
| Description | API Description | Full description |
| Repository URL | Deployment > URL | Link to GitHub repo |
| Version | API Version | e.g., "1.0.0" |
| package.json | API Definition | If OpenAPI spec available |
| Language/Framework | Custom Metadata | TypeScript, Python, etc. |
| Author/Org | Custom Metadata | Creator attribution |
| Category | Custom Metadata | Official/Community |
| License | Custom Metadata | MIT, Apache, etc. |
| Approval Status | Custom Metadata | Approved/Deprecated |
| Security Review | Custom Metadata | Pass/Fail status |
| Owner Team | Custom Metadata | Internal ownership |

### Example Transformation

**Input (MCP Registry):**
```markdown
• [Slack](https://github.com/slack/mcp-server) - Official Slack MCP integration
```

**Enriched (After Scraping):**
```json
{
  "name": "Slack MCP Server",
  "description": "Official Slack MCP integration for managing channels, messages, and users",
  "repositoryUrl": "https://github.com/slack/mcp-server",
  "author": "Slack",
  "category": "Official Integrations",
  "language": "TypeScript",
  "license": "MIT",
  "latestVersion": "1.2.0"
}
```

**Output (API Center):**
```json
{
  "properties": {
    "name": "Slack MCP Server",
    "description": "Official Slack MCP integration for managing channels, messages, and users",
    "kind": "rest",
    "lifecycleStage": "production",
    "customProperties": {
      "mcpServerType": "Official Integration",
      "language": "TypeScript",
      "license": "MIT",
      "repositoryUrl": "https://github.com/slack/mcp-server",
      "author": "Slack",
      "approvalStatus": "Approved",
      "securityReview": "Passed"
    }
  }
}
```

---

## Security & Compliance

### Security Considerations

1. **Authentication**
   - Service Principal for Azure API Center access
   - GitHub Personal Access Token (PAT) for API calls
   - Secrets stored in Azure Key Vault

2. **Authorization**
   - RBAC roles for API Center management
   - Separate approval permissions
   - Audit logging enabled

3. **Data Validation**
   - Validate repository URLs
   - Check for malicious code patterns (optional)
   - License compliance checks
   - Dependency scanning (future)

4. **Network Security**
   - Run from secure environment (Azure Automation, VM)
   - Private endpoints for API Center (optional)

### Compliance & Governance

1. **Audit Trail**
   - Log all approval decisions
   - Track who approved what and when
   - Version history in API Center

2. **Change Management**
   - Documented approval process
   - Stakeholder notifications
   - Regular review cycles

3. **Data Privacy**
   - No PII in MCP server metadata
   - Public data only (from public GitHub repos)

---

## Deployment Options

### Recommended: GitHub Actions (GitOps)

**Overview:**
This solution uses GitHub Actions as the primary deployment mechanism, providing a GitOps workflow for discovery, approval, and synchronization.

**Key Workflows:**

#### 1. Discovery Workflow (`discover-servers.yml`)

**Trigger:** Scheduled (weekly) or manual dispatch

**Steps:**
1. Checkout repository
2. Run `Get-MCPServers.ps1`
3. Compare output with `approved-servers/`
4. If changes detected:
   - Create new branch
   - Commit changes
   - Create Pull Request
5. Run validation checks

**Example:**
```yaml
name: Discover MCP Servers

on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Mondays
  workflow_dispatch:

jobs:
  discover:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Discovery Script
        shell: pwsh
        run: |
          ./scripts/Get-MCPServers.ps1 -OutputPath ./output/discovered-servers.json
      
      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          title: "chore: Update MCP Server Discovery"
          branch: discovery/automated-update
          commit-message: "Update discovered servers"
```

#### 2. Validation Workflow (`validate-servers.yml`)

**Trigger:** Pull request to `main`

**Steps:**
1. Validate JSON schema
2. Check required fields
3. Verify repository URLs
4. Run automated security checks (optional)
5. Post results as PR comment

#### 3. Sync Workflow (`sync-to-api-center.yml`)

**Trigger:** Push to `main` branch (after PR merge)

**Steps:**
1. Checkout repository
2. Authenticate to Azure (OIDC, passwordless)
3. Run `Sync-ToAPICenter.ps1`
4. Process all files in `approved-servers/`
5. Create/update APIs in Azure API Center
6. Post sync results as comment

**Example:**
```yaml
name: Sync to Azure API Center

on:
  push:
    branches:
      - main
    paths:
      - 'approved-servers/**'

permissions:
  id-token: write
  contents: read

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Sync to API Center
        shell: pwsh
        run: |
          ./scripts/Sync-ToAPICenter.ps1 `
            -ApprovedServersPath ./approved-servers `
            -SubscriptionId ${{ secrets.AZURE_SUBSCRIPTION_ID }} `
            -ResourceGroupName ${{ secrets.API_CENTER_RG }} `
            -ApiCenterName ${{ secrets.API_CENTER_NAME }}
```

**Advantages:**
- ✅ No infrastructure to manage
- ✅ Built-in secrets management
- ✅ Audit trail via Git history
- ✅ PR-based approval workflow
- ✅ Passwordless Azure auth (OIDC)
- ✅ Free for public repos, generous limits for private
- ✅ Easy collaboration and review
- ✅ Version control for all changes

**Setup Requirements:**
1. Configure Azure OIDC federated identity
2. Set GitHub secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `API_CENTER_RG`
   - `API_CENTER_NAME`
3. Configure branch protection on `main`
4. Set up CODEOWNERS for approval workflow

---

### Alternative: Azure DevOps Pipeline

**Use Case:** Organizations already using Azure DevOps

**Pros:**
- Integrated with Azure ecosystem
- Advanced pipeline features
- Approval gates

**Cons:**
- More complex than GitHub Actions
- Less natural for PR-based workflows

---

### Alternative: Manual Execution

**Use Case:** POC or very small deployments

**Pros:**
- Simple to start
- Full control

**Cons:**
- No automation
- No audit trail
- Error-prone

---

## Future Enhancements

### Phase 2 Features

1. **Automated GitHub Repository Analysis**
   - Dependabot/Snyk integration
   - Vulnerability scanning
   - License compliance checks
   - Code quality metrics

2. **Enhanced PR Automation**
   - Auto-categorize servers by language/framework
   - Pre-fill custom metadata based on repo analysis
   - Risk scoring for approval prioritization
   - Automated security review summaries

3. **Multi-Instance Support**
   - Sync to multiple API Center instances
   - Environment-specific configurations (dev/test/prod)
   - Regional deployments
   - Different approval workflows per environment

4. **OpenAPI Spec Generation**
   - Auto-generate specs from MCP server definitions
   - Use MCP protocol schema
   - Enable better API Center analysis and testing

5. **Bidirectional Sync**
   - Internal MCP servers → Git → API Center
   - API Center metadata → Git repository
   - Publish internal servers to private registry

6. **Advanced Notifications**
   - Teams/Slack integration for new discoveries
   - @mention security team in PRs automatically
   - Email digests of pending approvals
   - Webhook notifications for sync completions

7. **Analytics & Reporting**
   - Dashboard showing MCP server adoption
   - Most popular servers by downloads/usage
   - Approval pipeline metrics
   - Time-to-approval tracking
   - Compliance reports

8. **Self-Service Portal**
   - Web UI for searching pending servers
   - Bulk approval operations
   - Custom metadata templates
   - Approval workflow visualization

---

## GitOps Security & Compliance

### Authentication & Authorization

1. **Azure Authentication (OIDC)**
   - Passwordless authentication via workload identity
   - GitHub Actions federated identity
   - No secrets/keys to rotate
   - Azure RBAC for API Center access

2. **GitHub Access Control**
   - Branch protection on `main`
   - Required PR reviews (1-2 approvers)
   - CODEOWNERS for approval routing
   - Status checks must pass before merge

3. **Secret Management**
   - GitHub encrypted secrets
   - Azure Key Vault integration (optional)
   - No credentials in code or Git history

### Audit & Compliance

1. **Complete Audit Trail**
   - Git history = immutable approval record
   - PR comments document discussions
   - Commit messages show who approved what
   - Azure Monitor logs for API Center changes

2. **Change Management**
   - Documented approval criteria
   - Required security reviews
   - Version control for all changes
   - Rollback capability via Git

3. **Data Privacy**
   - Public data only (from public GitHub repos)
   - No PII in MCP server metadata
   - Compliance with data retention policies

### Security Best Practices

1. **Repository Security**
   - Dependabot alerts enabled
   - Secret scanning enabled
   - Code scanning (optional)
   - Branch protection rules enforced

2. **Network Security**
   - GitHub Actions runners: GitHub-hosted (ephemeral)
   - Azure: Private endpoints (optional)
   - Minimal permissions principle

3. **Validation & Testing**
   - JSON schema validation
   - URL validation
   - Automated security checks in PR
   - Integration tests before sync

---

## Technology Stack Summary

| Layer | Technology |
|-------|------------|
| **Scripting** | PowerShell 7+ |
| **Azure SDK** | Az.ApiCenter, Az.Accounts, Az.Resources |
| **Data Storage** | Git (JSON files in repository) |
| **Execution** | GitHub Actions |
| **Approval Workflow** | GitHub Pull Requests + Reviews |
| **Source Control** | GitHub |
| **Authentication** | Azure OIDC (Workload Identity) |
| **Secrets** | GitHub Encrypted Secrets |
| **Monitoring** | GitHub Actions logs, Azure Monitor |
| **Audit Trail** | Git commit history |

---

## Implementation Roadmap

### Phase 1: Core GitOps Setup (Week 1-2)

1. **Repository Structure**
   - ✅ Create `approved-servers/official/` directory
   - ✅ Create `approved-servers/community/` directory
   - ✅ Create `.github/workflows/` directory
   - ✅ Update documentation

2. **GitHub Actions Workflows**
   - Create `discover-servers.yml` (discovery workflow)
   - Create `validate-servers.yml` (PR validation)
   - Create `sync-to-api-center.yml` (sync to Azure)

3. **Azure Setup**
   - Configure Azure API Center instance
   - Set up OIDC federated identity
   - Configure RBAC permissions
   - Define custom metadata schema

4. **GitHub Setup**
   - Configure branch protection on `main`
   - Set up CODEOWNERS file
   - Add GitHub secrets
   - Enable security features (Dependabot, secret scanning)

### Phase 2: Automation & Testing (Week 3-4)

5. **Enhance Discovery**
   - Add GitHub repository enrichment
   - Implement rate limiting
   - Add error handling and retry logic

6. **Sync Script Development**
   - Create `Sync-ToAPICenter.ps1`
   - Implement API Center API integration
   - Add idempotent create/update logic
   - Add comprehensive logging

7. **Validation & Testing**
   - Create Pester tests
   - Add JSON schema validation
   - Implement automated security checks
   - Test end-to-end workflow

### Phase 3: Production & Optimization (Week 5-6)

8. **Production Deployment**
   - Test with 5-10 sample servers
   - Conduct security review
   - Document approval criteria
   - Train team on workflow

9. **Monitoring & Optimization**
   - Set up Azure Monitor alerts
   - Add workflow performance metrics
   - Optimize GitHub Actions run times
   - Document runbook procedures

10. **Iteration & Feedback**
    - Gather user feedback
    - Refine approval criteria
    - Enhance automation
    - Plan Phase 2 features

---

## Key Decisions & Rationale

### Why GitOps?

1. **Audit Trail:** Git history provides immutable record of all approvals
2. **Collaboration:** PR reviews are familiar to development teams
3. **Version Control:** All changes tracked with full context
4. **Automation:** GitHub Actions eliminates manual deployment steps
5. **Security:** Branch protection + OIDC = secure, auditable process
6. **Cost:** Free for public repos, generous limits for private repos

### Why GitHub Actions vs. Azure Automation/DevOps?

1. **Simplicity:** No separate infrastructure to manage
2. **Integration:** Native PR workflow integration
3. **Flexibility:** Easy to extend with marketplace actions
4. **Modern:** Industry-standard GitOps pattern
5. **Cost-Effective:** Included with GitHub

### Why JSON Files vs. Database?

1. **Version Control:** Changes tracked in Git
2. **Simplicity:** No database to manage
3. **Transparency:** Easy to review and audit
4. **Portability:** Easy to migrate or backup
5. **GitOps-Native:** Fits the workflow pattern

---

## Success Metrics

### Operational Metrics

- **Discovery Frequency:** Weekly automated scans
- **Time to Approval:** < 3 business days for new servers
- **Sync Success Rate:** > 99%
- **Audit Compliance:** 100% of changes tracked in Git

### Business Metrics

- **MCP Server Catalog Size:** 50-100 approved servers in first quarter
- **Developer Adoption:** 80%+ of developers using API Center for discovery
- **Security Incidents:** 0 unapproved servers in production
- **Time to Onboard New Server:** < 1 week from discovery to availability

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-09-29 | Architecture Team | Initial architecture design |
| 2.0 | 2025-09-29 | Architecture Team | Refactored to GitOps/GitHub Actions approach |

