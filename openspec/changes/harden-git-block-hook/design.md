## Context

`.claude/hooks/block-git-writes.sh` runs as a `PreToolUse` hook on the `Bash` matcher. It reads the harness JSON envelope from stdin, extracts `tool_input.command`, normalises away `git -C <path>` / `git --git-dir <path>` style flags, and matches a regex against a fixed list of blocked subcommands. On match it emits a JSON deny decision; otherwise it exits `0` with no output (which the harness treats as "no opinion → allow").

Two concrete weaknesses motivated this change:

1. **Incomplete blocklist.** The current set (`commit|push|pull|merge|rebase|reset|checkout|branch|tag|stash|cherry-pick|clean|rm`) leaves daylight around several mutating git commands. Notable misses: `add` (stages writes), `mv` (moves files in worktree+index), `restore`/`switch` (modern replacements for `checkout`), `revert` (creates commits), `apply`/`am` (mutates worktree/history), `worktree`, `submodule`, `notes`, `gc`/`prune`/`repack`, `replace`, `reflog` (mutates via `expire`/`delete`), `filter-branch`/`filter-repo`, `init`/`clone` (creates new repos), `fast-import`, `bisect` (uses checkout). Plumbing equivalents (`update-ref`, `update-index`, `commit-tree`, `write-tree`, `pack-refs`, `symbolic-ref` with a value, `mktag`, `mktree`) can do the same damage. `fetch` updates remote-tracking refs and the `remote` subcommand can rewrite the URL/refspec configuration.
2. **Silent failure on missing dependencies.** The script unconditionally calls `jq`, `grep`, and `sed`. With `set -euo pipefail`, an unavailable `jq` causes the script to abort before any decision JSON is emitted. The Claude Code harness interprets a hook that exits non-zero without a structured decision as a tool-execution error rather than a deny — so the human risk model is "fail open" in some interpretations and "fail confused" in others. Either way, the user wants explicit fail-closed semantics.

The user's repo-level CLAUDE.md is the source of truth: GitHub operations should not happen from Claude sessions; the user commits via VSCode after review. The hook's job is to enforce that as defence-in-depth on top of the textual instruction.

## Goals / Non-Goals

**Goals:**
- Block every git porcelain subcommand that mutates the working tree, the index, refs, the object database, the stash, hooks, or repo configuration.
- Block the small set of plumbing subcommands a sufficiently determined session might reach for (`update-ref`, `update-index`, `commit-tree`, `write-tree`, `pack-refs`, `symbolic-ref`, `mktag`, `mktree`, `fast-import`, `hash-object -w`).
- Block `gh` and `hub` entirely (already done — keep parity).
- Fail closed: if `jq`, `grep`, or `sed` is missing, deny the tool call with a clear reason instead of letting the script crash.
- Keep the most common read-only flows fast: `git status`, `git log`, `git diff`, `git show`, `git blame`, `git ls-files`, `git config --get`/`--list`, `git remote -v` / `git remote show`.

**Non-Goals:**
- Becoming a full git command parser. We accept that someone determined enough to write `git $(echo c)ommit` or pipe into `bash -c '...'` can bypass any regex; CLAUDE.md remains the policy of record.
- Blocking arbitrary shell mutations of `.git/` directories (e.g. `rm -rf .git/index`). The existing project-wide `rm` block already mitigates this.
- Adding any external configuration surface (env vars, files) — keep the rule set inline so review is one diff.

## Decisions

### Decision 1: Treat the blocklist as "all subcommands that can mutate, by default"

**Choice:** Switch from "small denylist" to "broad denylist that mirrors `git help -a`'s mutation surface". Allow only a fixed list of read-only subcommands.

**Rationale:** The current curated list was incomplete in ways that aren't obvious without reading every git man page. A larger, named list is cheap to maintain and easy to audit in code review.

**Alternatives considered:**
- *Allowlist-only model:* Define an explicit `read_only_subs` and deny everything else. Cleaner conceptually, but the long tail of read-only plumbing (`rev-parse`, `cat-file`, `for-each-ref`, `name-rev`, `merge-base`, `describe`, …) is huge — we'd lock ourselves out of useful diagnostics. **Rejected.**
- *Per-flag analysis (e.g. parse `git config` flags to decide read vs write):* Accurate, but rapidly turns the script into a parser. Adopt only for `git config` and `git hash-object`, where a single flag fully decides intent.

### Decision 2: `git config` and `git hash-object` get flag-aware treatment

**Choice:**
- `git config` is blocked unless the invocation contains one of `--get`, `--get-all`, `--get-regexp`, `--get-urlmatch`, `--list`, `-l`, `--show-origin`, `--show-scope` and contains no `--unset`/`--add`/`--replace-all`/`--rename-section`/`--remove-section`/`--edit`/`-e` flags.
- `git hash-object` is blocked when invoked with `-w` (writes object into the database). Plain `hash-object <file>` (no `-w`) only computes a hash and is allowed.

**Rationale:** These two commands have a clean "read flag vs write flag" split, and blocking both modes wholesale would break legitimate diagnostic use.

**Alternatives considered:**
- *Block both modes always:* Simpler regex but loses common read-only inspection. **Rejected.**

### Decision 3: `git fetch` is blocked

**Choice:** Add `fetch` to the blocklist.

**Rationale:** `fetch` writes remote-tracking refs (and can prune them). Although the working tree is unchanged, the user's stated workflow keeps all repo writes in VSCode, so an unannounced `fetch` from a Claude session violates that contract.

**Alternatives considered:**
- *Allow `fetch`:* Convenient for read-only diagnostic flows ("what's on origin?"). **Rejected** because the user's policy is "no git mutations from Claude sessions" without qualification.

### Decision 4: Pre-flight tool check, fail-closed via structured deny JSON

**Choice:** As the first step after `set -euo pipefail`, iterate over a tools list (`jq grep sed`) with `command -v`. If any is missing, emit a deny JSON via `printf` (which is a bash builtin, so it works even if `jq` is absent) and `exit 0`.

**Rationale:** The harness honours `permissionDecision: "deny"` only when the script exits `0` and prints valid JSON. Crashing the script (exit non-zero) does not produce a deny — it produces a hook error, which different harness versions handle inconsistently. Emitting a hand-built JSON via `printf` keeps the deny path independent of the very tools we are checking for.

**Alternatives considered:**
- *Just `exit 1` if jq missing:* Relies on harness fail-closed semantics that aren't guaranteed. **Rejected.**
- *Use a heredoc instead of `printf`:* Equivalent, but `printf` keeps the JSON on one line and is easier to grep for in audits.

### Decision 5: Keep the regex-based normaliser, extend its flag list, and harden it against quoted/escaped values

**Choice:** Reuse the existing `normalize` function that strips `git <flag> <value>` prefix pairs, with three extensions:

1. **Boolean / value-less flags.** Add a separate stripping pass for value-less flags between `git` and the subcommand: `--no-pager`, `--paginate`, `-P`, `--bare`, `--no-replace-objects`, `--literal-pathspecs`, `--no-optional-locks`, and any `--list-cmds=…` / `--namespace=…` style flag where `=` joins name and value into one token.

2. **Quoted and escaped values for valued flags.** The current value matcher `[^[:space:]]+` truncates at the first internal whitespace, so `git -C "/path with spaces" commit` normalises to `git with spaces" commit` and `commit` then fails to match. Replace the value matcher with one that accepts a single shell-style argument:

   ```
   value := "[^"\\]*(\\.[^"\\]*)*"          # double-quoted, allowing escaped chars
          | '[^']*'                          # single-quoted (no escapes inside)
          | (\\[[:space:]]|[^[:space:]])+    # bare token, allowing backslash-escaped spaces
   ```

   Apply the same matcher to `git -C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`, `--super-prefix`, `--exec-path`.

3. **Convergence as a security signal.** The existing iteration cap (10) silently leaves un-stripped flags in place if it's exceeded. Change the contract: if the iteration loop terminates because the cap was hit (`prev != s` on the final pass), the hook SHALL emit a deny JSON with reason "could not normalise git flag prefix; refusing to evaluate" rather than fall through to the matcher. Pathological inputs become deny-by-default.

**Rationale:** All three extensions close a real bypass. Boolean flags hide a subcommand behind `git --no-pager add`; quoted flag values hide it behind `git -C "/path with spaces" commit`; pathological recursive flag stacks could in principle exhaust the iteration cap. Treating any of those situations as deny costs nothing in real workflows — `git -C /tmp/repo log` (no spaces, simple flag) still normalises and matches as today.

**Alternatives considered:**
- *Drop the regex normaliser and shell-tokenise via `xargs -n1` or `eval set --`:* Token-based detection would handle quotes natively. `xargs` quoting rules diverge from POSIX shell quoting (notably for backslashes and the special `\` continuation), so it would introduce its own corner cases. `eval set --` is unsafe because the input is attacker-shaped (a malicious or coerced session could inject `$(rm -rf …)` into the command and have `eval` execute it just by tokenising). **Rejected** in favour of a slightly bigger regex.
- *Drop the normaliser, anchor regex more loosely:* Yields false positives (e.g. `mygitcommit-helper` matching), and still doesn't handle `git -C <path> commit`. **Rejected.**
- *Walk tokens manually in pure bash:* Workable but ~50 lines of state machine for a single file; the regex extension is ~5 extra characters per alternative. **Rejected** on simplicity grounds.

## Risks / Trade-offs

- **[Risk] Broader denylist increases friction for read-only workflows that happen to use a blocked subcommand (e.g. `git fetch --dry-run`).**
  → Mitigation: Document the blocklist clearly in the script's comment header and in the spec; the user can run those commands externally.

- **[Risk] Regex still parses commands, not real shells; tricks like `eval "$(echo git commit)"` or backtick substitutions could bypass.**
  → Mitigation: Out of scope per Non-Goals; CLAUDE.md remains the binding policy. The hook is defence-in-depth, not a sandbox.

- **[Risk] Pre-flight check using `command -v` itself depends on `command` (a bash builtin — always available with `#!/usr/bin/env bash`).**
  → Mitigation: Keep the `bash` shebang explicit; document that the script requires `bash`, not POSIX `sh`.

- **[Risk] False positives from over-eager regex (e.g. a string literal `"git commit"` inside an unrelated shell command).**
  → Mitigation: The boundary anchor `(^|[;&|`])` plus required `[[:space:]]` after the subcommand keeps matches scoped to actual command positions. We accept the rare false positive given the security-leaning bias.

- **[Risk] Quoted flag values containing spaces could bypass the normaliser, leaving the blocked subcommand unmatched (e.g. `git -C "/path with spaces" commit` normalises to `git with spaces" commit`, hiding `commit`).**
  → Mitigation: Decision 5 extends the value matcher to accept double-quoted strings, single-quoted strings, and backslash-escaped spaces. Any input the matcher cannot consume in ≤10 normalisation passes is denied as suspicious rather than evaluated.

- **[Risk] Sed ERE support for nested alternation with quotes varies between BSD `sed` (macOS default) and GNU `sed` (Linux). Backreferences and lookarounds are not portable.**
  → Mitigation: Use only POSIX ERE features — character classes, alternation, capture groups `\1`, and quantifiers `+`/`*`. No lookaheads, no `\d`, no PCRE-only syntax. Confirm the regex on macOS BSD sed during verification (task 6.1).

## Migration Plan

1. Edit `.claude/hooks/block-git-writes.sh` in place. The hook is referenced by absolute path from `.claude/settings.json`; no settings changes are needed.
2. Smoke-test from a Claude session by attempting one previously-allowed-but-now-blocked command (e.g. `git fetch`) and confirming the deny JSON surfaces as a permission denial.
3. Smoke-test the fail-closed path by temporarily renaming `jq` on `PATH` (e.g. running with `PATH=/tmp` for a sandbox shell) and confirming the deny is emitted.
4. No rollback plan beyond `git checkout` of the previous file — this is a config-tier change with no persistent state.

## Open Questions

- None blocking. If experience shows `git fetch` is needed for diagnostic flows often, we can revisit (e.g. allow `git fetch --dry-run` only) — but defer until a real case appears.
