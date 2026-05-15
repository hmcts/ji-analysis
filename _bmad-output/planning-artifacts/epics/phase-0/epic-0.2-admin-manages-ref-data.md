---
parent: 'epics/phase-0/index.md'
epic: 0.2
title: 'Admin manages reference data with named-owner migration sign-off'
storyCount: 5
status: 'validated'
---

# Epic 0.2: Admin manages reference data with named-owner migration sign-off

**User outcome:** An admin user signs into `nji-admin-ui`, opens Reference Data maintenance, can view and edit Regions, Offices, judicial vocabularies (12 controlled lists), and calendar / financial-year boundaries. Phase 0 ETL has loaded initial data from APEX; named owners review the migration reconciliation report and sign off before downstream phases consume the data.

**Vertical slice:**
- `nji-reference-data` backend service scaffolded (per AR2–AR4)
- 15 Reference Data tables (`regions`, `offices`, `calendar_periods` + 12 vocabulary tables) with service-owned Flyway migrations (per AR18, AR20)
- Per-service `SELECT` grants pattern established for direct-SQL reads (per FR7 / Principle 2)
- Reference Data maintenance API exposing versioned writes (FR6) with admin-gated `POST/PUT`
- `nji-admin-ui` repo scaffolded (React + TypeScript + Vite; same stack as `nji-ui`, separate Helm + Static Web App + distinct hostname per AR42–AR45b)
- Admin UI Reference Data module (`modules/reference-data/`) with list/edit/create flows + named-owner sign-off workflow
- Reference Data ETL stream at `nji-architecture/migration/reference-data/` (per AR46–AR48): reads APEX dumps, transforms to NJI shape, loads via Reference Data API
- Per-run reconciliation report under `migration/reports/` (Risk #13 mitigation)
- First end-to-end exercise of API-as-Product standards: URL versioning (`/v1/reference-data/...`), OpenAPI 3.x spec published as Maven artefact, RFC 9457 problem-details errors, RFC 9745 `Deprecation` + RFC 8594 `Sunset` deprecation signalling
- First Postman collection for Phase 0 published under `postman/nji-reference-data-phase0.postman_collection.json` (NFR42 first instance)

**FRs covered:** FR4 (admin-foundation portion), FR6, FR7, FR57 (Reference Data portion), FR59, FR60

**Key NFRs:** NFR14 (no forbidden data — vocabularies contain no case/bank data by construction), NFR17–NFR19 (admin UI WCAG), NFR40 (admin UI independently deployable from business UI), NFR42 (Postman collection)

---

## Story 0.2.1: Scaffold `nji-reference-data` service + 15 Reference Data tables via Flyway

As a **platform engineer**,
I want to scaffold `nji-reference-data` following the established pattern from Story 0.1.1 and create the 15 Reference Data tables via service-owned Flyway migrations,
So that **all other NJI services can read Reference Data via direct SQL on SELECT grants** (per FR7 revised, AR22) without each service having to own a copy of the schema.

**Acceptance Criteria:**

**Given** the engineer runs `nji-scaffold.sh nji-reference-data`,
**When** the scaffold completes,
**Then** the new repo follows all conventions from Story 0.1.1 (Spring Boot 4, Helm chart, GitHub Actions, Actuator, structured logs, OpenAPI tooling, Spectral, ArchUnit, Spotless, Checkstyle, Pact, Postman),
**And** Group ID is `uk.gov.hmcts.nji`, artefact is `nji-reference-data`, package is `uk.gov.hmcts.nji.referencedata`, default port is 8082,
**And** initial commit is *"Scaffold NJI reference-data from HMCTS starter"* (per AR4).

**Given** the engineer adds Flyway migration `V1__init_reference_data_schema.sql`,
**When** the migration runs,
**Then** 15 Reference Data tables exist with schemas per `architecture/data-tables.md`: `regions`, `offices`, `calendar_periods`, plus 12 vocabulary tables covering judge types, work types, ticket types, session types, booking types, absence types, fee entitlement types, location types, court types, jurisdictional categories, judicial vocabularies, and financial-year boundaries,
**And** `nji_reference_data` DB role owns the tables (per AR19),
**And** ArchUnit fitness function in CI verifies no other service writes to these tables.

**Given** the migration includes SELECT grants for downstream service DB roles,
**When** Flyway applies the grants,
**Then** every NJI service DB role (`nji_authorisation`, `nji_notification`, and placeholders for future domain service roles) has `SELECT` on all 15 Reference Data tables (per FR7 revised, AR22),
**And** the grants are tested by a CI integration test asserting each placeholder role can SELECT.

**Given** the service is deployed to dev AKS,
**When** `/actuator/health` is queried,
**Then** the response is `200 OK`,
**And** Application Insights receives the service's structured logs (per NFR27),
**And** `/actuator/info` returns Git metadata (per NFR28).

**References:** FR7, FR8 (re-uses `configuration_values`), FR59, FR60; NFR25–NFR28, NFR31, NFR40; AR2–AR22.

---

## Story 0.2.2: Reference Data API exposes admin-gated CRUD with versioning, OpenAPI, RFC 9457 errors, deprecation signalling

As an **API consumer** (admin UI now; downstream services in Phase 1+),
I want a versioned Reference Data API with admin-gated writes and public reads, full OpenAPI spec, RFC 9457 error envelopes, and APIM-injected deprecation headers,
So that **Reference Data is the single writer for the controlled lists** (per revised FR7) and the API-as-Product standards are validated on Reference Data before any domain service is built (per PRD Key Characteristic 4 / D1).

**Acceptance Criteria:**

**Given** `nji-reference-data` is scaffolded per Story 0.2.1,
**When** the engineer implements read endpoints,
**Then** `GET /v1/reference-data/regions`, `/offices`, `/judicial-vocabularies`, `/calendar` return `200 OK` with structured JSON (per FR6 read surface, AR38),
**And** read endpoints are protected by `JWTFilter` (any authenticated principal can read; per NFR13),
**And** OpenAPI spec generated by springdoc lists all read endpoints with full request/response schemas.

**Given** the engineer implements write endpoints,
**When** an authenticated user with `RSU` or `system-admin` role calls `POST /v1/reference-data/regions` with a valid body,
**Then** the response is `201 Created` with the created resource and a `Location` header (per FR6 write surface),
**And** the change enters a "pending" state requiring named-owner sign-off (per FR6 named-owner workflow),
**And** an audit row is written recording who/when/what changed,
**And** non-admin authenticated users get `403 Forbidden` with RFC 9457 problem-details (per NFR13).

**Given** the engineer implements validation,
**When** a malformed request reaches a write endpoint,
**Then** the response is `400 Bad Request` with an RFC 9457 problem-details body containing `type`, `title`, `status`, `detail`, `instance`, and a per-field errors extension (per AR37, NFR39),
**And** validation rules align with table constraints (e.g. uniqueness on region code, valid date ranges on calendar periods).

**Given** the OpenAPI spec is generated and Spectral lint runs in CI,
**When** the spec is built,
**Then** the spec passes Spectral lint (per AR17),
**And** the spec is published to internal Maven as `uk.gov.hmcts.nji:api-nji-reference-data:1.0.0` (per AR8),
**And** Swagger UI is exposed for developer browsing (ops-restricted at APIM).

**Given** APIM is configured for `nji-reference-data` per AR27 + AR39,
**When** a response leaves APIM to the client,
**Then** rate-limit headers are present per APIM policy,
**And** `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) headers are injected on endpoints flagged in the OpenAPI spec as `deprecated: true` (none at Phase 0; mechanism verified by a test endpoint),
**And** `/actuator/*` paths are blocked at APIM (per AR33).

**Given** the engineer publishes the first Phase 0 Postman collection,
**When** the collection runs in CI,
**Then** `postman/nji-reference-data-phase0.postman_collection.json` exercises every endpoint in the API,
**And** the collection covers happy path + 401 + 403 + 400 + 404 cases (per NFR42),
**And** the collection is versioned alongside the service.

**References:** FR4 (admin-gated foundation), FR6, FR7, FR59, FR60; NFR12–NFR16, NFR39, NFR42; AR8, AR17, AR21, AR27, AR33, AR34, AR37, AR38, AR39, AR41.

---

## Story 0.2.3: Scaffold `nji-admin-ui` repo with admin-distinct accent and independent deployment

As a **front-end engineer**,
I want to scaffold `nji-admin-ui` following the `nji-ui` pattern from Story 0.1.4 but as a separate repo with distinct visual treatment and independent deployment,
So that **admin workflows are unambiguously separated from business-user workflows** (per AR42, AR45b) — different hostname, different review team, different release cadence, no risk of admin screens leaking into business navigation.

**Acceptance Criteria:**

**Given** the engineer initialises the `nji-admin-ui` repo from the same Vite React+TypeScript template as `nji-ui`,
**When** scaffolding completes,
**Then** the repo has the same baseline as Story 0.1.4 (React + TypeScript + Vite + Vitest + Playwright; GOV.UK Design System base; TanStack Query; OpenAPI client generation tooling per AR43),
**And** the repo is private under HMCTS org with branch protection on `main`,
**And** `CODEOWNERS` defines a distinct admin-focused review team (per AR42 rationale 3).

**Given** the engineer applies the visual differentiation,
**When** the foundation renders,
**Then** the header and primary navigation use a distinct accent colour (configurable token; recommendation: HMCTS amber or charcoal) so the admin surface is visually unambiguous (per AR42),
**And** a header banner reads *"NJI Administration"* with the user's email and sign-out,
**And** the `<PageLayout>` is duplicated (not shared) with `nji-ui` per the polyrepo discipline (per AR44).

**Given** the engineer implements the auth wrapper,
**When** wrapper is complete,
**Then** `HmctsIdpProvider`, `ProtectedRoute`, `useAuth`, HTTP client with RFC 9457 handling are duplicated from `nji-ui` (not imported as a shared package — per AR44),
**And** `ProtectedRoute` checks the authenticated principal's roles via `useAuth().user.roles` and rejects non-admin users with a `403` view (per AR44).

**Given** the engineer configures independent deployment,
**When** the PR merges to `main`,
**Then** the bundle deploys to a separate Azure Static Web App from `nji-ui` (per AR45b),
**And** the dev environment uses a distinct hostname (configurable in production to `admin.nji.hmcts.gov.uk`),
**And** the deploy pipeline can release `nji-admin-ui` without touching `nji-ui` (verified by deploying a no-op change to `nji-admin-ui` while watching the `nji-ui` deployment timestamp remain unchanged).

**Given** accessibility CI is configured,
**When** axe-core checks run in `ci.yml`,
**Then** the build fails on any new WCAG 2.2 AA violation,
**And** keyboard navigation through the admin chrome is verified by a Playwright smoke test.

**Given** the first Admin UI E2E suite is written,
**When** `tests/e2e/admin-foundation.spec.ts` runs in CI,
**Then** it covers: unauthenticated redirect → sign-in → non-admin user blocked with `403` view → admin user lands on admin Home → sign-out flow.

**References:** FR4 (admin foundation), FR56 (admin stack); NFR17, NFR18, NFR19, NFR31, NFR40; AR42–AR45b.

---

## Story 0.2.4: Admin UI Reference Data maintenance module — list, view, edit, create, sign-off

As a **named Reference Data owner** (RSU lead or judicial-vocabulary owner),
I want to list, view, edit, and create Reference Data entries through `nji-admin-ui`, with a named-owner sign-off workflow for changes,
So that **Reference Data evolves under explicit owner accountability** (per FR6) — critical for Risk #13 (Reference Data + Users/Roles migration correctness).

**Acceptance Criteria:**

**Given** an admin signs into `nji-admin-ui` (Story 0.2.3),
**When** they open `/reference-data`,
**Then** they see a list of Reference Data categories: Regions, Offices, Calendar Periods, and 12 judicial vocabularies,
**And** selecting a category renders a paginated list with search and filter inputs,
**And** the auto-generated TypeScript client from `nji-reference-data` OpenAPI handles the HTTP calls (per AR43).

**Given** the admin opens an entry,
**When** they edit a field and submit,
**Then** the change enters a "pending sign-off" state (per FR6 workflow + Story 0.2.2 backend),
**And** the UI shows a notification *"Change submitted — awaiting named-owner sign-off"*,
**And** the entry appears in the admin's "Pending Changes" view.

**Given** a named owner views the "Pending Changes" queue,
**When** they review a pending change and click "Approve",
**Then** the API marks the change as approved, the audit log records who/when/why,
**And** the change becomes live in Reference Data,
**And** the admin who submitted the change receives a UI confirmation,
**And** a named owner can also "Reject" with a mandatory reason field.

**Given** validation errors come back from the API,
**When** the form receives an RFC 9457 problem-details response with field-level errors,
**Then** the UI renders the field-level error messages inline,
**And** the title/detail render in a page-level alert,
**And** the user can fix and resubmit.

**Given** accessibility checks run on every page in the module,
**When** axe-core scans the list, edit, and pending-changes views,
**Then** no new WCAG 2.2 AA violations,
**And** keyboard navigation works through the table, form, and modal interactions,
**And** ARIA labels are correct on tabbed content (per NFR18).

**Given** Playwright E2E coverage for the module,
**When** `tests/e2e/reference-data.spec.ts` runs,
**Then** it covers: list → search → edit → submit → pending state → named-owner approve → live state,
**And** also covers rejection path with mandatory reason,
**And** also covers validation-error path.

**References:** FR4 (admin role enforcement), FR6 (maintenance + sign-off), FR56 (admin stack); NFR12, NFR13, NFR14, NFR17, NFR18, NFR19; AR42–AR45.

---

## Story 0.2.5: Phase 0 Reference Data ETL — APEX dumps to NJI via API + reconciliation report + owner sign-off

As a **Reference Data named owner**,
I want the Phase 0 ETL to load Reference Data from APEX into NJI via the Reference Data API (not direct DB writes) and produce a per-run reconciliation report for me to sign off on,
So that **the migration's correctness is auditably gated by domain owners** (per FR57, D3, Risk #13) and re-runs are idempotent for incremental waves.

**Acceptance Criteria:**

**Given** the engineer creates the ETL at `nji-architecture/migration/reference-data/`,
**When** the ETL is implemented,
**Then** it reads APEX dumps (CSV files extracted from APEX, format defined per the migration spec at `nji-architecture/migration/reference-data/spec.md`),
**And** it transforms rows into NJI shapes per the mapping tables defined in `architecture/data-tables.md`,
**And** it loads data via `POST /v1/reference-data/...` admin endpoints with a service-token (per AR46, AR36),
**And** it is NOT a Flyway migration (NJI Flyway owns NJI DDL only; APEX-to-NJI data transform is a separate programme-level activity per FR57 framing).

**Given** the ETL completes a run,
**When** the reconciliation report is generated,
**Then** the report at `nji-architecture/migration/reports/reference-data/{run-date}.md` shows:
   • source-row counts per APEX dump
   • target-row counts per NJI table
   • per-table diff (added / updated / unchanged / skipped)
   • anomalies (e.g. unmapped values, validation failures, character-encoding issues)
   • a "named owner sign-off required" footer,
**And** the report is also exposed via the Admin UI Migration Reports module (placeholder per AR42 — promoted to real implementation in Story 0.3.4 alongside the Users/Roles equivalent).

**Given** the ETL is re-run on the same APEX dump,
**When** the second run completes,
**Then** it is idempotent — no duplicate rows, no spurious updates (per AR49),
**And** the reconciliation report shows zero new changes.

**Given** the ETL is re-run after an APEX-side update is dumped,
**When** the second run completes,
**Then** only the changed rows are updated,
**And** the reconciliation report shows the per-table diff.

**Given** a named owner reviews the reconciliation report,
**When** they sign off via a versioned commit to `nji-architecture/migration/reports/reference-data/signoffs/{run-date}-{owner-handle}.md` (containing owner identity, timestamp, the specific report version signed off, and a short approval note),
**Then** the sign-off is recorded in git history (immutable audit trail),
**And** the commit is co-signed by a second reviewer per the `CODEOWNERS` policy on `migration/reports/`,
**And** unsigned reports block downstream Phase 1+ consumption of Reference Data (enforced operationally at this stage by the Phase 1 first-consumer story; the same artefact also feeds the UI sign-off surface that Story 0.3.4 later adds — but Story 0.2.5 does **not** depend on Story 0.3.4 being delivered first).

**Given** the ETL encounters an anomaly it cannot resolve (e.g. an APEX value not in the NJI controlled list),
**When** the run halts on the anomaly,
**Then** the row is logged with detail to a `migration/reports/reference-data/anomalies/{run-date}.md` file,
**And** the run continues with the remaining rows,
**And** the reconciliation report includes the anomaly count and a link to the anomalies file,
**And** the named owner can decide handling (correct in NJI controlled list / correct in APEX dump / drop) before re-run.

**References:** FR6 (load via API per FR6 write surface), FR7 (no direct DB writes), FR57 (ETL framing); NFR15 (audit), NFR40 (ETL independent of services); AR21, AR36, AR46, AR47, AR48, AR49.
