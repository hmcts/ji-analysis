#!/usr/bin/env bash
# scan-codebase.sh — deterministic codebase inventory for the
# check-for-owasp-top10 skill.
#
# Usage:
#   scan-codebase.sh <input-folder> [output-folder]
#
# Outputs (in <output-folder>, default <input-folder>/security/owasp/scan/):
#   inventory.txt          — relative paths of every code-eligible file scanned
#   inventory-counts.txt   — file count per top-level directory + per extension
#   fingerprint-hits.txt   — grep hits for agentic-app fingerprints (frameworks,
#                            vector stores, RCE-surface patterns, peer-agent
#                            protocols). Each hit is path:line:matched-text.
#   loc.txt                — total lines of code across scanned files
#
# Behaviour:
#   - Excludes: .git/, node_modules/, .venv/, venv/, dist/, build/, target/,
#               .next/, .nuxt/, .pytest_cache/, __pycache__/, .mypy_cache/,
#               .ruff_cache/, *.min.js, *.min.css, *.lock binary blobs (lockfiles
#               are kept — they're load-bearing for ASI04).
#   - Includes: source files in common languages plus dependency manifests.
#   - Output is sorted, line-oriented and stable across runs (no timestamps).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <input-folder> [output-folder]" >&2
  exit 2
fi

input_dir="$1"
output_dir="${2:-${input_dir%/}/security/owasp/scan}"

if [[ ! -d "${input_dir}" ]]; then
  echo "error: input folder not found: ${input_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}"

# Common excluded directories. We use -path patterns rather than -name so that
# nested matches are also excluded.
exclude=(
  -not -path '*/.git/*'
  -not -path '*/node_modules/*'
  -not -path '*/.venv/*'
  -not -path '*/venv/*'
  -not -path '*/.tox/*'
  -not -path '*/dist/*'
  -not -path '*/build/*'
  -not -path '*/target/*'
  -not -path '*/.next/*'
  -not -path '*/.nuxt/*'
  -not -path '*/.pytest_cache/*'
  -not -path '*/__pycache__/*'
  -not -path '*/.mypy_cache/*'
  -not -path '*/.ruff_cache/*'
  -not -path '*/.cache/*'
  -not -path '*/coverage/*'
  -not -path '*/.idea/*'
  -not -path '*/.vscode/*'
  -not -name '*.min.js'
  -not -name '*.min.css'
  -not -name '*.map'
  -not -name '.DS_Store'
)

# Code-eligible extensions plus dependency manifests we always want to read.
include=(
  -name '*.py' -o
  -name '*.js' -o
  -name '*.mjs' -o
  -name '*.cjs' -o
  -name '*.ts' -o
  -name '*.tsx' -o
  -name '*.jsx' -o
  -name '*.go' -o
  -name '*.rs' -o
  -name '*.java' -o
  -name '*.kt' -o
  -name '*.kts' -o
  -name '*.scala' -o
  -name '*.rb' -o
  -name '*.php' -o
  -name '*.cs' -o
  -name '*.swift' -o
  -name '*.sh' -o
  -name '*.bash' -o
  -name '*.zsh' -o
  -name '*.toml' -o
  -name '*.yaml' -o
  -name '*.yml' -o
  -name '*.json' -o
  -name 'Dockerfile' -o
  -name 'Makefile' -o
  -name 'requirements.txt' -o
  -name 'requirements-*.txt' -o
  -name 'Pipfile' -o
  -name 'Pipfile.lock' -o
  -name 'pyproject.toml' -o
  -name 'poetry.lock' -o
  -name 'uv.lock' -o
  -name 'package.json' -o
  -name 'package-lock.json' -o
  -name 'pnpm-lock.yaml' -o
  -name 'yarn.lock' -o
  -name 'go.mod' -o
  -name 'go.sum' -o
  -name 'Cargo.toml' -o
  -name 'Cargo.lock' -o
  -name 'pom.xml' -o
  -name 'build.gradle' -o
  -name 'build.gradle.kts' -o
  -name 'Gemfile' -o
  -name 'Gemfile.lock'
)

# 1. inventory.txt — all eligible files, relative to input_dir, sorted.
(cd "${input_dir}" && \
  find . -type f "${exclude[@]}" \( "${include[@]}" \) \
    | sed 's|^\./||' \
    | LC_ALL=C sort) > "${output_dir}/inventory.txt"

file_count=$(wc -l < "${output_dir}/inventory.txt" | tr -d ' ')

# 2. inventory-counts.txt — per top-level dir + per extension counts.
{
  echo "# File counts by top-level directory"
  awk -F/ 'NF==1 {top="(root)"} NF>1 {top=$1} {print top}' "${output_dir}/inventory.txt" \
    | LC_ALL=C sort | uniq -c | LC_ALL=C sort -rn
  echo
  echo "# File counts by extension"
  awk -F. '{
    if (NF==1) { print "(no-ext)" }
    else { print $NF }
  }' "${output_dir}/inventory.txt" \
    | LC_ALL=C sort | uniq -c | LC_ALL=C sort -rn
  echo
  echo "Total scanned files: ${file_count}"
} > "${output_dir}/inventory-counts.txt"

# 3. loc.txt — total LOC across scanned files (rough — counts every line).
if [[ "${file_count}" -gt 0 ]]; then
  loc=$(cd "${input_dir}" && xargs wc -l < "${output_dir}/inventory.txt" 2>/dev/null \
    | awk '/total$/ {print $1; exit}')
  loc="${loc:-0}"
else
  loc=0
fi
echo "${loc}" > "${output_dir}/loc.txt"

# 4. fingerprint-hits.txt — agentic-app fingerprint patterns.
# We use ripgrep if available (much faster) and fall back to grep -rn otherwise.
patterns_file=$(mktemp)
cat > "${patterns_file}" <<'EOF'
# Anthropic / Claude
from anthropic
import anthropic
claude_agent_sdk
Claude\(
tool_choice
# OpenAI agents / assistants
openai\.beta\.assistants
openai\.beta\.threads
Runs\.create
tool_resources
Assistant\(
# LangChain / LangGraph
from langchain
from langgraph
AgentExecutor
ChatPromptTemplate
StructuredTool
# LlamaIndex
from llama_index
QueryEngine
AgentRunner
# AutoGen
from autogen
GroupChat
ConversableAgent
# CrewAI
from crewai
Crew\(
# MCP
mcp\.server
mcp\.client
ServerCapabilities
@mcp\.tool
@server\.tool
modelcontextprotocol
# A2A
agent2agent
well-known/agent\.json
\.well-known/agent
# Vector / memory stores
chromadb
import chromadb
pinecone
weaviate
qdrant
pgvector
faiss
# RCE-surface patterns
\beval\(
\bexec\(
subprocess\.run\(.*shell=True
subprocess\.Popen\(.*shell=True
os\.system\(
shell=True
pickle\.loads
pickle\.load
yaml\.load\(
\.unsafeLoad
new Function\(
# Auto-install / dynamic dependency fetch
pip install
npm install
yarn add
# Confirmation patterns (affirmative)
human_input
require_confirmation
dry_run
require_approval
confirm=
EOF

if command -v rg >/dev/null 2>&1; then
  (cd "${input_dir}" && \
    rg --line-number --no-heading --no-messages \
       --hidden \
       --glob '!.git' --glob '!node_modules' --glob '!.venv' \
       --glob '!venv' --glob '!dist' --glob '!build' --glob '!target' \
       --glob '!__pycache__' --glob '!*.min.js' --glob '!*.min.css' \
       -f "${patterns_file}" \
       2>/dev/null \
    | LC_ALL=C sort) > "${output_dir}/fingerprint-hits.txt" || true
else
  # Fallback: grep -rn with the same exclude list.
  (cd "${input_dir}" && \
    grep -rn -E -f "${patterns_file}" \
      --exclude-dir=.git --exclude-dir=node_modules \
      --exclude-dir=.venv --exclude-dir=venv \
      --exclude-dir=dist --exclude-dir=build --exclude-dir=target \
      --exclude-dir=__pycache__ \
      --exclude='*.min.js' --exclude='*.min.css' \
      . 2>/dev/null \
    | sed 's|^\./||' \
    | LC_ALL=C sort) > "${output_dir}/fingerprint-hits.txt" || true
fi
rm -f "${patterns_file}"

hits=$(wc -l < "${output_dir}/fingerprint-hits.txt" | tr -d ' ')

# Final report to stdout.
echo "Scanned: ${file_count} files, ${loc} lines"
echo "Fingerprint hits: ${hits}"
echo "Outputs:"
echo "  ${output_dir}/inventory.txt"
echo "  ${output_dir}/inventory-counts.txt"
echo "  ${output_dir}/loc.txt"
echo "  ${output_dir}/fingerprint-hits.txt"
