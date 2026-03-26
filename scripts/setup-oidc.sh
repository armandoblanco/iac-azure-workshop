#!/bin/bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# setup-oidc.sh
# Configures Azure AD application with federated credentials
# for GitHub Actions OIDC authentication (zero secrets stored)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "═══════════════════════════════════════════════"
echo " GitHub Actions OIDC Setup for Azure"
echo "═══════════════════════════════════════════════"
echo ""

# ── Validate inputs ──
if [ -z "${GITHUB_REPO:-}" ]; then
  read -rp "GitHub repo (owner/name): " GITHUB_REPO
fi

if [ -z "${APP_NAME:-}" ]; then
  APP_NAME="sp-iac-workshop-oidc"
fi

echo ""
echo "→ GitHub repo:     $GITHUB_REPO"
echo "→ App name:        $APP_NAME"
echo ""

# ── Verify Azure CLI ──
if ! command -v az &> /dev/null; then
  echo "ERROR: Azure CLI not installed."
  echo "Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

ACCOUNT=$(az account show --query '{sub:id, tenant:tenantId, name:name}' -o json 2>/dev/null) || {
  echo "ERROR: Not logged in. Run 'az login' first."
  exit 1
}

SUBSCRIPTION_ID=$(echo "$ACCOUNT" | jq -r '.sub')
TENANT_ID=$(echo "$ACCOUNT" | jq -r '.tenant')
ACCOUNT_NAME=$(echo "$ACCOUNT" | jq -r '.name')

echo "→ Subscription:    $ACCOUNT_NAME ($SUBSCRIPTION_ID)"
echo "→ Tenant:          $TENANT_ID"
echo ""

# ── Create Azure AD Application ──
echo "Creating Azure AD application..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "  App ID: $APP_ID"

# ── Create Service Principal ──
echo "Creating service principal..."
az ad sp create --id "$APP_ID" --query appId -o tsv > /dev/null 2>&1 || true
echo "  Done."

# ── Assign Contributor role to subscription ──
echo "Assigning Contributor role..."
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --only-show-errors > /dev/null
echo "  Done."

# ── Get object ID for federated credentials ──
OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)

# ── Create federated credentials ──
echo "Creating federated credentials..."

# 1. For pull requests
echo "  → Pull Request credential..."
az rest --method POST \
  --uri "https://graph.microsoft.com/beta/applications/$OBJECT_ID/federatedIdentityCredentials" \
  --body "{
    \"name\": \"github-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:pull_request\",
    \"description\": \"GitHub Actions - Pull Requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --headers "Content-Type=application/json" \
  --only-show-errors > /dev/null 2>&1 || echo "    (may already exist)"

# 2. For main branch pushes
echo "  → Main branch credential..."
az rest --method POST \
  --uri "https://graph.microsoft.com/beta/applications/$OBJECT_ID/federatedIdentityCredentials" \
  --body "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:ref:refs/heads/main\",
    \"description\": \"GitHub Actions - Main Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --headers "Content-Type=application/json" \
  --only-show-errors > /dev/null 2>&1 || echo "    (may already exist)"

# 3. For production environment
echo "  → Production environment credential..."
az rest --method POST \
  --uri "https://graph.microsoft.com/beta/applications/$OBJECT_ID/federatedIdentityCredentials" \
  --body "{
    \"name\": \"github-env-production\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:environment:production\",
    \"description\": \"GitHub Actions - Production Environment\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --headers "Content-Type=application/json" \
  --only-show-errors > /dev/null 2>&1 || echo "    (may already exist)"

echo ""
echo "═══════════════════════════════════════════════"
echo " ✅ Setup complete!"
echo "═══════════════════════════════════════════════"
echo ""
echo " Add these as GitHub Repository Secrets:"
echo ""
echo "   AZURE_CLIENT_ID        = $APP_ID"
echo "   AZURE_TENANT_ID        = $TENANT_ID"
echo "   AZURE_SUBSCRIPTION_ID  = $SUBSCRIPTION_ID"
echo ""
echo " Steps:"
echo "   1. Go to: https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo "   2. Click 'New repository secret' for each value above"
echo "   3. Create a 'production' environment at:"
echo "      https://github.com/$GITHUB_REPO/settings/environments"
echo ""
echo " Note: No client secrets are stored. Authentication"
echo " uses short-lived OIDC tokens issued by GitHub."
echo "═══════════════════════════════════════════════"
