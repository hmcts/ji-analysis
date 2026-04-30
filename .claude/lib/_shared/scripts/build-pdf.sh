#!/usr/bin/env bash
# build-pdf.sh — convert a Markdown file (with optional Mermaid blocks) to PDF.
#
# Usage:
#   build-pdf.sh <input.md> [output.pdf]
#
# Mermaid fenced blocks (```mermaid``` ... ```) are pre-rendered to PNG via
# mmdc and the rendered images embedded before pandoc runs the final
# Markdown -> HTML -> PDF (weasyprint) conversion.
#
# This wrapper bootstraps a Python virtual environment under
# scripts/python/.venv/ on first run (and refreshes it whenever
# scripts/python/requirements.txt is updated), then prepends the venv's
# bin directory to PATH so pandoc finds the venv-installed weasyprint
# binary, and finally execs the Python builder.
#
# External tools required on PATH (not managed by the venv):
#   - python3  (3.10+ for type-hint syntax in md_to_pdf.py)
#   - pandoc
#   - mmdc     (npm install -g @mermaid-js/mermaid-cli)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_DIR="${SCRIPT_DIR}/python"
VENV="${PYTHON_DIR}/.venv"
REQUIREMENTS="${PYTHON_DIR}/requirements.txt"
MARKER="${VENV}/.requirements.installed"

# (Re)bootstrap the venv when missing, or when requirements.txt is newer
# than the install marker.
if [[ ! -d "${VENV}" || "${REQUIREMENTS}" -nt "${MARKER}" ]]; then
  if [[ ! -d "${VENV}" ]]; then
    echo "Creating virtual environment at ${VENV}..." >&2
    python3 -m venv "${VENV}"
  fi
  "${VENV}/bin/pip" install --quiet --upgrade pip
  "${VENV}/bin/pip" install --quiet -r "${REQUIREMENTS}"
  touch "${MARKER}"
fi

# Prepend the venv's bin to PATH so pandoc finds the venv's weasyprint.
export PATH="${VENV}/bin:${PATH}"

exec "${VENV}/bin/python" "${PYTHON_DIR}/md_to_pdf.py" "$@"
