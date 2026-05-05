## 1. Pre-flight tool check

- [x] 1.1 At the top of `.claude/hooks/block-git-writes.sh` (after `set -euo pipefail`), iterate over `jq grep sed` and use `command -v <tool> >/dev/null 2>&1` to verify each is available.
- [x] 1.2 If any required tool is missing, emit a single-line deny JSON via `printf` (not `jq`) whose `permissionDecisionReason` names the missing tool and references CLAUDE.md, then `exit 0`.
- [x] 1.3 Confirm the deny path uses no external binaries beyond `printf` (a bash builtin) so the script can fail-closed even when `jq` is the missing tool.

## 2. Expand and reorganise the blocklist

- [x] 2.1 Replace the current `blocked_subs` list with the full set from spec Requirement 1: `add|am|apply|bisect|branch|checkout|cherry-pick|clean|clone|commit|commit-tree|fast-import|fetch|filter-branch|filter-repo|gc|init|merge|mktag|mktree|mv|notes|pack-refs|prune|pull|push|rebase|replace|reflog|remote|repack|reset|restore|revert|rm|stash|submodule|switch|symbolic-ref|tag|update-index|update-ref|worktree|write-tree`.
- [x] 2.2 Keep `gh` and `hub` blocked exactly as today (no behaviour change for the GitHub CLI matchers).
- [x] 2.3 Update the `boundary` regex (or the assembled `git_pattern`) so subcommands like `cherry-pick`, `commit-tree`, `update-ref`, `update-index`, `write-tree`, `pack-refs`, `symbolic-ref`, `fast-import`, `filter-branch`, `filter-repo` (which contain hyphens) are matched literally and not treated as alternation operators.

## 3. Extend the flag normaliser

- [x] 3.1 Extend `normalize()` to also strip value-less boolean flags between `git` and the subcommand: `--no-pager`, `--paginate`, `-P`, `--bare`, `--no-replace-objects`, `--literal-pathspecs`, `--no-optional-locks`, `--list-cmds=*`, `--exec-path` (when used as `--exec-path` with no value), and `--html-path`/`--man-path`/`--info-path` (which are read-only by themselves but should be stripped to prevent shielding the next token).
- [x] 3.2 Keep the existing handling for valued flags `-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`, `--super-prefix`, `--exec-path` (when followed by a value).
- [x] 3.3 Replace the value matcher `[^[:space:]]+` with one that accepts a single shell-style argument: a double-quoted string `"[^"\\]*(\\.[^"\\]*)*"`, a single-quoted string `'[^']*'`, or a bare token allowing backslash-escaped spaces `(\\[[:space:]]|[^[:space:]])+`. Verify it works on BSD `sed` (macOS) as well as GNU `sed`, using only POSIX ERE features (no lookarounds, no `\d`).
- [x] 3.4 Test the new value matcher with: `git -C "/p with spaces" commit`, `git --git-dir '/var/d with spaces/.git' push`, `git -C /p/with\ spaces commit`, and the existing `git -C /tmp/repo commit` — all four must normalise to a string where the blocked subcommand is directly adjacent to `git` and gets denied.
- [x] 3.5 After the normalisation loop, check whether the iteration cap was reached without convergence (`prev != s` on the final pass). If so, emit a deny JSON with reason "could not normalise git flag prefix; refusing to evaluate" and `exit 0` instead of falling through to the matcher.
- [x] 3.6 Verify the iteration cap (currently 10) is high enough to collapse realistic flag combinations under the new matcher; raise to 16 if real-world combinations need it. Whatever the cap is, the convergence check from 3.5 owns the failure mode.

## 4. Flag-aware handling for `git config` and `git hash-object`

- [x] 4.1 Add a dedicated branch that detects `git config` after normalisation. Allow only when the command line contains one of `--get`, `--get-all`, `--get-regexp`, `--get-urlmatch`, `--list`, `-l`, `--show-origin`, `--show-scope` AND none of `--unset`, `--unset-all`, `--add`, `--replace-all`, `--rename-section`, `--remove-section`, `--edit`, `-e`. Otherwise emit a deny.
- [x] 4.2 Add a dedicated branch for `git hash-object`: deny when the invocation contains `-w` or `--stdin-paths` combined with `-w`; otherwise allow.
- [x] 4.3 Place the `config` and `hash-object` branches AFTER the broad blocklist match check is bypassed for those two specific subcommands (i.e. remove `config` and `hash-object` from the broad blocklist regex so the flag-aware branches own them).

## 5. Documentation in the script

- [x] 5.1 Rewrite the header comment block to enumerate every blocked git subcommand by name, the blocked binaries (`gh`, `hub`), the `git config` read-vs-write rule, the `git hash-object -w` rule, the fail-closed dependency semantics, and a one-line link to CLAUDE.md as the source policy.
- [x] 5.2 Add a one-line comment immediately above each significant code block explaining what it does (pre-flight check, normaliser, top-level pattern match, `config` branch, `hash-object` branch, deny emit).

## 6. Verification

- [x] 6.1 Add a smoke-test shell script under `scripts/` (top-level project directory) that pipes representative tool-input JSON through `.claude/hooks/block-git-writes.sh` and asserts the expected exit code and stdout for each spec scenario in `specs/git-write-blocking-hook/spec.md`.
- [x] 6.2 Verify the missing-`jq` path manually by running the script with `PATH=/usr/bin:/bin` (or a similarly minimal PATH) and confirming a structured deny is emitted.
- [x] 6.3 Run the smoke-test from a fresh shell after the edits land; confirm every scenario passes before marking the change done.

## 7. Wire-up sanity check

- [x] 7.1 Confirm `.claude/settings.json` still references the hook by absolute `$CLAUDE_PROJECT_DIR/.claude/hooks/block-git-writes.sh` path and that the `PreToolUse` matcher is `Bash` (no edits expected — this is a guard against accidental drift).
- [x] 7.2 Re-run `chmod +x .claude/hooks/block-git-writes.sh` if the rewrite touched permissions.
