# Official MCP Servers

This directory contains metadata for **official MCP servers** from the Model Context Protocol organization.

## 📋 What are Official Servers?

Official servers are those maintained and published by the [modelcontextprotocol](https://github.com/modelcontextprotocol) organization on GitHub. These servers are:

- ✅ Maintained by the MCP core team
- ✅ Follow MCP best practices
- ✅ Well-documented and supported
- ✅ Considered reference implementations

## 📁 Server Metadata Files

Each file in this directory represents an approved official MCP server. Files must:

1. Use the server name as the filename (e.g., `filesystem.json`)
2. Follow the metadata schema (see [approved-servers/README.md](../README.md))
3. Include `"source": "official"` in the metadata
4. Pass validation checks

## 📝 Example Metadata

```json
{
  "name": "filesystem",
  "description": "Secure file operations with configurable access controls",
  "homepage": "https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem",
  "source": "official",
  "approved_by": "security-team",
  "approved_date": "2025-09-29",
  "security_review": {
    "reviewed_by": "security-reviewer",
    "review_date": "2025-09-28",
    "notes": "Reviewed for path traversal vulnerabilities. Access controls properly implemented.",
    "approved": true
  },
  "tags": [
    "filesystem",
    "storage",
    "official"
  ],
  "custom_metadata": {
    "department": "Platform Engineering",
    "support_contact": "platform-team@example.com"
  }
}
```

## 🚀 Adding an Official Server

1. **Check Discovery Results**: Official servers are automatically discovered from the MCP registry
2. **Create Metadata File**: Add a JSON file with required fields
3. **Security Review**: Conduct security review (recommended for official servers)
4. **Create PR**: Submit pull request with the metadata file
5. **Validation**: Automated validation checks run on PR
6. **Approval**: Get required approvals and merge
7. **Sync**: Automatic sync to Azure API Center on merge

## 📊 Current Servers

<!-- Add links to individual server files as they are approved -->

Check the files in this directory for the complete list of approved official MCP servers.

## 🔗 Resources

- [MCP Official Servers Repository](https://github.com/modelcontextprotocol/servers)
- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [Approval Process](../README.md)
