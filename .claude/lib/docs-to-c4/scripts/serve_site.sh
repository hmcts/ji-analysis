#!/usr/bin/env bash
# Start structurizr-site-generatr in live-preview mode.
# Serves on http://localhost:<port>; defaults to 8080 but auto-picks 8081-8090
# if 8080 is busy. Pass an explicit port as the second arg to override.
#
# Usage: serve_site.sh <workspace.dsl> [port]
# Example: serve_site.sh /path/to/docs/output/workspace.dsl
set -euo pipefail

WORKSPACE="${1:-}"
PORT="${2:-}"

if [ -z "$WORKSPACE" ]; then
  echo "Usage: $0 <workspace.dsl> [port]" >&2
  exit 64
fi
if [ ! -f "$WORKSPACE" ]; then
  echo "ERROR: workspace file not found: $WORKSPACE" >&2
  exit 66
fi

WORKSPACE_ABS=$(cd "$(dirname "$WORKSPACE")" && pwd)/$(basename "$WORKSPACE")

port_free() {
  ! lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

if [ -z "$PORT" ]; then
  for candidate in 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089 8090; do
    if port_free "$candidate"; then
      PORT="$candidate"
      break
    fi
  done
  if [ -z "$PORT" ]; then
    echo "ERROR: ports 8080-8090 are all in use. Pass an explicit port: $0 <workspace.dsl> <port>" >&2
    exit 1
  fi
fi

echo "Serving $WORKSPACE_ABS"
echo "  URL: http://localhost:$PORT"
echo "  Ctrl+C to stop."

exec structurizr-site-generatr serve \
  --workspace-file "$WORKSPACE_ABS" \
  --port "$PORT"
