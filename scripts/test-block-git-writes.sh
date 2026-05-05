#!/usr/bin/env bash
# Smoke test for block-git-writes.sh.
# Exercises every scenario in
# openspec/changes/harden-git-block-hook/specs/git-write-blocking-hook/spec.md.
#
# Run from anywhere; uses an absolute path to the hook under test.
#
# Each test feeds a tool-input JSON envelope on stdin and asserts:
#   - exit code  (always 0 — the hook never exits non-zero)
#   - stdout     ("deny" present or absent, depending on expectation)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/block-git-writes.sh"

if [ ! -x "$HOOK" ]; then
  printf 'FAIL: hook not found or not executable at %s\n' "$HOOK" >&2
  exit 1
fi

pass=0
fail=0
failures=()

# Run a single test case.
#   $1: descriptive name
#   $2: expected outcome — "deny" or "allow"
#   $3: command string to feed via tool_input
run_case() {
  local name="$1"
  local expect="$2"
  local cmd="$3"
  local input
  local output
  local rc
  input=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | jq -Rs .)")
  output=$(printf '%s' "$input" | "$HOOK" 2>&1) || rc=$? && rc=${rc:-0}
  if [ "$rc" -ne 0 ]; then
    fail=$((fail + 1))
    failures+=("$name: hook exited non-zero ($rc)")
    return
  fi
  case "$expect" in
    deny)
      if printf '%s' "$output" | grep -q '"permissionDecision":"deny"'; then
        pass=$((pass + 1))
      else
        fail=$((fail + 1))
        failures+=("$name: expected deny, got: $output")
      fi
      ;;
    allow)
      if printf '%s' "$output" | grep -q '"permissionDecision":"deny"'; then
        fail=$((fail + 1))
        failures+=("$name: expected allow, got deny: $output")
      else
        pass=$((pass + 1))
      fi
      ;;
    *)
      fail=$((fail + 1))
      failures+=("$name: bad expectation '$expect'")
      ;;
  esac
}

# --- Requirement 1: blocked porcelain / plumbing ---
run_case "porcelain commit"           deny  'git commit -m "x"'
run_case "porcelain push"             deny  'git push origin main'
run_case "porcelain pull"             deny  'git pull'
run_case "porcelain merge"            deny  'git merge feature-branch'
run_case "porcelain rebase"           deny  'git rebase main'
run_case "porcelain checkout"         deny  'git checkout main'
run_case "porcelain switch"           deny  'git switch main'
run_case "porcelain restore"          deny  'git restore file.txt'
run_case "porcelain add"              deny  'git add file.txt'
run_case "porcelain mv"               deny  'git mv a b'
run_case "porcelain rm"               deny  'git rm file.txt'
run_case "porcelain branch"           deny  'git branch -d old'
run_case "porcelain tag"              deny  'git tag v1.0'
run_case "porcelain reset"            deny  'git reset --hard HEAD~1'
run_case "porcelain revert"           deny  'git revert HEAD'
run_case "porcelain stash"            deny  'git stash'
run_case "porcelain cherry-pick"      deny  'git cherry-pick abc123'
run_case "porcelain clean"            deny  'git clean -fd'
run_case "porcelain apply"            deny  'git apply patch.diff'
run_case "porcelain am"               deny  'git am < patch.mbox'
run_case "porcelain init"             deny  'git init /tmp/newrepo'
run_case "porcelain clone"            deny  'git clone https://example/x.git'
run_case "porcelain fetch"            deny  'git fetch origin'
run_case "porcelain remote"           deny  'git remote add foo url'
run_case "porcelain notes"            deny  'git notes add'
run_case "porcelain worktree"         deny  'git worktree add ../wt'
run_case "porcelain submodule"        deny  'git submodule update'
run_case "porcelain bisect"           deny  'git bisect start'
run_case "porcelain reflog"           deny  'git reflog expire --all'
run_case "porcelain replace"          deny  'git replace abc def'
run_case "porcelain gc"               deny  'git gc'
run_case "porcelain prune"            deny  'git prune'
run_case "porcelain repack"           deny  'git repack'
run_case "porcelain filter-branch"    deny  'git filter-branch --tree-filter rm'
run_case "porcelain fast-import"      deny  'git fast-import'
run_case "plumbing update-ref"        deny  'git update-ref refs/heads/main HEAD~1'
run_case "plumbing update-index"      deny  'git update-index --add file'
run_case "plumbing commit-tree"       deny  'git commit-tree HEAD^{tree}'
run_case "plumbing write-tree"        deny  'git write-tree'
run_case "plumbing pack-refs"         deny  'git pack-refs --all'
run_case "plumbing symbolic-ref"      deny  'git symbolic-ref HEAD refs/heads/main'
run_case "plumbing mktag"             deny  'git mktag'
run_case "plumbing mktree"            deny  'git mktree'

# --- Requirement 1: flag prefix and shell-separator boundaries ---
run_case "flag prefix -C path"        deny  'git -C /tmp/repo --no-pager add file.txt'
run_case "shell sep && push"          deny  'cd /tmp/repo && git push origin main'
run_case "shell sep ; commit"         deny  'cd /tmp/repo ; git commit -m x'
run_case "shell sep | push"           deny  'echo hi | git push'

# --- Requirement 1: quoted/escaped flag values (the original bypass) ---
run_case "double-quoted -C with spaces"  deny  'git -C "/path with spaces" commit -m "msg"'
run_case "single-quoted --git-dir spaces" deny  "git --git-dir '/var/repos/dir with spaces/.git' push origin main"
run_case "backslash-escaped path"     deny  'git -C /path/with\ spaces commit'
run_case "plain -C path commit"       deny  'git -C /tmp/repo commit'
run_case "value-less --no-pager"      deny  'git --no-pager commit -m x'
run_case "joined --git-dir=value"     deny  'git --git-dir=/tmp/repo/.git push'

# --- Requirement 2: gh / hub ---
run_case "gh pr create"               deny  'gh pr create --title x'
run_case "gh repo view"               deny  'gh repo view'
run_case "hub fork"                   deny  'hub fork'

# --- Requirement 3: git config (write-by-default) ---
run_case "config set value"           deny  'git config user.email someone@example.com'
run_case "config positional only"     deny  'git config user.email'
run_case "config --get allowed"       allow 'git config --get user.email'
run_case "config --list allowed"      allow 'git config --list'
run_case "config --list --show-origin" allow 'git config --list --show-origin'
run_case "config -l allowed"          allow 'git config -l'
run_case "config --edit denied"       deny  'git config --get user.email --edit'
run_case "config --unset denied"      deny  'git config --unset user.email'
run_case "config --add denied"        deny  'git config --add core.x y'
run_case "config alone (usage)"       allow 'git config'

# --- Requirement 4: git hash-object ---
run_case "hash-object plain allowed"  allow 'git hash-object README.md'
run_case "hash-object -w denied"      deny  'git hash-object -w README.md'

# --- Requirement 5: missing-tool fail-closed ---
fail_closed_test() {
  local name="$1"
  local missing_tool="$2"
  local fake_path
  fake_path=$(mktemp -d)
  # Symlink only the tools that should be present (exclude the missing one).
  for t in jq grep sed; do
    if [ "$t" != "$missing_tool" ]; then
      local real
      real=$(command -v "$t" || true)
      if [ -n "$real" ]; then
        ln -s "$real" "$fake_path/$t"
      fi
    fi
  done
  # Include the system bash and basic utilities the script may need.
  for t in bash printf; do
    real=$(command -v "$t" || true)
    [ -n "$real" ] && ln -s "$real" "$fake_path/$t" 2>/dev/null || true
  done
  local output rc
  output=$(printf '{"tool_input":{"command":"git status"}}' | PATH="$fake_path" "$HOOK" 2>&1) || rc=$? && rc=${rc:-0}
  rm -rf "$fake_path"
  if [ "$rc" -ne 0 ]; then
    fail=$((fail + 1))
    failures+=("$name: hook exited non-zero ($rc)")
    return
  fi
  if printf '%s' "$output" | grep -q '"permissionDecision":"deny"' \
     && printf '%s' "$output" | grep -q "$missing_tool"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failures+=("$name: expected deny naming $missing_tool, got: $output")
  fi
}
fail_closed_test "missing-jq fail-closed"   jq
fail_closed_test "missing-grep fail-closed" grep
fail_closed_test "missing-sed fail-closed"  sed

# --- Requirement 6: read-only allow ---
run_case "git status allow"           allow 'git status'
run_case "git log allow"              allow 'git log --oneline -n 20'
run_case "git diff allow"             allow 'git diff HEAD~1'
run_case "git show allow"             allow 'git show HEAD'
run_case "git blame allow"            allow 'git blame README.md'
run_case "git ls-files allow"         allow 'git ls-files'
run_case "git rev-parse allow"        allow 'git rev-parse HEAD'
run_case "git cat-file allow"         allow 'git cat-file -p HEAD'
run_case "git for-each-ref allow"     allow 'git for-each-ref'
run_case "non-git command allow"      allow 'ls -la'
run_case "git mention in string"      allow 'echo "git commit was useful"'

# --- Pathological iteration cap (Requirement 1, convergence) ---
# Constructed input: many --git-dir= flags chained without spaces between
# them; each iteration of the normaliser strips one. With the cap at 10,
# 12 chained flags should fail to converge.
many_flags=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  many_flags+=" --git-dir=/tmp/x"
done
run_case "iteration cap exceeded"     deny  "git${many_flags} commit"

# --- Summary ---
total=$((pass + fail))
printf '\n--- Smoke test summary ---\n'
printf 'Passed: %d / %d\n' "$pass" "$total"
if [ "$fail" -gt 0 ]; then
  printf 'Failed: %d\n' "$fail"
  for f in "${failures[@]}"; do
    printf '  - %s\n' "$f"
  done
  exit 1
fi
exit 0
