# Approved MCP Servers

This directory contains metadata for MCP servers that have been reviewed and approved for inclusion in the Azure API Center.

## 📁 Directory Structure

```
approved-servers/
├── official/          # Official MCP servers (from modelcontextprotocol org)
│   └── *.json        # Individual server metadata files
└── community/         # Community-contributed MCP servers
    └── *.json        # Individual server metadata files
```

## 📋 Metadata Format

Each approved server must have a JSON file with the following structure:

```json
{
  "name": "server-name",
  "description": "Brief description of the server's functionality",
  "homepage": "https://github.com/org/repo",
  "source": "official",
  "approved_by": "username",
  "approved_date": "2025-09-29",
  "security_review": {
    "reviewed_by": "security-team-member",
    "review_date": "2025-09-28",
    "notes": "Security review notes and findings",
    "approved": true
  },
  "tags": [
    "category1",
    "category2"
  ],
  "custom_metadata": {
    "department": "Engineering",
    "cost_center": "CC-1234",
    "support_contact": "team@example.com"
  }
}
```

## ✅ Required Fields

- **name**: Server name (must match filename without .json)
- **description**: Clear description of server functionality
- **homepage**: URL to server's homepage or repository
- **source**: Must be either `"official"` or `"community"`
- **approved_by**: GitHub username of approver
- **approved_date**: Approval date in YYYY-MM-DD format

## 🔒 Recommended Fields

- **security_review**: Security review information
  - `reviewed_by`: Security team member
  - `review_date`: Date of security review
  - `notes`: Security review findings
  - `approved`: Boolean approval status
- **tags**: Array of categorization tags
- **custom_metadata**: Organization-specific metadata

## 🚀 Adding a New Server

### Step 1: Discovery
Servers are automatically discovered weekly by the GitHub Actions workflow. Check the discovery PRs for new servers.

### Step 2: Create Metadata File
1. Create a new branch from `main`
2. Add a JSON file in the appropriate directory:
   - `approved-servers/official/` for official servers
   - `approved-servers/community/` for community servers
3. Name the file using the server name: `server-name.json`

### Step 3: Create Pull Request
1. Commit your changes
2. Create a pull request to `main`
3. The validation workflow will automatically check your metadata
4. Request review from required approvers

### Step 4: Review & Approval
1. PR must pass validation checks
2. Security review (if required by policy)
3. Approval from designated reviewers
4. Merge to `main`

### Step 5: Automatic Sync
Once merged, the sync workflow automatically updates Azure API Center with the new server.

## 📝 Naming Convention

**Filename**: Use lowercase with hyphens
- ✅ Good: `filesystem.json`, `brave-search.json`, `google-drive.json`
- ❌ Bad: `FileSystem.json`, `brave_search.json`, `Google Drive.json`

**Source Field**: Must match directory location
- Files in `official/` must have `"source": "official"`
- Files in `community/` must have `"source": "community"`

## 🔍 Validation Rules

The validation workflow checks:
- Valid JSON syntax
- All required fields present
- Source field matches directory location
- Homepage is a valid URL
- Approved date is in YYYY-MM-DD format
- Tags field is an array (if present)
- Filename matches server name

## 🔗 Related Documentation

- [Architecture Documentation](../docs/ARCHITECTURE.md)
- [Main README](../README.md)
- [GitHub Actions Workflows](../.github/workflows/)

## 💡 Examples

See the individual directories for example metadata files:
- [Official Servers](official/README.md)
- [Community Servers](community/README.md)
