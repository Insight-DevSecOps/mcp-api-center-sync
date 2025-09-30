# Community MCP Servers

This directory contains metadata for **community-contributed MCP servers** from various authors and organizations.

## 📋 What are Community Servers?

Community servers are MCP servers developed by the broader community outside the core modelcontextprotocol organization. These servers:

- 🌍 Created by third-party developers and organizations
- 🔧 May serve specialized use cases
- 📚 Vary in documentation and support levels
- ⚠️ Require more thorough security review before approval

## 📁 Server Metadata Files

Each file in this directory represents an approved community MCP server. Files must:

1. Use the server name as the filename (e.g., `brave-search.json`)
2. Follow the metadata schema (see [approved-servers/README.md](../README.md))
3. Include `"source": "community"` in the metadata
4. Pass validation checks
5. Include security review information (strongly recommended)

## 📝 Example Metadata

```json
{
  "name": "brave-search",
  "description": "Web search using Brave Search API",
  "homepage": "https://github.com/example-org/mcp-brave-search",
  "source": "community",
  "approved_by": "platform-team",
  "approved_date": "2025-09-29",
  "security_review": {
    "reviewed_by": "security-team",
    "review_date": "2025-09-28",
    "notes": "Reviewed API key handling, data privacy, and rate limiting. No security concerns identified.",
    "approved": true
  },
  "tags": [
    "search",
    "web",
    "community",
    "third-party"
  ],
  "custom_metadata": {
    "department": "Research",
    "risk_level": "medium",
    "support_contact": "research-team@example.com",
    "license": "MIT"
  }
}
```

## ⚠️ Security Considerations

Community servers require additional scrutiny:

### 🔍 Review Checklist

- [ ] **Source Code Review**: Verify repository exists and code is accessible
- [ ] **Dependency Audit**: Check for known vulnerabilities in dependencies
- [ ] **API Key Handling**: Ensure secrets are managed securely
- [ ] **Data Privacy**: Review data handling and external API calls
- [ ] **License Compliance**: Verify license is compatible with organizational policy
- [ ] **Maintenance Status**: Check last commit date and issue response time
- [ ] **Documentation**: Ensure adequate setup and usage documentation

### 🎯 Risk Levels

Consider assigning a risk level in `custom_metadata`:

- **Low**: Well-maintained, popular, simple functionality
- **Medium**: Active but less popular, moderate complexity
- **High**: New, complex, handles sensitive data, infrequent updates

## 🚀 Adding a Community Server

1. **Check Discovery Results**: Community servers are discovered from the MCP registry
2. **Initial Assessment**: Review repository, documentation, and maintenance status
3. **Security Review**: **Required** - Conduct thorough security review
4. **Create Metadata File**: Add JSON file with all required fields and security review
5. **Create PR**: Submit pull request with detailed description
6. **Validation**: Automated validation checks run on PR
7. **Security Approval**: Get security team approval
8. **Platform Approval**: Get platform team approval
9. **Sync**: Automatic sync to Azure API Center on merge

## 📊 Current Servers

<!-- Add links to individual server files as they are approved -->

Check the files in this directory for the complete list of approved community MCP servers.

## 🔗 Resources

- [MCP Community Servers](https://github.com/modelcontextprotocol/servers#community-servers)
- [Security Review Guidelines](../../docs/ARCHITECTURE.md)
- [Approval Process](../README.md)
