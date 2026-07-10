#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/cert-common.sh
source "$SCRIPT_DIR/lib/cert-common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./cert-manager.sh inventory
  ./cert-manager.sh renew CLIENT_NAME
  ./cert-manager.sh revoke CLIENT_NAME [REASON]

inventory  Lists local client certificates, serials, and validity periods.
renew      Renews the certificate in place, then rebuilds P12/ZIP using the
           latest plaintext password recorded in issued_passwords.csv.
revoke     Revokes using the local certificate/key pair. This prevents future
           renewal; relying services must use CRL/OCSP for active enforcement.
EOF
}

client_paths() {
  local name=$1
  client_dir="$OUT_DIR/$name"
  crt="$client_dir/$name.crt"
  key="$client_dir/$name.key"
}

require_client_files() {
  local name=$1
  client_paths "$name"
  if [[ ! -f $crt || ! -f $key ]]; then
    echo "❌ Certificate or key not found for '$name' under $client_dir" >&2
    return 1
  fi
}

inventory() {
  require_command openssl
  if [[ ! -d $OUT_DIR ]]; then
    echo "No local certificates found under $OUT_DIR"
    return
  fi

  printf '%-24s %-42s %-25s %s\n' CLIENT SERIAL NOT_AFTER STATUS
  local found=false certificate name serial end_date status
  while IFS= read -r -d '' certificate; do
    found=true
    name=$(basename -- "$certificate" .crt)
    serial=$(openssl x509 -in "$certificate" -noout -serial | sed 's/^serial=//')
    end_date=$(openssl x509 -in "$certificate" -noout -enddate | sed 's/^notAfter=//')
    if openssl x509 -in "$certificate" -noout -checkend 0 >/dev/null 2>&1; then
      status=valid
    else
      status=expired
    fi
    printf '%-24s %-42s %-25s %s\n' "$name" "$serial" "$end_date" "$status"
  done < <(find "$OUT_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.crt' -print0 | sort -z)
  $found || echo "No local certificates found under $OUT_DIR"
}

renew_client() {
  local name=$1
  validate_client_name "$name"
  require_command step openssl zip
  require_client_files "$name"
  [[ -s $ROOT_CA ]] || { echo "❌ Root CA not found: $ROOT_CA" >&2; return 1; }

  local password backup
  if ! password=$(password_for_client "$name"); then
    echo "❌ No plaintext password found for '$name' in $PASSWORD_LOG; refusing to change bundle credentials." >&2
    return 1
  fi
  backup="${crt}.before-renew.$(date '+%Y%m%d%H%M%S')"
  cp -p -- "$crt" "$backup"

  if ! step ca renew --force --ca-url "$CA_URL" --root "$ROOT_CA" "$crt" "$key"; then
    cp -p -- "$backup" "$crt"
    echo "❌ Renewal failed; the previous certificate was restored." >&2
    return 1
  fi
  if ! package_client_certificate "$name" "$password"; then
    cp -p -- "$backup" "$crt"
    package_client_certificate "$name" "$password" >/dev/null 2>&1 || true
    echo "❌ Repackaging failed; the previous certificate was restored." >&2
    return 1
  fi
  record_password "$name" "$password" renewed
  echo "✅ Renewed '$name'; rebuilt P12/ZIP with the recorded password."
  echo "   Previous certificate: $backup"
}

revoke_client() {
  local name=$1 reason=${2:-Cessation of use}
  validate_client_name "$name"
  require_command step
  require_client_files "$name"
  [[ -s $ROOT_CA ]] || { echo "❌ Root CA not found: $ROOT_CA" >&2; return 1; }

  step ca revoke \
    --cert "$crt" \
    --key "$key" \
    --reason "$reason" \
    --ca-url "$CA_URL" \
    --root "$ROOT_CA"
  echo "✅ Revoked '$name'. Local files were retained for audit and recovery."
  echo "ℹ️ Configure CRL/OCSP on relying services if immediate active revocation is required."
}

command_name=${1:-}
case $command_name in
  inventory)
    (( $# == 1 )) || { usage >&2; exit 2; }
    inventory
    ;;
  renew)
    (( $# == 2 )) || { usage >&2; exit 2; }
    renew_client "$2"
    ;;
  revoke)
    (( $# >= 2 && $# <= 3 )) || { usage >&2; exit 2; }
    revoke_client "$2" "${3:-}"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
