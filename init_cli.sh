#!/usr/bin/env bash

set -Eeuo pipefail

STEP_CLI_VERSION=${STEP_CLI_VERSION:-0.30.2}
declare -A STEP_CLI_SHA256=(
  [amd64]=9aee0346ffd154ed643063953ef42ff86a9880ed82810789e0fe1a103fc31613
  [arm64]=c723ea00ee837d2e832e04d95dfd61de18175a81c367fb13add1e64dc07cce66
  [armhf]=f341e42c10ce23633f3c5cc29929f44b2093c3d2308755899e91f87c9b1e9d8a
)

install_step_cli() (
  local architecture package temporary_dir url
  architecture=$(dpkg --print-architecture)
  if [[ -z ${STEP_CLI_SHA256[$architecture]:-} ]]; then
    echo "❌ Unsupported Debian architecture for automated install: $architecture" >&2
    return 1
  fi

  package="step-cli_${STEP_CLI_VERSION}-1_${architecture}.deb"
  url="https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/${package}"
  temporary_dir=$(mktemp -d)
  trap 'rm -rf -- "$temporary_dir"' EXIT

  echo "📦 Installing pinned step-cli v$STEP_CLI_VERSION for $architecture..."
  curl --fail --location --silent --show-error "$url" --output "$temporary_dir/$package"
  printf '%s  %s\n' "${STEP_CLI_SHA256[$architecture]}" "$temporary_dir/$package" | sha256sum --check --status
  sudo dpkg -i "$temporary_dir/$package"
)

echo "🔍 Checking required tools..."
need_apt_update=false
install_zip=false
install_qrencode=false

if ! command -v step >/dev/null 2>&1; then
  install_step_cli
else
  echo "✅ step-cli already installed: $(step version 2>/dev/null | head -n1)"
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "📦 zip not found. It will be installed."
  need_apt_update=true
  install_zip=true
else
  echo "✅ zip already installed."
fi

if ! command -v qrencode >/dev/null 2>&1; then
  read -rp "💡 Install optional qrencode for QR sharing? (Y/n): " response
  if [[ $response =~ ^[Yy]$ || -z $response ]]; then
    need_apt_update=true
    install_qrencode=true
  fi
else
  echo "✅ qrencode already installed."
fi

if $need_apt_update; then
  sudo apt-get update
fi
$install_zip && sudo apt-get install -y zip
$install_qrencode && sudo apt-get install -y qrencode

echo "🎉 CLI tools are ready."
