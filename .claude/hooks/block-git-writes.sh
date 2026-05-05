#!/usr/bin/env bash
# PreToolUse hook on Bash matcher.
# Reads {"tool_input":{"command":"..."}} on stdin and denies state-changing
# git/GitHub operations issued from Claude sessions. The user commits
# externally via VSCode after review (per CLAUDE.md).
#
# Blocked git subcommands (porcelain + plumbing that mutate state):
#   add, am, apply, bisect, branch, checkout, cherry-pick, clean, clone,
#   commit, commit-tree, fast-import, fetch, filter-branch, filter-repo,
#   gc, init, merge, mktag, mktree, mv, notes, pack-refs, prune, pull,
#   push, rebase, replace, reflog, remote, repack, reset, restore, revert,
#   rm, stash, submodule, switch, symbolic-ref, tag, update-index,
#   update-ref, worktree, write-tree
#
# Flag-aware (handled by dedicated branches, not the broad blocklist):
#   git config       Denied unless the invocation contains a read-only
#                    selector (--get / --get-all / --get-regexp /
#                    --get-urlmatch / --list / -l / --show-origin /
#                    --show-scope) AND no mutating flag (--unset[-all] /
#                    --add / --replace-all / --rename-section /
#                    --remove-section / --edit / -e). `git config` with no
#                    args (prints usage) is allowed.
#   git hash-object  Denied when -w is present in the invocation. Plain
#                    `git hash-object <file>` (computes hash only) is
#                    allowed.
#
# Blocked binaries: gh, hub (all subcommands).
#
# Allowed read-only git: status, log, diff, show, blame, ls-files, ls-tree,
# rev-parse, cat-file, for-each-ref, describe, name-rev, merge-base,
# version, help, var, count-objects, shortlog, grep, whatchanged, archive,
# bundle (and any other subcommand not in the blocklist).
#
# Fail-closed dependencies: jq, grep, sed must be on PATH. If any is
# missing, the hook emits a deny JSON via printf (a bash builtin) and
# exits 0 — so the deny path keeps working even when jq is the missing
# tool. If the flag normaliser cannot reduce a `git` invocation in
# <=10 passes, the hook denies rather than evaluate a pathological input.
#
# Source policy: CLAUDE.md ("DO NOT PERFORM ANY GITHUB OPERATIONS from
# within Claude sessions").

set -euo pipefail

deny_reason="Git/GitHub state-changing operations are blocked from Claude sessions per CLAUDE.md. User commits externally via VSCode after review. Allowed read-only: git status/log/diff/show/blame/ls-files, git config --get/--list, git hash-object (without -w)."

# Emit a deny JSON without invoking external tools (printf is a bash
# builtin) and exit 0. Keeps the deny path working even when the missing
# dependency is jq itself.
emit_deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# Pre-flight: verify required CLIs are on PATH; deny if any is missing.
for tool in jq grep sed; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    emit_deny "block-git-writes hook missing required tool: ${tool}. Refusing to allow command. See CLAUDE.md."
  fi
done

# Read the harness envelope and extract the candidate command string.
cmd=$(jq -r '.tool_input.command // ""')

# Strip "git <flag> <value>" prefix pairs and value-less git flags so the
# blocked-subcommand regex can anchor on "git[[:space:]]+<sub>". The
# value matcher accepts double-quoted strings, single-quoted strings, and
# bare tokens with backslash-escaped spaces — so `git -C "/p with sp" cmd`
# normalises correctly. Iterates to collapse multiple flag pairs; if it
# fails to converge within the cap, the caller treats the input as
# suspicious and denies.
normalize() {
  local s="$1"
  local prev=""
  local i=0
  while [ "$s" != "$prev" ] && [ "$i" -lt 10 ]; do
    prev="$s"
    # Pass 1: strip valued flags + their value (quoted / 'quoted' / bare).
    s=$(printf '%s' "$s" | sed -E 's/(^|[[:space:];&|`])git[[:space:]]+(-C|-c|--git-dir|--work-tree|--namespace|--super-prefix|--exec-path)[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|(\\[[:space:]]|[^[:space:]])+)/\1git/g')
    # Pass 2: strip value-less flags and joined-form (--name=value) flags.
    s=$(printf '%s' "$s" | sed -E 's/(^|[[:space:];&|`])git[[:space:]]+(--no-pager|--paginate|-P|--bare|--no-replace-objects|--literal-pathspecs|--no-literal-pathspecs|--no-optional-locks|--html-path|--man-path|--info-path|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--namespace=[^[:space:]]+|--super-prefix=[^[:space:]]+|--exec-path=[^[:space:]]+|--list-cmds=[^[:space:]]+|--config-env=[^[:space:]]+)/\1git/g')
    i=$((i + 1))
  done
  # If we hit the cap with progress still being made, the input is
  # pathological — signal the caller to fail closed.
  if [ "$s" != "$prev" ]; then
    return 1
  fi
  printf '%s' "$s"
}

if ! normalized=$(normalize "$cmd"); then
  emit_deny "could not normalise git flag prefix; refusing to evaluate. See CLAUDE.md."
fi

# Anchors and patterns. `config` and `hash-object` are excluded from the
# broad blocklist because they have read-vs-write flag splits handled
# below.
boundary='(^|[[:space:];&|`])'
gh_pattern="${boundary}[[:space:]]*(gh|hub)([[:space:]]|$)"
# `commit-tree` listed before `commit` defensively in case a regex engine
# returns leftmost-first instead of leftmost-longest.
blocked_subs='add|am|apply|bisect|branch|checkout|cherry-pick|clean|clone|commit-tree|commit|fast-import|fetch|filter-branch|filter-repo|gc|init|merge|mktag|mktree|mv|notes|pack-refs|prune|pull|push|rebase|replace|reflog|remote|repack|reset|restore|revert|rm|stash|submodule|switch|symbolic-ref|tag|update-index|update-ref|worktree|write-tree'
git_pattern="${boundary}[[:space:]]*git([[:space:]]+--?[^[:space:]]+(=[^[:space:]]+)?)*[[:space:]]+(${blocked_subs})([[:space:]]|$)"

# Match 1: deny `gh` and `hub` anywhere on the line.
if printf '%s' "$normalized" | grep -qE "$gh_pattern"; then
  emit_deny "$deny_reason"
fi

# Match 2: deny any of the broad blocklist subcommands.
if printf '%s' "$normalized" | grep -qE "$git_pattern"; then
  emit_deny "$deny_reason"
fi

# Match 3: `git config` — deny unless it has a read-only selector AND no
# mutating flag. Empty-args form (`git config` alone, prints usage) is
# allowed. Args are extracted up to the next shell separator so flags
# from sibling commands on the same line don't pollute the decision.
config_invocation_re='(^|[[:space:];&|`])git[[:space:]]+config([[:space:]]+[^;&|`]*)?'
if [[ "$normalized" =~ $config_invocation_re ]]; then
  config_args="${BASH_REMATCH[2]:-}"
  config_mutating_re='(^|[[:space:]])(--unset|--unset-all|--add|--replace-all|--rename-section|--remove-section|--edit|-e)([[:space:]=]|$)'
  config_selector_re='(^|[[:space:]])(--get|--get-all|--get-regexp|--get-urlmatch|--list|-l|--show-origin|--show-scope)([[:space:]=]|$)'
  if [[ "$config_args" =~ $config_mutating_re ]]; then
    emit_deny "$deny_reason"
  fi
  # Strip whitespace from config_args; if nothing left, it's `git config`
  # alone — allow. Otherwise require an explicit read-only selector.
  if [ -n "${config_args//[[:space:]]/}" ] && ! [[ "$config_args" =~ $config_selector_re ]]; then
    emit_deny "$deny_reason"
  fi
fi

# Match 4: `git hash-object` — deny only when -w is present.
hashobj_invocation_re='(^|[[:space:];&|`])git[[:space:]]+hash-object([[:space:]]+[^;&|`]*)?'
if [[ "$normalized" =~ $hashobj_invocation_re ]]; then
  hashobj_args="${BASH_REMATCH[2]:-}"
  hashobj_w_re='(^|[[:space:]])-w([[:space:]]|$)'
  if [[ "$hashobj_args" =~ $hashobj_w_re ]]; then
    emit_deny "$deny_reason"
  fi
fi

exit 0
