---
parent: 'epics/index.md'
purpose: 'Phase × Area architectural framework — the spine that organises concrete epics across 10 sequential phases'
---

# Phase × Area Framework

NJI is built in **10 sequential phases (0–9+)** per the PRD's Phase-by-Phase Journey Mapping and the architecture's Repository Strategy:

- **Phase 0** is cross-cutting foundations (multiple parallel areas).
- **Phases 1–8** each deliver one service end-to-end (backend + UI module).
- **Phase 9+** is the per-region rollout (wave 1, then subsequent waves).

The first level of grouping below is **Phase** (delivery sequence); the second level is **Area** (the capability or cross-cutting concern that anchors the epic). Within each Area, concrete epics with stories and Gherkin acceptance criteria live in the per-phase folders (e.g. [phase-0/](phase-0/index.md)).

## Epic Phase × Area Summary

| Phase | Area | Component(s) | Primary FR/NFR coverage |
|---|---|---|---|
| **0** | Platform & DevEx | `nji-architecture` (scaffolding), GitHub Actions, APIM, AKS, Application Insights, shared `configuration_values` | FR8, FR59, FR60, NFR25–NFR28, NFR40, NFR42 |
| **0** | Identity & Authorisation | `nji-mock-auth`, `nji-authorisation` | FR1–FR4, NFR12, NFR13 |
| **0** | Reference Data | `nji-reference-data` (backend); maintenance UI in `nji-admin-ui` | FR6, FR7 *(revised)* |
| **0** | Notification | `nji-notification` | FR9, NFR22 |
| **0** | Phase 0 Data Migration ETL | `nji-architecture/migration/` | FR57, FR58 *(data side)* |
| **0** | Business UI Foundation | `nji-ui` (shell, auth, design system) | FR55 *(shell)*, FR56 *(stack)*, NFR17 |
| **0** | Admin UI Foundation | `nji-admin-ui` (shell, auth, design system, Reference Data maintenance, User & Role admin) | FR4 *(UI surface)*, FR6 *(UI surface)*, FR56 *(stack)*, NFR17 |
| **1** | Judge Records & Working Patterns | `nji-judge` + UI module | FR10–FR18 |
| **2** | Absence Workflow | `nji-absence` + UI module | FR19–FR22 |
| **3** | Vacancy & Cover | `nji-vacancy` + UI module | FR23–FR28 |
| **4** | Booking Management | `nji-booking` + UI module | FR29–FR34 |
| **5** | Sitting Management | `nji-sitting` + UI module | FR35–FR40 |
| **6** | Payment Processing & Reconciliation | `nji-payment` + UI module | FR41 *(part)*, FR44, FR46, FR47, NFR21, NFR35 |
| **6** | Payment Batch | `nji-payment-batch` (scheduled) | FR42, FR43, FR45 |
| **7** | Itineraries Read Model | `nji-itinerary` *(no own tables)* + UI views | FR48–FR52, NFR8, NFR37 |
| **8** | MI Feed & Reporting | `nji-mi-feed` *(no own tables)* + Reports UI module | FR53, FR54, NFR23 |
| **9+** | Pilot Rollout & Subsequent Waves | per-region activation, manual UAT, rollback playbook | FR58 *(activation)*, FR61, NFR36, NFR38, NFR41 |

Cross-cutting NFRs (performance NFR1–NFR9, security/data NFR10–NFR16, NFR30–NFR33, accessibility NFR17–NFR19, maintainability NFR39) are inherited by every phase; their architectural support lives in Phase 0 (Platform & DevEx) and is exercised in every domain phase.

## Phase 0 — Foundations

> Phase 0 is the platform smoke-test (per PRD Key Characteristic 4). All API-as-Product standards (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), `Deprecation`/`Sunset`) are exercised on Reference Data writes and Authorisation lookups before any domain service is built.
>
> The seven Areas below are the **architectural map**. The **implementation plan** is the four concrete user-value epics in [phase-0/](phase-0/index.md).

### Phase 0 · Area: Platform & DevEx

**Scope**: Service scaffolding (`nji-scaffold.sh` over HMCTS Crime SpringBoot template), per-service GitHub Actions pipeline (`ci.yml` + `deploy-{env}.yml` + per-region per-wave gated production deploy), OpenAPI/Spectral/ArchUnit/Spotless/Checkstyle tooling, structured Logback JSON logging conventions, OpenTelemetry → Application Insights wiring, shared `configuration_values` infrastructure table managed by `nji-architecture` Flyway baseline, Azure API Management at the edge (rate limits, deprecation headers, `/actuator/*` restriction), AKS UK South multi-AZ HA, Helm chart conventions, Azure Key Vault integration.

**Component(s)**: `nji-architecture` (scaffolding script + ADRs), GitHub Actions workflows, shared Flyway baseline, APIM policies, Helm chart conventions.

**Primary FR/NFR coverage**: FR8, FR59, FR60, NFR25–NFR28, NFR40, NFR42; underpins every AR1–AR45.

### Phase 0 · Area: Identity & Authorisation

**Scope**: `nji-mock-auth` OIDC issuer for non-prod (human users via `authorization_code`; batch components via `client_credentials`; refuses production profile). `nji-authorisation` service owning the 5 auth tables (`auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`). Custom `JWTFilter` pattern in every service that validates JWT against JWKS and calls `POST /authz/check` to populate request-scoped `AuthDetails`. Per-user activation flags (FR58) wired to enable per-region phased cutover. APEX → IdP principal reconciliation per D9 (email primary, employee number fallback).

**Component(s)**: `nji-mock-auth`, `nji-authorisation`.

**Primary FR/NFR coverage**: FR1, FR2, FR3, FR4, FR58 *(flags wired here; activation orchestrated in Phase 9+)*; NFR12 *(revised v2.6)*, NFR13, NFR16, NFR20. *(FR5 is reframed as post-MVP per v2.5; out of scope here.)*

### Phase 0 · Area: Reference Data

**Scope**: `nji-reference-data` service owning the 15 Reference Data tables (`regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables). API for maintenance writes with named-owner sign-off workflow. Per-service DB SELECT grants for direct-SQL reads (per revised FR7 / Principle 2). API-as-Product standards exercised here first (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), deprecation signalling).

**Component(s)**: `nji-reference-data` (backend). The maintenance UI (FR6) lives in `nji-admin-ui`.

**Primary FR/NFR coverage**: FR6 *(backend API only — UI is in admin)*, FR7 *(revised 2026-05-11)*; cross-references NFR39 (API-as-Product), AR18, AR20, AR22.

### Phase 0 · Area: Notification

**Scope**: `nji-notification` service. Outbound transactional email dispatch to HMCTS email infrastructure (SMTP). Delivery log with retry on transient failure. Consumed in Phase 1+ for booking acks (FR32), absence acks (FR20), and the Phase 6 payment-schedule dispatch (FR43).

**Component(s)**: `nji-notification`.

**Primary FR/NFR coverage**: FR9, NFR22.

### Phase 0 · Area: Data Migration ETL

**Scope**: `nji-architecture/migration/` two-stream ETL — `reference-data/` (Regions, Offices, calendar, 12 vocabularies; named-owner sign-off per Risk #13) and `users-roles/` (active APEX users; reconciled to HMCTS IdP by email primary + employee number fallback per D9 / Risk #14). Loads via the Reference Data API and Authorisation API (not direct DB writes; not Flyway). Per-run reconciliation reports under `migration/reports/`; `unmatched/` bucket with explicit handling decisions (drop / hold / manual map). Re-runs are idempotent and gated per wave.

**Component(s)**: `nji-architecture/migration/` (programme-level deliverable; not a runtime service).

**Primary FR/NFR coverage**: FR57; data side of FR58 (initial seed).

### Phase 0 · Area: Business UI Foundation

**Scope**: `nji-ui` repo scaffolded (React + TypeScript + Vite + Vitest + Playwright). GOV.UK Design System base + HMCTS/NJI extensions. OIDC client wrapper (`HmctsIdpProvider`, `ProtectedRoute`, `useAuth`). HTTP client with auth header attachment and RFC 9457 error handling. Business-user Home shell with role-scoped navigation and Region/Area selector (FR55). axe-core CI for WCAG 2.2 AA gate. Per-phase E2E test suite scaffolding under `tests/e2e/`. **Excludes admin workflows** — Reference Data maintenance (FR6) and User & Role admin (FR4) live in `nji-admin-ui`, never here.

**Component(s)**: `nji-ui` (shared + business Home shell only — per-domain modules land in their respective phases).

**Primary FR/NFR coverage**: FR55 *(business Home shell)*, FR56 *(modern UI stack)*, NFR17, NFR18, NFR19.

### Phase 0 · Area: Admin UI Foundation

**Scope** *(new 2026-05-11)*: `nji-admin-ui` repo scaffolded with the **same stack as `nji-ui`** (React + TypeScript + Vite + Vitest + Playwright; GOV.UK Design System base; OIDC client wrapper; RFC 9457 error handling) but **deployed independently** to its own Static Web App / CDN on a distinct hostname (e.g. `admin.nji.hmcts.gov.uk`). Distinct accent in the header/nav to make the admin surface visually unambiguous.

**MVP admin modules built in Phase 0:**

- **Reference Data maintenance** (FR6) — list/edit/create flows for Regions, Offices, judicial vocabularies (12 tables), calendar / financial-year boundaries. Named-owner sign-off workflow per FR6. Calls `nji-reference-data` API.
- **User & Role admin** (FR4) — list and search users (migrated + new), edit role and Region/Area scope assignments, view per-user effective permissions. Calls `nji-authorisation` API.

**Future admin surfaces reserved as module placeholders only** (not built at MVP):

- `modules/activation/` — per-region activation flag dashboard (FR58 admin side)
- `modules/migration-reports/` — Phase 0 reconciliation report viewer (FR57)
- `modules/audit/` — post-MVP user-action audit viewer (D7 roadmap)

**Why a separate repo, not just a separate route inside `nji-ui`:**

1. **Audience separation** — admin role is a system administrator, not RSU/Court/Judge/Finance/MI. Different mental model, different training, different change-management posture.
2. **Independent rollout** — admin surface changes (e.g. adding a new vocabulary table) can deploy without touching the business surface or vice versa.
3. **CODEOWNERS** — distinct review teams.
4. **No accidental nav-leakage** — admin-only screens cannot accidentally appear in a business user's navigation via misconfiguration. Authorisation gating is enforced server-side too, but the repo-level boundary is defence-in-depth.
5. **Consistency with backend polyrepo discipline** — same logic as the per-service backend repos: minimise shared code, accept duplication, gain independence.

**Component(s)**: `nji-admin-ui` (full repo: shared + Reference Data module + User & Role module at MVP).

**Primary FR/NFR coverage**: FR4 *(UI surface)*, FR6 *(UI surface)*, FR56 *(stack)*, NFR17, NFR18, NFR19. Also AR42–AR45b.

→ **Phase 0 concrete epics + stories:** [phase-0/](phase-0/index.md)

## Phase 1 — Judge

### Phase 1 · Area: Judge Records & Working Patterns

**Scope**: `nji-judge` backend service + `judge/` UI module in `nji-ui`. Judge profile CRUD (search/filter, personal details, judge type, base office, active/inactive, role-specific data). Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split (100% sum constraint), per-day work-type pattern. Forward-sitting generation up to next 31st March from working pattern, preserving prior absences. Tickets per judge role. Full-time ↔ part-time conversion. Same-Region base-location switching (cross-Region is out-of-system). Off-circuit / cross-Region judge linking for booking purposes. Demo: Journey *(stakeholder per-module demo of Judge management)*.

**Component(s)**: `nji-judge`, `nji-ui/src/modules/judge/`.

**Primary FR/NFR coverage**: FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18.

## Phase 2 — Absence

### Phase 2 · Area: Absence Workflow

**Scope**: `nji-absence` backend + `absence/` UI module. Absence recording (start/end date, partial-day, type from controlled list, NTBF flag). Auto-confirmed (judicial team) vs confirmation-required (Court / judge) distinction; confirmation can trigger acknowledgement email via Notification. Sickness extension (no new record) vs non-sickness (new record required). NTBF and *needs fee-paid cover* flags. Hook to Vacancy auto-creation (Vacancy itself lives in Phase 3 — Phase 2 stubs the call; Phase 3 wires it).

**Component(s)**: `nji-absence`, `nji-ui/src/modules/absence/`.

**Primary FR/NFR coverage**: FR19, FR20, FR21, FR22.

## Phase 3 — Vacancy

### Phase 3 · Area: Vacancy & Cover

**Scope**: `nji-vacancy` backend + `vacancy/` UI module. Auto-creation from approved absence with cover (R4, pre-populated with judge type, work type, ticket, dates). Standalone vacancies. Per-day breakdown editing (cancel individual days with captured reason; extend / shorten period). `markFilled` endpoint called by Booking (Phase 4) — implemented as a direct DB UPDATE per architecture Principle 1 with explicit cross-service grants. Vacancy days locked once a booking is recorded. Fee-paid judge filter as advertising hint (advertising itself is out-of-system). Cancel / close.

**Component(s)**: `nji-vacancy`, `nji-ui/src/modules/vacancy/`.

**Primary FR/NFR coverage**: FR23, FR24, FR25, FR26, FR27, FR28.

## Phase 4 — Booking

### Phase 4 · Area: Booking Management

**Scope**: `nji-booking` backend + `booking/` UI module. Fee-paid booking creation (linked to vacancy or standalone), capturing judge, court, date, session type, booking type, work type. Same-transaction `Vacancy.markFilled` orchestration (R5, Principle 1 — in-process direct DB UPDATE via per-service grant). Status tracking (planned / provisional / confirmed / cancelled / rejected) with cancellation reason. Booking acknowledgement emails to fee-paid judges (batched overnight or *Create and Email Now*). Y/N answer at booking time when fee entitlement is *Ask when booking*. Double-booking prevention via DB unique constraints over overlapping sessions (FR34).

**Component(s)**: `nji-booking`, `nji-ui/src/modules/booking/`.

**Primary FR/NFR coverage**: FR29, FR30, FR31, FR32, FR33, FR34.

## Phase 5 — Sitting

### Phase 5 · Area: Sitting Management

**Scope**: `nji-sitting` backend + `sitting/` UI module. Planned-sitting generation from working patterns (court, date, work type). Region/Office/judge-type/judge/date-range filtering. Confirmation (took-place / cancelled / rejected) with actual work-type recording. AM/PM session split within a single day (different work types). Ad-hoc sittings for salaried judges (including DJ(MC)s and Legal Advisers in County Courts). Verifier sign-off; once verified, data is read-only. Post-verification amendment via a UI **re-open** action gated by RBAC (RSU Admin only at MVP, distinct from confirmer and from standard Verifier) with mandatory justification and full audit — no external RFC ticketing.

**Component(s)**: `nji-sitting`, `nji-ui/src/modules/sitting/`.

**Primary FR/NFR coverage**: FR35, FR36, FR37, FR38, FR39, FR40.

> **End-of-Phase-5 demo gate**: Journey 2 (Court daily sitting confirmation) becomes demoable.

## Phase 6 — Payment

### Phase 6 · Area: Payment Processing & Reconciliation

**Scope**: `nji-payment` synchronous backend + `payment/` UI module. Authorised users list confirmed bookings and salaried sittings filterable by Region/Office/judge/date range/lifecycle status. Generated schedule review (pre/post dispatch). Reconciliation marking (Finance / RSU) with notes for mismatches; once fully reconciled, payment cannot be re-requested. Versioned content-type API for the payment schedule (`application/vnd.hmcts.jfeps+json` vs `+xlsx`). Hard architectural constraints: **no bank details** (FR47), **no case-level data**.

**Component(s)**: `nji-payment` (sync API), `nji-ui/src/modules/payment/`.

**Primary FR/NFR coverage**: FR41 *(list/review surface)*, FR44, FR46, FR47, NFR21, NFR35.

### Phase 6 · Area: Payment Batch

**Scope**: `nji-payment-batch` scheduled component (configurable cron; typically end-of-week). Authenticates via OAuth `client_credentials` against `nji-mock-auth` (non-prod) — production service-principal issuer deferred per gaps.md G7.1 (default recommendation: Azure Workload Identity). SQL JOIN over confirmed bookings + sittings without an existing payment record. Generates JFEPS-compatible Excel and dispatches to Payment Authoriser via `nji-notification` (using its service-principal token). Natural-key uniqueness on `(payment_cycle_id, booking_id)` for idempotent re-runs. No user interaction. Operational contingency to fall back to manual handling within a payment cycle if NJI is unavailable.

**Component(s)**: `nji-payment-batch` (deployed alongside `nji-payment`).

**Primary FR/NFR coverage**: FR42 *(revised v2.6)*, FR43 *(revised v2.6)*, FR45.

> **End-of-Phase-6 demo gate**: Journey 1 (RSU cover-creation through payment — the canonical operational cycle) becomes demoable.

## Phase 7 — Itineraries

### Phase 7 · Area: Itineraries Read Model

**Scope**: `nji-itinerary` backend + Itinerary UI views in `nji-ui`. **No own tables** — SQL JOINs across `judges`, `absences`, `vacancies`, `bookings`, `sittings`. Court Itinerary (monthly / annual for Office + Financial Year + Month). Judge Itinerary scoped by Authorisation per R2 (judges see only their own; courts see their office; RSU sees their region). Forward Look across Region with paged / filtered access. Clickable drill into underlying record (Sitting, Absence, Vacancy, Booking). Copy / export to Excel and PDF. Strategy A degraded-mode contract: if NFR8 (≤ 30 s p95) is breached, fall back to Strategy C cached projection (designed but not built unless Phase 7 measurement shows the breach).

**Component(s)**: `nji-itinerary`, `nji-ui/src/modules/itinerary/`.

**Primary FR/NFR coverage**: FR48, FR49, FR50, FR51, FR52, NFR8, NFR37.

> **End-of-Phase-7 demo gate**: Journey 3 (Judge views itinerary) becomes demoable.

## Phase 8 — MI Feed & Reporting

### Phase 8 · Area: MI Feed & Reporting

**Scope**: `nji-mi-feed` backend + Reports UI module in `nji-ui`. **No own tables** — SQL JOINs over the shared schema. Fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report and same parameter shape as APEX. MI Feed REST API for external consumers (DA&I post-MVP, future programmes). **Aggregate-only by contract** (FR54, NFR23) — no case-level data in any read model or report under any consumer authorisation.

**Component(s)**: `nji-mi-feed`, `nji-ui/src/modules/reports/`.

**Primary FR/NFR coverage**: FR53, FR54, NFR23.

> **End-of-Phase-8 demo gate**: Journey 4 (DA&I MI Feed API consumer) becomes demoable post-MVP onboarding.

## Phase 9+ — Pilot Rollout (Wave 1) and Subsequent Waves

### Phase 9+ · Area: Pilot Rollout & Subsequent Waves

**Scope**: Per-region phased activation — flip `auth_user_activation_flags` for the region's users (FR58) once that region's feature-parity gate is passed. Manual UAT execution per role per region (FR61): RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI walk through per-service UAT scripts (under `docs/uat/` in each domain service repo) side-by-side against APEX; sign-off per role per region is the wave-cutover gate. Per-wave rollback playbook (NFR36): documented path returning the region to APEX within one operational cycle if the gate is breached post-cutover. Cross-region manual coordination during partial rollout (Risk #1 mitigation; operational, not application-level). Reference Data + Users/Roles ETL re-run for incremental activation per wave (architecture/migration ownership). Wave 1 is the Pilot; Phases 10..N are subsequent regions until all regions are on NJI and APEX is retired (D8).

**Component(s)**: Programme-level (manual UAT scripts, runbooks, activation orchestration). Cross-region edge case (Journey 5) handled out-of-system per Risk #1 — no application capability built.

**Primary FR/NFR coverage**: FR58 *(activation orchestration)*, FR61, NFR36, NFR38, NFR41. Closes the MVP.
