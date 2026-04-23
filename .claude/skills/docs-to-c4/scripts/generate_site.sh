#!/usr/bin/env bash
# Generate a static Structurizr site from a DSL workspace file.
#
# Usage: generate_site.sh <workspace.dsl> <output-dir>
# Example: generate_site.sh /path/to/docs/output/workspace.dsl /path/to/docs/output/site
set -euo pipefail

WORKSPACE="${1:-}"
OUTPUT="${2:-}"

if [ -z "$WORKSPACE" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: $0 <workspace.dsl> <output-dir>" >&2
  exit 64
fi
if [ ! -f "$WORKSPACE" ]; then
  echo "ERROR: workspace file not found: $WORKSPACE" >&2
  exit 66
fi

WORKSPACE_ABS=$(cd "$(dirname "$WORKSPACE")" && pwd)/$(basename "$WORKSPACE")
mkdir -p "$OUTPUT"
OUTPUT_ABS=$(cd "$OUTPUT" && pwd)

echo "Generating site..."
echo "  workspace: $WORKSPACE_ABS"
echo "  output:    $OUTPUT_ABS"

structurizr-site-generatr generate-site \
  --workspace-file "$WORKSPACE_ABS" \
  --output-dir "$OUTPUT_ABS"

echo "Site generated at: $OUTPUT_ABS"
echo "Open: $OUTPUT_ABS/master/index.html"
