#!/usr/bin/env bash

# Shared configuration and certificate packaging helpers.
# This file is meant to be sourced by the command scripts.

SCRIPT_DIR=${SCRIPT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
CA_URL=${CA_URL:-https://localhost:9001}
PROVISIONER=${PROVISIONER:-admin}
CERT_DURATION=${CERT_DURATION:-8760h}
OUT_DIR=${OUT_DIR:-$SCRIPT_DIR/certs_output}
ROOT_CA=${ROOT_CA:-$SCRIPT_DIR/roots.pem}
PASSWORD_LOG=${PASSWORD_LOG:-$SCRIPT_DIR/issued_passwords.csv}

require_command() {
  local command_name
  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "❌ Required command not found: $command_name" >&2
      return 1
    fi
  done
}

validate_client_name() {
  local name=$1
  if [[ ! $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    echo "❌ Invalid client name. Use 1-64 letters, numbers, dots, underscores, or hyphens." >&2
    return 1
  fi
}

ensure_root_ca() {
  if [[ -s $ROOT_CA ]] && openssl x509 -in "$ROOT_CA" -noout >/dev/null 2>&1; then
    echo "✅ Root CA certificate already cached at $ROOT_CA"
    return
  fi

  mkdir -p "$(dirname -- "$ROOT_CA")"
  local temporary_root="${ROOT_CA}.tmp.$$"
  rm -f -- "$temporary_root"

  echo "[*] Downloading CA root certificate from $CA_URL/roots.pem..."
  if [[ -n ${CA_FINGERPRINT:-} ]]; then
    step ca root "$temporary_root" --ca-url "$CA_URL" --fingerprint "$CA_FINGERPRINT"
  else
    echo "⚠️ CA_FINGERPRINT is unset; bootstrapping the local CA root over TLS without verification." >&2
    curl --fail --silent --show-error --location --insecure \
      "$CA_URL/roots.pem" --output "$temporary_root"
  fi

  if ! openssl x509 -in "$temporary_root" -noout >/dev/null 2>&1; then
    rm -f -- "$temporary_root"
    echo "❌ Downloaded root CA is not a valid X.509 certificate." >&2
    return 1
  fi
  chmod 0644 "$temporary_root"
  mv -f -- "$temporary_root" "$ROOT_CA"
}

password_for_client() {
  local name=$1
  [[ -f $PASSWORD_LOG ]] || return 1
  awk -F, -v wanted="$name" '$1 == wanted { password=$2 } END { if (password != "") print password; else exit 1 }' \
    "$PASSWORD_LOG"
}

record_password() {
  local name=$1 password=$2 operation=${3:-issued}
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf '%s,%s,%s,%s\n' "$name" "$password" "$timestamp" "$operation" >>"$PASSWORD_LOG"
  chmod 0600 "$PASSWORD_LOG"
}

package_client_certificate() {
  local name=$1 password=$2
  local client_dir="$OUT_DIR/$name"
  local crt="$client_dir/$name.crt"
  local key="$client_dir/$name.key"
  local p12="$client_dir/$name.p12"
  local archive="$client_dir/$name-certs.zip"

  openssl pkcs12 -export \
    -in "$crt" -inkey "$key" \
    -out "$p12" \
    -name "$name" \
    -passout "pass:$password" \
    -certfile "$ROOT_CA"

  local -a archive_files=("$p12" "$crt" "$ROOT_CA")
  if [[ ${INCLUDE_RAW_KEY_IN_ZIP:-false} == true ]]; then
    echo "⚠️ INCLUDE_RAW_KEY_IN_ZIP=true: adding the raw private key to the ZIP for legacy compatibility." >&2
    archive_files+=("$key")
  fi

  rm -f -- "$archive"
  zip -j -q -P "$password" "$archive" "${archive_files[@]}"
  chmod 0600 "$key" "$p12" "$archive"
}
