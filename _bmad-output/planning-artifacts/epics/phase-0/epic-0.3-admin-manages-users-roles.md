---
parent: 'epics/phase-0/index.md'
epic: 0.3
title: 'Users, roles, and activation flags are SQL-loaded'
storyCount: 1
status: 'validated'
revisedAt: '2026-05-15'
revisionNote: 'Admin UI for Users/Roles management is post-MVP (was Stories 0.3.2 + 0.3.4). Admin API extensions are not needed because there is no admin UI consumer (was Story 0.3.1). Only the SQL-driven ETL remains in Phase 0 (was Story 0.3.3, now renumbered to 0.3.1).'
---

# Epic 0.3: Users, roles, and activation flags are SQL-loaded

**User outcome:** Active APEX users and their role/Region/Area assignments are loaded into the RAM Pathfinder Authorisation tables via a direct-SQL ETL, with named-owner sign-off and explicit handling of unmatched records via versioned CSV decision files. Per-region activation flags are initialised based on Phase 9+ planned cutover order (all `FALSE` initially; flipped per region during cutover via direct SQL). **No admin UI in MVP** — operational user/role/scope maintenance happens via direct SQL by DBAs; an admin UI surface is on the post-MVP roadmap.

**Vertical slice:**
- Phase 0 Users/Roles ETL stream at `ram-architecture/migration/users-roles/` (per AR46–AR48)
- Reads APEX user dumps, reconciles to HMCTS IdP principals (email primary, employee number fallback per D9 / Risk #14)
- **Loads matched records via direct SQL INSERT** into `auth_users`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags` (using the `ram_authorisation` DB role — write access for the ETL runner is granted via a one-time DBA-issued credential held in Azure Key Vault)
- Unmatched records routed to `unmatched/{run-date}.csv` with an editable `decision` column (drop / hold / `manual_map:<idp_email>`)
- Named owner edits the CSV; ETL re-run applies decisions
- Per-run reconciliation report under `migration/reports/users-roles/{run-date}.md`
- Owner sign-off via versioned git commits in `migration/reports/users-roles/signoffs/{run-date}-{owner-handle}.md` with `CODEOWNERS`-enforced two-reviewer policy
- **Activation flag initial state:** all FALSE; flipped per region during Phase 9+ cutover via direct SQL by DBA on cutover day (no UI for activation toggle in MVP)
- ETL re-run for incremental waves is idempotent (`INSERT ... ON CONFLICT DO NOTHING`)

**FRs covered:**
- **FR57** — Users/Roles portion of the Phase 0 ETL, now via direct SQL
- **FR58** — initial activation flag state set by ETL; cutover flips happen per region during Phase 9+ via direct SQL

**FRs deferred to post-MVP:**
- **FR4** (admin role updates) — the data exists in the auth tables and can be edited by DBAs via direct SQL, but the **admin UI surface for system administrators to update assignments is post-MVP** (was Story 0.3.2 in the prior plan, removed)

**Out of scope for Phase 0 (deferred post-MVP):**
- `ram-authorisation` admin write endpoints (was Story 0.3.1 in the prior plan, removed)
- `ram-admin-ui` Users & Roles module (was Story 0.3.2)
- `ram-admin-ui` Migration Reports module with decisions UI (was Story 0.3.4 — replaced by editable CSV files in MVP)
- Activation flag toggle UI (Phase 9+ cutover happens via direct SQL only in MVP)

---

## Story 0.3.1: Phase 0 Users/Roles ETL — APEX users via direct SQL + decisions CSV + reconciliation report + owner sign-off

As a **Users/Roles named owner** (identity / HMCTS IT lead),
I want the Phase 0 ETL to read APEX user dumps, reconcile to HMCTS IdP principals (email primary, employee number fallback), load matched users via direct SQL into the RAM Pathfinder Authorisation tables, and route unmatched users into an explicit decisions CSV that I edit and approve via versioned git commits,
So that **migration correctness is auditably owned** (per FR57, D9, Risk #14), unmatched records are not silently dropped, and the workflow works without an admin UI (which is now post-MVP).

**Acceptance Criteria:**

**Given** the engineer creates the ETL at `ram-architecture/migration/users-roles/`,
**When** the ETL is implemented,
**Then** it reads APEX user dumps (format per the migration spec),
**And** for each row, it reconciles to an HMCTS IdP principal:
   • try exact email match against the HMCTS IdP directory (primary key per D9)
   • on no email match, try employee-number match (fallback per D9)
   • on neither match, route the row to the unmatched bucket,
**And** matched rows are **inserted via direct SQL** into `auth_users`, `auth_user_roles`, `auth_user_region_scopes`, and `auth_user_activation_flags` using the `ram_authorisation` DB role,
**And** the ETL does NOT call the Authorisation API (which is read-only in Phase 0).

**Given** the ETL completes a run,
**When** the reconciliation report is generated at `ram-architecture/migration/reports/users-roles/{run-date}.md`,
**Then** the report shows:
   • source-row count per APEX dump
   • matched count (email primary, employee-number fallback breakdown)
   • unmatched count with per-row reason
   • per-role assignment counts
   • per-Region/Area scope counts
   • activation-flag initial state per region (all FALSE at MVP)
   • anomalies (e.g. APEX role not in RAM Pathfinder controlled list, ambiguous email match),
**And** the unmatched rows are written to `ram-architecture/migration/reports/users-roles/unmatched/{run-date}.csv` with columns `apex_id`, `apex_email`, `apex_employee_number`, `apex_name`, `apex_role`, `apex_region`, `apex_area`, `reason`, `decision` (last column empty for owner to fill).

**Given** a named owner edits the decisions CSV with `drop` / `hold` / `manual_map:<idp_email>` per row,
**When** the owner commits the updated CSV to git,
**Then** the next ETL re-run reads the decisions,
**And** applies them: `drop` rows are skipped; `hold` rows remain unmatched (carried forward); `manual_map:<email>` rows are loaded with the specified IdP email binding (the email is recorded in `auth_users.idp_principal` alongside the original APEX identifiers for audit).

**Given** the ETL is re-run incrementally for a subsequent wave,
**When** the second run completes,
**Then** previously-matched users are not re-created (idempotency per AR49, via `INSERT ... ON CONFLICT DO NOTHING`),
**And** new APEX rows are matched fresh against IdP,
**And** previously-unmatched rows whose APEX side has changed re-enter the unmatched CSV with an updated reason.

**Given** an APEX role appears that does not exist in `auth_roles`,
**When** the ETL encounters the row,
**Then** the row routes to the unmatched CSV with reason *"Unknown APEX role: {role-name}"*,
**And** the row does not load with a partial role assignment.

**Given** the activation flag initial state is being set,
**When** the ETL inserts `auth_user_activation_flags`,
**Then** every user has an entry per applicable region with `activated = FALSE`,
**And** Phase 9+ cutover flips these flags per region via direct SQL (no UI in MVP).

**Given** a named owner reviews the reconciliation report,
**When** they sign off via a versioned commit to `ram-architecture/migration/reports/users-roles/signoffs/{run-date}-{owner-handle}.md`,
**Then** the sign-off is recorded in git history (immutable audit trail),
**And** the commit is co-signed by a second reviewer per the `CODEOWNERS` policy on `migration/reports/`,
**And** the absence of a signoff file blocks Phase 9+ regional activation (enforced operationally — the cutover runbook checks for the signoff before flipping flags).

**References:** FR57 (Users/Roles via SQL ETL per D9), FR58 (initial activation flag state); NFR15 (audit via git); AR21, AR46, AR47, AR48, AR49.

**Explicitly NOT in scope (deferred post-MVP):**
- Admin API for user / role / scope edits on `ram-authorisation` (was Story 0.3.1 in the prior plan)
- Admin UI Users & Roles module in `ram-admin-ui` (was Story 0.3.2)
- Admin UI Migration Reports module with decisions UI (was Story 0.3.4 — replaced by editable CSV files)
- UI for activation flag toggle
