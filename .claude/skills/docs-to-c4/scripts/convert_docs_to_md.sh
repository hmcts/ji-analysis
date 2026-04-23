#!/usr/bin/env bash
# Convert binary documents (.docx, .pdf, .xlsx) to Markdown.
# Creates/reuses a venv, installs dependencies, then runs the Python script.
#
# Usage:
#   ./scripts/convert_docs_to_md.sh <input_folder> <output_folder> [--skip-existing]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_DIR="${SCRIPT_DIR}/python"
VENV_DIR="${SCRIPT_DIR}/python/.venv"
REQUIREMENTS="${PYTHON_DIR}/requirements.txt"
PYTHON_SCRIPT="${PYTHON_DIR}/convert_docs_to_md.py"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input_folder> <output_folder> [--skip-existing]" >&2
    exit 1
fi

# Create venv if it doesn't exist
if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Creating virtual environment at ${VENV_DIR}..." >&2
    python3 -m venv "${VENV_DIR}"
fi

# Install/update requirements if needed
MARKER="${VENV_DIR}/.requirements_installed"
if [[ ! -f "${MARKER}" ]] || [[ "${REQUIREMENTS}" -nt "${MARKER}" ]]; then
    echo "Installing dependencies..." >&2
    "${VENV_DIR}/bin/pip" install --quiet --upgrade pip
    "${VENV_DIR}/bin/pip" install --quiet -r "${REQUIREMENTS}"
    touch "${MARKER}"
fi

# Run the conversion
"${VENV_DIR}/bin/python" "${PYTHON_SCRIPT}" "$@"
