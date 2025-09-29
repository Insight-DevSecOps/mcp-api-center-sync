# MCP Registry to Azure API Center - Architecture Design

**Version:** 1.0  
**Date:** September 29, 2025  
**Author:** System Architecture Team

---

## Executive Summary

This document outlines the architecture for a solution that **selectively replicates approved MCP (Model Context Protocol) servers** from the public MCP registry into one or more Azure API Center instances. The solution provides centralized governance, discovery, and management of MCP servers within an enterprise context.

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

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     MCP PUBLIC REGISTRY                          │
│  (GitHub: modelcontextprotocol/servers)                         │
│  - README.md with server listings                               │
│  - Individual server repositories                               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (1) Fetch & Parse
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              DATA AGGREGATION LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Registry Scraper (PowerShell)                           │  │
│  │  - Fetch GitHub README                                   │  │
│  │  - Parse server metadata                                 │  │
│  │  - Extract repository info                               │  │
│  │  - Fetch package.json/schema if available                │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (2) Store Raw Data
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              STAGING & APPROVAL LAYER                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Candidate Database (JSON/CSV/Table Storage)             │  │
│  │  - All discovered MCP servers                            │  │
│  │  - Metadata from registry                                │  │
│  │  - Status: New/Under Review/Approved/Rejected            │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Approval Workflow                                       │  │
│  │  - Manual review process                                 │  │
│  │  - Security vetting                                      │  │
│  │  - Custom metadata assignment                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 │ (3) Sync Approved Servers
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              AZURE INTEGRATION LAYER                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Azure API Center Sync Engine (PowerShell)               │  │
│  │  - Transform MCP metadata to API Center schema           │  │
│  │  - Create/Update APIs, Versions, Definitions             │  │
│  │  - Assign custom metadata                                │  │
│  │  - Manage deployments/environments                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Azure PowerShell SDK / REST API                         │  │
│  │  - Az.ApiCenter module                                   │  │
│  │  - Azure REST API                                        │  │
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

#### **2.1 Candidate Database**

**Purpose:** Store all discovered MCP servers with approval status tracking.

**Options:**
1. **JSON Files** (Simple, for small deployments)
2. **Azure Table Storage** (Scalable, serverless)
3. **Azure SQL Database** (Full relational features)
4. **CSV + Git** (Version-controlled approval list)

**Schema:**
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
  "approvalStatus": "Approved",
  "approvedBy": "user@example.com",
  "approvedDate": "2025-09-30",
  "securityReview": "Passed",
  "customMetadata": {
    "owner": "Platform Team",
    "costCenter": "IT-001",
    "supportLevel": "Community"
  },
  "versions": [
    {
      "version": "1.0.0",
      "approvalStatus": "Approved"
    }
  ]
}
```

#### **2.2 Approval Workflow**

**Options:**

**Option A: Manual Review (Simple)**
- Admin reviews candidate list
- Updates approval status in database
- Adds custom metadata
- Triggers sync

**Option B: GitHub Issues/PRs (Collaborative)**
- New servers create GitHub issues
- Team reviews in issue comments
- Approval = close issue with label
- Automated sync on approval

**Option C: Azure DevOps/Jira Integration**
- Create work items for new servers
- Security team reviews
- Approval workflow with gates
- Integration triggers sync

**Approval Criteria:**
- [ ] Security review completed
- [ ] License compatible with organization
- [ ] Actively maintained repository
- [ ] Documentation quality acceptable
- [ ] Fits organizational use cases
- [ ] No known vulnerabilities

---

### 3. Azure Integration Layer

#### **3.1 Azure API Center Sync Engine**

**Purpose:** Transform approved MCP servers into Azure API Center resources.

**Core Functions:**

```powershell
# Main sync workflow
function Sync-MCPServersToAPICenter {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$ApiCenterName,
        [string]$ApprovedServersFile
    )
    
    # 1. Load approved servers
    # 2. For each approved server:
    #    - Create/Update API
    #    - Create/Update Version
    #    - Upload Definition (if available)
    #    - Set custom metadata
    #    - Create deployment reference
    # 3. Generate sync report
}
```

**PowerShell Modules Required:**
- `Az.Accounts` - Authentication
- `Az.ApiCenter` - API Center management
- `Az.Resources` - Resource management

**Alternative: REST API**
- Direct HTTP calls to Azure API Center REST API
- More control, but requires manual auth handling

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

### Initial Sync Flow

```
1. Schedule Trigger (Daily/Weekly) OR Manual Execution
   ↓
2. Registry Scraper runs
   ↓
3. Fetch MCP servers from GitHub
   ↓
4. Parse and extract metadata
   ↓
5. Compare with Candidate Database
   ↓
6. Identify NEW servers → Mark as "Under Review"
   ↓
7. Identify UPDATED servers → Check if approved version changed
   ↓
8. Manual Approval Process (async)
   ↓
9. Once approved: Sync Engine runs
   ↓
10. Transform to API Center schema
    ↓
11. Create/Update in Azure API Center via PowerShell/API
    ↓
12. Generate sync report
    ↓
13. Notify stakeholders (optional)
```

### Update Flow

```
1. Detect changes in MCP registry (version updates, new servers)
   ↓
2. Check if server already approved
   ↓
3a. New Server → Approval workflow
3b. Version Update → Re-approval workflow (if required)
   ↓
4. Sync approved changes to API Center
   ↓
5. Maintain version history
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

### Option 1: Manual PowerShell Script
**Pros:**
- Simple to start
- Full control
- Easy debugging

**Cons:**
- Manual execution required
- No scheduling
- Requires local environment

**Use Case:** Initial POC, small teams

---

### Option 2: Azure Automation Runbook
**Pros:**
- Scheduled execution
- Managed environment
- Integrated with Azure
- No infrastructure management

**Cons:**
- PowerShell 7 support limited
- Debugging more complex

**Use Case:** Production deployment, scheduled syncs

**Architecture:**
```
Azure Automation Account
├── Runbook: Sync-MCPServers
├── Schedule: Weekly on Mondays
├── Assets:
│   ├── Credential: Azure Service Principal
│   ├── Variable: API Center Name
│   └── Variable: Resource Group
└── Modules:
    ├── Az.Accounts
    └── Az.ApiCenter
```

---

### Option 3: Azure DevOps Pipeline
**Pros:**
- Full CI/CD capabilities
- Version control integration
- Advanced workflows
- Approval gates

**Cons:**
- More complex setup
- Requires Azure DevOps

**Use Case:** Enterprise deployment, integration with existing DevOps

**Pipeline YAML:**
```yaml
trigger:
  schedules:
  - cron: "0 0 * * 1" # Weekly on Mondays
    branches:
      include:
      - main

stages:
- stage: Discover
  jobs:
  - job: ScrapeRegistry
    steps:
    - task: PowerShell@2
      displayName: 'Fetch MCP Servers'
      inputs:
        filePath: 'scripts/Fetch-MCPServers.ps1'
    - task: PublishPipelineArtifact@1
      inputs:
        targetPath: 'output/discovered-servers.json'

- stage: Approve
  dependsOn: Discover
  jobs:
  - job: ManualApproval
    pool: server
    steps:
    - task: ManualValidation@0
      inputs:
        instructions: 'Review new MCP servers before sync'

- stage: Sync
  dependsOn: Approve
  jobs:
  - job: SyncToAPICenter
    steps:
    - task: AzurePowerShell@5
      inputs:
        azureSubscription: 'MySubscription'
        scriptType: 'FilePath'
        scriptPath: 'scripts/Sync-ToAPICenter.ps1'
```

---

### Option 4: Azure Function (Event-Driven)
**Pros:**
- Serverless
- Event-driven (webhook from GitHub)
- Cost-effective for infrequent runs

**Cons:**
- PowerShell support requires planning
- Cold start times

**Use Case:** Real-time sync on registry updates

---

## Future Enhancements

### Phase 2 Features

1. **Automated Security Scanning**
   - Integrate with Dependabot/Snyk
   - Scan for known vulnerabilities
   - Auto-reject servers with critical issues

2. **Usage Analytics**
   - Track which MCP servers are most used
   - Integration with application insights
   - Popularity scoring

3. **Multi-Instance Support**
   - Sync to multiple API Center instances
   - Dev/Test/Prod separation
   - Regional deployments

4. **OpenAPI Spec Generation**
   - Auto-generate OpenAPI specs from MCP server definitions
   - Use MCP protocol schema
   - Enable better API Center analysis

5. **Bidirectional Sync**
   - Internal MCP servers → API Center
   - API Center → internal registry
   - Publish approved internal servers back to community

6. **Notification System**
   - Teams/Slack notifications for new servers
   - Email digests
   - RSS feed

7. **Self-Service Portal**
   - Web UI for approval workflow
   - Search and filter candidates
   - Bulk operations

---

## Technology Stack Summary

| Layer | Technology |
|-------|------------|
| **Scripting** | PowerShell 7+ |
| **Azure SDK** | Az.ApiCenter, Az.Accounts, Az.Resources |
| **Data Storage** | JSON files, Azure Table Storage, or Azure SQL |
| **Execution** | Azure Automation, Azure DevOps, or Azure Functions |
| **Source Control** | Git (Azure Repos or GitHub) |
| **Secrets** | Azure Key Vault |
| **Monitoring** | Azure Monitor, Application Insights |

---

## Next Steps

1. **Define approval criteria** - Document what makes an MCP server "approved"
2. **Set up Azure API Center** - Create initial instance
3. **Develop scraper POC** - PowerShell script to fetch MCP servers
4. **Define custom metadata schema** - Configure in API Center
5. **Build sync script POC** - PowerShell to create APIs in API Center
6. **Test with 5-10 sample servers**
7. **Implement approval workflow**
8. **Deploy to production**
9. **Train team on discovery/usage**
10. **Iterate based on feedback**

---

## Questions for Decision

1. **Approval Process:** Manual, GitHub-based, or ticketing system?
2. **Deployment:** Azure Automation, DevOps, or manual scripts?
3. **Scope:** Single API Center or multiple instances?
4. **Frequency:** How often should we sync? Daily, weekly, on-demand?
5. **Security:** What level of vetting is required before approval?
6. **Versioning:** Auto-approve minor updates or require re-review?

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-09-29 | Architecture Team | Initial architecture design |

