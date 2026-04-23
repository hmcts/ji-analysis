#!/usr/bin/env bash
# Verify prerequisites for the docs-to-c4 skill.
# Exits 0 on success, 1 on missing/invalid Java, 2 on missing structurizr-site-generatr.
# Designed to be run from any directory.
set -euo pipefail

fail() {
  echo "ERROR: $1" >&2
  exit "${2:-1}"
}

# --- Java 17+ ---
if ! command -v java >/dev/null 2>&1; then
  fail "java not found on PATH. Install Java 17+ (macOS: 'brew install openjdk@17'; or https://adoptium.net/)." 1
fi

# `java -version` writes to stderr. Parse the first line.
JAVA_RAW=$(java -version 2>&1 | head -n1)
# Extract the major version. Handles both '1.8.0_xxx' and '17.0.x' / '21.0.x' formats.
JAVA_MAJOR=$(echo "$JAVA_RAW" | sed -E 's/.*version "([^"]+)".*/\1/' | awk -F. '{ if ($1 == "1") print $2; else print $1 }')

if ! [[ "$JAVA_MAJOR" =~ ^[0-9]+$ ]]; then
  fail "Could not parse Java version from: $JAVA_RAW" 1
fi

if [ "$JAVA_MAJOR" -lt 17 ]; then
  fail "Java $JAVA_MAJOR found, but 17+ is required. Upgrade with 'brew install openjdk@17' or install from adoptium.net." 1
fi

# --- Python 3 (for convert_docs_to_md) ---
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found on PATH. Install Python 3.10+ (macOS: 'brew install python@3')." 3
fi

# --- bmad-distillator skill ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$(dirname "$SKILL_DIR")")"

BMAD_FOUND=0
# Check common locations for the bmad-distillator skill
for candidate in \
  "$PROJECT_DIR/bmad-distillator/SKILL.md" \
  "$PROJECT_DIR/skills/bmad-distillator/SKILL.md" \
  "$HOME/.claude/skills/bmad-distillator/SKILL.md"; do
  if [ -f "$candidate" ]; then
    BMAD_FOUND=1
    BMAD_PATH="$(dirname "$candidate")"
    break
  fi
done

if [ "$BMAD_FOUND" -eq 0 ]; then
  cat >&2 <<EOF
ERROR: bmad-distillator skill not found.

This skill depends on bmad-distillator for document compression.
Install the BMAD skill bundle, or ensure bmad-distillator/SKILL.md
exists alongside this skill or in ~/.claude/skills/.
EOF
  exit 4
fi

# --- structurizr-site-generatr ---
if ! command -v structurizr-site-generatr >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: structurizr-site-generatr not found on PATH.

Install (macOS, recommended):
  brew tap avisi-cloud/tools
  brew install structurizr-site-generatr

Or download a release tarball from:
  https://github.com/avisi-cloud/structurizr-site-generatr/releases
EOF
  exit 2
fi

echo "OK — prerequisites satisfied."
echo "  java: $JAVA_RAW"
echo "  python3: $(python3 --version 2>&1)"
echo "  structurizr-site-generatr: $(command -v structurizr-site-generatr)"
echo "  bmad-distillator: $BMAD_PATH"
