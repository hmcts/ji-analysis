#!/usr/bin/env bash
# Build static HTML view of the RAM Pathfinder planning artefacts.
# Reads _bmad-output/planning-artifacts/ and writes html/ at the repo root.
# Requirements: pandoc on PATH; Python 3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 "${SCRIPT_DIR}/python/build_html.py" "$@"
