# Azure OIDC Setup Guide

This guide walks through configuring **OpenID Connect (OIDC) Workload Identity Federation** between GitHub Actions and Azure. This enables passwordless authentication, eliminating the need for long-lived service principal secrets.

## 🎯 Overview

With OIDC, GitHub Actions can authenticate to Azure using short-lived tokens that are automatically managed by GitHub. This provides:

- ✅ **No secrets to manage** - No service principal keys to rotate
- ✅ **Improved security** - Short-lived tokens instead of long-lived credentials
- ✅ **Automatic rotation** - Tokens expire automatically
- ✅ **Audit trail** - Clear identity in Azure activity logs

## 📋 Prerequisites

Before starting, ensure you have:

- **Azure Subscription** with appropriate permissions to:
  - Create App Registrations in Entra ID (Azure AD)
  - Assign roles to service principals
  - Create/manage API Center resources
- **GitHub Repository** with admin access
- **Azure CLI** installed locally ([Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- **PowerShell 7+** (for automation scripts)

## 🔧 Setup Process

### Step 1: Gather Information

Collect the following information before starting:

```bash
# GitHub Information
GITHUB_ORG="Insight-DevSecOps"
GITHUB_REPO="mcp-api-center-sync"

# Azure Information
AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
AZURE_RESOURCE_GROUP="<your-resource-group>"
AZURE_API_CENTER_NAME="<your-api-center-name>"
AZURE_LOCATION="eastus"  # or your preferred region
```

You can get your Azure subscription ID with:

```bash
az login
az account show --query id -o tsv
```

### Step 2: Create Azure App Registration

Create an App Registration in Microsoft Entra ID (Azure AD):

```bash
# Set variables
APP_NAME="github-mcp-api-center-sync"

# Create the app registration
az ad app create \
  --display-name "$APP_NAME" \
  --query appId -o tsv

# Save the App (Client) ID
AZURE_CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

echo "Azure Client ID: $AZURE_CLIENT_ID"
```

**Alternative: Azure Portal**

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** > **App registrations**
3. Click **New registration**
4. Enter name: `github-mcp-api-center-sync`
5. Leave defaults and click **Register**
6. Copy the **Application (client) ID**

### Step 3: Create Service Principal

Create a service principal for the app registration:

```bash
# Create service principal
az ad sp create --id $AZURE_CLIENT_ID

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $AZURE_CLIENT_ID --query id -o tsv)

echo "Service Principal Object ID: $SP_OBJECT_ID"
```

### Step 4: Configure Federated Credentials

Configure the app to trust GitHub Actions tokens:

```bash
# Get your Azure Tenant ID
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

# Create federated credential for main branch
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions access from main branch"
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':pull_request",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions access from pull requests"
  }'

# (Optional) Create federated credential for environment
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{
    "name": "github-production-env",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':environment:production",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions access from production environment"
  }'
```

**Alternative: Azure Portal**

1. Go to your App Registration
2. Navigate to **Certificates & secrets** > **Federated credentials**
3. Click **Add credential**
4. Select **GitHub Actions deploying Azure resources**
5. Fill in:
   - **Organization**: `Insight-DevSecOps`
   - **Repository**: `mcp-api-center-sync`
   - **Entity type**: `Branch`
   - **GitHub branch name**: `main`
   - **Name**: `github-main-branch`
6. Repeat for pull requests (Entity type: `Pull request`)

### Step 5: Assign Azure Permissions

Grant the service principal permissions to manage the API Center:

```bash
# Assign Contributor role on the resource group
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"

# Verify role assignment
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

**Alternative Scopes:**

```bash
# Option 1: Subscription-level access (broader permissions)
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

# Option 2: API Center-specific access (most restrictive)
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.ApiCenter/services/$AZURE_API_CENTER_NAME"
```

**Recommended Custom Role** (Principle of Least Privilege):

```bash
# Create custom role definition
cat > api-center-sync-role.json <<EOF
{
  "Name": "API Center Sync",
  "Description": "Custom role for MCP API Center sync operations",
  "Actions": [
    "Microsoft.ApiCenter/services/read",
    "Microsoft.ApiCenter/services/write",
    "Microsoft.ApiCenter/services/workspaces/read",
    "Microsoft.ApiCenter/services/workspaces/write",
    "Microsoft.ApiCenter/services/workspaces/apis/read",
    "Microsoft.ApiCenter/services/workspaces/apis/write",
    "Microsoft.ApiCenter/services/workspaces/apis/delete"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/$AZURE_SUBSCRIPTION_ID"
  ]
}
EOF

# Create the custom role
az role definition create --role-definition api-center-sync-role.json

# Assign the custom role
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "API Center Sync" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"
```

### Step 6: Configure GitHub Secrets

Add the Azure configuration to GitHub repository secrets:

**Option 1: GitHub CLI**

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Authenticate
gh auth login

# Add secrets
gh secret set AZURE_CLIENT_ID --body "$AZURE_CLIENT_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_TENANT_ID --body "$AZURE_TENANT_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_SUBSCRIPTION_ID --body "$AZURE_SUBSCRIPTION_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_RESOURCE_GROUP --body "$AZURE_RESOURCE_GROUP" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_API_CENTER_NAME --body "$AZURE_API_CENTER_NAME" --repo "$GITHUB_ORG/$GITHUB_REPO"

# Verify secrets
gh secret list --repo "$GITHUB_ORG/$GITHUB_REPO"
```

**Option 2: GitHub Web UI**

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add each of the following secrets:

   | Secret Name | Value | Description |
   |-------------|-------|-------------|
   | `AZURE_CLIENT_ID` | Application (client) ID | From Step 2 |
   | `AZURE_TENANT_ID` | Directory (tenant) ID | From Step 4 |
   | `AZURE_SUBSCRIPTION_ID` | Subscription ID | From Step 1 |
   | `AZURE_RESOURCE_GROUP` | Resource group name | From Step 1 |
   | `AZURE_API_CENTER_NAME` | API Center name | From Step 1 |

### Step 7: Test the Configuration

Create a test workflow to verify OIDC authentication:

```bash
# Create test file
mkdir -p .github/workflows
cat > .github/workflows/test-oidc.yml <<'EOF'
name: Test Azure OIDC

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Verify Connection
        run: |
          echo "Testing Azure connection..."
          az account show
          az group show --name ${{ secrets.AZURE_RESOURCE_GROUP }}
          echo "✅ OIDC authentication successful!"
EOF

# Commit and push
git add .github/workflows/test-oidc.yml
git commit -m "Add OIDC test workflow"
git push
```

Run the test workflow:

1. Go to **Actions** tab in GitHub
2. Select **Test Azure OIDC** workflow
3. Click **Run workflow**
4. Monitor the output for successful authentication

### Step 8: Verify API Center Permissions

Test that the service principal can access the API Center:

```bash
# Login as the service principal (local testing)
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --tenant $AZURE_TENANT_ID \
  --allow-no-subscriptions \
  --federated-token $(curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)

# List API Center
az resource show \
  --resource-group $AZURE_RESOURCE_GROUP \
  --resource-type "Microsoft.ApiCenter/services" \
  --name $AZURE_API_CENTER_NAME

# Logout
az logout
```

## ✅ Verification Checklist

Confirm all setup steps are complete:

- [ ] App Registration created in Entra ID
- [ ] Service Principal created
- [ ] Federated credentials configured for:
  - [ ] Main branch
  - [ ] Pull requests
  - [ ] (Optional) Production environment
- [ ] Azure role assignments configured
- [ ] GitHub secrets added:
  - [ ] `AZURE_CLIENT_ID`
  - [ ] `AZURE_TENANT_ID`
  - [ ] `AZURE_SUBSCRIPTION_ID`
  - [ ] `AZURE_RESOURCE_GROUP`
  - [ ] `AZURE_API_CENTER_NAME`
- [ ] Test workflow runs successfully
- [ ] Service principal can access API Center

## 🔒 Security Best Practices

### Principle of Least Privilege

- ✅ Use custom roles with minimal permissions
- ✅ Scope permissions to specific resources (API Center only)
- ✅ Avoid subscription-level Contributor role if possible

### Federated Credential Scope

- ✅ Use branch-specific credentials (`refs/heads/main`)
- ✅ Separate credentials for pull requests vs production
- ✅ Consider environment-based credentials for staging/production

### Secret Management

- ✅ Never commit secrets to Git
- ✅ Use GitHub encrypted secrets
- ✅ Rotate credentials periodically (even OIDC client IDs)
- ✅ Monitor Azure activity logs for suspicious access

### GitHub Actions Security

- ✅ Set minimal `permissions` in workflows
- ✅ Use `id-token: write` only when needed
- ✅ Pin action versions (e.g., `azure/login@v2`)
- ✅ Enable branch protection on `main`

## 🐛 Troubleshooting

### Error: "Failed to get federated token"

**Cause**: Federated credential subject doesn't match workflow context

**Solution**: Verify the subject in federated credential matches exactly:
- For branch: `repo:ORG/REPO:ref:refs/heads/BRANCH`
- For PR: `repo:ORG/REPO:pull_request`
- For env: `repo:ORG/REPO:environment:ENV_NAME`

### Error: "Insufficient privileges to complete the operation"

**Cause**: Service principal lacks necessary permissions

**Solution**: Verify role assignments:
```bash
az role assignment list --assignee $AZURE_CLIENT_ID --all
```

Add missing permissions with appropriate scope.

### Error: "The client 'xxx' with object id 'xxx' does not have authorization"

**Cause**: Role assignment not yet propagated or incorrect scope

**Solution**: 
1. Wait 5-10 minutes for Azure to propagate permissions
2. Verify scope matches resource location
3. Check role definition includes required actions

### Workflow fails but local Azure CLI works

**Cause**: Different authentication contexts

**Solution**: Ensure workflow uses:
```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read
```

## 📚 Additional Resources

- [Azure Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
- [GitHub Actions OIDC with Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure API Center Documentation](https://learn.microsoft.com/en-us/azure/api-center/)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Azure RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)

## 📝 Quick Reference

### Required GitHub Secrets

```bash
AZURE_CLIENT_ID         # App (client) ID from App Registration
AZURE_TENANT_ID         # Directory (tenant) ID
AZURE_SUBSCRIPTION_ID   # Azure subscription ID
AZURE_RESOURCE_GROUP    # Resource group containing API Center
AZURE_API_CENTER_NAME   # API Center instance name
```

### Federated Credential Subjects

```bash
# Main branch
repo:Insight-DevSecOps/mcp-api-center-sync:ref:refs/heads/main

# Pull requests
repo:Insight-DevSecOps/mcp-api-center-sync:pull_request

# Specific environment
repo:Insight-DevSecOps/mcp-api-center-sync:environment:production
```

### Minimal Workflow Permissions

```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read   # Read repository contents
```

---

## 🎉 Next Steps

With OIDC configured, you're ready to:

1. ✅ Run automated server discovery workflows
2. ✅ Create pull requests for server approvals
3. ✅ Sync approved servers to Azure API Center
4. ✅ Monitor Azure activity logs for sync operations

See the [main README](../README.md) for usage instructions.
