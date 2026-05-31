#!/usr/bin/env bash
# distil-binary-data.sh — extract plain text from a folder of binary documents.
#
# Usage:
#   distil-binary-data.sh <input-folder> [output-folder]
#
# Behaviour:
#   - Iterates only the *top level* of <input-folder> (does NOT descend into
#     subfolders — this matches the "do not go into subfolders" instruction
#     that applies to source document folders).
#   - For each supported file, writes a UTF-8 .txt extraction to
#     <output-folder> (default: <input-folder>/output/extracted-text/ — keeps
#     tooling output alongside the input data, never inside the running
#     project).
#   - Skips macOS .DS_Store and dotfiles.
#
# Tool selection (in order of preference, per file type):
#   .docx                  → pandoc (always present in this skill's environment)
#   .pptx                  → pandoc (built-in pptx reader; renders speaker text + bullets as plain text)
#   .doc                   → textutil (macOS) — handles legacy Word binary
#   .pdf                   → pdftotext (poppler) — falls back to skip if missing
#   .md, .markdown, .txt   → cat (passthrough copy)
#   anything else          → skipped with a warning
#
# Why text and not bmad-distillator directly?
#   The skill's analysis phase reads these .txt files instead of the binaries
#   so that (a) Claude does not load the binaries into context, and (b) the
#   distillation step is deterministic and inspectable. If bmad-distillator is
#   available locally and produces richer markdown, it can be used in addition
#   to or in place of this script — the SKILL.md describes the policy.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <input-folder> [output-folder]" >&2
  exit 2
fi

input_dir="$1"
output_dir="${2:-${input_dir%/}/output/extracted-text}"

if [[ ! -d "${input_dir}" ]]; then
  echo "error: input folder not found: ${input_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}"

extracted=0
skipped=0

# Top-level files only (-maxdepth 1).
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  case "${base}" in
    .* ) continue ;;  # skip dotfiles incl. .DS_Store
  esac
  stem="${base%.*}"
  ext="${base##*.}"
  ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  out="${output_dir}/${stem}.txt"

  case "${ext_lc}" in
    docx)
      if command -v pandoc >/dev/null 2>&1; then
        pandoc "$f" -t plain --wrap=none -o "$out"
        printf 'OK   %-12s  %s\n' "[docx]" "${base}"
        extracted=$((extracted + 1))
      else
        printf 'SKIP %-12s  %s (pandoc not found)\n' "[docx]" "${base}" >&2
        skipped=$((skipped + 1))
      fi
      ;;
    pptx)
      if command -v pandoc >/dev/null 2>&1; then
        pandoc -f pptx -t plain --wrap=none "$f" -o "$out"
        printf 'OK   %-12s  %s\n' "[pptx]" "${base}"
        extracted=$((extracted + 1))
      else
        printf 'SKIP %-12s  %s (pandoc not found)\n' "[pptx]" "${base}" >&2
        skipped=$((skipped + 1))
      fi
      ;;
    doc)
      if command -v textutil >/dev/null 2>&1; then
        textutil -convert txt -output "$out" "$f" >/dev/null
        printf 'OK   %-12s  %s\n' "[doc]" "${base}"
        extracted=$((extracted + 1))
      else
        printf 'SKIP %-12s  %s (textutil not found; macOS only)\n' "[doc]" "${base}" >&2
        skipped=$((skipped + 1))
      fi
      ;;
    pdf)
      if command -v pdftotext >/dev/null 2>&1; then
        pdftotext -layout "$f" "$out"
        printf 'OK   %-12s  %s\n' "[pdf]" "${base}"
        extracted=$((extracted + 1))
      else
        printf 'SKIP %-12s  %s (pdftotext not found)\n' "[pdf]" "${base}" >&2
        skipped=$((skipped + 1))
      fi
      ;;
    md|markdown|txt)
      cp "$f" "$out"
      printf 'OK   %-12s  %s\n' "[passthru]" "${base}"
      extracted=$((extracted + 1))
      ;;
    *)
      printf 'SKIP %-12s  %s (unsupported type)\n' "[${ext_lc}]" "${base}" >&2
      skipped=$((skipped + 1))
      ;;
  esac
done < <(find "${input_dir}" -maxdepth 1 -type f -print0 | sort -z)

echo
echo "Distilled: ${extracted} extracted, ${skipped} skipped → ${output_dir}"
