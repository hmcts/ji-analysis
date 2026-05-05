## Why

The PreToolUse hook at `.claude/hooks/block-git-writes.sh` is the only enforcement that stops Claude sessions from mutating local git state — a critical guardrail per CLAUDE.md ("DO NOT PERFORM ANY GITHUB OPERATIONS from within Claude sessions"). Two gaps weaken it today:

1. The blocklist misses several state-changing porcelain and plumbing subcommands (`add`, `mv`, `restore`, `switch`, `revert`, `apply`, `am`, `worktree`, `submodule`, `notes`, `gc`, `prune`, `repack`, `replace`, `reflog`, `filter-branch`, `init`, `clone`, `fast-import`, `bisect`, mutating `update-ref`/`update-index`/`commit-tree`/`write-tree`/`hash-object -w`/`symbolic-ref <name> <ref>`/`pack-refs`, and mutating `git config <write>`), so Claude can still alter the repo via the missing entry points.
2. If `jq` (or any required CLI) is missing, `set -euo pipefail` aborts the pipeline mid-evaluation and the hook exits non-zero with no `permissionDecision`. Depending on harness behavior, missing decisions can be treated as "allow" — silently disabling the guardrail rather than failing closed.
3. The `normalize()` function uses `[^[:space:]]+` as its flag-value matcher, which truncates at the first internal whitespace. `git -C "/path with spaces" commit` therefore normalises to `git with spaces" commit`, and the subsequent regex no longer sees `commit` adjacent to `git` — the command passes through unblocked.

## What Changes

- **BREAKING for hook semantics:** Expand the blocked-git-subcommand list to cover every porcelain command that writes to the working tree, index, refs, or config, plus the plumbing commands that mutate refs/objects/index. New entries: `add`, `mv`, `restore`, `switch`, `revert`, `apply`, `am`, `worktree`, `submodule`, `notes`, `gc`, `prune`, `repack`, `replace`, `reflog`, `filter-branch`, `filter-repo`, `init`, `clone`, `fast-import`, `bisect`, `update-ref`, `update-index`, `commit-tree`, `write-tree`, `pack-refs`, `symbolic-ref`, `mktag`, `mktree`, `fetch` (writes remote-tracking refs), `remote` (when used with `add`/`remove`/`set-url`/`rename`/`prune`).
- Treat `git config` as blocked when it writes (any invocation without `--get*`/`--list`/`-l`/`--show-origin`-only flags) — simplest is to block `git config` whenever a value is being set; allow read-only forms.
- Treat `hash-object` as blocked only when invoked with `-w` (write).
- Add an explicit pre-flight check at the top of the script: verify `jq`, `grep`, and `sed` are on `PATH`. If any is missing, emit a structured `permissionDecision: "deny"` JSON with a clear reason and exit `0` (so the harness honours the deny rather than treating absence as allow).
- Harden `normalize()` to consume quoted (`"…"`, `'…'`) and backslash-escaped flag values as single tokens, and treat any input that exhausts the iteration cap without converging as deny-by-default rather than evaluate-as-is.
- Update the comment block in the hook to reflect the new blocklist and the fail-closed behavior.
- Update or add minimal docs/tests so the rule set is auditable.

## Capabilities

### New Capabilities

- `git-write-blocking-hook`: PreToolUse Bash hook that denies state-changing git/GitHub operations issued from Claude sessions, fails closed when its dependencies are unavailable, and documents the blocklist.

### Modified Capabilities

<!-- None — this capability does not yet exist as a published spec. -->

## Impact

- **Code:** `.claude/hooks/block-git-writes.sh` (rewritten blocklist + tool pre-flight). No change to `.claude/settings.json` wiring.
- **Behavior:** Claude sessions will see deny decisions for a broader set of git invocations, including some currently-tolerated ones (e.g. `git add`, `git fetch`, `git config user.email …`). Read-only operations (`status`, `log`, `diff`, `show`, `blame`, `ls-files`, `git config --get`, `git config --list`) remain allowed.
- **Dependencies:** Hook now explicitly requires `jq`, `grep`, `sed` on `PATH`. Missing tools cause a hard deny rather than silent passthrough.
- **Risk:** Slightly more friction inside Claude sessions when read-only-looking flows actually mutate state (e.g. `git fetch`); user can still run those externally via VSCode, which matches the existing workflow.
