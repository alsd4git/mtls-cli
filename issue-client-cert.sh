#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/cert-common.sh
source "$SCRIPT_DIR/lib/cert-common.sh"

usage() {
  cat <<'EOF'
Usage: ./issue-client-cert.sh [CLIENT_NAME]

Issue a client certificate. With no CLIENT_NAME, the script prompts as before.
Configuration can be overridden with CA_URL, PROVISIONER, CERT_DURATION,
OUT_DIR, ROOT_CA, and PASSWORD_LOG. CA_FINGERPRINT is required when CA_URL is
not a loopback address and optional for a local CA.
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

require_command step openssl zip curl flock

name=${1:-}
if [[ -z $name ]]; then
  read -rp "Enter client name (e.g. alice): " name
fi
validate_client_name "$name"

client_dir="$OUT_DIR/$name"
crt="$client_dir/$name.crt"
key="$client_dir/$name.key"
p12="$client_dir/$name.p12"
archive="$client_dir/$name-certs.zip"

files_existed=false
if [[ -e $crt || -e $key || -e $p12 || -e $archive ]]; then
  files_existed=true
  read -rp "⚠️ Files for '$name' already exist. Overwrite them? (y/N) " confirm
  [[ $confirm =~ ^[Yy]$ ]] || exit 1
fi

acquire_lifecycle_lock
trap release_lifecycle_lock EXIT
ensure_root_ca
mkdir -p "$client_dir"

# Another issuer may have created these files while this process waited for the
# lock. Never overwrite that work without a fresh confirmation.
if [[ $files_existed == false ]] && [[ -e $crt || -e $key || -e $p12 || -e $archive ]]; then
  read -rp "⚠️ Files for '$name' were created by another process. Overwrite them? (y/N) " confirm
  [[ $confirm =~ ^[Yy]$ ]] || exit 1
fi

p12_pass=$(openssl rand -hex 12)
echo "[*] Requesting certificate from Step CA..."
step ca certificate "$name" "$crt" "$key" \
  --not-after="$CERT_DURATION" \
  --provisioner "$PROVISIONER" \
  --ca-url "$CA_URL" \
  --root "$ROOT_CA"

echo "[*] Creating protected .p12 and shareable ZIP bundles..."
package_client_certificate "$name" "$p12_pass"
record_password "$name" "$p12_pass" issued
release_lifecycle_lock
trap - EXIT

echo
echo "✅ Certificate created for '$name'"
echo "   - P12 File: $p12"
echo "   - Password: $p12_pass"
echo "   - Bundle:   $archive"
echo "   - Password log: $PASSWORD_LOG (plaintext by design, mode 0600)"
echo

read -rp "🌐 Press [S] to share only this bundle temporarily, or [Enter] to finish: " response
if [[ $response =~ ^[Ss]$ ]]; then
  "$SCRIPT_DIR/serve-certs.sh" "$archive"
else
  echo "✅ Done. Cert files are in: $client_dir"
fi
