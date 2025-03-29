#!/bin/bash

set -e

# === BEFORE USE ===
# 1. Make sure you have the Step CA CLI installed and configured.
# 2. Ensure the Step CA is running and accessible at the specified CA_URL.
# 3. Update the ROOT_CA path if your root CA certificate is located elsewhere.
# 4. Make sure the OpenSSL CLI is installed.
# 5. Ensure the zip utility is installed for creating the ZIP file.
# 6. Make sure the script has execute permissions: chmod +x issue-client-cert.sh
# 7. Extend certs max duration adding this to ca.json:
#   	"authority": {
#       "claims": {
# 	      "maxTLSCertDuration": "8760h"
#         },

# === CONFIGURATION ===
CA_URL="https://localhost:9001" # as exposed in the step-ca docker container
PROVISIONER="admin"             # Change if you use a different provisioner
CERT_DURATION="8760h"           # 1 year
OUT_DIR="./certs_output"        # Directory to save the certs

# Where to store the cached root cert
ROOT_CA="./roots.pem"

# Download and cache the CA root certificate if not already present
if [[ ! -f "$ROOT_CA" ]]; then
  echo "[*] Downloading CA root certificate from $CA_URL/roots.pem..."
  curl -s -k -L "$CA_URL/roots.pem" -o "$ROOT_CA"

  if [[ $? -ne 0 || ! -s "$ROOT_CA" ]]; then
    echo "❌ Failed to download or save root CA certificate."
    exit 1
  fi
else
  echo "✅ Root CA certificate already cached at $ROOT_CA"
fi


# === GET CLIENT INFO ===
read -rp "Enter client name (e.g. alice): " NAME
CN="$NAME"
P12_PASS=$(openssl rand -hex 12)

# === FILE PATHS ===
CRT="$OUT_DIR/$NAME/$NAME.crt"
KEY="$OUT_DIR/$NAME/$NAME.key"
P12="$OUT_DIR/$NAME/$NAME.p12"
ZIP="$OUT_DIR/$NAME/$NAME-certs.zip"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/$NAME"

if [[ -f "$CRT" || -f "$KEY" || -f "$P12" ]]; then
  echo "⚠️ Files for '$NAME' already exist. Do you want to overwrite them? (y/N)"
  read -r CONFIRM
  [[ "$CONFIRM" == "y" ]] || exit 1
fi


# === ISSUE CERT ===
echo "[*] Requesting certificate from Step CA..."
step ca certificate "$CN" "$CRT" "$KEY" \
  --not-after="$CERT_DURATION" \
  --provisioner "$PROVISIONER" \
  --ca-url "$CA_URL" \
  --root "$ROOT_CA"

# === CONVERT TO .P12 ===
echo "[*] Creating .p12 bundle..."
openssl pkcs12 -export \
  -in "$CRT" -inkey "$KEY" \
  -out "$P12" \
  -name "$NAME" \
  -passout pass:"$P12_PASS" \
  -certfile "$ROOT_CA"

# === ZIP AND INFO ===
zip -j -P "$P12_PASS" "$ZIP" "$P12" "$CRT" "$KEY" "$ROOT_CA"

# === SAVE ISSUED PASSWORD ===
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$NAME,$P12_PASS,$TIMESTAMP" >> issued_passwords.csv


echo ""
echo "✅ Certificate created for '$NAME'"
echo "   - P12 File: $P12"
echo "   - Password: $P12_PASS"
echo "   - Bundle:   $ZIP"
echo ""
echo "📱 Send the ZIP to the user and give them the password."
echo "🔐 They can import the .p12 on Android via Settings > Security > Credentials."


echo ""
read -rp "🌐 Press [S] to serve the certs folder over HTTP, or press [Enter] to finish: " RESP
if [[ "$RESP" =~ ^[Ss]$ ]]; then
  if [[ -x "./serve-certs.sh" ]]; then
    ./serve-certs.sh
  else
    echo "⚠️ 'serve-certs.sh' not found or not executable."
    echo "   → Make sure it's in the same folder and run: chmod +x serve-certs.sh"
  fi
else
  echo "✅ Done. Cert files are in: $OUT_DIR/$NAME"
fi
