---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
workflowCompleted: true
assessor: Claude (bmad-check-implementation-readiness)
overallVerdict: NEEDS WORK
filesIncluded:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/architecture-summary.md
  - _bmad-output/planning-artifacts/architecture/assumptions.md
  - _bmad-output/planning-artifacts/architecture/changelog.md
  - _bmad-output/planning-artifacts/architecture/conventions.md
  - _bmad-output/planning-artifacts/architecture/data-tables.md
  - _bmad-output/planning-artifacts/architecture/functional-requirements-coverage.md
  - _bmad-output/planning-artifacts/architecture/gaps.md
  - _bmad-output/planning-artifacts/architecture/non-functional-requirements-coverage.md
  - _bmad-output/planning-artifacts/architecture/repo-structure.md
  - _bmad-output/planning-artifacts/architecture/repository-strategy.md
  - _bmad-output/planning-artifacts/architecture/starter-template.md
  - _bmad-output/planning-artifacts/architecture/user-types.md
  - _bmad-output/planning-artifacts/epics.md
uxIncluded: false
uxDeferralReason: Project currently scoped to domains and APIs only; UI deferred to a later stage.
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-15
**Project:** ji-analysis

## 1. Document Inventory

### PRD
- `prd.md` (72 KB, 2026-05-11 15:44) — **source of truth**
- `prd.pdf` — rendered output, not used for analysis

### Architecture
- `architecture.md` (71 KB, 2026-05-11 15:00) — **source of truth (aggregates the folder)**
- `architecture-summary.md` (16 KB) — companion summary
- `architecture/` folder — supporting detail files, all included as part of the architecture source of truth:
  - `assumptions.md`, `changelog.md`, `conventions.md`, `data-tables.md`
  - `functional-requirements-coverage.md`, `non-functional-requirements-coverage.md`
  - `gaps.md`, `repo-structure.md`, `repository-strategy.md`, `starter-template.md`, `user-types.md`
  - `diagrams/`, `sequence-diagrams/` (referenced but not directly assessed)

### Epics & Stories
- `epics.md` (53 KB, 2026-05-11 15:44) — **source of truth**

### UX Design
- **Not included.** Project scope is currently domains and APIs only; UI work is deferred.

### Prior Readiness Reports (context)
- `implementation-readiness-report-2026-05-05.md`
- `implementation-readiness-report-2026-05-06.md`

## 2. PRD Analysis

PRD: `prd.md`, 728 lines, completed 2026-05-05 (`workflowCompleted: true`), with revisions on 2026-05-06, 2026-05-07, and 2026-05-11 marked inline. Project codename **NJI**, release mode `phased`, project type `api_backend` with UX override per D4.

### Functional Requirements (FR1–FR61, total: 61)

**Identity & Authorisation**
- **FR1** — Authenticated users access NJI via HMCTS IdP single sign-on; password, session, and account lifecycle owned by the IdP, not duplicated in NJI.
- **FR2** — NJI's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- **FR3** — Authorised users can retrieve their effective permissions for their authenticated session.
- **FR4** — System administrators can update role and Region/Area assignments for migrated and new users.
- **FR5** *(reframed v2.5, 2026-05-07 as post-MVP)* — External machine-to-machine consumer authentication mechanism. **At MVP, no M2M consumers in scope** — every NJI runtime request is user-initiated. Genuine service-principal auth is a post-MVP open question (architecture gap G7); options to evaluate later: NJI-internal service-auth issuer, Azure Workload Identity, mTLS, HMCTS IdP `client_credentials`.

**Foundational Data Management**
- **FR6** — RSU users can view and maintain Reference Data lists (Regions, Offices, judicial vocabularies, calendar / financial-year boundaries) with named-owner sign-off on changes.
- **FR7** *(revised 2026-05-11)* — Every NJI service reads Reference Data via **direct SQL** on the shared schema's Reference Data tables (15 tables, SELECT-granted to each service's DB role) — no client class, no API fan-out, no cache. Reference Data is the single writer; writes (Phase 0 ETL load + ongoing RSU maintenance) go through the versioned Reference Data API. No service holds duplicate or cached copies.
- **FR8** *(revised v2.2, 2026-05-07)* — Cross-service runtime policy values stored in a shared `configuration_values` infrastructure table managed by `nji-architecture`'s Flyway baseline; SELECT-granted to every NJI service DB role. Updates via Flyway migrations or direct admin SQL — no API service. Per-service config uses Spring profiles + `application.yml` + Azure Key Vault.
- **FR9** — NJI dispatches transactional emails (booking acks, absence acks, payment schedules) via HMCTS email infrastructure with a delivery log retained.

**Judge Records & Working Patterns**
- **FR10** — RSU users can search and filter judges by name, base location, location type, and judge type.
- **FR11** — RSU users can maintain judge profiles (personal details, judge type, base office, active/inactive, payroll number, retirement date, fee entitlement, London weighting, name-for-itinerary, heading).
- **FR12** — Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- **FR13** — NJI auto-populates judge itineraries up to the next 31st March from the working pattern, preserving prior absences.
- **FR14** — RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- **FR15** — RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- **FR16** — NJI validates jurisdictional split percentages total 100% before saving.
- **FR17** — RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- **FR18** — Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

**Absence Workflow**
- **FR19** — Authorised users (RSU, Court, Judges where permitted) can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- **FR20** — NJI distinguishes auto-confirmed absences from those requiring confirmation; confirmation can trigger an acknowledgement email.
- **FR21** — Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- **FR22** — Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

**Vacancy & Cover**
- **FR23** — NJI auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- **FR24** — Authorised users can create standalone vacancies independent of any absence.
- **FR25** — Authorised users can edit a vacancy's daily breakdown (cancel days with reason; extend/shorten the period).
- **FR26** — NJI marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- **FR27** — NJI surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is out-of-system.
- **FR28** — Authorised users can cancel or close vacancies (e.g. when parent absence becomes NTBF).

**Booking Management**
- **FR29** — Authorised users can create fee-paid bookings (linked to vacancy or standalone), capturing judge, court, date, session type, booking type, work type.
- **FR30** — Booking creation marks the linked vacancy as filled within the same transaction when `vacancyId` is supplied. *(Implementation: in-process direct DB update via per-service DB role grant — architecture Principle 1.)*
- **FR31** — NJI tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- **FR32** — NJI sends booking acknowledgement emails to fee-paid judges (batched overnight or *Create and Email Now*).
- **FR33** — NJI requires a Y/N answer at booking time when a judge's fee entitlement is *Ask when booking*.
- **FR34** — NJI prevents double-booking of fee-paid judges for overlapping sessions.

**Sitting Management**
- **FR35** — NJI generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- **FR36** — Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- **FR37** — Authorised users can confirm that a sitting took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- **FR38** — Authorised users can split a sitting into AM/PM with different work types within a single day.
- **FR39** — Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- **FR40** *(revised 2026-05-11)* — Verifiers can verify confirmed sittings; once verified, data is read-only. Amendments require **re-opening** via a UI action gated by a distinct authorised role (re-opener ≠ original confirmer ≠ standard Verifier; MVP: RSU Admin only). Captures mandatory justification, fully audited. No external RFC ticketing.

**Payment & Reconciliation**
- **FR41** *(revised v2.6, 2026-05-07)* — Authorised users can list confirmed bookings and salaried sittings, filterable by Region/Office, judge, date range, and payment lifecycle status. Payment-eligible subset = read-only union of confirmed bookings + sittings without an existing payment record.
- **FR42** *(revised v2.6)* — NJI's **payment-processing batch** (`nji-payment-batch`, scheduled cron, typically end-of-week) automatically marks eligible bookings as *payment requested* and creates `payments` + `payment_schedules` records. **No user click required.**
- **FR43** *(revised v2.6)* — The **payment batch** generates JFEPS-compatible payment schedules and dispatches as Excel attachments to a configured Payment Authoriser via email (Notification API, batch service-principal); Authoriser forwards to Liberata out-of-system.
- **FR44** — NJI exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`).
- **FR45** — NJI prevents double submission of the same booking for payment via natural-key unique constraint on `(payment_cycle_id, booking_id)`; re-runs of the same cycle are idempotent.
- **FR46** — Authorised users (Finance, RSU) can flag payments as reconciled with notes for mismatches; fully reconciled payments cannot be re-requested.
- **FR47** — NJI does not store or expose bank details for any judge.

**Itineraries & Reporting (Read Models)**
- **FR48** — Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month.
- **FR49** — Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation.
- **FR50** — Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- **FR51** — Itinerary cells are clickable and drill into the underlying record.
- **FR52** — Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- **FR53** — NJI provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type).
- **FR54** — NJI exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); aggregate-only by contract, no case-level data.

**Platform Operations & Migration**
- **FR55** — Authenticated users land on a Home page with role-scoped navigation, Region/Area selector, summary tiles, and contextual help.
- **FR56** — NJI's UI replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA.
- **FR57** — Phase 0 Data Migration ETL takes Reference Data and active user records from APEX, transforms to NJI shape, and loads via the NJI Reference Data API and Authorisation API. Keyed to HMCTS IdP principals (email primary, employee number fallback). Lives at `nji-architecture/migration/`, separate from Flyway DDL.
- **FR58** — NJI supports per-region phased activation — region's user accounts activated when feature-parity gate passed; activation is a flag flip on `auth_user_activation_flags`, not a data migration.
- **FR59** — Every NJI service exposes a versioned API contract, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, published OpenAPI spec, and `Deprecation` ([RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745)) + `Sunset` ([RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) headers.
- **FR60** — Every NJI service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- **FR61** *(revised 2026-05-06)* — Every domain service has a **manual UAT script** capturing workflows and edge cases for APEX-experienced users to verify against APEX. UAT performed by RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI users; recorded with explicit per-role sign-off. No automated APEX-comparison harness.

### Non-Functional Requirements (NFR1–NFR42, total: 42)

**Performance (NFR1–NFR9)**
- **NFR1** — Static page load ≤ 3 s.
- **NFR2** — Dashboard refresh ≤ 5 s on Region/Area selection change.
- **NFR3** — List / filter operations ≤ 10 s for typical operational lists at Region scope.
- **NFR4** — Batch / annual operations ≤ 15 s (annual itinerary render, batch payment-request processing).
- **NFR5** — Reports / Forward Look ≤ 30 s for standard parameters at Region scope.
- **NFR6** — Single-resource API read ≤ 500 ms p95.
- **NFR7** — Domain write API ≤ 1 s p95 (excluding orchestrated cross-service calls).
- **NFR8** — Federated read (Itinerary, Forward Look) ≤ 30 s p95 under Strategy A; Strategy C cache fallback pre-designed.
- **NFR9** — Capacity: ~50–100 concurrent users per region; ~200–500 nationally once all regions migrated.

**Security (NFR10–NFR16)**
- **NFR10** — Latest TLS only on every endpoint; HTTP-only rejected.
- **NFR11** — All personal data encrypted at rest.
- **NFR12** *(revised v2.6, 2026-05-07)* — Human users authenticated via HMCTS IdP SSO. **Inter-service auth for user-initiated calls is JWT propagation** validated against IdP's JWKS endpoint. **Inter-service auth for batch / scheduled components is OAuth 2.0 `client_credentials`** against `nji-mock-auth` non-prod; production issuer deferred per gap G7.1 (recommendation: Azure Workload Identity).
- **NFR13** — Every API call resolves principal's roles + Region/Area scope through Authorisation; no operation bypasses.
- **NFR14** — No bank details stored or exposed; no case-level data in any read model or report.
- **NFR15** — Aligns with HMCTS / MoJ Government Functional Standard 7 — Security.
- **NFR16** — Service credentials, signing keys, and integration secrets in managed secret store (Azure Key Vault); never in source control or images.

**Accessibility (NFR17–NFR19)**
- **NFR17** — Every UI page meets WCAG 2.2 Level AA; tested per UI page in each domain phase.
- **NFR18** — Keyboard navigation, ARIA labels for tabbed/dynamic content, screen-reader compatibility per HMCTS standards.
- **NFR19** — Complies with Public Sector Bodies Accessibility Regulations 2018 including published accessibility statement.

**Integration (NFR20–NFR24)**
- **NFR20** — HMCTS IdP integration is Phase 0 hard dependency (OIDC or SAML).
- **NFR21** — JFEPS / Liberata integration unchanged from APEX (format, delivery, authoriser-forwards workflow).
- **NFR22** — HMCTS email infrastructure for outbound transactional emails; reliable but not low-latency-critical.
- **NFR23** — DA&I MI Feed is aggregate-only REST API contract.
- **NFR24** — No automated eLinks/HR integration in MVP; manual data entry continues.

**Observability (NFR25–NFR29) — MVP minimum per D7**
- **NFR25** — Structured logs with consistent fields, correlation IDs across service-to-service calls, defined error-categorisation taxonomy. Logging schema is Phase 0 deliverable.
- **NFR26** — Log retention sufficient for pilot incident triage; specific period in Phase 0 within HMCTS retention policy.
- **NFR27** — Logs ingested into Azure-native logging (App Insights / Log Analytics).
- **NFR28** — Every service exposes Kubernetes-compatible liveness/readiness endpoints (Spring Actuator).
- **NFR29** — Post-MVP: structured user-action auditing and metrics/trace observability beyond logs.

**Data Privacy & Sovereignty (NFR30–NFR33)**
- **NFR30** — UK GDPR / DPA 2018 compliance; personal data scope limited; no case-level data.
- **NFR31** — All NJI services and data hosted in Azure UK regions only.
- **NFR32** — Retention per HMCTS schedules; migrated transactional history stays in APEX (D3).
- **NFR33** — Aggregate data FOI-exposable; case-level forbidden by contract (REP-BR-NFR-03).

**Reliability & Availability (NFR34–NFR38)**
- **NFR34** — Available during HMCTS operational hours (~07:00–19:00 UK weekdays); out-of-hours best-effort.
- **NFR35** — Zero failed JFEPS payment cycles attributable to NJI. Manual fallback within a cycle is contingency, not normal mode.
- **NFR36** — Each rollout wave has documented rollback path within one operational cycle.
- **NFR37** — Strategy A degraded-mode falls back to Strategy C cached projection rather than failing; cache freshness in OpenAPI spec metadata + response headers.
- **NFR38** *(disambiguated 2026-05-06)* — HMCTS-judicial-region rollout isolation: wave activation in one region does not affect users in others. Enforced at application tier via `auth_user_activation_flags` (FR58), **not** at infrastructure tier. Production runs in single Azure region (UK South) with multi-AZ HA. DR scope is an open gap (G3.6).

**Maintainability (NFR39–NFR42)**
- **NFR39** — API-as-Product standards per FR59 (versioned contracts, RFC 9457 errors, OpenAPI, RFC 9745 + RFC 8594 deprecation signalling).
- **NFR40** — Each of the 11 services is independently deployable on Kubernetes; rolling updates per service per region.
- **NFR41** — Every domain service has a **manual UAT script** (per FR61); sign-off per role per region is the wave gate. No automated parity test suite; CI is unit + integration (Testcontainers) + contract tests only.
- **NFR42** — Each phase produces a Postman collection exercising the phase's endpoints; versioned alongside services.

### Additional Requirements & Constraints

**Decisions Log (D1–D9) — locked programme-level decisions**
- **D1** — Phase 0 scope locked: Reference Data, Authorisation+SSO, Notification, API contracts, deployment platform, structured logging, shared `configuration_values` table (no configuration service per v2.2). Audit/metrics/trace observability post-MVP.
- **D2** — Phased rollout; migrated users don't use APEX; non-migrated users don't use NJI. No dual-write coexistence.
- **D3** — Migration scope: Reference Data only (extended by D9). No transactional data migration. Phase 0 ETL: APEX dumps → transform → load via NJI Reference Data API. Lives in `nji-architecture/migration/`, separate from Flyway DDL.
- **D4** — Feature-parity gate is functional + UI-replicates-APEX (modern UI stack, no redesign). UX/visual_design/user_journeys in scope (override on `api_backend`).
- **D5** *(revised 2026-05-06)* — APEX is behavioural reference verified by **manual UAT performed by APEX-experienced users**; not a migration host. Earlier "automated comparison reference" framing retracted.
- **D6** — APEX maintenance out of project scope (not co-managed).
- **D7** — Audit/observability MVP minimum: log-based. User-action audit post-MVP.
- **D8** — Rollout boundary: by region, all applicable user roles. Region migrates only when every in-region role's functionality is complete.
- **D9** — Active users + role/scope mappings extracted from APEX, transformed, loaded into NJI Authorisation tables via NJI Authorisation API in Phase 0. Each user keyed to HMCTS IdP principal (email primary, employee number fallback).

**Service decomposition (11 services in 3 clusters):**
- **Domain (6):** Judge, Absence, Vacancy, Booking, Sitting, Payment
- **Cross-cutting (3):** Reference Data, Authorisation, Notification
- **Read-model federated (2):** Itinerary, MI Feed
- Configuration is **not** a service — per-service Spring profiles + Key Vault; shared `configuration_values` table for cross-service policy values.

**Build phases (per MVP strategy):**
- Phase 0: Foundations (Reference Data, Authorisation+SSO, Notification, contracts, platform, logging conventions, stub Home)
- Phases 1–6: Judge → Absence → Vacancy → Booking → Sitting → Payment
- Phases 7–8: Itinerary, MI Feed (federated read models)
- Phase 9: Pilot rollout (wave 1) — one region migrates
- Phases 10..N: Wave-by-wave per-region rollout

**Forbidden by contract:**
- Bank details (PAY-NFR-05) — never in any Payment resource shape.
- Case-level identifiers (REP-BR-NFR-03) — never in Reports or MI Feed shapes.

**Integrations (binding):**
- HMCTS IdP (SSO) — inbound AuthN, Phase 0 hard dependency.
- JFEPS / Liberata — outbound payment via Excel email, unchanged from APEX, Phase 6.
- HMCTS email — outbound transactional emails, Phase 0+.
- DA&I (MI Feed) — outbound aggregate-only REST, Phase 8.
- eLinks / HR — out of MVP scope; manual entry continues.

### PRD Completeness Assessment (initial)

- ✅ **Scope clarity** — MVP, Growth, Vision distinctly delineated with explicit exclusions list.
- ✅ **Traceability anchors** — FR/NFR numbered IDs, D1–D9 decision IDs, RFC citations, cross-references to source documents.
- ✅ **User journeys** — 5 journeys cover the main operational cycle, daily confirmation, judge self-service, external API consumer, and a known cross-region edge case during partial rollout.
- ✅ **Compliance & constraints** — UK govtech specifics (WCAG 2.2 AA, UK GDPR, FOI, GovS 7) addressed; data-residency NFR31 binding.
- ✅ **Recent revisions logged inline** — multiple `(revised YYYY-MM-DD)` markers indicate the doc has been actively maintained.
- ⚠️ **Several deferred/TBD items remain** to be cross-checked against architecture:
  - FR5 — M2M auth deferred to post-MVP (gap G7).
  - NFR12 — production issuer for batch service-auth deferred (gap G7.1).
  - NFR38 — DR scope an open gap (G3.6).
  - Rate limits — architecture-phase decision.
  - API versioning policy details — Phase 0 deliverable, working assumption is path-prefix.
- ⚠️ **Risk #1 and Risk #9 fallbacks** (cross-region manual coordination; Strategy C cache fallback) reference items that must appear in architecture risk-mitigations and observability/rollout plans.

PRD is **well-formed and traceable**. Coverage validation in Step 3 will check whether epics map every FR/NFR.

## 3. Epic Coverage Validation

Loaded `epics.md` (523 lines). Frontmatter shows `stepsCompleted: ['step-01-validate-prerequisites']` only — confirming the document is at the framework stage of its own multi-step workflow.

### ⚠️ Critical structural finding

The epics document is currently a **Phase × Area framework**, not a stories-with-acceptance-criteria deliverable. Line 523 explicitly states: *"Next step (Step 2 of this workflow): For each Phase × Area row above, design one or more concrete epics with an explicit goal, story breakdown, and Gherkin-style acceptance criteria."*

What exists:
- ✅ Phase × Area summary table with FR/NFR coverage at the Area level
- ✅ Scope description per Area
- ✅ Component identification (`nji-judge`, `nji-payment-batch`, etc.)
- ✅ Demo gate identification per phase
- ✅ Architecture-derived additional requirements (AR1–AR50)

What's missing (required for implementation kick-off):
- ❌ Concrete epics with explicit goals
- ❌ User stories (`As a... I want... So that...`)
- ❌ Gherkin-style acceptance criteria
- ❌ Story-level dependencies and sequencing within an Area
- ❌ Populated **FR Coverage Map** — the doc has a placeholder: *"Placeholder — populated in Step 3 once epics and stories are designed."*

### FR Coverage Matrix (Area-level — pre-story)

| FR | Area | Phase | Coverage | Notes |
|---|---|---|---|---|
| FR1 | Identity & Authorisation | 0 | ✅ Covered | HMCTS IdP SSO via `nji-mock-auth` |
| FR2 | Identity & Authorisation | 0 | ✅ Covered | `nji-authorisation` + JWTFilter |
| FR3 | Identity & Authorisation | 0 | ✅ Covered | `GET /users/{id}/effective-permissions` |
| FR4 | Identity (backend) + Admin UI | 0 | ✅ Covered | Backend API + admin UI surface |
| FR5 | — | post-MVP | ⏸️ Deferred (intentional) | Per PRD v2.5; epic explicitly states "out of scope here" |
| FR6 | Reference Data + Admin UI | 0 | ✅ Covered | Backend API + admin UI maintenance |
| FR7 | Reference Data | 0 | ✅ Covered | Direct SQL via SELECT grants |
| FR8 | Platform & DevEx | 0 | ✅ Covered | `configuration_values` Flyway baseline |
| FR9 | Notification | 0 | ✅ Covered | `nji-notification` |
| FR10–FR18 | Judge | 1 | ✅ Covered | `nji-judge` + UI module |
| FR19–FR22 | Absence | 2 | ✅ Covered | `nji-absence` + UI module |
| FR23–FR28 | Vacancy | 3 | ✅ Covered | `nji-vacancy` + UI module |
| FR29–FR34 | Booking | 4 | ✅ Covered | `nji-booking` + UI module |
| FR35–FR40 | Sitting | 5 | ✅ Covered | `nji-sitting` + UI module |
| FR41 | Payment Processing | 6 | ✅ Covered | Listing/review surface |
| FR42 | Payment Batch | 6 | ✅ Covered | `nji-payment-batch` |
| FR43 | Payment Batch | 6 | ✅ Covered | Email dispatch via Notification |
| FR44 | Payment Processing | 6 | ✅ Covered | Content-type negotiation |
| FR45 | Payment Batch | 6 | ✅ Covered | Natural-key uniqueness |
| FR46 | Payment Processing | 6 | ✅ Covered | Reconciliation marking |
| FR47 | Payment Processing | 6 | ✅ Covered | Architectural constraint (no bank details) |
| FR48–FR52 | Itineraries | 7 | ✅ Covered | `nji-itinerary` read model |
| FR53 | MI Feed & Reporting | 8 | ✅ Covered | Reports UI module |
| FR54 | MI Feed & Reporting | 8 | ✅ Covered | Aggregate-only contract |
| FR55 | Business UI Foundation | 0 | ✅ Covered | Home shell with tiles + selector |
| FR56 | Business UI + Admin UI Foundation | 0 | ✅ Covered | Modern UI stack + WCAG 2.2 AA |
| FR57 | Data Migration ETL | 0 | ✅ Covered | `nji-architecture/migration/` ETL |
| FR58 | Identity (flags) + Rollout (orchestration) | 0 + 9+ | ✅ Covered | Split: flags wired Phase 0; orchestrated Phase 9+ |
| FR59 | Platform & DevEx | 0 | ✅ Covered | Versioning + OpenAPI + RFC 9457 + RFC 9745/8594 |
| FR60 | Platform & DevEx | 0 | ✅ Covered | Logstash JSON logs + correlation IDs |
| FR61 | Rollout | 9+ | ✅ Covered | Manual UAT scripts per service |

**Total FRs: 61. Covered: 60 (98%). Deferred (intentional): 1 (FR5).**

### NFR Coverage Matrix (Area-level — pre-story)

| NFR | Coverage type | Phase / Area | Notes |
|---|---|---|---|
| NFR1–NFR7 | Implicit cross-cutting | All phases | Performance NFRs claimed as inherited; **no explicit per-phase acceptance criteria** |
| NFR8 | Explicit | 7 — Itineraries | Strategy A; Strategy C fallback |
| NFR9 | Implicit cross-cutting | All phases | Capacity targets |
| NFR10–NFR11 | Implicit cross-cutting | 0 — Platform & DevEx | TLS / at-rest encryption (architecture-level) |
| NFR12 | Explicit | 0 — Identity | JWT propagation + `client_credentials` for batch |
| NFR13 | Explicit | 0 — Identity | Authorisation enforcement |
| NFR14 | Implicit (architectural constraint) | 6 + 8 | No bank details (Payment), no case-level (Reports/MI Feed) |
| NFR15–NFR16 | Implicit cross-cutting | 0 — Platform & DevEx | GovS 7; Azure Key Vault |
| NFR17 | Explicit | 0 — Business UI + Admin UI | WCAG 2.2 AA; per-phase gating |
| NFR18–NFR19 | Explicit | 0 — Business UI + Admin UI | Assistive tech + accessibility regs |
| NFR20 | Implicit | 0 — Identity | HMCTS IdP integration (scope text mentions; coverage line doesn't) |
| NFR21 | Explicit | 6 — Payment Processing | JFEPS/Liberata unchanged |
| NFR22 | Explicit | 0 — Notification | HMCTS email infrastructure |
| NFR23 | Explicit | 8 — MI Feed | Aggregate-only contract |
| NFR24 | N/A | — | No automated eLinks/HR in MVP (intentional) |
| NFR25–NFR28 | Explicit | 0 — Platform & DevEx | Structured logs, ingestion, probes |
| NFR29 | Deferred (intentional) | post-MVP | User-action audit + metrics/traces |
| NFR30–NFR33 | Implicit cross-cutting | All phases | UK GDPR / data residency / retention / FOI scope |
| NFR34 | Implicit | All phases | Operational hours availability |
| NFR35 | Explicit | 6 — Payment Processing | Payment-cycle continuity |
| NFR36 | Explicit | 9+ — Rollout | Per-wave rollback path |
| NFR37 | Explicit | 7 — Itineraries | Strategy A degraded mode |
| NFR38 | Explicit | 9+ — Rollout | Region rollout isolation |
| NFR39 | Implicit | 0 — Platform & DevEx (foundations); every phase exercises it | API-as-Product standards |
| NFR40 | Explicit | 0 — Platform & DevEx | Independently deployable services |
| NFR41 | Explicit | 9+ — Rollout | Manual UAT suite |
| NFR42 | Explicit | 0 — Platform & DevEx | Postman collections per phase |

**Total NFRs: 42. Explicitly mapped to a phase: 22. Implicit cross-cutting: 19. Intentionally deferred: 1 (NFR29).**

### Missing Coverage

#### Critical Missing (blocks implementation start)

None — every MVP-scoped FR has an Area mapping. **The blocker is structural**, not coverage:

- **No epics with stories or acceptance criteria yet.** A developer agent (`bmad-dev-story`) cannot pick up a story to implement because no stories have been written. Phase × Area framework is necessary but not sufficient.
- **FR Coverage Map placeholder unfilled.** The doc commits to populating this once stories exist; currently it's a sentinel.

#### Implicit-cross-cutting NFRs (medium-priority gap)

Performance, broad security, data-privacy and reliability NFRs are tagged "inherited by every phase" but lack **explicit per-phase acceptance criteria**. Risk: when Step 2 of the epics workflow generates stories, these may quietly fall off the AC list. Recommend:
- Each Phase 1–8 epic must include explicit NFR-anchored acceptance criteria for the NFRs that apply at that phase (e.g. Phase 5 Sitting stories must call out NFR3 ≤ 10 s list/filter explicitly in the AC, not as a generic cross-cutting note).

#### Architecture-derived requirements (AR1–AR50)

Epics document lists 50 architecture-derived additional requirements (AR1–AR50) but only AR1 (polyrepo strategy) and AR42–AR45b (UI split) are clearly mapped to specific Phase 0 work. The other 45+ ARs need story-level surfaces — particularly the per-service scaffolding (AR2–AR4), build/supply-chain tooling (AR9–AR13), and security implementation (AR34–AR37). These are likely "Story 1 of every service epic" type stories but aren't yet stories.

### Coverage Statistics

- **Total PRD FRs:** 61
- **FRs covered (mapped to a Phase × Area):** 60 (98%)
- **FRs intentionally deferred:** 1 (FR5 — post-MVP)
- **FRs missing without justification:** 0
- **Total PRD NFRs:** 42
- **NFRs explicitly mapped:** 22 (52%)
- **NFRs implicit cross-cutting:** 19 (45%)
- **NFRs intentionally deferred:** 1 (NFR29 — post-MVP)
- **Architecture-derived requirements (AR1–AR50):** 50 — most not yet story-mapped

### Headline verdict for this step

**Coverage at the Phase × Area level is comprehensive** — the framework demonstrates that every FR has a home. But the epics document is at **~30% maturity** for implementation kick-off: framework done, stories not yet drafted. This is the single biggest readiness gap and will dominate the final assessment in Step 6.

## 4. UX Alignment Assessment

### UX Document Status

**Not Found.** No `*ux*.md` whole document or `*ux*/index.md` sharded folder under `_bmad-output/planning-artifacts/`.

### Is UX implied by the other artefacts?

**Yes — strongly implied.** Despite the explicit decision to defer UX work, UI surface is unambiguously part of MVP scope:

| Source | Evidence |
|---|---|
| PRD Classification | `projectType=api_backend` with explicit overrides `ux_ui in scope per D4`, `visual_design in scope per D4`, `user_journeys in scope per D4` |
| PRD D4 (locked decision) | "Feature-parity gate is functional + UI-replicates-APEX (modern UI stack, no redesign)" |
| PRD FR55 | Authenticated users land on a Home page with role-scoped navigation, Region/Area selector, summary tiles, contextual help |
| PRD FR56 | NJI's UI replicates the functional surface of as-is APEX UI on a modern UI stack and meets WCAG 2.2 AA |
| PRD NFR17–NFR19 | WCAG 2.2 AA accessibility per page, assistive tech compatibility, Public Sector Bodies Accessibility Regs 2018 compliance |
| PRD User Journeys 1–4 | Operational UI flows (RSU cover cycle, Court daily confirmation, Judge tablet itinerary, DA&I API consumer) |
| Epics doc AR42 | Two UI repos (`nji-ui` + `nji-admin-ui`), React + TypeScript + Vite + Vitest + Playwright stack |
| Epics doc AR43–AR45b | Auto-generated TS clients, OIDC client wrapper, per-phase E2E suites, axe-core CI, independent deployment with distinct hostnames, GOV.UK Design System base |

Both Phase 0 Business UI Foundation and Phase 0 Admin UI Foundation areas are present in the epic framework and gate Phase 1+ progress (the per-domain UI modules are part of each domain phase's scope).

### User direction (recorded)

User confirmed on **2026-05-15**: project is currently focused on **domains and APIs only**; UI is **deferred to a later stage**. This is an explicit scoping decision for the current planning cycle.

### Alignment Issues (between PRD ↔ Architecture ↔ Epics on UX matters)

Despite the missing standalone UX doc, the three artefacts internally align on UI matters:

| Topic | PRD | Architecture | Epics |
|---|---|---|---|
| UI stack | "modern UI stack" (PRD §Technology Stack) | React + TypeScript + Vite + Vitest + Playwright (architecture/conventions, repository-strategy) | AR42 explicit |
| UI repo strategy | Not specified | Two UI repos: `nji-ui` + `nji-admin-ui` (architecture/repository-strategy v2.2+) | AR42–AR45b explicit |
| Accessibility target | WCAG 2.2 AA per NFR17 | architecture/conventions accessibility rules | NFR17 mapped to Phase 0 Business UI + Admin UI |
| Home shell | FR55 | architecture/user-types — role-scoped navigation | Phase 0 Business UI Foundation |
| Admin separation | "Admin module's password-change capability disappears" (PRD §Compliance) | Two UI repos with admin separation | Phase 0 Admin UI Foundation |
| Reports/Itinerary UI | FR48–FR53 | architecture sequence-diagrams | Phase 7 (Itineraries) + Phase 8 (MI Feed Reports module) |

→ **No alignment conflicts found.** PRD, architecture, and epics tell a consistent story about UI even without a standalone UX doc.

### Warnings

#### ⚠️ WARNING 1 — UX deferral creates a hidden dependency at Phase 0

The epic framework lists **Phase 0 Business UI Foundation** and **Phase 0 Admin UI Foundation** as foundational areas that gate Phase 1+ (per-domain UI modules sit inside each domain phase). If UX work is genuinely deferred, then either:

- **(a)** Phase 0 ships **without** UI foundations — in which case Phase 1+ per-domain UI modules cannot start either, since they depend on the shared UI shell, auth wrapper, design system, accessibility CI, and Playwright scaffolding. This would push UI to a separate parallel programme post-Phase-8 and contradicts the per-phase demo gates (Journey 2 demoable end-of-Phase-5, Journey 1 demoable end-of-Phase-6, etc.).
- **(b)** UI foundations ship in Phase 0 **without explicit UX design** — relying on PRD's "replicate APEX" framing (D4) plus GOV.UK Design System + HMCTS extensions for visual treatment. This is feasible because the brief is "no redesign", but accessibility (NFR17) and information architecture for non-trivial flows (e.g. judge profile editing, vacancy day-breakdown editing, sitting re-open with justification) carry risk without UX validation.

**Recommendation:** make the deferral explicit in the epic narrative — pick one of:
- "UX design deferred; Phase 0 UI Foundation ships with GOV.UK DS + APEX-replica behaviour as the design baseline; per-phase UX walkthroughs gate domain phases."
- "UX design and Phase 0 UI Foundations both deferred to a follow-on UI programme; MVP delivery is API-first; Journey demos become API-only until UI programme ships."

The current epic doc reads as if both apply simultaneously, which is ambiguous.

#### ⚠️ WARNING 2 — Accessibility regulatory exposure carries hard deadlines

UK Public Sector Bodies Accessibility Regulations 2018 (NFR19) require a published accessibility statement and ongoing compliance for any UI shipped to users. Deferring UX without deferring UI delivery raises regulatory risk. If UI is also being deferred, this is moot during the deferral window but becomes hard the moment Phase 9 user activation begins.

#### ⚠️ WARNING 3 — APEX-replica behavioural spec is non-trivial

The "replicate APEX" framing (D4) treats APEX as the implicit UX spec, but the as-is APEX has known issues (NFR-baseline-only accessibility, dated patterns, dated information architecture). The PRD targets *modern UI* + *measurable accessibility improvement*. Without a UX document specifying *which* APEX patterns to preserve and *which* to modernise, this judgment lands on implementers per phase. Recommend lightweight UX guidance per domain phase even if a full UX doc is deferred — e.g. a per-phase "UI parity & uplift notes" appendix.

### Verdict for this step

- **No UX doc + UX explicitly deferred** is a **documented and accepted gap** for the current planning cycle.
- **PRD ↔ Architecture ↔ Epics are internally consistent** on UI matters — no alignment conflicts.
- The deferral is **not safely silent** — Phase 0 UI Foundations + Phase 1+ per-domain UI modules sit in the epic framework and are coupled to demo gates. The epic doc must declare which model applies (full deferral vs UI-without-UX) before stories are written.

## 5. Epic Quality Review

**Caveat:** standard quality enforcement targets epics with concrete stories and Gherkin acceptance criteria — neither exists yet (per Step 3 finding). What follows applies create-epics-and-stories standards to the **Phase × Area framework as proto-epics**, distinguishes violations that exist *now* from those that *will arise* when stories appear, and provides remediation guidance.

### A. User-Value vs Technical-Milestone Check

Each Phase × Area is treated as a proto-epic. Verdict: ✅ user-value | ⚠️ borderline | ❌ technical-only.

| Proto-Epic | Verdict | Note |
|---|---|---|
| Phase 0 Platform & DevEx | ❌ Technical | No direct user value — pure infra/tooling. Will need to be re-framed when storied, or split such that user-facing stories live in domain phases and only the genuinely cross-cutting infra survives. |
| Phase 0 Identity & Authorisation | ✅ User value | "User signs in via SSO and gets the right access" is a real user outcome (FR1–FR4 enable Journey 1–4). |
| Phase 0 Reference Data | ⚠️ Borderline | "RSU users maintain reference lists" is user value (FR6); reference-data-as-foundation is technical. The Admin UI surface restores the user value. |
| Phase 0 Notification | ❌ Technical | No user value as a standalone — but consumed by FR20, FR32, FR43 in later phases. Acceptable as a thin technical foundation **if** every user-visible email is owned by the consuming domain phase's stories with the Notification call as a step. |
| Phase 0 Data Migration ETL | ❌ Technical | Programme-level deliverable, not a user-facing capability. Named-owner sign-off (FR57) is the actual user touch-point. |
| Phase 0 Business UI Foundation | ⚠️ Borderline | "User lands on Home" (FR55) is real value; the rest is shared infra. |
| Phase 0 Admin UI Foundation | ✅ User value | Reference Data maintenance + User & Role admin are user-facing. |
| Phase 1 Judge | ✅ User value | RSU manages judges. |
| Phase 2 Absence | ✅ User value | Recording/approving absences. |
| Phase 3 Vacancy | ✅ User value | Cover workflow. |
| Phase 4 Booking | ✅ User value | Fee-paid booking management. |
| Phase 5 Sitting | ✅ User value | Daily sitting confirmation (Journey 2 demoable). |
| Phase 6 Payment Processing | ✅ User value | Finance review + reconciliation. |
| Phase 6 Payment Batch | ⚠️ Borderline | Scheduled component with no user click; the **payment outcome** is the user value, but the batch itself is invisible. Could be merged into Phase 6 Payment Processing or kept separate; reasonable either way. |
| Phase 7 Itineraries | ✅ User value | Judge/Court itinerary views (Journey 3 demoable). |
| Phase 8 MI Feed & Reporting | ✅ User value | Standard reports + DA&I API consumer (Journey 4). |
| Phase 9+ Pilot Rollout | ✅ User value | Region migrates onto NJI. |

**Findings:**
- **3 explicit technical proto-epics** (Platform & DevEx, Notification, Data Migration ETL) need user-value reframing or splitting at story-design time. For Platform & DevEx specifically, the standard pattern is to spread infra stories across early phases such that each delivers a vertical slice ending in something demoable, rather than running an "infrastructure epic" that delays first user value.
- **2 borderline cases** (Reference Data, Business UI Foundation) work fine if the foundational stories are kept narrow and the user-facing work happens in domain phases / Admin UI.

### B. Epic Independence Test

Per create-epics-and-stories: Epic N cannot require Epic N+1 to work.

NJI's phase structure has **deliberate, architecture-driven forward references** that need scrutiny:

| Forward reference | Phase | Description | Verdict |
|---|---|---|---|
| Phase 2 Absence → Phase 3 Vacancy | 2 → 3 | "Hook to Vacancy auto-creation (Vacancy itself lives in Phase 3 — Phase 2 stubs the call; Phase 3 wires it)" | ✅ **Acceptable** — Phase 2 ships standalone with a stubbed integration point; Phase 3 wires the real impl. This is the correct pattern (per create-epics-and-stories: stubs over forward dependencies). |
| Phase 3 Vacancy → Phase 4 Booking | 3 → 4 | `markFilled` endpoint "called by Booking (Phase 4)" | ✅ **Acceptable** — `markFilled` is exposed in Phase 3, consumed in Phase 4. Phase 3 doesn't depend on Phase 4. |
| Phase 0 Identity → Phase 9+ Rollout | 0 → 9+ | "Per-user activation flags (FR58) wired to enable per-region phased cutover" | ✅ **Acceptable** — flags wired in Phase 0; *orchestrated* in Phase 9+. Two distinct user stories, properly split. |
| Phase 7 Itinerary federation | 7 | "SQL JOINs across `judges`, `absences`, `vacancies`, `bookings`, `sittings`" | ✅ **Acceptable** — Phase 7 depends on Phase 1–5 schemas existing (backward dependency, not forward). Strategy C cache is a designed fallback that ships only if NFR8 measurement fails. |
| Phase 8 MI Feed federation | 8 | "SQL JOINs over the shared schema" | ✅ **Acceptable** — same as Phase 7, backward dependency only. |
| Phase 6 Payment Processing → Phase 6 Payment Batch | 6 | Two areas in the same phase | ⚠️ **Watch** — these will need clear story boundaries; the natural-key unique constraint owner (AR21) and the batch's idempotency must be aligned. |

**Verdict:** Epic independence is **architecturally well-managed** through the stub-then-wire pattern. No true forward dependencies in the framework.

### C. Story-Level Validation

**❌ Cannot be performed — no stories exist.**

When Step 2 of `bmad-create-epics-and-stories` runs to produce stories, every story must be checked against:
- Independent user value (does the story deliver something a user can do?)
- Independently completable (no dependency on a future story in the same epic or a later phase)
- Acceptance criteria in Given/When/Then form, testable, complete (happy + error paths), specific
- Story-scoped DB table creation (each service's Flyway migrations live in that service's story stream, not upfront — already mandated by AR18–AR19)

**Pre-defined risks for the story-writing pass:**

| Area | Risk | Mitigation |
|---|---|---|
| Phase 0 Platform & DevEx | Tendency to write "Set up GitHub Actions", "Set up APIM", "Set up Helm conventions" — all technical with no user value | Use AR2–AR4 to write *one* "Scaffold first service from HMCTS starter" story that establishes patterns; everything else lives inside per-service epic stories. |
| Phase 0 Identity | "Set up `nji-mock-auth`" tempting | Write as "User authenticates against `nji-mock-auth` and reaches stub Home page" — vertical slice. |
| Phase 0 Data Migration ETL | "Load APEX dumps into NJI tables" sounds technical | Write as "RSU sign-off on Reference Data migration (Risk #13)" — named-owner sign-off is the user outcome. |
| Phase 1+ domain phases | Database-tables-upfront temptation per service | Architecture already mandates per-service Flyway with table-creation in story stream (AR19); story templates should enforce. |
| Cross-area FR6 | Maintenance UI is in Admin UI but API is in Reference Data | Define an Admin-UI story that consumes the API and a Reference-Data story that exposes it — coordinate vertical slice or sequence carefully. |

### D. Database / Entity Creation Timing

Architecture mandates per-service Flyway migrations owning that service's tables (AR18, AR19, AR20). 39 NJI tables total, grouped by owning service. **This is the right pattern** and aligns with create-epics-and-stories best practice of creating tables when first needed.

⚠️ **Watch when storied:** the shared `configuration_values` baseline (AR19, FR8) is owned by `nji-architecture`'s Flyway, not by any specific service. The story for "establish shared `configuration_values` baseline" should live in **Phase 0 Platform & DevEx as a single story** and not be repeated. Its rows are added by per-service stories as policy values are introduced.

### E. Starter Template Requirement

Architecture **explicitly mandates** the HMCTS Crime SpringBoot template (AR2, AR3, AR4):

> "Initial commit for every new service is *'Scaffold NJI {service-name} from HMCTS starter'* — this is the first implementation story per service."

✅ **Compliant** — the standard create-epics-and-stories requirement is met by AR4. Every backend service epic will have Story 1 = scaffold from template.

⚠️ **However**, the Helm chart is **not** in the HMCTS template baseline (per AR24 — added by `nji-scaffold.sh`). The scaffold story per service must therefore include both:
- Clone from HMCTS template
- Run `nji-scaffold.sh` to apply NJI conventions (Helm chart, Spectral, ArchUnit, Spotless+Checkstyle, Pact, etc.)

Stories should call out both steps explicitly.

### F. Greenfield Indicators

✅ Initial project setup stories — covered by AR2–AR4 (per-service scaffolding) and `nji-architecture` (programme-level setup).
✅ Development environment configuration — covered by AR13 (docker-compose) + AR25 (Key Vault) + AR26 (Spring profiles).
✅ CI/CD pipeline setup early — covered by AR28 (per-service GitHub Actions; `ci.yml` + per-env deploy workflows).
✅ Migration / compatibility stories — Phase 0 Data Migration ETL + FR57 + FR58 — APEX-side coexistence is operational (per D2/D6), not application-level.

All greenfield indicators present in the framework.

### G. Best Practices Compliance Checklist (Framework-level)

For the Phase × Area framework as proto-epics:

- [x] Every FR has Area mapping (60/61, 1 deferred)
- [x] Phase ordering matches dependency chain
- [x] Stub-then-wire pattern used for cross-phase integration points (Phase 2 → Phase 3, Phase 3 → Phase 4)
- [x] Starter template requirement met (AR4)
- [x] Database creation timing aligns with story-driven Flyway (AR19)
- [x] Demo gates declared per phase (Journey 2 end-of-5, Journey 1 end-of-6, etc.)
- [ ] **Story breakdown** — not yet done
- [ ] **Acceptance criteria** — not yet written
- [ ] **FR Coverage Map populated** — explicit placeholder
- [ ] **Per-phase NFR acceptance criteria** — cross-cutting NFRs need pinning to specific phase stories
- [ ] **UX deferral framing** — must declare in epics doc which deferral model applies (per Step 4)

### Findings by Severity

#### 🔴 Critical Violations
None at the framework level — all are at the story tier and cannot be assessed yet.

#### 🟠 Major Issues (existing today)
1. **No stories or acceptance criteria** — implementation cannot start. (Same finding as Step 3.)
2. **3 technical proto-epics** (Platform & DevEx, Notification, Data Migration ETL) need user-value reframing or split at story-design time, **before** story-writing.
3. **Cross-cutting NFRs (NFR1–NFR9, NFR10–NFR11, NFR14–NFR16, NFR30–NFR33, NFR34, NFR39) lack explicit per-phase ACs** — risk they fall off the AC list at story-writing.
4. **Cross-Area FR6 coordination** — Reference Data backend + Admin UI maintenance need vertical-slice story coordination.

#### 🟡 Minor Concerns
1. Phase 0 has 7 proto-epics — may be more than ideal granularity; some natural merges may emerge at story-design time.
2. Phase 6 has 2 proto-epics (Payment Processing + Payment Batch) — boundary needs clean story split, especially around `(payment_cycle_id, booking_id)` constraint ownership.
3. Strategy C cache fallback (NFR8/NFR37) is "designed but not built" — must be a triggered story, not a forgotten contingency.

### Remediation Guidance (for the next planning iteration)

1. **Resolve the UX deferral framing** in `epics.md` (per Step 4) — choose a model and document it.
2. **Re-frame the 3 technical proto-epics** at story-design time: prefer vertical-slice stories that each end in a demoable user outcome, even in Phase 0.
3. **Make cross-cutting NFRs explicit in each phase** when writing ACs — e.g. Phase 5 Sitting list operations call out NFR3 (≤ 10 s) directly in their AC; do not rely on a generic cross-cutting note.
4. **Use the stub-then-wire pattern** consistently when writing stories that cross phase boundaries (Phase 2 → 3, Phase 3 → 4 already do this in the framework).
5. **Run `bmad-create-epics-and-stories` step 2+** to produce concrete epics with story breakdowns and Gherkin ACs. Then re-run this readiness check.

## 6. Summary and Recommendations

### Overall Readiness Status

# 🟠 NEEDS WORK

NJI's planning artefacts are **mature on PRD and architecture** but **structurally incomplete on epics**. The epics document is at framework stage (Phase × Area mapping), not implementation-ready (no stories, no acceptance criteria). A developer agent cannot begin implementation today because there is nothing for them to pick up.

This is one specific gap with a known path to closure. Once that gap is closed, NJI moves to **READY** status.

### Status by Artefact

| Artefact | Status | Why |
|---|---|---|
| PRD (`prd.md`) | 🟢 READY | 61 FRs + 42 NFRs + 9 decisions, fully traceable, recently maintained (last revision 2026-05-11) |
| Architecture (`architecture.md` + folder) | 🟢 READY | Comprehensive — coverage matrices, conventions, repo strategy, data tables, sequence diagrams, gaps document |
| Epics (`epics.md`) | 🟠 FRAMEWORK ONLY | Phase × Area mapping complete (60/61 FRs covered + 1 deferred); **no stories, no ACs, FR Coverage Map is a placeholder** |
| UX Design | 🟠 ACCEPTED GAP | Not present; explicitly deferred by user; PRD/architecture/epics internally consistent on UI matters; deferral framing needs to be declared in `epics.md` |

### Critical Issues Requiring Immediate Action

#### 🟠 BLOCKER — Epics document is a framework, not stories

`epics.md` line 523 says it itself: *"Next step (Step 2 of this workflow): For each Phase × Area row above, design one or more concrete epics with an explicit goal, story breakdown, and Gherkin-style acceptance criteria."* That step has not run. The `stepsCompleted: ['step-01-validate-prerequisites']` frontmatter confirms.

**Impact:** Sprint Planning cannot meaningfully run because there are no stories to plan. `bmad-create-story` cannot produce a story from scratch — it expects an existing epic with story candidates.

**Resolution:** Run `bmad-create-epics-and-stories` step 2 (and onward) to produce concrete epics with stories and Gherkin acceptance criteria.

#### 🟠 MAJOR — UX deferral model not declared in `epics.md`

Per Step 4: UX is explicitly deferred by user, but the epic framework still includes Phase 0 Business UI Foundation + Phase 0 Admin UI Foundation + per-domain UI modules in every Phase 1–8. Either Phase 0 ships those UI foundations without a UX doc (relying on D4 "replicate APEX" + GOV.UK Design System) or those areas need explicit deferral markers.

**Resolution:** decide the model and document it in `epics.md`. Recommended wording in the Overview section:

> *"UX design is deferred to a later programme stage. Phase 0 Business UI Foundation and Admin UI Foundation will ship per AR42–AR45b using GOV.UK Design System base + HMCTS extensions + APEX-replica behaviour (per D4) as the implicit UX spec. Per-phase domain UI modules carry the same baseline. A per-phase 'UI parity & uplift notes' appendix will be written per service epic at story-design time."*

#### 🟠 MAJOR — 3 technical proto-epics need re-framing at story-design time

Platform & DevEx, Notification, and Data Migration ETL are technical milestones, not user-value epics. At story-design time, prefer vertical-slice stories that each end in a demoable user outcome rather than running an "infrastructure epic" that defers first user value.

**Resolution:** when running `bmad-create-epics-and-stories`, explicitly call out these three areas for re-framing — push their work into the first vertical slice that consumes them (e.g. Notification consumed by Phase 2 Absence's first acknowledgement-email story).

#### 🟡 MEDIUM — Cross-cutting NFRs lack explicit per-phase ACs

NFR1–NFR9, NFR10–NFR11, NFR14–NFR16, NFR30–NFR33, NFR34, NFR39 are tagged "inherited by every phase" but not assigned to specific stories. Risk: they fall off ACs when stories are written.

**Resolution:** at story-design time, each phase's user-facing stories must explicitly call out the NFRs that apply at that phase. E.g. Phase 5 Sitting list-operation story AC includes "list returns ≤ 10 s p95 at Region scope (NFR3)".

### Recommended Next Steps

1. **(Highest priority)** Run `bmad-create-epics-and-stories` to advance `epics.md` from framework to stories-with-ACs. Apply the remediation guidance from Step 5 (vertical-slice stories for technical areas; explicit per-phase NFR ACs; stub-then-wire pattern for cross-phase integration points; AR2–AR4 scaffold story as Story 1 of every service epic).

2. **Declare the UX deferral model** in `epics.md` Overview section using the wording suggested above.

3. **Re-run this readiness check** (`bmad-check-implementation-readiness`) after stories are written, to validate story-level quality: independent value, no forward dependencies, Gherkin AC quality, FR Coverage Map populated, NFR-per-story AC traceability.

4. **Run `bmad-sprint-planning`** only after readiness check 2 reports 🟢 READY. Don't try to sprint-plan against a framework.

5. **Optional but recommended** before sprint planning:
   - Run `bmad-validate-prd` to confirm the PRD hasn't drifted since 2026-05-11.
   - Run `bmad-review-edge-case-hunter` on `epics.md` after stories are written, to catch missing edge cases.

### Path to READY

```
[Today] Framework + PRD + Architecture ready
   ↓
[Next] bmad-create-epics-and-stories (step 2+) → stories + ACs
   ↓
[Then] Re-run bmad-check-implementation-readiness → expect 🟢
   ↓
[Then] bmad-sprint-planning → kicks off implementation
```

### Final Note

This assessment identified **1 blocker, 2 major issues, 1 medium issue**, and a series of pre-emptive remediations for story-design time. The blocker has a clear, single-skill remediation (`bmad-create-epics-and-stories`).

**The good news:** PRD and architecture are in strong shape. NJI's planning is roughly 70% to implementation-ready. The remaining 30% is one focused workstream — turning the Phase × Area framework into stories with acceptance criteria.

These findings can be used to advance the artefacts; you may also choose to proceed as-is, with the understanding that sprint planning and story creation cannot be meaningfully run until the epics gap is closed.

---

**Report generated:** 2026-05-15
**Assessor:** Claude (bmad-check-implementation-readiness)
**Output file:** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-15.md`
**Previous reports for comparison:** `2026-05-05`, `2026-05-06`






