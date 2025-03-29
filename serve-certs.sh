#!/bin/bash

# ============================================
# Temporary HTTP Server for Sharing Cert Files
# --------------------------------------------
# - Serves ./certs_output over HTTP
# - Shows a QR code for easy LAN access
# - Automatically stops after X minutes
#
# Requirements:
# - Python 3 (for http.server)
# - qrencode (optional, for QR display)
# ============================================

# === CONFIG ===
EXPIRE_MINUTES=5  # How long to keep the server up
PORT=8080
SERVE_DIR="certs_output"

# === GET LOCAL IP ===
LOCAL_IP=$(ip -4 addr show eth0 | grep -Po 'inet \K[\d.]+')
if [[ -z "$LOCAL_IP" ]]; then
  echo "❌ Could not determine local IP. Check interface name in the script."
  exit 1
fi

# === CHECK FOLDER EXISTS ===
if [ ! -d "$SERVE_DIR" ]; then
  echo "❌ Error: '$SERVE_DIR' folder not found."
  exit 1
fi

cd "$SERVE_DIR"

# === SHOW URL & QR CODE ===
URL="http://$LOCAL_IP:$PORT"
echo "🌐 Serving files at: $URL"
echo ""

if command -v qrencode > /dev/null; then
  echo "📱 Scan this QR code to access from another device:"
  qrencode -t ansiutf8 "$URL"
else
  echo "⚠️ qrencode not found. Install it with: sudo apt install qrencode"
fi

# === START SERVER WITH AUTO-EXPIRATION ===
echo ""
echo "⏳ This server will automatically stop in $EXPIRE_MINUTES minute(s)..."
echo "🚀 Press Ctrl+C to stop the server when done."

# Start the server in the background
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

# Sleep for configured time then stop the server
sleep "${EXPIRE_MINUTES}m"
kill "$SERVER_PID" 2>/dev/null

echo "🛑 Server stopped after $EXPIRE_MINUTES minute(s)."
