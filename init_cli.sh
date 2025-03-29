#!/bin/bash

# ============================================
# Step CLI Setup Script (Efficient Version)
# --------------------------------------------
# Installs:
# - step-cli (Smallstep CLI)
# - zip (for packaging certs)
# - qrencode (optional, for QR sharing)
# Only runs 'apt update' if something needs to be installed.
# ============================================

set -e

echo "🔍 Checking required tools..."

NEED_APT_UPDATE=false

# === Check Step CLI ===
if ! command -v step >/dev/null 2>&1; then
  echo "📦 step-cli not found. Installing..."
  wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
  sudo dpkg -i step-cli_amd64.deb
  rm step-cli_amd64.deb
else
  echo "✅ step-cli already installed."
fi

# === Check zip ===
if ! command -v zip >/dev/null 2>&1; then
  echo "📦 zip not found. Will install it."
  NEED_APT_UPDATE=true
  INSTALL_ZIP=true
else
  echo "✅ zip already installed."
fi

# === Check qrencode (optional) ===
if ! command -v qrencode >/dev/null 2>&1; then
  echo "💡 qrencode (for QR sharing) not found."
  read -rp "   → Do you want to install qrencode? (Y/n): " RESP
  if [[ "$RESP" =~ ^[Yy]$ || -z "$RESP" ]]; then
    NEED_APT_UPDATE=true
    INSTALL_QRENCODE=true
  else
    echo "⚠️ Skipping qrencode install."
  fi
else
  echo "✅ qrencode already installed."
fi

# === Do apt update if needed ===
if [ "$NEED_APT_UPDATE" = true ]; then
  echo "🔄 Updating package list..."
  sudo apt update
fi

# === Install missing packages ===
if [ "$INSTALL_ZIP" = true ]; then
  sudo apt install -y zip
fi

if [ "$INSTALL_QRENCODE" = true ]; then
  sudo apt install -y qrencode
fi

echo ""
echo "🎉 All done! CLI tools are ready to use."
