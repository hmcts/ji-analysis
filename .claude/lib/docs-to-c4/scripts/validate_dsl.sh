#!/usr/bin/env bash
# Dry-run site generation to validate a Structurizr DSL workspace file.
# Produces no output files — only succeeds if the DSL parses and the model is valid.
#
# Usage: validate_dsl.sh <workspace.dsl>
# Example: validate_dsl.sh /path/to/docs/output/workspace.dsl
set -euo pipefail

WORKSPACE="${1:-}"
if [ -z "$WORKSPACE" ]; then
  echo "Usage: $0 <workspace.dsl>" >&2
  exit 64
fi
if [ ! -f "$WORKSPACE" ]; then
  echo "ERROR: workspace file not found: $WORKSPACE" >&2
  exit 66
fi

# Resolve to absolute path so --workspace-file works regardless of cwd.
WORKSPACE_ABS=$(cd "$(dirname "$WORKSPACE")" && pwd)/$(basename "$WORKSPACE")

# Use a user-local scratch dir (never /tmp or /var/folders).
SCRATCH_ROOT="${TMPDIR:-$HOME/.cache}/docs-to-c4"
SCRATCH=$(mktemp -d "$SCRATCH_ROOT.XXXXXX" 2>/dev/null || { mkdir -p "$SCRATCH_ROOT" && mktemp -d "$SCRATCH_ROOT/validate.XXXXXX"; })
trap 'rm -rf "$SCRATCH"' EXIT

echo "Validating $WORKSPACE_ABS via dry-run generate-site..."
if ! structurizr-site-generatr generate-site \
      --workspace-file "$WORKSPACE_ABS" \
      --output-dir "$SCRATCH" >"$SCRATCH/generatr.log" 2>&1; then
  echo "ERROR: DSL validation failed. Generator output:" >&2
  cat "$SCRATCH/generatr.log" >&2
  exit 1
fi

echo "OK — DSL validates."
