#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-$HOME/Downloads}"
PORT="${2:-8085}"
BIND="${3:-0.0.0.0}"
echo "Serving: $DIR"
echo "Address: http://$BIND:$PORT/"
echo "SECURITY: restrict TCP $PORT at your firewall to trusted source IPs."
exec python3 -m http.server "$PORT" --bind "$BIND" --directory "$DIR"
