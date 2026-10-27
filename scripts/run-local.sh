#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
coolvibes_host="${COOLVIBES_DEV_HOST:-}"
if [[ -z "$coolvibes_host" ]]; then
  coolvibes_interface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}' || true)"
  if [[ -n "$coolvibes_interface" ]]; then
    coolvibes_host="$(ipconfig getifaddr "$coolvibes_interface" 2>/dev/null || true)"
  fi
  # A VPN can own the default route while the local server remains on Wi-Fi.
  for coolvibes_candidate in en0 en1; do
    if [[ -z "$coolvibes_host" ]]; then
      coolvibes_host="$(ipconfig getifaddr "$coolvibes_candidate" 2>/dev/null || true)"
    fi
  done
fi
if [[ -z "$coolvibes_host" ]]; then
  echo 'Yerel IP bulunamadı. COOLVIBES_DEV_HOST=192.168.x.x ./scripts/run-local.sh -d DEVICE kullan.' >&2
  exit 1
fi
# HTTP and Socket.IO derive from the same host; no device uses its own localhost.
exec flutter run "--dart-define=DEV_HOST=$coolvibes_host" "$@"
