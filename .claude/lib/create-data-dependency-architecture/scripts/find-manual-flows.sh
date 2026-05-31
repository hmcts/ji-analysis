#!/usr/bin/env bash
#
# find-manual-flows.sh — Phase 2 discovery floor for the
# create-data-dependency-architecture skill.
#
# Scans every .txt file under <input-folder>/output/extracted-text/ for a fixed
# list of manual-flow phrases and writes <input-folder>/output/manual-flow-candidates.txt
# with one line per match, sorted by filename then line number, so the file is
# byte-stable across re-runs against the same extracted text.
#
# The phrase list below is the SINGLE source of truth for "what counts as a
# manual-copy signal". Adding a phrase is a one-line edit; the spec
# (data-dependency-discovery) requires at least the 23 phrases shipped here.
#
# Usage:
#   find-manual-flows.sh <input-folder>
#
# Exits non-zero if <input-folder>/output/extracted-text/ does not exist or
# contains no .txt files.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") <input-folder>" >&2
    exit 2
fi

INPUT_FOLDER="$1"
EXTRACTED_DIR="$INPUT_FOLDER/output/extracted-text"
OUTPUT_FILE="$INPUT_FOLDER/output/manual-flow-candidates.txt"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "error: extracted-text folder not found at $EXTRACTED_DIR" >&2
    echo "       run scripts/distil-binary-data.sh <input-folder> first" >&2
    exit 3
fi

# Canonical phrase list — single source of truth.
# 23 phrases matching the data-dependency-discovery spec.
PHRASES=(
    "copies from"
    "copy and paste"
    "copy/paste"
    "manually enter"
    "manually entered"
    "manually copied"
    "rekey"
    "re-keys"
    "rekeyed"
    "transcribe"
    "transcribed"
    "look up in"
    "looks up in"
    "look up from"
    "is entered by"
    "data is entered"
    "obtained from"
    "populated from"
    "populated by"
    "sourced from"
    "no integration"
    "no automated integration"
    "out-of-band"
)

# Collect .txt files at the top of extracted-text (top-level only, matching the
# rest of the skill's no-subfolder rule). Empty-glob safe.
shopt -s nullglob
TXT_FILES=("$EXTRACTED_DIR"/*.txt)
shopt -u nullglob

if [ "${#TXT_FILES[@]}" -eq 0 ]; then
    echo "error: no .txt files found in $EXTRACTED_DIR" >&2
    exit 4
fi

# Run the scan. grep -nFi gives us:
#   -n : line numbers
#   -F : fixed strings (so phrases with /, -, etc. don't need escaping)
#   -i : case-insensitive
#   -H : always print the filename (even with a single file argument)
# We strip the leading directory from filenames so the output is portable
# across machines: it shows the .txt basename, the line number, the matching
# line — never an absolute path.
TMP_OUTPUT="$INPUT_FOLDER/output/.manual-flow-candidates.tmp"
: > "$TMP_OUTPUT"

for phrase in "${PHRASES[@]}"; do
    # Use grep || true so a phrase with no matches doesn't kill the script
    # under set -e.
    grep -nFiH "$phrase" "${TXT_FILES[@]}" >> "$TMP_OUTPUT" 2>/dev/null || true
done

# Strip the directory prefix so output shows only the .txt basename.
# Then dedupe (a single line may match more than one phrase) and sort by
# filename then line number for byte-stable output.
sed "s|^${EXTRACTED_DIR%/}/||" "$TMP_OUTPUT" \
    | awk -F: '!seen[$1":"$2]++' \
    | sort -t: -k1,1 -k2,2n \
    > "$OUTPUT_FILE"

rm -f "$TMP_OUTPUT"

MATCH_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d '[:space:]')
echo "wrote $OUTPUT_FILE ($MATCH_COUNT candidate lines)"
