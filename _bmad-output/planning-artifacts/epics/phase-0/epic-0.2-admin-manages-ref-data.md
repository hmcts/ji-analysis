---
parent: 'epics/phase-0/index.md'
epic: 0.2
title: 'Reference data is SQL-loaded and served read-only'
storyCount: 3
status: 'validated'
revisedAt: '2026-05-15'
revisionNote: 'Admin UI removed from Phase 0 (pushed post-MVP). Reference Data API becomes read-only; ETL loads via direct SQL instead of via the API.'
---

# Epic 0.2: Reference data is SQL-loaded and served read-only

**User outcome:** Reference Data (Regions, Offices, judicial vocabularies, calendar / financial-year boundaries) is loaded into NJI via a direct-SQL ETL with named-owner sign-off, and is queryable read-only by downstream NJI services via a versioned REST API. Named owners approve the migration through versioned git commits — **no admin UI is in scope for MVP** (per the 2026-05-15 scope decision). Ongoing post-load updates happen operationally via direct SQL; a maintenance UI is on the post-MVP roadmap.

**Vertical slice:**
- `nji-reference-data` backend service scaffolded (per AR2–AR4)
- 15 Reference Data tables (`regions`, `offices`, `calendar_periods` + 12 vocabulary tables) with service-owned Flyway migrations (per AR18, AR20)
- Per-service `SELECT` grants pattern established for direct-SQL reads (per FR7 / Principle 2)
- Reference Data **read-only** REST API: `GET` endpoints for consumption by `nji-ui`, downstream services, and OpenAPI clients. **No `POST`/`PUT`/`DELETE` endpoints** at Phase 0 — writes happen only via Flyway/SQL (the ETL load + future operational changes by DBA)
- Reference Data ETL stream at `nji-architecture/migration/reference-data/` (per AR46–AR48): reads APEX dumps, transforms to NJI shape, **loads via direct SQL INSERT statements** (not via API — API is read-only). The ETL is NOT a Flyway migration; it's a programme-level data-transform script per FR57 framing.
- Per-run reconciliation report under `migration/reports/reference-data/{run-date}.md` (Risk #13 mitigation)
- Named-owner sign-off via versioned commits to `migration/reports/reference-data/signoffs/{run-date}-{owner-handle}.md` with `CODEOWNERS`-enforced two-reviewer policy
- First end-to-end exercise of API-as-Product **read-side** standards: URL versioning (`/v1/reference-data/...`), OpenAPI 3.x spec published as Maven artefact, RFC 9457 problem-details errors, RFC 9745 `Deprecation` + RFC 8594 `Sunset` deprecation signalling
- First Postman collection for Phase 0 published under `postman/nji-reference-data-phase0.postman_collection.json` (NFR42 first instance)

**FRs covered:** FR7 (direct-SQL read pattern + SELECT grants), FR57 (Reference Data portion of Phase 0 ETL, now via SQL), FR59 (versioned read API contract), FR60 (structured logs first-exercised here)

**FRs partially covered / deferred:**
- **FR6** — the read API surface and ETL load are in Phase 0; the **RSU maintenance UI surface is post-MVP** (was Story 0.2.4 in the prior plan, removed)
- **FR4** — the auth tables exist and are loaded; the **admin UI for updating role / Region/Area assignments is post-MVP** (was Epic 0.3 stories in the prior plan, removed)

**Key NFRs:** NFR14 (no forbidden data — vocabularies contain no case/bank data by construction), NFR40 (service independently deployable), NFR42 (Postman collection). **NFR17–NFR19 (accessibility) do not apply in Phase 0** because no UI surface for this domain is delivered; they re-engage when the maintenance UI ships post-MVP.

**Out of scope for Phase 0 (deferred post-MVP):**
- Admin-gated `POST/PUT/DELETE` endpoints on Reference Data API
- `nji-admin-ui` Reference Data maintenance module with named-owner sign-off workflow
- Sign-off UI surface (sign-off in MVP is via git commits only)

---

## Story 0.2.1: Scaffold `nji-reference-data` service + 15 Reference Data tables via Flyway

As a **platform engineer**,
I want to scaffold `nji-reference-data` following the established pattern from Story 0.1.1 and create the 15 Reference Data tables via service-owned Flyway migrations,
So that **all other NJI services can read Reference Data via direct SQL on SELECT grants** (per FR7 revised, AR22) without each service having to own a copy of the schema.

**Acceptance Criteria:**

**Given** the engineer has manually pre-created the private GitHub repo `nji-reference-data` with branch protection on `main` via the GitHub web UI (per `nji-architecture/runbooks/github-setup.md`; the `gh` CLI is **not** available — see Story 0.1.1 for the canonical manual-setup pattern),
**And** runs `nji-scaffold.sh nji-reference-data`,
**When** the scaffold completes,
**Then** the new repo follows all conventions from Story 0.1.1 (Spring Boot 4, Helm chart, GitHub Actions, Actuator, structured logs, OpenAPI tooling, Spectral, ArchUnit, Spotless, Checkstyle, Pact, Postman),
**And** Group ID is `uk.gov.hmcts.nji`, artefact is `nji-reference-data`, package is `uk.gov.hmcts.nji.referencedata`, default port is 8082,
**And** initial commit is *"Scaffold NJI reference-data from HMCTS starter"* (per AR4).

**Given** the engineer adds Flyway migration `V1__init_reference_data_schema.sql`,
**When** the migration runs,
**Then** 15 Reference Data tables exist with schemas per `architecture/data-tables.md`: `regions`, `offices`, `calendar_periods`, plus 12 vocabulary tables covering judge types, work types, ticket types, session types, booking types, absence types, fee entitlement types, location types, court types, jurisdictional categories, judicial vocabularies, and financial-year boundaries,
**And** `nji_reference_data` DB role owns the tables (per AR19),
**And** ArchUnit fitness function in CI verifies no other service has WRITE permission on these tables.

**Given** the migration includes SELECT grants for downstream service DB roles,
**When** Flyway applies the grants,
**Then** every NJI service DB role (`nji_authorisation`, `nji_notification`, and placeholders for future domain service roles) has `SELECT` on all 15 Reference Data tables (per FR7 revised, AR22),
**And** the grants are tested by a CI integration test asserting each placeholder role can SELECT,
**And** no role other than `nji_reference_data` itself has INSERT/UPDATE/DELETE on these tables.

**Given** the service is deployed to dev AKS,
**When** `/actuator/health` is queried,
**Then** the response is `200 OK`,
**And** Application Insights receives the service's structured logs (per NFR27),
**And** `/actuator/info` returns Git metadata (per NFR28).

**References:** FR7, FR8 (re-uses `configuration_values`), FR59, FR60; NFR25–NFR28, NFR31, NFR40; AR2–AR22.

---

## Story 0.2.2: Reference Data read-only REST API with versioning, OpenAPI, RFC 9457 errors

As an **API consumer** (`nji-ui` now; downstream services in Phase 1+),
I want a versioned **read-only** Reference Data API with full OpenAPI spec, RFC 9457 error envelopes, and APIM-injected deprecation headers,
So that **Phase 1+ services can query controlled lists at runtime** and the API-as-Product read-side standards are validated on Reference Data before any domain service is built (per PRD Key Characteristic 4 / D1). Write operations are explicitly out of scope at Phase 0 — Reference Data updates happen only via Flyway migrations (DDL) and direct SQL during ETL load and ongoing operational maintenance.

**Acceptance Criteria:**

**Given** `nji-reference-data` is scaffolded per Story 0.2.1,
**When** the engineer implements read endpoints,
**Then** `GET /v1/reference-data/regions`, `/offices`, `/judicial-vocabularies`, `/calendar` return `200 OK` with structured JSON,
**And** read endpoints are protected by `JWTFilter` (any authenticated principal can read; per NFR13),
**And** OpenAPI spec generated by springdoc lists all read endpoints with full request/response schemas,
**And** **no write endpoints** (`POST`, `PUT`, `PATCH`, `DELETE`) are implemented at Phase 0 — controller layer rejects with `405 Method Not Allowed` and an RFC 9457 problem-details body explaining "Reference Data writes are operationally managed; admin UI deferred post-MVP".

**Given** the engineer implements pagination + filtering,
**When** a consumer queries `GET /v1/reference-data/offices?region=northern&page=2&size=50`,
**Then** the response includes paginated data with a standard envelope `{items, page, size, totalElements, totalPages}`,
**And** invalid query parameters return `400 Bad Request` with RFC 9457 problem-details (per AR37, NFR39).

**Given** the engineer implements validation,
**When** a malformed query reaches a read endpoint (e.g. invalid date range, unknown region code),
**Then** the response is `400 Bad Request` with an RFC 9457 problem-details body containing `type`, `title`, `status`, `detail`, `instance`,
**And** the error is logged via structured JSON with correlation ID (per AR32).

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
**Then** `postman/nji-reference-data-phase0.postman_collection.json` exercises every read endpoint in the API,
**And** the collection covers happy path + 400 (invalid query) + 401 (unauthenticated) + 405 (write attempt) (per NFR42),
**And** the collection is versioned alongside the service.

**References:** FR6 (read-side surface only — UI maintenance is post-MVP), FR7, FR59, FR60; NFR12, NFR13, NFR14, NFR39, NFR42; AR8, AR17, AR27, AR33, AR34, AR37, AR38, AR39, AR41.

**Explicitly NOT in scope (deferred post-MVP):**
- Admin write endpoints (`POST/PUT/PATCH/DELETE`)
- Named-owner sign-off API workflow (UI deferred; sign-off in MVP is via git commits on the ETL reconciliation reports)
- Pending-change queue + approval API

---

## Story 0.2.3: Phase 0 Reference Data ETL — APEX dumps via direct SQL + reconciliation report + owner sign-off

As a **Reference Data named owner** (RSU lead or judicial-vocabulary owner),
I want the Phase 0 ETL to load Reference Data from APEX directly via SQL INSERT statements and produce a per-run reconciliation report for me to sign off on via a versioned git commit,
So that **the migration's correctness is auditably gated by domain owners** (per FR57, D3, Risk #13), re-runs are idempotent for incremental waves, and the workflow doesn't depend on an admin UI (which is now post-MVP).

**Acceptance Criteria:**

**Given** the engineer creates the ETL at `nji-architecture/migration/reference-data/`,
**When** the ETL is implemented,
**Then** it reads APEX dumps (CSV files extracted from APEX, format defined per the migration spec at `nji-architecture/migration/reference-data/spec.md`),
**And** it transforms rows into NJI shapes per the mapping tables defined in `architecture/data-tables.md`,
**And** it **loads data via direct SQL INSERT statements** using the `nji_reference_data` DB role (the ETL runner is granted appropriate write access through a one-time DBA-issued credential held in Azure Key Vault),
**And** it is NOT a Flyway migration (NJI Flyway owns NJI DDL only; APEX-to-NJI data transform is a separate programme-level activity per FR57 framing),
**And** it does NOT call the Reference Data API (which is read-only per Story 0.2.2).

**Given** the ETL completes a run,
**When** the reconciliation report is generated,
**Then** the report at `nji-architecture/migration/reports/reference-data/{run-date}.md` shows:
   • source-row counts per APEX dump
   • target-row counts per NJI table
   • per-table diff (added / updated / unchanged / skipped)
   • anomalies (e.g. unmapped values, validation failures, character-encoding issues)
   • a "named owner sign-off required" footer with instructions to commit a signoff file.

**Given** the ETL is re-run on the same APEX dump,
**When** the second run completes,
**Then** it is idempotent — no duplicate rows, no spurious updates (per AR49). Idempotency is enforced via natural-key uniqueness checks before each INSERT (`INSERT ... ON CONFLICT DO NOTHING` for PostgreSQL),
**And** the reconciliation report shows zero new changes.

**Given** the ETL is re-run after an APEX-side update is dumped,
**When** the second run completes,
**Then** only the changed rows are inserted or updated,
**And** the reconciliation report shows the per-table diff,
**And** updates are applied via `INSERT ... ON CONFLICT (natural_key) DO UPDATE SET ...` so deletions in APEX do NOT result in deletions in NJI (NJI is the system of record post-migration).

**Given** a named owner reviews the reconciliation report,
**When** they sign off via a versioned commit to `nji-architecture/migration/reports/reference-data/signoffs/{run-date}-{owner-handle}.md` (containing owner identity, timestamp, the specific report version signed off, and a short approval note),
**Then** the sign-off is recorded in git history (immutable audit trail),
**And** the commit is co-signed by a second reviewer per the `CODEOWNERS` policy on `migration/reports/`,
**And** the absence of a signoff file for the latest report blocks downstream Phase 1+ first-consumer stories from advancing (enforced operationally; the Phase 1 Judge story checks for the signoff before pulling Reference Data).

**Given** the ETL encounters an anomaly it cannot resolve (e.g. an APEX value not in the NJI controlled list),
**When** the run halts on the anomaly,
**Then** the row is logged with detail to `migration/reports/reference-data/anomalies/{run-date}.md`,
**And** the run continues with the remaining rows,
**And** the reconciliation report includes the anomaly count and a link to the anomalies file,
**And** the named owner can decide handling (correct in NJI controlled list / correct in APEX dump / drop) before re-run.

**References:** FR7 (writes via direct SQL not via API), FR57 (ETL framing per D3); NFR15 (audit via git), NFR40 (ETL independent of services); AR21, AR46, AR47, AR48, AR49.

**Explicitly NOT in scope (deferred post-MVP):**
- Admin UI surface for reviewing reconciliation reports (was Story 0.3.4 in the prior plan)
- Web-based sign-off workflow (sign-off in MVP is via git commits only)
