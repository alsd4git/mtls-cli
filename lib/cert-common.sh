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
LIFECYCLE_LOCK_TIMEOUT=${LIFECYCLE_LOCK_TIMEOUT:-30}

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

is_loopback_ca_url() {
  [[ $CA_URL =~ ^https?://(localhost|127([.][0-9]{1,3}){3}|\[::1\])(:[0-9]+)?(/|$) ]]
}

acquire_lifecycle_lock() {
  mkdir -p "$OUT_DIR"
  local lock_path="$OUT_DIR/.lifecycle.lock"
  exec {LIFECYCLE_LOCK_FD}>"$lock_path"
  if ! flock -w "$LIFECYCLE_LOCK_TIMEOUT" "$LIFECYCLE_LOCK_FD"; then
    echo "❌ Timed out waiting for certificate lifecycle lock: $lock_path" >&2
    return 1
  fi
}

release_lifecycle_lock() {
  if [[ -n ${LIFECYCLE_LOCK_FD:-} ]]; then
    flock -u "$LIFECYCLE_LOCK_FD" || true
    exec {LIFECYCLE_LOCK_FD}>&-
    unset LIFECYCLE_LOCK_FD
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
    if ! is_loopback_ca_url; then
      rm -f -- "$temporary_root"
      echo "❌ CA_FINGERPRINT is required when CA_URL is not loopback: $CA_URL" >&2
      return 1
    fi
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
  local timestamp lock_path
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$(dirname -- "$PASSWORD_LOG")"
  lock_path="${PASSWORD_LOG}.lock"
  if ! (
    flock -w "$LIFECYCLE_LOCK_TIMEOUT" 9 || {
      echo "❌ Timed out waiting for password ledger lock: $lock_path" >&2
      exit 1
    }
    printf '%s,%s,%s,%s\n' "$name" "$password" "$timestamp" "$operation" >>"$PASSWORD_LOG"
    chmod 0600 "$PASSWORD_LOG"
  ) 9>"$lock_path"; then
    return 1
  fi
}

package_client_certificate() {
  local name=$1 password=$2
  local client_dir="$OUT_DIR/$name"
  local crt="$client_dir/$name.crt"
  local key="$client_dir/$name.key"
  local p12="$client_dir/$name.p12"
  local archive="$client_dir/$name-certs.zip"

  local password_fd
  exec {password_fd}<<<"$password"
  local temporary_p12="${p12}.tmp.$$"
  rm -f -- "$temporary_p12"
  if ! openssl pkcs12 -export \
    -in "$crt" -inkey "$key" \
    -out "$temporary_p12" \
    -name "$name" \
    -passout "fd:$password_fd" \
    -certfile "$ROOT_CA"; then
    exec {password_fd}<&-
    rm -f -- "$temporary_p12"
    return 1
  fi
  exec {password_fd}<&-
  chmod 0600 "$temporary_p12"
  mv -f -- "$temporary_p12" "$p12"

  local -a archive_files=("$p12" "$crt" "$ROOT_CA")
  if [[ ${INCLUDE_RAW_KEY_IN_ZIP:-false} == true ]]; then
    echo "⚠️ INCLUDE_RAW_KEY_IN_ZIP=true: adding the raw private key to the ZIP for legacy compatibility." >&2
    archive_files+=("$key")
  fi

  rm -f -- "$archive"
  if [[ ${LEGACY_ZIP_PASSWORD:-false} == true ]]; then
    echo "⚠️ LEGACY_ZIP_PASSWORD=true uses weak ZipCrypto and exposes the password in the process list." >&2
    if ! zip -j -q -P "$password" "$archive" "${archive_files[@]}"; then
      rm -f -- "$archive"
      return 1
    fi
  else
    if ! zip -j -q "$archive" "${archive_files[@]}"; then
      rm -f -- "$archive"
      return 1
    fi
  fi
  chmod 0600 "$key" "$p12" "$archive"
}
