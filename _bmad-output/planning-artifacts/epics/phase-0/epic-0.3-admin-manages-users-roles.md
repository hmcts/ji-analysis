---
parent: 'epics/phase-0/index.md'
epic: 0.3
title: 'Admin manages users, roles, and per-region activation with migration sign-off'
storyCount: 4
status: 'validated'
---

# Epic 0.3: Admin manages users, roles, and per-region activation with migration sign-off

**User outcome:** An admin user signs into `nji-admin-ui`, opens the User & Role admin module, can search users (migrated from APEX + new), edit role and Region/Area scope assignments, view per-user effective permissions, and flip per-user activation flags. Phase 0 ETL has loaded the active APEX users and produced a reconciliation report keyed to HMCTS IdP principals (email primary, employee number fallback); named owners review and sign off, with explicit handling decisions (drop / hold / manual map) for unmatched records.

**Vertical slice:**
- Admin UI Users & Role module (`modules/users-roles/`) in `nji-admin-ui` — list and search users, edit role and Region/Area scope, view effective permissions, view and toggle per-user activation flag
- `nji-authorisation` API extensions: role/scope edit endpoints, effective-permissions endpoint, activation-flag endpoints
- Users/Roles ETL stream at `nji-architecture/migration/users-roles/` (per AR46–AR48): reads APEX user dumps, reconciles to HMCTS IdP (email primary, employee number fallback per D9 / Risk #14), loads via `nji-authorisation` API
- Per-run reconciliation report under `migration/reports/users-roles/`
- `unmatched/` bucket with explicit handling-decision workflow (drop / hold / manual map)
- Per-user activation flag surface (FR58 — orchestration of flag-flips at cutover lives in Phase 9+, but the admin-side toggle and reporting view live here)

**FRs covered:** FR4 (full role/scope edits), FR57 (Users/Roles portion), FR58 (flag wire-up surface)

**Key NFRs:** NFR12–NFR13 (auth enforcement on admin endpoints), NFR17–NFR19 (admin UI WCAG)

**Why separate from Epic 0.2:** Different ETL stream, different domain owners (judicial-team owners for Reference Data vs identity / IT owners for Users/Roles), different reconciliation methodology (controlled-list vs identity-reconciliation), different risk profile (Risk #13 vs Risk #14). Bundling would dilute the user value and the sign-off accountability.

---

## Story 0.3.1: `nji-authorisation` API extensions for user, role, scope, and activation administration

As an **API consumer** (admin UI now; downstream Phase 9+ rollout orchestration later),
I want `nji-authorisation` to expose admin-gated endpoints for managing users, role assignments, Region/Area scope, and per-user activation flags,
So that **admins can edit migrated user data** (per FR4) and the activation surface (per FR58) is available before Phase 9+ rollout orchestration uses it.

**Acceptance Criteria:**

**Given** `nji-authorisation` is deployed per Epic 0.1 (Story 0.1.3) with the 5 auth tables in place,
**When** the engineer adds admin endpoints,
**Then** `GET /v1/admin/users` supports list + search + filter by email, employee number, role, region, area, activation state (per FR4),
**And** `GET /v1/admin/users/{id}` returns full user detail including role assignments and Region/Area scope,
**And** `PUT /v1/admin/users/{id}/roles` updates the user's role assignments (writes `auth_user_roles`),
**And** `PUT /v1/admin/users/{id}/region-scopes` updates Region/Area scope (writes `auth_user_region_scopes`),
**And** `PUT /v1/admin/users/{id}/activation` toggles per-region activation flags (writes `auth_user_activation_flags`) — per FR58.

**Given** any admin endpoint is called,
**When** the authenticated principal does NOT have a `system-admin` role,
**Then** the response is `403 Forbidden` with an RFC 9457 problem-details body (per NFR13).

**Given** an admin user updates another user's roles,
**When** the API processes the request,
**Then** an audit row is written to a `auth_audit` table (added via Flyway migration in this story) recording principal / target user / before-state / after-state / timestamp,
**And** the response is `200 OK` with the updated user resource (or `409 Conflict` if optimistic locking via `@Version` detects a concurrent edit — per AR21),
**And** the change is reflected in the next `POST /v1/authz/check` call for the target user.

**Given** the admin endpoints are tested via Postman collection,
**When** the collection runs in CI,
**Then** it covers happy path + `403` (non-admin caller) + `404` (missing user) + `409` (optimistic-lock conflict) + `400` (validation failure with RFC 9457),
**And** the collection is appended to `postman/nji-authorisation-phase0.postman_collection.json`.

**Given** the OpenAPI spec is regenerated,
**When** `uk.gov.hmcts.nji:api-nji-authorisation:1.1.0` is published,
**Then** all admin endpoints are documented with full request/response schemas,
**And** Spectral lint passes,
**And** the spec version bumps from 1.0.0 (Story 0.1.3) to 1.1.0 reflecting backwards-compatible additions (per AR38 versioning policy).

**References:** FR4, FR58 (activation surface); NFR12–NFR13, NFR15, NFR39, NFR42; AR18–AR21, AR34, AR37–AR39, AR41.

---

## Story 0.3.2: Admin UI Users & Roles module — search, edit roles, edit scope, toggle activation, view permissions

As a **system administrator**,
I want to search NJI users, edit their role and Region/Area scope assignments, view their effective permissions, and toggle their per-region activation flag through `nji-admin-ui`,
So that **migrated APEX users can be onboarded to NJI** (per FR4) and rollout orchestration (per FR58) has a UI surface to verify activation state before flag-flip.

**Acceptance Criteria:**

**Given** an admin signs into `nji-admin-ui` (Story 0.2.3) with a `system-admin` role,
**When** they open `/users-roles`,
**Then** they see a paginated user list with search by email, employee number, name, role, region,
**And** the list is fetched via the auto-generated TypeScript client from `nji-authorisation` OpenAPI (per AR43).

**Given** the admin opens a user,
**When** the detail view renders,
**Then** they see user identity (email, employee number, name), current roles, current Region/Area scope, current activation state per region, and effective permissions (computed by `GET /v1/users/{id}/effective-permissions`),
**And** an "Edit roles" form lists available roles with checkboxes,
**And** an "Edit Region/Area scope" form lists regions and areas,
**And** a "Toggle activation" control shows the current state per region with a confirmation modal before flip.

**Given** the admin edits and submits,
**When** the form posts via the auto-generated client,
**Then** a success toast confirms the change,
**And** the effective permissions panel refreshes to show the new state,
**And** on optimistic-lock conflict (`409`), the UI shows *"This user was edited by someone else — please reload"* with a refresh button.

**Given** the admin clicks the activation toggle for a region,
**When** the confirmation modal asks *"Activate user `judge.test@…` for region Northern?"*,
**Then** the admin confirms,
**And** the API call updates `auth_user_activation_flags` for that user + region,
**And** the user immediately sees (per Story 0.1.5) the new state on next sign-in (banner appears/disappears).

**Given** accessibility CI runs,
**When** axe-core scans the list, detail, edit forms, and confirmation modal,
**Then** no new WCAG 2.2 AA violations,
**And** keyboard navigation works through all forms and the modal,
**And** ARIA labels are correct on the toggle controls.

**Given** Playwright E2E coverage,
**When** `tests/e2e/users-roles.spec.ts` runs,
**Then** it covers: search → open user → edit roles → submit → effective-permissions refreshed → activation toggle → confirmation modal → flip → user sees new banner,
**And** also covers the optimistic-lock conflict path,
**And** also covers non-admin rejection.

**References:** FR4 (full edits), FR58 (activation surface), FR56 (admin stack); NFR12–NFR13, NFR17–NFR19; AR42–AR45.

---

## Story 0.3.3: Phase 0 Users/Roles ETL — APEX users to NJI Authorisation + IdP reconciliation + reconciliation report

As a **Users/Roles named owner** (identity / HMCTS IT lead),
I want the Phase 0 ETL to read APEX user dumps, reconcile to HMCTS IdP principals (email primary, employee number fallback), load matched users into NJI Authorisation, and route unmatched users into an explicit handling-decision workflow,
So that **migration correctness is auditably owned** (per FR57, D9, Risk #14) and unmatched records are not silently dropped.

**Acceptance Criteria:**

**Given** the engineer creates the ETL at `nji-architecture/migration/users-roles/`,
**When** the ETL is implemented,
**Then** it reads APEX user dumps (format per the migration spec),
**And** for each row, it reconciles to an HMCTS IdP principal:
   • try exact email match against the HMCTS IdP directory (primary key per D9)
   • on no email match, try employee-number match (fallback per D9)
   • on neither match, route the row to the unmatched bucket,
**And** matched rows load via `nji-authorisation` admin API (`POST /v1/admin/users` and friends) using a service-token (per AR36, AR46).

**Given** the ETL completes a run,
**When** the reconciliation report is generated at `nji-architecture/migration/reports/users-roles/{run-date}.md`,
**Then** the report shows:
   • source-row count per APEX dump
   • matched count (email primary, employee-number fallback breakdown)
   • unmatched count with per-row reason
   • per-role assignment counts
   • per-Region/Area scope counts
   • anomalies (e.g. APEX role not in NJI controlled list, ambiguous email match),
**And** the unmatched rows are written to `nji-architecture/migration/reports/users-roles/unmatched/{run-date}/` as one file per row,
**And** each unmatched-row file includes the raw APEX row + a "handling decision" placeholder (drop / hold / manual map).

**Given** the ETL is re-run incrementally for a subsequent wave,
**When** the second run completes,
**Then** previously-matched users are not re-created (idempotency per AR49),
**And** new APEX rows are matched fresh against IdP,
**And** previously-unmatched rows whose APEX side has changed re-enter the unmatched bucket with an updated reason.

**Given** an unmatched row's named-owner decision is `manual map`,
**When** the engineer (or named owner via Story 0.3.4 promoted UI) creates the mapping by providing an IdP principal email,
**Then** the mapping is recorded in the ETL's reconciliation state,
**And** subsequent re-runs pick up the manual map and load the user normally.

**Given** an APEX role appears that does not exist in `auth_roles`,
**When** the ETL encounters the row,
**Then** the row routes to the unmatched bucket with reason *"Unknown APEX role: {role-name}"*,
**And** the row does not load with a partial role assignment.

**References:** FR4 (load via admin API), FR57 (ETL framing per D9), FR58 (activation flag initial state); NFR15 (audit); AR21, AR36, AR46, AR47, AR48, AR49.

---

## Story 0.3.4: Admin UI Migration Reports module — view reports + resolve unmatched records with sign-off

As a **named migration owner** (Reference Data owner from Epic 0.2 or Users/Roles owner from Epic 0.3),
I want a Migration Reports view in `nji-admin-ui` to review the latest ETL reconciliation reports, drill into unmatched records, apply handling decisions (drop / hold / manual map), and sign off on the migration,
So that **the named-owner sign-off workflow** (per FR57 + Risk #13/#14) is properly auditable and unmatched user records cannot pass into NJI without an explicit decision.

**Acceptance Criteria:**

**Given** an admin with `migration-owner` role signs into `nji-admin-ui`,
**When** they open `/migration-reports`,
**Then** they see a list of available reconciliation reports grouped by stream (Reference Data + Users/Roles) and date,
**And** each report row shows status (Pending / Signed off / Rejected), matched/unmatched counts, owner identity if signed,
**And** the list is fetched from a new `nji-architecture/migration-reports` API exposure (engineer to decide at story implementation: read directly from the `nji-architecture/migration/reports/` directory via a thin file-system API, OR expose a per-service endpoint — recommend a single read-only endpoint on `nji-authorisation` to centralise the auth/audit surface).

**Given** the owner opens a Users/Roles reconciliation report,
**When** the detail view renders,
**Then** they see the report's summary (matched / unmatched / anomalies counts),
**And** a list of unmatched rows with reason, raw APEX data, and a "handling decision" dropdown (drop / hold / manual map),
**And** for "manual map", a text input accepts the IdP principal email to bind to.

**Given** the owner applies decisions to all unmatched rows,
**When** they click "Submit decisions",
**Then** each decision is persisted to the ETL's reconciliation state (per Story 0.3.3),
**And** a confirmation banner shows the per-decision counts.

**Given** all unmatched rows have decisions,
**When** the owner clicks "Sign off",
**Then** a confirmation modal appears with the summary,
**And** on confirm, the sign-off is recorded with owner identity, timestamp, report version,
**And** the report status moves to "Signed off",
**And** downstream Phase 1+ consumption is no longer operationally blocked (enforcement gate at this stage is operational; can be wired to an activation flag in a follow-up).

**Given** axe-core checks run on every page in the module,
**When** the scans complete,
**Then** no new WCAG 2.2 AA violations,
**And** keyboard navigation works through the report list, unmatched-rows table, decision dropdowns, manual-map input, and confirmation modal.

**Given** Playwright E2E coverage,
**When** `tests/e2e/migration-reports.spec.ts` runs,
**Then** it covers: list → open report → apply drop/hold/manual-map decisions → submit → sign off → report status updates to signed off,
**And** also covers the rejection path (owner rejects with mandatory reason).

**References:** FR4 (admin role), FR57 (sign-off workflow), FR56 (admin stack); NFR12, NFR13, NFR15, NFR17, NFR18, NFR19; AR42–AR45, AR47, AR48.
