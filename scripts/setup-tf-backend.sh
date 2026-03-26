#!/bin/bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# setup-tf-backend.sh
# Creates the Azure Storage Account for Terraform remote state.
# Only needed if you choose the Terraform track.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "═══════════════════════════════════════════════"
echo " Terraform Backend Bootstrap"
echo "═══════════════════════════════════════════════"
echo ""

RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="stiacworkshoptfstate"
CONTAINER="tfstate"
LOCATION="eastus2"

# ── Verify Azure CLI ──
ACCOUNT=$(az account show --query '{sub:id, name:name}' -o json 2>/dev/null) || {
  echo "ERROR: Not logged in. Run 'az login' first."
  exit 1
}

SUBSCRIPTION_ID=$(echo "$ACCOUNT" | jq -r '.sub')
echo "→ Subscription: $(echo "$ACCOUNT" | jq -r '.name') ($SUBSCRIPTION_ID)"
echo ""

# ── Create Resource Group ──
echo "Creating resource group: $RESOURCE_GROUP..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --only-show-errors > /dev/null
echo "  Done."

# ── Create Storage Account ──
echo "Creating storage account: $STORAGE_ACCOUNT..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --min-tls-version "TLS1_2" \
  --allow-blob-public-access false \
  --only-show-errors > /dev/null
echo "  Done."

# ── Create Blob Container ──
echo "Creating blob container: $CONTAINER..."
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --only-show-errors > /dev/null
echo "  Done."

# ── Assign RBAC for OIDC identity ──
if [ -n "${APP_ID:-}" ]; then
  echo "Assigning Storage Blob Data Contributor to $APP_ID..."
  az role assignment create \
    --assignee "$APP_ID" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
    --only-show-errors > /dev/null
  echo "  Done."
else
  echo ""
  echo "⚠️  Set APP_ID env var to auto-assign RBAC:"
  echo "   export APP_ID=<your-azure-ad-app-client-id>"
  echo "   Then re-run this script."
fi

echo ""
echo "═══════════════════════════════════════════════"
echo " ✅ Terraform backend ready!"
echo "═══════════════════════════════════════════════"
echo ""
echo " Backend config (already set in backend.tf):"
echo ""
echo "   resource_group_name  = $RESOURCE_GROUP"
echo "   storage_account_name = $STORAGE_ACCOUNT"
echo "   container_name       = $CONTAINER"
echo "   key                  = iac-workshop.tfstate"
echo ""
echo "═══════════════════════════════════════════════"
