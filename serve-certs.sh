#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SERVE_ROOT=${OUT_DIR:-$SCRIPT_DIR/certs_output}
PORT=${PORT:-8080}
EXPIRE_SECONDS=${EXPIRE_SECONDS:-${EXPIRE_MINUTES:-5}m}
SHARE_TMP_PARENT=${SHARE_TMP_PARENT:-${TMPDIR:-/tmp}}
server_pid=
share_dir=

usage() {
  cat <<'EOF'
Usage: ./serve-certs.sh [PATH_TO_BUNDLE.zip]

Temporarily share one certificate ZIP over the LAN. If no path is supplied,
the newest *-certs.zip under certs_output is selected. The temporary directory
and HTTP process are always cleaned up on exit.

Environment: PORT=8080, EXPIRE_MINUTES=5 (or EXPIRE_SECONDS), SHARE_IP=x.x.x.x
EOF
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n $server_pid ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ -n $share_dir ]]; then
    rm -rf -- "$share_dir"
    if [[ -e $share_dir ]]; then
      echo "❌ Failed to remove temporary share directory: $share_dir" >&2
      status=1
    else
      echo "🧹 Temporary share removed: $share_dir"
    fi
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

if [[ -n ${1:-} ]]; then
  bundle=$1
else
  bundle=$(find "$SERVE_ROOT" -type f -name '*-certs.zip' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | head -n1 | cut -d' ' -f2-)
fi

if [[ -z ${bundle:-} || ! -f $bundle ]]; then
  echo "❌ No certificate bundle found. Pass the path to a *-certs.zip file." >&2
  exit 1
fi
case $(basename -- "$bundle") in
  *-certs.zip) ;;
  *)
    echo "❌ Refusing to share a file that is not a *-certs.zip bundle: $bundle" >&2
    exit 1
    ;;
esac

if [[ -n ${SHARE_IP:-} ]]; then
  local_ip=$SHARE_IP
else
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z $local_ip ]] && command -v ip >/dev/null 2>&1; then
    local_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')
  fi
fi
if [[ -z ${local_ip:-} ]]; then
  echo "❌ Could not determine a LAN IP. Set SHARE_IP explicitly." >&2
  exit 1
fi

mkdir -p "$SHARE_TMP_PARENT"
share_dir=$(mktemp -d "$SHARE_TMP_PARENT/mtls-share.XXXXXX")
cp -- "$bundle" "$share_dir/"
shared_name=$(basename -- "$bundle")
url="http://$local_ip:$PORT/$shared_name"

echo "🌐 Temporarily serving one file: $shared_name"
echo "🌐 URL: $url"
if command -v qrencode >/dev/null 2>&1; then
  qrencode -t ansiutf8 "$url"
else
  echo "ℹ️ qrencode not found; use the URL above."
fi

python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$share_dir" >/dev/null 2>&1 &
server_pid=$!
sleep 0.2
if ! kill -0 "$server_pid" 2>/dev/null; then
  wait "$server_pid" || true
  echo "❌ HTTP server failed to start (is port $PORT already in use?)." >&2
  exit 1
fi

echo "⏳ The share will stop after $EXPIRE_SECONDS. Press Ctrl+C to stop earlier."
sleep "$EXPIRE_SECONDS"
echo "🛑 Share expired."
