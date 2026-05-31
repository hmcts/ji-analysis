#!/usr/bin/env bash
#
# find-modules.sh — Phase 2a discovery floor for the
# create-functional-modules-architecture skill.
#
# Scans every .txt file under <input-folder>/output/extracted-text/ for a fixed
# list of module-introduction patterns and writes
# <input-folder>/output/module-candidates.txt with one line per match, sorted
# by filename then line number, so the file is byte-stable across re-runs
# against the same extracted text.
#
# The pattern list below is the SINGLE source of truth for "what counts as a
# module signal". Adding a pattern is a one-line edit.
#
# Usage:
#   find-modules.sh <input-folder>
#
# Exits non-zero if <input-folder>/output/extracted-text/ does not exist or
# contains no .txt files.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") <input-folder>" >&2
    exit 2
fi

INPUT_FOLDER="$1"
EXTRACTED_DIR="$INPUT_FOLDER/output-functional-modules/extracted-text"
OUTPUT_FILE="$INPUT_FOLDER/output-functional-modules/module-candidates.txt"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "error: extracted-text folder not found at $EXTRACTED_DIR" >&2
    echo "       run scripts/distil-binary-data.sh <input-folder> first" >&2
    exit 3
fi

# Canonical pattern list — single source of truth.
#
# Two flavours:
#   1. FIXED phrases (matched case-insensitively with grep -F): keywords that
#      reliably introduce a module in the source documents.
#   2. REGEXES (matched case-insensitively with grep -E): heading-like patterns
#      that catch numbered top-level headings and the requirements-table prefixes
#      used in HMCTS-style docs.
#
# False positives are cheap to dismiss in module-phase-2d-checks.md;
# missed modules are expensive (they're the failure mode this exists to prevent).

FIXED_PHRASES=(
    "Ribbon"
    "Module"
    "Sub-module"
    "Screen"
    "Capability"
    "Capabilities"
    "Major Capabilities"
    "Functional Area"
    "Functional Requirement"
    "Non-Functional Requirement"
    "User Group"
    "Domain"
    "Top-level tab"
    "Sub-menu"
    "Maintain"
    "Manage Judges"
    "Manage Users"
    "Court Itinerary"
    "Judge Itinerary"
    "Forward Look"
    "Absences"
    "Vacancies"
    "Bookings"
    "Fee-paid"
    "Payments"
    "Reconciliation"
    "Sittings"
    "Reports"
    "Admin"
    "Configure"
)

REGEXES=(
    # Numbered top-level headings: "1. Foo", "1.1 Foo", "4.2a Foo"
    '^[[:space:]]*[0-9]+(\.[0-9]+)?[a-z]?[[:space:]]+[A-Z]'
    # Requirements-table prefix: "MJ-FR-01", "HOME-NFR-05", "REC-FR-07", "VAC-NFR-02"
    '^[[:space:]]*[A-Z]{2,6}(-[A-Z]{2,4})?-(F|N)R-[0-9]+'
    # Section heading words used as module markers in HMCTS docs
    '^[[:space:]]*(Manage|View|Maintain|Report|Admin|Configure|Process)[[:space:]]+[A-Z]'
)

# Collect .txt files at the top of extracted-text (top-level only).
shopt -s nullglob
TXT_FILES=("$EXTRACTED_DIR"/*.txt)
shopt -u nullglob

if [ "${#TXT_FILES[@]}" -eq 0 ]; then
    echo "error: no .txt files found in $EXTRACTED_DIR" >&2
    exit 4
fi

TMP_OUTPUT="$INPUT_FOLDER/output-functional-modules/.module-candidates.tmp"
: > "$TMP_OUTPUT"

# Fixed-phrase pass: grep -nFiH for each phrase, append to tmp file.
for phrase in "${FIXED_PHRASES[@]}"; do
    grep -nFiH "$phrase" "${TXT_FILES[@]}" >> "$TMP_OUTPUT" 2>/dev/null || true
done

# Regex pass: grep -nEH for each pattern.
for re in "${REGEXES[@]}"; do
    grep -nEH "$re" "${TXT_FILES[@]}" >> "$TMP_OUTPUT" 2>/dev/null || true
done

# Strip directory prefix → portable output, dedupe by filename:line, sort.
sed "s|^${EXTRACTED_DIR%/}/||" "$TMP_OUTPUT" \
    | awk -F: '!seen[$1":"$2]++' \
    | sort -t: -k1,1 -k2,2n \
    > "$OUTPUT_FILE"

rm -f "$TMP_OUTPUT"

MATCH_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d '[:space:]')
echo "wrote $OUTPUT_FILE ($MATCH_COUNT candidate lines)"
