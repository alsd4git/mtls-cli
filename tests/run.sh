#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary_dir=$(mktemp -d)
trap 'rm -rf -- "$temporary_dir"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || fail "expected '$needle' in output: $haystack"
}

echo "[1/4] Checking shell syntax"
bash -n "$REPO_DIR"/*.sh "$REPO_DIR"/lib/*.sh

echo "[2/4] Checking shared validation and plaintext password lookup"
export SCRIPT_DIR=$REPO_DIR
export PASSWORD_LOG="$temporary_dir/passwords.csv"
# The absolute repository path is computed at runtime in this integration test.
# shellcheck disable=SC1091
source "$REPO_DIR/lib/cert-common.sh"
validate_client_name alice-01
if validate_client_name '../escape' 2>/dev/null; then
  fail "unsafe client name was accepted"
fi
printf 'alice,old,2026-01-01 00:00:00,issued\nalice,current,2026-02-01 00:00:00,renewed\n' >"$PASSWORD_LOG"
[[ $(password_for_client alice) == current ]] || fail "latest plaintext password was not returned"

echo "[3/4] Exercising inventory, renewal, and revocation with a fake CA command"
export OUT_DIR="$temporary_dir/certs_output"
export ROOT_CA="$temporary_dir/roots.pem"
export PASSWORD_LOG="$temporary_dir/issued_passwords.csv"
mkdir -p "$OUT_DIR/alice" "$temporary_dir/bin"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=alice \
  -keyout "$OUT_DIR/alice/alice.key" -out "$OUT_DIR/alice/alice.crt" >/dev/null 2>&1
cp "$OUT_DIR/alice/alice.crt" "$ROOT_CA"
printf 'alice,test-password,2026-01-01 00:00:00,issued\n' >"$PASSWORD_LOG"
cat >"$temporary_dir/bin/step" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STEP_TEST_LOG"
if [[ ${1:-} == ca && ${2:-} == certificate ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$3" \
    -keyout "$5" -out "$4" >/dev/null 2>&1
fi
EOF
chmod +x "$temporary_dir/bin/step"
export STEP_TEST_LOG="$temporary_dir/step.log"

inventory_output=$(PATH="$temporary_dir/bin:$PATH" "$REPO_DIR/cert-manager.sh" inventory)
assert_contains "$inventory_output" alice
assert_contains "$inventory_output" valid

PATH="$temporary_dir/bin:$PATH" "$REPO_DIR/cert-manager.sh" renew alice >/dev/null
[[ -s $OUT_DIR/alice/alice.p12 ]] || fail "renewal did not rebuild P12"
[[ -s $OUT_DIR/alice/alice-certs.zip ]] || fail "renewal did not rebuild ZIP"
if unzip -Z1 "$OUT_DIR/alice/alice-certs.zip" | grep -q 'alice.key'; then
  fail "raw private key was included in the default ZIP"
fi
find "$OUT_DIR/alice" -name 'alice.crt.before-renew.*' -print -quit | grep -q . \
  || fail "renewal did not retain a certificate backup"
tail -n1 "$PASSWORD_LOG" | grep -q ',renewed$' || fail "renewal was not recorded"

PATH="$temporary_dir/bin:$PATH" "$REPO_DIR/cert-manager.sh" revoke alice 'device retired' >/dev/null
grep -q 'ca renew --force' "$STEP_TEST_LOG" || fail "step renewal command not invoked"
grep -q 'ca revoke .*--reason device retired' "$STEP_TEST_LOG" || fail "step revocation command not invoked"

printf '\n' | PATH="$temporary_dir/bin:$PATH" "$REPO_DIR/issue-client-cert.sh" bob >/dev/null
[[ -s $OUT_DIR/bob/bob-certs.zip ]] || fail "issuance did not create a ZIP"
grep -q '^bob,[0-9a-f]\{24\},.*,issued$' "$PASSWORD_LOG" || fail "issued plaintext password was not recorded"
[[ $(stat -c '%a' "$PASSWORD_LOG") == 600 ]] || fail "password log mode is not 0600"

echo "[4/4] Checking temporary single-file sharing and verified cleanup"
share_parent="$temporary_dir/shares"
mkdir -p "$share_parent"
share_output=$(SHARE_IP=127.0.0.1 PORT=0 EXPIRE_SECONDS=0.1 SHARE_TMP_PARENT="$share_parent" \
  "$REPO_DIR/serve-certs.sh" "$OUT_DIR/alice/alice-certs.zip")
assert_contains "$share_output" 'Temporarily serving one file'
assert_contains "$share_output" 'Temporary share removed'
if find "$share_parent" -mindepth 1 -print -quit | grep -q .; then
  fail "temporary share directory was not removed"
fi

echo "All tests passed."
