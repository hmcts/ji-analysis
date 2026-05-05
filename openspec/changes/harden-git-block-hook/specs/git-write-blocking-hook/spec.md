## ADDED Requirements

### Requirement: Hook denies state-changing git porcelain subcommands

The PreToolUse Bash hook SHALL deny any tool call whose `tool_input.command` invokes the `git` binary (after stripping `git -C <path>` / `git --git-dir <path>` / `git --work-tree <path>` / `git --namespace <ns>` / `git --super-prefix <prefix>` / `git --exec-path <path>` / `git -c <kv>` flag-value pairs and value-less flags such as `--no-pager`, `--paginate`, `-P`, `--bare`, `--no-replace-objects`, `--literal-pathspecs`, `--no-optional-locks`) with any of the following subcommands as its first non-option token:

`add`, `am`, `apply`, `bisect`, `branch`, `checkout`, `cherry-pick`, `clean`, `clone`, `commit`, `commit-tree`, `fast-import`, `fetch`, `filter-branch`, `filter-repo`, `gc`, `init`, `merge`, `mktag`, `mktree`, `mv`, `notes`, `pack-refs`, `prune`, `pull`, `push`, `rebase`, `replace`, `reflog`, `remote`, `repack`, `reset`, `restore`, `revert`, `rm`, `stash`, `submodule`, `switch`, `symbolic-ref`, `tag`, `update-index`, `update-ref`, `worktree`, `write-tree`.

#### Scenario: Blocked porcelain command is denied

- **WHEN** Claude submits `git commit -m "x"` as a Bash tool call
- **THEN** the hook emits a JSON object with `hookSpecificOutput.permissionDecision = "deny"` and a non-empty `permissionDecisionReason` referencing CLAUDE.md
- **AND** the hook exits `0`

#### Scenario: Blocked plumbing command is denied

- **WHEN** Claude submits `git update-ref refs/heads/main HEAD~1` as a Bash tool call
- **THEN** the hook emits a deny decision and exits `0`

#### Scenario: Blocked subcommand reached via flag prefix is denied

- **WHEN** Claude submits `git -C /tmp/repo --no-pager add file.txt` as a Bash tool call
- **THEN** the hook normalises the command and emits a deny decision

#### Scenario: Blocked subcommand reached via shell separator is denied

- **WHEN** Claude submits `cd /tmp/repo && git push origin main` as a Bash tool call
- **THEN** the hook detects `git push` after the `&&` boundary and emits a deny decision

#### Scenario: Blocked subcommand behind a double-quoted flag value with spaces is denied

- **WHEN** Claude submits `git -C "/path with spaces" commit -m "msg"` as a Bash tool call
- **THEN** the hook normalises the quoted value as a single token and emits a deny decision for `commit`

#### Scenario: Blocked subcommand behind a single-quoted flag value with spaces is denied

- **WHEN** Claude submits `git --git-dir '/var/repos/dir with spaces/.git' push origin main` as a Bash tool call
- **THEN** the hook normalises the quoted value as a single token and emits a deny decision for `push`

#### Scenario: Blocked subcommand behind a backslash-escaped flag value with spaces is denied

- **WHEN** Claude submits `git -C /path/with\ spaces commit` as a Bash tool call
- **THEN** the hook treats `\ ` as part of the same token and emits a deny decision for `commit`

#### Scenario: Pathological flag stack that exceeds the normalisation iteration cap is denied

- **WHEN** Claude submits a `git` invocation whose flag prefix cannot be reduced by the normaliser within 10 passes
- **THEN** the hook emits a deny decision with reason "could not normalise git flag prefix; refusing to evaluate"
- **AND** the hook does not fall through to the matcher

### Requirement: Hook denies all `gh` and `hub` invocations

The hook SHALL deny any tool call whose command invokes the `gh` or `hub` binary as a top-level command (anchored by start-of-string or by a shell separator boundary), regardless of subcommand.

#### Scenario: gh subcommand is denied

- **WHEN** Claude submits `gh pr create --title "x"` as a Bash tool call
- **THEN** the hook emits a deny decision

#### Scenario: hub subcommand is denied

- **WHEN** Claude submits `hub fork` as a Bash tool call
- **THEN** the hook emits a deny decision

### Requirement: Hook treats `git config` as write-only-by-default

The hook SHALL deny `git config` invocations unless the command line contains at least one read-only selector flag (`--get`, `--get-all`, `--get-regexp`, `--get-urlmatch`, `--list`, `-l`, `--show-origin`, `--show-scope`) AND contains none of the mutating flags (`--unset`, `--unset-all`, `--add`, `--replace-all`, `--rename-section`, `--remove-section`, `--edit`, `-e`).

#### Scenario: Setting a config value is denied

- **WHEN** Claude submits `git config user.email someone@example.com`
- **THEN** the hook emits a deny decision

#### Scenario: Reading a config value is allowed

- **WHEN** Claude submits `git config --get user.email`
- **THEN** the hook exits `0` with no output (no deny decision)

#### Scenario: Listing config is allowed

- **WHEN** Claude submits `git config --list --show-origin`
- **THEN** the hook exits `0` with no output

#### Scenario: Edit flag forces deny even with read-only selector present

- **WHEN** Claude submits `git config --get user.email --edit`
- **THEN** the hook emits a deny decision

### Requirement: Hook treats `git hash-object` as read-only unless `-w` is present

The hook SHALL allow `git hash-object` invocations that do not contain the `-w` (or `--stdin-paths` combined with `-w`) flag, and SHALL deny invocations that include `-w`.

#### Scenario: hash-object without -w is allowed

- **WHEN** Claude submits `git hash-object README.md`
- **THEN** the hook exits `0` with no output

#### Scenario: hash-object with -w is denied

- **WHEN** Claude submits `git hash-object -w README.md`
- **THEN** the hook emits a deny decision

### Requirement: Hook fails closed when required CLI tools are missing

Before evaluating the command, the hook SHALL verify that `jq`, `grep`, and `sed` are resolvable via `command -v`. If any required tool is missing, the hook SHALL emit a structured `permissionDecision: "deny"` JSON object whose `permissionDecisionReason` names the missing tool, and SHALL exit `0` so the harness honours the deny. The deny JSON SHALL be produced without invoking any of the missing tools (e.g. via `printf` rather than `jq`).

#### Scenario: Missing jq triggers a structured deny

- **WHEN** the hook runs in an environment where `jq` is not on `PATH`
- **THEN** the hook prints a single-line JSON object with `hookSpecificOutput.permissionDecision = "deny"` and a reason naming `jq`
- **AND** the hook exits `0`

#### Scenario: Missing sed triggers a structured deny

- **WHEN** the hook runs in an environment where `sed` is not on `PATH`
- **THEN** the hook prints a deny JSON naming `sed` and exits `0`

#### Scenario: All tools present allows normal evaluation

- **WHEN** `jq`, `grep`, and `sed` are all on `PATH`
- **AND** the command is read-only (e.g. `git status`)
- **THEN** the hook exits `0` with no output

### Requirement: Hook allows common read-only git operations

The hook SHALL exit `0` with no output (no deny decision) for git invocations whose first non-option subcommand is one of: `status`, `log`, `diff`, `show`, `blame`, `ls-files`, `ls-tree`, `rev-parse`, `cat-file`, `for-each-ref`, `describe`, `name-rev`, `merge-base`, `version`, `help`, `var`, `count-objects`, `shortlog`, `grep`, `whatchanged`, `archive`, `bundle` (when used without `create`), and any other subcommand not present in the blocklist.

#### Scenario: git status is allowed

- **WHEN** Claude submits `git status`
- **THEN** the hook exits `0` with no output

#### Scenario: git log is allowed

- **WHEN** Claude submits `git log --oneline -n 20`
- **THEN** the hook exits `0` with no output

#### Scenario: git diff is allowed

- **WHEN** Claude submits `git diff HEAD~1`
- **THEN** the hook exits `0` with no output

### Requirement: Hook self-documents its blocklist

The hook script SHALL contain a header comment block that:
- Lists every blocked git subcommand by name.
- Lists every blocked top-level binary (`gh`, `hub`).
- Documents the read-vs-write rules for `git config` and `git hash-object`.
- States the fail-closed semantics for missing dependencies.
- References the project policy ("CLAUDE.md") that this hook enforces.

#### Scenario: Reviewer can audit the rule set without running the hook

- **WHEN** a reviewer reads the first 40 lines of `.claude/hooks/block-git-writes.sh`
- **THEN** they can enumerate the full blocklist and the fail-closed behaviour without inspecting the regex
