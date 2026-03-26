#!/bin/bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# cleanup.sh
# Removes all Azure resources created by this workshop.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "═══════════════════════════════════════════════"
echo " Workshop Cleanup"
echo "═══════════════════════════════════════════════"
echo ""
echo "⚠️  This will PERMANENTLY DELETE:"
echo "   • rg-iacworkshop (app + ACR + plan)"
echo "   • rg-terraform-state (TF backend)"
echo "   • Azure AD application sp-iac-workshop-oidc"
echo ""
read -rp "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""

# ── Delete application resource group ──
echo "Deleting rg-iacworkshop..."
az group delete --name "rg-iacworkshop" --yes --no-wait 2>/dev/null || echo "  (not found)"

# ── Delete terraform state resource group ──
echo "Deleting rg-terraform-state..."
az group delete --name "rg-terraform-state" --yes --no-wait 2>/dev/null || echo "  (not found)"

# ── Delete Azure AD application ──
echo "Deleting Azure AD application..."
APP_ID=$(az ad app list --display-name "sp-iac-workshop-oidc" --query "[0].appId" -o tsv 2>/dev/null) || true
if [ -n "$APP_ID" ]; then
  az ad app delete --id "$APP_ID"
  echo "  Deleted: $APP_ID"
else
  echo "  (not found)"
fi

echo ""
echo "✅ Cleanup initiated. Resource groups are deleting in the background."
echo "   Check the Azure portal to confirm deletion."
