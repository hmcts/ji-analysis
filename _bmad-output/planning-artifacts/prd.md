---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation-skipped', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
workflowCompleted: true
completedAt: '2026-05-05'
productCodename: 'RAM Pathfinder'
releaseMode: 'phased'
inputDocuments:
  - '_bmad-output/brainstorming/brainstorming-session-2026-05-05-1600.md'
  - 'docs/architecture/asis/functional-modules.md'
  - 'docs/architecture/asis/data-dependencies.md'
  - 'docs/architecture/asis/integration-dependencies.md'
workflowType: 'prd'
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 1
  projectDocs: 3
  projectContext: 0
classification:
  projectType: 'api_backend'
  projectTypeOverrides:
    - 'ux_ui in scope per D4'
    - 'visual_design in scope per D4'
    - 'user_journeys in scope per D4'
  domain: 'govtech'
  domainNotes: 'UK HMCTS — judicial operations; HMCTS/WCAG accessibility, GDS service standard, UK GDPR, FOI/transparency.'
  complexity: 'high'
  projectContext: 'brownfield-rebuild'
  classificationRationale: 'Scoring during Advanced Elicitation: api_backend (24) vs web_app (22) vs saas_b2b (18); govtech (29) vs legaltech (10). api_backend is composed of 11 APIs; UX/journeys is in scope because D4 requires UI replication.'
---

# Product Requirements Document - ji-analysis

**Author:** Ramnish
**Date:** 2026-05-05

## Document Map

RAM Pathfinder is a greenfield rebuild of HMCTS's Judicial Itineraries system. 11 services, modern UI, Azure-deployed. Replaces the unsupported Oracle APEX (OPT) platform. Built in isolation from APEX; cutover is phased per region.

| Section | Contents |
|---|---|
| Executive Summary | What RAM Pathfinder is and why it is being built |
| Project Classification | Project type, domain, complexity |
| Success Criteria | Definition and measures of success |
| Product Scope | MVP, growth, vision |
| User Journeys | How users flow through RAM Pathfinder |
| Domain-Specific Requirements | UK govtech compliance, technical, integration constraints |
| API Backend Specific Requirements | The 11-service API surface |
| Project Scoping & Phased Development | MVP scope, build phases, rollout waves |
| Functional Requirements (FR1–FR61) | Capability contract |
| Non-Functional Requirements (NFR1–NFR42) | Quality-attribute contract |
| Decisions Log (D1–D10) | Programme-level decisions |
| Glossary, References | Acronyms and source documents |

## Executive Summary

JI (Judicial Itineraries) is HMCTS's system for planning, allocating, confirming, and paying judicial sittings across Civil, Family, and Crown Courts. It runs on an unsupported Oracle APEX (OPT) platform and is Board-endorsed for full replacement.

This PRD describes the greenfield rebuild — **RAM Pathfinder** — as an API-driven application. RAM Pathfinder replicates APEX's functional surface across 11 services (Domain / Cross-cutting / Read-model), with a modern UI replacing APEX's. RAM Pathfinder exposes APIs that HMCTS programmes (DA&I, finance, Tribunals, Actuals, Scheduling & Listing) consume directly, replacing today's export-file-by-email integration.

**Target users (~11 roles, scoped by Region and Area):**

- RSU / Judicial Team (Admin, Full Access, Verifier / Read-only)
- Court users (Full Access, Enhanced CJ, Limited / Read-only)
- Judges, Judges' Clerks, Presiding Judges / Clerks
- Finance / Payment Authoriser
- MI / Reporting User

*Operational platform support (OPT Support in the legacy system) is handled by external HMCTS roles and is not a JI user role.*

**Problems being solved:**

1. OPT / APEX is unsupported with a fixed end-of-life.
2. The export-only integration model (Excel, PDF, email) does not scale to upcoming HMCTS programmes (Tribunals coverage, Actuals, Scheduling & Listing reforms).
3. APEX's UI is dated. RAM Pathfinder provides a modern, accessible, performant UI.

**Success:** every region migrated to RAM Pathfinder; APEX retired; downstream consumers integrating via API; future HMCTS programmes building on JI's APIs.

### Key characteristics

1. **Greenfield, not strangler.** APEX does not support strangler decomposition. RAM Pathfinder is built end-to-end before any user moves; APEX runs unchanged for non-migrated regions during phased rollout. No dual-write, no event bus, no synchronisation layer.

2. **Simplification.** REST-first synchronous coordination; Strategy A federated read models (Itinerary, MI Feed); no event stream; no webhook surface; log-based audit and observability for MVP (D7) with structured user-action audit on the post-MVP roadmap.

3. **APEX as the behavioural reference, verified by manual UAT (D5, revised 2026-05-06).** UAT is performed by users with hands-on APEX experience — RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI. They compare RAM Pathfinder behaviour against APEX side-by-side. No automated APEX-comparison harness; APEX is not co-managed (D6).

4. **Phase 0 as platform smoke-test.** Reference Data and Users + Roles migrate from APEX into RAM Pathfinder tables in Phase 0 (D3 + D9 + D10), via a dedicated ETL that reads APEX dumps, transforms rows, and **loads via direct SQL INSERT** statements (per D10, revised from "via the Reference Data and Authorisation APIs"). API-as-Product standards (versioning, OpenAPI, deprecation via [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) are exercised on **Reference Data read endpoints** and Authorisation lookups before any domain service is built. Admin-write API endpoints (and the admin UI that would consume them) are deferred post-MVP per D10.

5. **Per-region phased cutover (D8).** Each wave moves one region with all applicable user roles together. Migrated users do not use APEX; non-migrated users do not use RAM Pathfinder. No contention or synchronisation.

**Why now:** OPT is unsupported. HMCTS programmes need integration patterns the export-only legacy cannot deliver. Each month on APEX delays API integration for the wider ecosystem.

## Project Classification

| Dimension | Value |
|---|---|
| **Project Type** | `api_backend` — composed of 11 APIs |
| **Project Type override** | `ux_ui`, `visual_design`, `user_journeys` are in scope per D4 (modern UI replicates APEX layouts) |
| **Domain** | `govtech` (UK HMCTS — judicial operations) |
| **Domain notes** | UK compliance: HMCTS / WCAG accessibility, GDS service standard, UK GDPR, FOI / transparency. |
| **Complexity** | `high` |
| **Project Context** | `greenfield-rebuild` |
| **Classification rationale** | Scoring during Advanced Elicitation: `api_backend` 24, `web_app` 22, `saas_b2b` 18; `govtech` 29, `legaltech` 10. `api_backend` + UX override fits an API-first product with UI in scope. |

## Success Criteria

### User Success

Each role can complete its legacy workflow on RAM Pathfinder without re-training, and faster or no slower than APEX:

- **RSU / Judicial Team**: maintain judges, working patterns, tickets, absences, vacancies. Vacancy auto-creation from approved absences works end-to-end (R4).
- **Court users**: confirm sittings and bookings with comparable or fewer clicks than APEX. AM/PM split, work-type editing, and verifier sign-off (County Courts) preserved.
- **Judges and Judges' Clerks**: itinerary and forward look filtered to authorised judges only (R2). No case-level data exposure.
- **Finance / Payment Authoriser**: JFEPS-compatible Excel via the same email mechanism as APEX. JFEPS schedule shape unchanged.
- **MI / Reporting**: standard reports with the same parameter filters as APEX. Excel and PDF export preserved. Aggregate-only.
- **All roles**: WCAG-compliant UI; performance baseline meets APEX page-level NFRs (≤ 5 s dashboard refresh, ≤ 10 s list/filter, ≤ 15 s batch/annual, ≤ 30 s reports/Forward Look).

### Business Success

- **APEX retirement** — every region migrated; Oracle APEX (OPT) decommissioned.
- **Strategic integration platform** — at least one HMCTS programme (Tribunals coverage, Actuals, Scheduling & Listing) integrating via API by `TBD post-MVP date`, replacing the export workflow.
- **Continuity** — zero unpaid judges due to migration. Payment exports to JFEPS/Liberata continue uninterrupted across every rollout wave.
- **Delivery** — phase-by-phase cadence (Phase 0 → 8 build, then per-region rollout). Specific dates are programme-management territory.

### Technical Success

- **All 11 services live** — Reference Data, Authorisation, Notification, Judge, Absence, Vacancy, Booking, Sitting, Payment, Itinerary, MI Feed (Phases 0 → 8). Per-service config: Spring profiles + Key Vault. Cross-service policy values: shared `configuration_values` table.
- **Phase 0 migration correctness** — 100% of in-scope Reference Data lists ETL'd into RAM Pathfinder and signed off by RSU/judicial-team owners (D3, Risk #13). 100% of active APEX users loaded into Authorisation and mapped to IdP principals (D9, Risk #14); unmatched records have an explicit decision (drop/hold/manual map). Zero ambiguous migrations.
- **Behavioural parity** (D5) — manual UAT script per domain service, walked by APEX-experienced users (RSU, Court, Judge, Judges' Clerks, Finance, MI). Sign-off is the wave gate.
- **API-as-Product** from Phase 0 — versioned contract, OpenAPI spec, deprecation policy ([RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) `Deprecation` + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) `Sunset`) per service.
- **Performance NFRs** met or exceeded (≤ 5 s dashboard refresh; ≤ 10 s list/filter; ≤ 15 s batch/annual; ≤ 30 s reports/Forward Look).
- **Strategy A federated read models** (Itinerary, MI Feed) meet their NFRs at MVP, or Strategy C cache fallback is in place by the wave that needs it (Risk #9).
- **Log-based observability** (D7) from Phase 1 — structured logs, correlation IDs, error categorisation, retention sufficient for pilot incident triage.

### Measurable Outcomes

| Outcome | Target | Source |
|---|---|---|
| Reference Data migration accuracy | 100% of in-scope lists, signed off by named owners | D3 + Risk #13 |
| User-record migration accuracy | 100% of active APEX users mapped to IdP principal; zero ambiguous records | D9 + Risk #14 |
| Payment export continuity at cutover | Zero failed JFEPS payment cycles attributable to migration | Business success criterion above |
| Behavioural parity per domain service | 100% of manual UAT scripts (run by APEX-experienced users comparing RAM Pathfinder vs APEX) signed off before that wave's cutover | D5 (revised) |
| Per-wave feature parity | 100% of in-region role workflows demoed and signed off before wave cutover | D8 + Risk #3 |
| Page-level performance | All page-level NFRs from `functional-modules.md` met or exceeded | functional-modules.md cross-cutting NFRs |
| Forward Look (federated read) | ≤ 30 s for a Region under Strategy A; Strategy C cache fallback designed | JFL-NFR-01, Risk #9 |
| API consumer onboarding (post-MVP) | At least one external HMCTS programme integrating via API by `TBD` | Vision: strategic integration platform |
| MVP user-action audit | Not in MVP; on roadmap (D7) | D7 |

## Product Scope

### MVP — Minimum Viable Product

The MVP is the smallest deliverable that supports phased per-region rollout (D8). It comprises:

- **Phase 0 Foundations** (D1, D7, D9): Reference Data + Users/Roles migrated from APEX; Authorisation with SSO; Notification; API contracts (versioned + paper contracts for Itinerary / MI Feed); deployment platform (CI/CD); structured logging conventions (D7); stub Home / navigation shell. *(Per-service configuration via Spring profiles + Key Vault; shared `configuration_values` infrastructure table managed by `ram-architecture` Flyway baseline.)*
- **All 11 services built** (Phases 0–8): Reference Data, Authorisation, Notification (Phase 0); Judge, Absence, Vacancy, Booking, Sitting, Payment (incl. Reconciliation) (Phases 1–6); Itinerary, MI Feed (Phases 7–8). *(Per-service config is Spring profiles + Key Vault; cross-service policy values use the shared `configuration_values` infrastructure table — no separate configuration service per arch v2.2.)*
- **Modern business-user UI** for all 11 judicial / operational roles replicating APEX layouts (D4) — every domain phase delivers its corresponding APEX module(s) end-to-end through `ram-ui`. **Admin UI (`ram-admin-ui`) is NOT in MVP** per D10 (2026-05-15 scope decision); admin tasks in MVP — reference-data maintenance, user/role/scope updates, activation toggles, migration-report review — happen via direct SQL by DBAs / platform engineers per operational runbooks.
- **Phase 9 — Pilot rollout (wave 1)**: one region migrates, all applicable roles, with feature-parity gating per Risk #3.
- **Behavioural parity with APEX** verified through **manual UAT performed by APEX-experienced users** (D5 revised) for every domain service. There is no automated APEX-comparison test harness in the MVP.
- **Log-based audit and observability** (D7) — application logs only; no metrics platform, no traces, no structured user-action audit.

**Explicit exclusions from MVP** (post-MVP roadmap):

- Structured user-action audit (D7 roadmap)
- Metrics + traces + dashboards observability (D7 — log-based MVP only)
- Domain event stream / webhooks (architecturally rejected for MVP — REST-first)
- Active matching / allocation service (architecturally deferred)
- Bi-temporal history
- Tribunals coverage
- Historical-data access for migrated users (D3 + Risk #2 — separate decision)
- **Admin UI (`ram-admin-ui`) — entire admin-facing surface deferred post-MVP per D10 (2026-05-15)**, including:
  - Reference Data maintenance UI (FR6's UI surface — read API + SQL-loaded data remain in MVP)
  - Users / Roles / Scope admin UI (FR4's UI surface — auth tables populated by SQL ETL in MVP; DBAs maintain via direct SQL)
  - Migration Reports review UI (sign-off in MVP via versioned git commits to `signoffs/` directory)
  - Activation Flag toggle UI (FR58 cutover in MVP via direct SQL by DBA per the rollout runbook)
  - Admin "Send Test Email" + Delivery-Log viewer (Notification integration testing in MVP via Postman against Mailpit)
- **Admin-write API endpoints** on `ram-reference-data` and `ram-authorisation` — read-only surfaces only in MVP; write endpoints ship with the admin UI post-MVP

### Growth Features (Post-MVP)

- **Admin UI (`ram-admin-ui`) — full repo + auth wrapper + admin theme + four MVP-deferred modules** (per D10):
  - Reference Data maintenance with named-owner sign-off workflow (UI surface of FR6)
  - Users & Roles admin: search, role edits, Region/Area scope edits, activation toggle (UI surface of FR4 + FR58)
  - Migration Reports module: view reconciliation reports, apply decisions to unmatched records, sign off via UI (alternative to the git-based sign-off used in MVP)
  - Notification utilities: "Send Test Email" + delivery-log viewer
- **Admin-write API endpoints** ship alongside the admin UI: `POST/PUT/PATCH/DELETE` on Reference Data; `PUT /v1/admin/users/{id}/{roles|region-scopes|activation}` on Authorisation.
- **Wave-by-wave rollout**: Phase 10..N — additional regions migrate, wave by wave, until all regions are on RAM Pathfinder and APEX is retired.
- **Structured user-action auditing** (D7 roadmap commitment) — who did what, when, with before/after values for write operations.
- **Full observability** — metrics + traces + dashboards beyond the log-based MVP minimum.
- **External API consumer onboarding** — DA&I migrates from export-based MI to API-based MI Feed; future programmes (Tribunals, Actuals, Scheduling & Listing) onboard onto JI's APIs.
- **Historical-data access** policy for migrated users — read-only APEX bridge, or one-shot export, or policy-of-no-access (Risk #2).
- **Cross-region workflow handling** matures from per-wave manual coordination (Risk #1) to system-supported flows.

### Vision (Future)

- **Strategic integration platform** for HMCTS judicial scheduling — Tribunals, Magistrates, Civil, Family, Crown all served by a single API-driven foundation.
- **Real-time data flow** to downstream systems (DA&I, finance, performance teams) — potentially via event streams or webhooks if integration patterns demand it (architecturally deferred today, revisitable when justified).
- **Active matching / allocation** service for fee-paid judges to vacancies, beyond today's filter-as-hint approach.
- **Automated reconciliation feed** from JFEPS to JI, replacing today's manual flag-as-reconciled step.
- **Bi-temporal / audit-grade compliance trail** if regulatory scope demands it (today out of scope; revisitable).

## User Journeys

### Journey 1 — RSU Admin: cover-creation through payment (canonical operational cycle)

**Persona:** Sam, RSU Admin in a regional office. Sam handles absences, vacancies, fee-paid allocations, booking confirmation, and reconciliation. (Payment-schedule generation is a scheduled batch — Sam confirms bookings/sittings, then reconciles after Liberata has paid; the batch generates and dispatches the JFEPS Excel in between.)

**Trigger:** A Court office logs an absence request for a salaried judge with cover required. The request appears in Sam's "Outstanding Actions" tile on the Home dashboard.

**Steps:**

1. Sam opens the absence from the dashboard tile. RAM Pathfinder shows the judge's profile, dates, work-type and ticket fields, and an *Approve* action.
2. Sam approves. The system auto-creates a vacancy (R4) pre-populated with judge type, work type, ticket, and dates. Status: *Needs allocation*.
3. Sam advertises the vacancy out-of-system (same as APEX). A fee-paid judge replies.
4. Sam clicks *Create Booking*, picks the judge, fills the session details. The booking is created and the vacancy is marked filled in the same transaction (R5). An acknowledgement email is queued to the booked judge.
5. The Court confirms the sitting. Booking moves to *Confirmed* and becomes eligible for payment.
6. The payment batch runs on schedule, picks up confirmed bookings/sittings without payment records, generates the JFEPS Excel, and emails it to the Payment Authoriser. No user action.

**Outcome:** Sam completes the cycle in fewer clicks than APEX. JFEPS output lands at the same finance team.

### Journey 2 — Court user: daily sitting confirmation

**Persona:** Priya, Court user (Full Access) in a Crown Court office. Priya confirms yesterday's sittings — verifying they took place, recording actual work type, adjusting session duration. Confirmed sittings drive payment and MI.

**Trigger:** Priya logs in via SSO. Home shows a *Sittings awaiting confirmation* tile scoped to her office.

**Steps:**

1. Priya opens the sittings list, filtered to *yesterday, this office*.
2. For each sitting: confirm with one click; or open the row, change work-type (e.g. *Crime* → *Civil*, per functional-modules.md line 422), split AM/PM as needed.
3. For one fee-paid Recorder, the booking required confirmation rather than a sitting; same one-click flow in the Bookings list.
4. Priya finishes the day's confirmations in under five minutes.

**Outcome:** Yesterday's data is locked in for payment and MI before Priya's first coffee.

### Journey 3 — Judge: view itinerary and request absence

**Persona:** Justice Hawthorne, salaried Circuit Judge. Uses JI to see planned sittings and request absences (training, leave).

**Trigger:** Logs in via SSO on a tablet between hearings. The Judge Itinerary view loads scoped to their own profile (R2).

**Steps:**

1. Itinerary renders on tablet — accessible, responsive, performant.
2. Justice Hawthorne sees a clash with planned training next month, opens *Request Absence*.
3. Form: dates, type (training), notes. Submit.
4. Request routes to RSU for approval (functional-modules.md §4.5). Acknowledgement email sent via Notification.

**Outcome:** Request lands with RSU; the judge moves on to the next hearing.

### Journey 4 — DA&I analyst: consume MI Feed API instead of Excel exports

**Persona:** Riya, DA&I analyst building monthly utilisation dashboards. Today she runs APEX reports, copy-pastes to Excel, transforms, then feeds her dashboard.

**Trigger:** Post-MVP, JI exposes the MI Feed API. Riya gets API credentials (her IdP principal, authorised by JI Authorisation) and writes a script.

**Steps:**

1. `GET /reporting/sittings` with region, judge type, date range. Returns aggregated JSON (no case-level data per REP-BR-NFR-03).
2. Replaces three APEX-export-and-transform steps.
3. Riya schedules the script nightly.
4. When the contract changes, the OpenAPI spec, versioned content-type, and `Deprecation`/`Sunset` headers tell Riya what changed and when.

**Outcome:** The export-and-transform manual chain is gone. Future programmes (Tribunals, Actuals) onboard onto the same APIs.

### Journey 5 — Edge case: cross-region fee-paid booking during partial rollout (Risk #1)

**Persona:** Sam (from Journey 1) needs to book an off-circuit fee-paid judge. Judge's home region (B) is on RAM Pathfinder; Sam's region (A) is still on APEX. Only applies during the rollout window.

**Trigger:** Sam needs to allocate a Region B fee-paid judge to a Region A vacancy.

**Steps:**

1. APEX (Region A) has the vacancy. RAM Pathfinder (Region B) has the judge.
2. Per Risk #1 mitigation, the workflow falls back to manual coordination: Sam phones Region B's RSU; Sam records the booking in APEX with a manual reference to the Region B judge identifier.
3. APEX processes the booking. Region B's RSU records the booking in RAM Pathfinder out-of-band.
4. When Region A migrates, the workflow disappears — both sides on RAM Pathfinder.

**Outcome:** Cross-region operations continue with documented manual handling for the rollout window only. Risk #1 is operationally managed, not architecturally solved.

### Journey Requirements Summary

The five journeys reveal these capability areas (mapped to the 11-service decomposition):

| Capability area | Services / decisions involved |
|---|---|
| Authentication via SSO + Authorisation gating per role + Region/Area | Authorisation (cross-cutting); D9 (users + roles migrated) |
| Absence approval workflow → automatic Vacancy creation | Absence (domain), Vacancy (domain); R4 |
| Booking with `Vacancy.markFilled` orchestration | Booking (domain), Vacancy (domain); R5 |
| Sitting / Booking confirmation by Court users | Sitting (domain), Booking (domain) |
| Payment schedule generation in JFEPS-compatible Excel | Payment (domain) with versioned content-type |
| Booking acknowledgement and absence acknowledgement emails | Notification (cross-cutting) |
| Modern UI with accessibility, responsiveness, performance | UX-override per D4 |
| Itinerary view scoped to own profile (Judges) | Itinerary (read model); Strategy A federation |
| Aggregated, case-level-stripped MI Feed API for DA&I | MI Feed (read model); REP-BR-NFR-03 |
| API-as-Product standards (versioning, OpenAPI spec, deprecation policy via `Deprecation` + `Sunset` headers) | All services per Phase 0 (D1) |
| Per-wave cross-boundary manual coordination | Programme management (not application capability); Risk #1 |

## Domain-Specific Requirements

### Compliance & Regulatory (UK govtech)

- **Accessibility — WCAG 2.2 Level AA**, required by the Public Sector Bodies (Websites and Mobile Applications) Accessibility Regulations 2018. Every domain phase delivers UI per D4; each phase's UI must be tested for WCAG 2.2 AA before cutover. APEX-era baseline is preserved at minimum; modern UI on new technology (per the user-experience uplift in the vision) targets a measurable improvement.
- **GDS Service Standard alignment** — HMCTS internal systems reference the GDS Service Standard as the bar for digital service quality. Full GDS service assessments are not always required for internal-only systems, but the principles (user research, accessibility, performance, security, simple-as-possible) apply.
- **UK GDPR and Data Protection Act 2018** — personal data scope is limited to user/judge identity, contact details, payroll numbers, and operational metadata. **JI does not hold case-level data** (REP-BR-NFR-03 from `functional-modules.md`); this remains a binding constraint.
- **HMCTS / MoJ Government Functional Standard 7 — Security** — protective marking, access control, secure development practices. Implementation aligns with HMCTS-approved technology stack and security frameworks.
- **MoJ authentication policy** — under SSO (per locked Authorisation decision), authentication policy is owned by the HMCTS IdP, not JI. JI's Admin module's password-change capability disappears (D9 + the noted absorption of the Admin module under SSO).
- **Freedom of Information Act 2000** — JI's aggregate sitting / utilisation data is FOI-exposable; the MI Feed API is aggregate-only by contract (REP-BR-NFR-03). Case-level data is forbidden by contract; this protects against FOI scope creep into individual hearings.
- **Government / HMCTS retention schedules** — data retention is determined by HMCTS policy. Note: migrated transactional history stays in APEX (D3); new transactional data starts fresh on RAM Pathfinder. Retention obligations therefore span both systems during the rollout window.

### Technical Constraints

- **Encryption in transit** — latest TLS only (per programme-level security guidance and the standing rule on latest SSL/TLS versions). HTTP-only endpoints rejected.
- **Encryption at rest** — for personal data (judge records, user/role records, working patterns, payroll numbers).
- **No bank details exposure** (PAY-NFR-05) — JI never stores bank details; the finance system retains them. This is a hard architectural constraint, carried from APEX.
- **No case-level data exposure** (REP-BR-NFR-03) — Reports and MI Feed are aggregate-only. Case-level identifiers are not part of the JI data model.
- **Audit minimum (MVP)** — log-based per D7. Structured user-action audit (who did what, when, with before/after values) is a post-MVP roadmap commitment, not an MVP capability.
- **AuthN delegated to HMCTS IdP via SSO**; **AuthZ owned by JI's Authorisation service** per architectural decision. User records and role/scope mappings migrated from APEX in Phase 0 (D9), keyed to IdP principal. **HMCTS IdP password policy, session policy, and account lifecycle are wholly external to JI** — owned by central HMCTS org; JI inherits whatever the IdP enforces and does not duplicate or constrain it.
- **Performance NFRs** carried from APEX page-level baselines (≤ 5 s dashboard, ≤ 10 s list/filter, ≤ 15 s batch/annual, ≤ 30 s reports/Forward Look) — already enumerated in Success Criteria.
- **No JI involvement in payment processing** — JI generates the JFEPS-shaped Excel and emails it to a Payment Authoriser; the authoriser forwards to Liberata out-of-system. JI is not in the payment chain itself, only the schedule-generation chain.

### Technology Stack (locked)

- **API layer:** Java 25 (current LTS) with Spring Boot 4.
- **Runtime / orchestration:** Kubernetes — containerised deployment for every domain and cross-cutting service.
- **Cloud platform:** Microsoft Azure — all services deployed on the Azure platform. Production runs in Azure UK South; data residency is restricted to Azure UK regions per NFR31. Azure-native service choices (e.g. AKS, Azure Container Registry, Azure Key Vault, Azure Application Insights, Azure database services) are implementation decisions in the architecture phase.
- **UI stack:** modern UI per D4; specific framework family is an implementation decision in the architecture phase, not locked here.
- **Implications worth carrying forward:**
  - Spring Boot 4 + Java 25 fits REST-first synchronous coordination. The HTTP client, JSON content-type negotiation, and OpenAPI tooling are all standard.
  - Spring Actuator endpoints serve build/version metadata (`/actuator/info`, populated by `gradle-git-properties`) and Kubernetes liveness/readiness probes (`/actuator/health`, `/actuator/readiness`); the `/actuator/*` namespace is ops-restricted at the APIM layer. The OpenAPI spec (Swagger Core, published as a Maven artefact) is the consumer-facing contract.
  - Kubernetes orchestration on Azure enables the per-region phased rollout (D8) — region-scoped deployments, rolling updates, isolated rollbacks per wave.
  - Azure UK regions support UK GDPR and HMCTS data-sovereignty requirements (data residency in-country); avoids the need for Standard Contractual Clauses or transfer impact assessments that would apply if data left the UK.
  - Azure-native logging (Application Insights / Log Analytics) is a natural fit for the log-based audit / observability minimum (D7); structured logging conventions defined in Phase 0 should target Azure-native ingestion.

### Integration Requirements

| Integration | Direction | Phase | Mechanism | Notes |
|---|---|---|---|---|
| **HMCTS IdP (SSO)** | Inbound (AuthN) | Phase 0 | OIDC / SAML (per HMCTS standard) | Hard dependency; must be live in Phase 0 for any user-facing demo. Risk #6 in 1600 brainstorming. |
| **JFEPS / Liberata** | Outbound (payment) | Phase 6 | JFEPS-compatible Excel via HMCTS email, forwarded by Payment Authoriser | **Unchanged from APEX** — same format, same mechanism, same human-in-the-loop. |
| **HMCTS Email infrastructure** | Outbound (notifications) | Phase 0 / used Phase 1+ | SMTP via HMCTS email | Booking ack, absence ack, payment schedule. Required dependency. |
| **DA&I (MI Feed)** | Outbound (data) | Phase 8 | MI Feed REST API (Strategy A pull-based federation) | Replaces export-by-email; aggregate-only contract per REP-BR-NFR-03. |
| **eLinks / HR systems** | Inbound (judge data) | — (out of scope for MVP) | Manual entry (carried from APEX) | Aspirational eLinks integration (NFR-3 in source docs) is **not** in MVP scope; manual data entry continues. |
| **Future programmes** (Tribunals, Actuals, Scheduling & Listing) | Outbound (APIs) | Post-MVP | REST APIs from JI | Vision-level; specific contract design happens when programme demand crystallises. |

### Risk Mitigations (domain-specific)

- **Accessibility regression vs APEX.** APEX meets HMCTS accessibility commitments (HOME-NFR-04, MJ-NFR-05, etc.). RAM Pathfinder must match or exceed. **Mitigation:** WCAG 2.2 AA testing per UI page in each domain phase; assistive-technology compatibility (keyboard navigation, ARIA labels for tabbed content) included in acceptance tests.
- **Data-protection regression.** APEX's constraints (no bank details, no case-level data) are binding for RAM Pathfinder. **Mitigation:** these constraints are encoded as architectural rules — Payment service contract excludes bank fields; MI Feed and Reports schemas exclude case identifiers.
- **FOI exposure broadening.** A new API surface (MI Feed) creates new FOI questions about what data is published. **Mitigation:** MI Feed contract is aggregate-only and version-controlled; FOI scope is pre-determined by the contract, not by ad-hoc query capability.
- **Security clearance / vetting of implementation team.** Programme-management territory; not specified in this PRD. **Mitigation:** team members handling judicial / personal data work under HMCTS standard clearance levels.
- **HMCTS IdP integration timing.** SSO must be live in Phase 0; if HMCTS IdP integration slips, the MVP rollout is blocked. **Mitigation:** mock-IdP fallback for internal demo during Phase 0, contingency to wire to a different HMCTS-approved IdP if needed (carried from Risk #6 in 1600 brainstorming).
- **Reference Data + Users/Roles migration correctness** (D3 + D9 + Risk #13 + Risk #14) — already in the Risk register; restated here as a domain-specific concern because incorrect role assignments are a governance and access-control issue, not just a technical bug.

## API Backend Specific Requirements

### Project-Type Overview

JI is composed of 11 services in three clusters (revised v2.2 — `ram-configuration` dropped; cross-service policy values live in a shared `configuration_values` table):

- **Domain services:** Judge, Absence, Vacancy, Booking, Sitting, Payment.
- **Cross-cutting services:** Reference Data, Authorisation, Notification. (Configuration is not a service — per-service Spring profiles + Key Vault, with a shared `configuration_values` table for cross-service policy values.)
- **Read-model services (federated):** Itinerary, MI Feed.

Every service is API-first with a versioned contract. Services are callable by the UI (per D4) and external consumers (DA&I, future programmes).

### Technical Architecture Considerations

- **Coordination:** REST-first synchronous. Services call each other directly (e.g. Booking → `Vacancy.markFilled`). No event stream, message bus, or webhook fabric.
- **Read-model federation:** Strategy A — fan-out at request time. Itinerary and MI Feed hold no data of their own. Strategy C (cached projection) is the designed fallback if Forward Look misses ≤ 30 s NFR (Risk #9).
- **Service-to-service auth:** internal calls use service-token / mTLS (specifics in architecture phase); external calls use the same SSO/IdP-derived principal as user calls.
- **Idempotency:** retryable writes (e.g. `POST /bookings`, `POST /payments/process`) accept an idempotency key. Mechanism in architecture phase.

### Endpoint Specifications

Endpoint shape is illustrative — definitive contracts are produced as Phase 0 paper artefacts (per D1) and in each domain phase as the service is built.

**Cross-cutting services (Phase 0):**

| Service | Representative endpoints |
|---|---|
| Reference Data | `GET /reference-data/regions`, `/offices`, `/judicial-vocabularies`, `/calendar`; admin-gated `POST/PUT` writes |
| Authorisation | `POST /authz/check`, `GET /users/{id}/effective-permissions` |
| Configuration | Per-service: Spring profiles + `application.yml` + Azure Key Vault. Cross-service policy values: shared `configuration_values` table (read-only via direct SQL; no API). |
| Notification | `POST /notifications/send` (transactional emails: booking ack, absence ack, payment schedule) |

**Domain services (Phases 1–6):**

| Service | Representative endpoints |
|---|---|
| Judge | `POST/GET/PUT /judges`, `POST /judges/{id}/working-patterns`, `POST /judges/{id}/tickets` |
| Absence | `POST/GET /absences`, `POST /absences/{id}/approve`, `POST /absences/{id}/extend` *(sickness only)* |
| Vacancy | `POST/GET /vacancies`, `POST /vacancies/{id}/markFilled` *(called by Booking, R5)*, `POST /vacancies/{id}/cancel` |
| Booking | `POST /bookings` *(accepts optional `vacancyId` and orchestrates `Vacancy.markFilled`)*, `POST /bookings/{id}/confirm`, `POST /bookings/{id}/cancel` |
| Sitting | `POST/GET /sittings`, `POST /sittings/{id}/confirm`, `POST /sittings/{id}/verify`, `POST /sittings/{id}/split` *(AM/PM)* |
| Payment | `POST /payments/process` *(eligible bookings → schedule)*, `GET /payments/{id}/schedule` *(content-type negotiated)*, `POST /payments/{id}/reconcile` |

**Read-model services (Phases 7–8):**

| Service | Representative endpoints |
|---|---|
| Itinerary | `GET /itineraries/courts/{officeId}` *(monthly / annual)*, `GET /itineraries/judges/{judgeId}`, `GET /itineraries/forward-look` |
| MI Feed | `GET /reporting/sittings`, `GET /reporting/utilisation`, `GET /reporting/vacancies`, `GET /reporting/bookings` *(all aggregate-only per REP-BR-NFR-03)* |

### Authentication Model

- **End-user authentication: HMCTS IdP via SSO** (OIDC or SAML — exact mechanism is HMCTS-IdP-side; JI integrates with whichever the IdP exposes).
- **End-user authorisation: JI's Authorisation service.** Migrated APEX users (per D9) are keyed to the IdP principal. Every domain call resolves the principal's roles + Region/Area scope via Authorisation before authorising the action.
- **HMCTS IdP password / session / account lifecycle policies are wholly external to JI** (per Step 5 Technical Constraints) — JI inherits whatever the IdP enforces.
- **Service-to-service authentication:** TBD in architecture phase; mTLS or service-token is the typical fit for the chosen Java/Spring/Kubernetes stack.
- **External consumer authentication** (DA&I MI Feed, future programmes): same IdP principal model where possible; service principals or API keys are an architecture-phase fallback if the IdP doesn't issue principals for non-human consumers.

### Data Schemas

Canonical representation: **JSON** for all REST endpoints. Specific resource schemas (Judge, Absence, Vacancy, Booking, Sitting, Payment, Itinerary, Reporting feed) are produced as Phase 0 paper contracts (per D1) and refined per phase.

**Versioned content-types** for shape-sensitive resources:

- `GET /payments/{id}/schedule` accepts `application/vnd.hmcts.jfeps+json` (canonical JI shape) or `application/vnd.hmcts.jfeps+xlsx` (format-shifted JFEPS Excel for Liberata workflow). The JFEPS shape evolves independently of Payment internals.
- Other resources may grow versioned content-types over time as integration partners require shape-stability.

**Forbidden fields by contract:**

- Bank details (PAY-NFR-05) — not in any Payment resource shape.
- Case-level identifiers (REP-BR-NFR-03) — not in Reports or MI Feed shapes.

### Error Codes

- **HTTP status codes** semantically — 200/201 for success, 400 for validation errors, 401/403 for auth, 404 for not-found, 409 for conflict (e.g. double-booking attempts blocked by FPB-NFR-04), 422 for semantically valid but business-rule-rejected, 5xx for server-side faults.
- **[RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) Problem Details for HTTP APIs** as the standard error envelope — `type`, `title`, `status`, `detail`, `instance`, plus problem-specific extension fields where useful. (RFC 9457 obsoleted [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807) in July 2023; the `application/problem+json` content type and field shape are unchanged.)
- Architecture-phase decision: define the specific problem `type` URIs for the cross-cutting categories (validation failure, authorisation failure, business-rule rejection, dependency failure, etc.).

### Rate Limits

**TBD — architecture-phase decision.** For internal HMCTS systems with a bounded user population, rate limits are typically low priority for human traffic; the relevant cases (per-service-principal limits for MI Feed, burst protection against runaway scripts) will be specified in the architecture phase.

### API Versioning

- **Versioning policy is a Phase 0 deliverable** as part of API-as-Product standards (per D1).
- Working assumption (architecture-phase confirmable): versioning via the URI path prefix (e.g. `/v1/judges`, `/v2/judges`) for major versions; backwards-compatible additions within a major version don't require a new path.
- **Deprecation policy** is part of the same Phase 0 artefact: deprecated endpoints emit `Deprecation` ([RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745)) and `Sunset` ([RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) response headers, are documented, and are retired no sooner than N months after first deprecation notice (specific N TBD).
- **Consumer contract surface** is the published OpenAPI spec (Maven artefact; Swagger UI for browsing). Build/version metadata is exposed via Spring Actuator `/actuator/info` (ops-restricted).

### Client Tooling

- **API testing during build: Postman.** Postman collections are the primary client for validating APIs end-to-end as each service is built, ahead of the UI layer being wired in. Each phase produces a Postman collection that exercises the phase's endpoints against running services in the deployment platform.
- **UI layer client:** TBD in architecture phase. UI stack itself is not locked (per Step 5 Technology Stack — UI framework is an architecture-phase decision); specific UI-client tooling (e.g. generated TypeScript client from OpenAPI) follows from that decision.
- **External consumer clients** (DA&I, future programmes): direct REST calls in their native stack are sufficient; no formal SDK is required for MVP.

### API Documentation

- **OpenAPI 3.x specifications** generated from each service's code (Spring Boot has standard OpenAPI tooling).
- **Lifecycle metadata** is conveyed via the OpenAPI spec (`info.version`, `paths.{path}.{method}.deprecated`) plus per-response `Deprecation` ([RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745)) and `Sunset` ([RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) headers.
- **Documentation hosting:** Swagger UI per service for developer onboarding, plus a published consolidated API catalog (architecture-phase decision on hosting / branding).
- **Postman collections** per phase serve double duty as test artefacts and as practical, executable API documentation for stakeholders ahead of UI demos.

### Implementation Considerations

- **Stack:** Java 25 + Spring Boot 4 + Kubernetes on Azure. Spring Web for REST endpoints, Spring Security for AuthZ, Spring Actuator for build/version metadata and liveness/readiness probes (`/actuator/info`, `/actuator/health`, `/actuator/readiness`; ops-restricted at APIM), springdoc-openapi for OpenAPI generation, Azure API Management for rate limits, header injection, and deprecation/`Sunset` policies.
- **Per-service deployment unit:** each of the 11 services is a containerised Spring Boot app on Kubernetes. Per-region rollout (D8) uses region-scoped namespaces or service-instance-level region targeting (architecture-phase choice).
- **Phase 0 as standards validation:** Reference Data exercises every API-as-Product standard (versioning, content-type negotiation, OpenAPI spec, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) errors, deprecation signalling) before any domain service is built.

## Project Scoping & Phased Development

Extends Product Scope with MVP philosophy, phase-by-phase journey mapping, and risk-based scoping.

### MVP Strategy

The MVP is "enough for one region — every applicable role, every operational workflow — to move off APEX and stay off it." For a greenfield rebuild of an unsupported system, the MVP cannot be smaller; less than this means no region can migrate (D2 + D8).

**Resource requirements:** TBD (programme-management territory). Two viable structures:

- **Variant α** (single squad, sequential): Phase 0 → Judge → Absence → Vacancy → Booking → Sitting → Payment → Itinerary → MI Feed → wave 1. Lower coordination overhead; longer calendar.
- **Variant β** (multi-squad, Sitting parallel from Phase 2): same dependency order; Sitting is co-developed with Booking. Shorter calendar; needs 2+ squads.

Default is α; β is a capacity-conditional upgrade.

### Phase-by-Phase Journey Mapping

Mapping the **5 user journeys** (Step 4) to the **build phases** (from the brainstorming session migration table). A journey becomes *demoable* at the end of the phase that completes its last dependency.

| Journey | Demoable at end of | Dependency |
|---|---|---|
| Journey 3 — Judge views itinerary | Phase 7 (Itinerary) | Federates over Judge + Absence + Vacancy + Booking + Sitting |
| Journey 2 — Court daily sitting confirmation | Phase 5 (Sitting) | Sitting + Authorisation; Phase 5 ends with confirmation flow live |
| Journey 1 — RSU cover-creation through payment (canonical operational cycle) | Phase 6 (Payment) | Full operational chain Judge → Absence → Vacancy → Booking → Sitting → Payment must be live |
| Journey 4 — DA&I MI Feed API consumer | Phase 8 (MI Feed) | MI Feed federates over all domain services including Payment |
| Journey 5 — Cross-region edge case during partial rollout | Phase 9+ (rollout window only) | Only relevant once at least one region has migrated; resolves once last region migrates |

**Stakeholder communication:** the canonical operational demo (Journey 1) is available at Phase 6. Phases 1–5 produce per-module demos against partial chains (e.g. Phase 1 demos Judge management; Phase 4 demos vacancy → booking but not confirmation → payment).

### Risk-Based Scoping

The 1600 brainstorming risk register applies. Scoping-level risks:

**Technical:**

- Strategy A read-model federation may miss ≤ 30 s Forward Look NFR (Risk #9). Strategy C cache fallback is designed and switched on if Phase 7 measurement shows the breach.
- Reference Data + Users/Roles migration correctness (Risk #13). Phase 0 includes named-owner sign-off as a deliverable.
- APEX ⇄ IdP identity mapping (Risk #14). Phase 0 produces a reconciliation report with explicit handling rules for unmatched records.

**Programme:**

- The strategic-platform vision (external HMCTS programme integrating via API by post-MVP) is aspirational. MVP ships with the API surface in place; external consumer onboarding is post-MVP.
- Cross-region workflow during partial rollout (Risk #1). Manual coordination per wave is a programme-management deliverable, not an application feature. Application stays simple.

**Resource:**

- Variant β is capacity-conditional. If capacity is constrained, α delivers the same MVP content on a longer calendar.
- HMCTS IdP integration timing (Risk #6). Mock-IdP for internal demos during Phase 0; contingency to wire to a different HMCTS-approved IdP if needed.

### Scope Confirmation

No requirement from the brainstorming session, the as-is docs, or D1–D9 has been de-scoped here. The MVP / Growth / Vision split is unchanged from Step 3. This step adds framing only.

## Functional Requirements

This section is the binding capability contract for RAM Pathfinder. UX, architecture, and epic breakdown will all trace back to these requirements. A capability not listed here will not exist in the final product unless explicitly added.

### Identity & Authorisation

- **FR1**: Authenticated users access RAM Pathfinder via HMCTS IdP single sign-on; password, session, and account lifecycle are owned by the IdP and not duplicated in RAM Pathfinder.
- **FR2**: RAM Pathfinder's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- **FR3**: Authorised users can retrieve their effective permissions for their authenticated session.
- **FR4** *(scoped 2026-05-15 per D10)*: System administrators can update role and Region/Area assignments for migrated and new users. **In MVP, the data layer is editable by DBAs via direct SQL on the auth tables** (data populated by Phase 0 Users/Roles ETL); **the admin UI surface is post-MVP** (`ram-admin-ui` Users & Roles module — see Growth Features). FR4's MVP success criterion is "an authorised DBA can update role/scope per the operational runbook"; the system-administrator role-with-UI surface ships post-MVP.
- **FR5** *(reframed v2.5, 2026-05-07 as post-MVP)*: External machine-to-machine consumers (e.g. DA&I post-MVP MI Feed) require an authentication mechanism. **At MVP, no machine-to-machine consumers are in scope** — every RAM Pathfinder runtime request is user-initiated, including planned DA&I integration (DA&I would authenticate as a human-equivalent identity at HMCTS IdP if onboarded post-MVP). The mechanism for genuine service-principal authentication (for non-user-initiated flows) is **a post-MVP open question** — see architecture changelog v2.5 and `architecture/gaps.md` G7. Options to be evaluated when the requirement arrives include an RAM Pathfinder-internal service-auth issuer, Azure Workload Identity, mTLS, and (if HMCTS IdP supports it) `client_credentials` against HMCTS IdP.

### Foundational Data Management

- **FR6** *(scoped 2026-05-15 per D10)*: RSU users can view and maintain Reference Data lists — Regions, Offices, judicial vocabularies, calendar / financial-year boundaries — with named-owner sign-off on changes. **In MVP**: the read API surface is delivered (`GET /v1/reference-data/...`), data is initially loaded by the Phase 0 Reference Data ETL via direct SQL, and named-owner sign-off happens via versioned git commits on the reconciliation reports; ongoing data corrections in MVP are made by DBAs via direct SQL per the operational runbook. **Post-MVP**: RSU-facing maintenance UI in `ram-admin-ui` with admin-gated write endpoints on `ram-reference-data` and an in-UI sign-off workflow (see Growth Features).
- **FR7** *(revised 2026-05-11)*: Every RAM Pathfinder service reads Reference Data via **direct SQL** on the shared schema's Reference Data tables (15 tables, SELECT-granted to each service's DB role) — no client class, no API fan-out, no cache (per architecture Principle 2). Reference Data is the **single writer** — all writes (Phase 0 ETL load + ongoing RSU maintenance per FR6) go through the versioned Reference Data API. No service holds duplicate or cached copies of Reference Data in its own tables.
- **FR8** *(revised v2.2, 2026-05-07)*: Cross-service runtime policy values (e.g. session timeout warnings, batch schedules, feature flags) are stored in a shared `configuration_values` infrastructure table, schema-managed by `ram-architecture`'s Flyway baseline migration and SELECT-granted to every RAM Pathfinder service DB role. Updates are made via Flyway migrations or direct admin SQL — no API service. Per-service configuration scoped to a single service uses Spring profiles + `application.yml` + Azure Key Vault.
- **FR9**: RAM Pathfinder dispatches transactional emails (booking acknowledgements, absence acknowledgements, payment schedules) via HMCTS email infrastructure, with a delivery log retained.

### Judge Records & Working Patterns

- **FR10**: RSU users can search and filter judges by name, base location, location type, and judge type.
- **FR11**: RSU users can maintain judge profiles, including personal details, judge type, base office, active/inactive status, and role-specific data (payroll number, retirement date, fee entitlement, London weighting, name-for-itinerary, heading).
- **FR12**: Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- **FR13**: RAM Pathfinder auto-populates judge itineraries up to the next 31st March from the working pattern, preserving any prior absences.
- **FR14**: RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- **FR15**: RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- **FR16**: RAM Pathfinder validates that jurisdictional split percentages total 100% before saving.
- **FR17**: RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- **FR18**: Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

### Absence Workflow

- **FR19**: Authorised users (RSU, Court, Judges where permitted) can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- **FR20**: RAM Pathfinder distinguishes auto-confirmed absences (from judicial teams) from those requiring confirmation (from Courts or judges); confirmation can trigger an acknowledgement email.
- **FR21**: Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- **FR22**: Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

### Vacancy & Cover

- **FR23**: RAM Pathfinder auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- **FR24**: Authorised users can create standalone vacancies independent of any absence.
- **FR25**: Authorised users can edit a vacancy's daily breakdown — cancel individual days with a captured reason; extend or shorten the period.
- **FR26**: RAM Pathfinder marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- **FR27**: RAM Pathfinder surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is performed out-of-system by judicial teams.
- **FR28**: Authorised users can cancel or close vacancies (e.g. when a parent absence becomes NTBF).

### Booking Management

- **FR29**: Authorised users can create fee-paid bookings (linked to a vacancy or standalone), capturing judge, court, date, session type (full / AM / PM / evening / reserved-matter), booking type, and work type.
- **FR30**: Booking creation marks the linked vacancy as filled within the same transaction when a `vacancyId` is supplied. *(Implementation per architecture: in-process direct DB update on the `vacancies` row using a per-service DB role grant; see architecture Principle 1 for the rationale and the cross-service-write rules.)*
- **FR31**: RAM Pathfinder tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- **FR32**: RAM Pathfinder sends booking acknowledgement emails to fee-paid judges, batched overnight or sent immediately via *Create and Email Now*.
- **FR33**: RAM Pathfinder requires a Y/N answer at booking time when a judge's fee entitlement is *Ask when booking*.
- **FR34**: RAM Pathfinder prevents double-booking of fee-paid judges for overlapping sessions.

### Sitting Management

- **FR35**: RAM Pathfinder generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- **FR36**: Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- **FR37**: Authorised users can confirm that a sitting actually took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- **FR38**: Authorised users can split a sitting into AM/PM with different work types within a single day.
- **FR39**: Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- **FR40** *(revised 2026-05-11)*: Verifiers can verify confirmed sittings; once verified, the data is read-only. Amendments after verification require **re-opening** the sitting via a UI re-open action gated by a distinct authorised role — the re-opener must be different from the original confirmer (SIT-NFR-02) and from a standard Verifier (at MVP, the permission is granted to RSU Admin only). The action captures a mandatory justification field and is fully audited (who, when, why, which sittings). No external Request-for-Change ticketing process — re-open is a first-class UI action with RBAC controls.

### Payment & Reconciliation

- **FR41** *(revised v2.6, 2026-05-07)*: Authorised users can list confirmed bookings and salaried sittings, filterable by Region/Office, judge, date range, and payment lifecycle status (pending, requested, paid, reconciled). The **payment-eligible** subset is the read-only union of confirmed bookings + sittings whose payment record does not yet exist; this is the input the scheduled batch consumes.
- **FR42** *(revised v2.6)*: RAM Pathfinder's **payment-processing batch** (`ram-payment-batch`, scheduled on a configurable cron — typically end-of-week) automatically marks eligible bookings as *payment requested* and creates the corresponding `payments` + `payment_schedules` records. **No user click is required** — the batch identifies the eligible set via SQL JOIN over confirmed bookings + sittings without an existing payment record. Authorised users can also list and review the generated schedule before / after dispatch.
- **FR43** *(revised v2.6)*: The **payment batch** generates JFEPS-compatible payment schedules and dispatches them as Excel attachments to a configured Payment Authoriser via email (using its service-principal identity to call the Notification API); the Payment Authoriser forwards to Liberata out-of-system. Schedule generation and dispatch are batch-driven, not user-initiated.
- **FR44**: RAM Pathfinder exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`); the JFEPS shape evolves independently of Payment internals.
- **FR45**: RAM Pathfinder prevents double submission of the same booking for payment. The batch's natural-key unique constraint on `(payment_cycle_id, booking_id)` rejects duplicate creates; re-runs of the same cycle are idempotent.
- **FR46**: Authorised users (Finance, RSU) can flag payments as reconciled, capturing notes for mismatches; once fully reconciled, a payment cannot be re-requested for the same booking.
- **FR47**: RAM Pathfinder does not store or expose bank details for any judge — those remain in the finance system.

### Itineraries & Reporting (Read Models)

- **FR48**: Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month, showing sittings, bookings, vacancies, and NTBF absences for each day.
- **FR49**: Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation (judges see only their own; courts see their office; RSU sees their region).
- **FR50**: Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- **FR51**: Itinerary cells are clickable and drill into the underlying record (Sitting, Absence, Vacancy, or Booking).
- **FR52**: Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- **FR53**: RAM Pathfinder provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report.
- **FR54**: RAM Pathfinder exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); MI Feed responses contain no case-level data and are aggregate-only by contract.

### Platform Operations & Migration

- **FR55**: Authenticated users land on a Home page showing role-scoped navigation, Region/Area selector, summary tiles for the selected scope (judges, absences, vacancies, pending payments, payments made, unreconciled), and contextual help.
- **FR56** *(scoped 2026-05-15 per D10)*: RAM Pathfinder's **business-user UI** (`ram-ui`) replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA accessibility standards. **In MVP**: `ram-ui` only — the business-user-facing SPA used by RSU, Court, Judges, Judges' Clerks, Finance/Payment Authoriser, MI/Reporting roles. **Post-MVP**: `ram-admin-ui`, the admin-facing SPA carrying Reference Data maintenance, User/Role/Scope admin, Migration Reports, and Activation Flag toggle modules (see Growth Features).
- **FR57**: A Phase 0 Data Migration ETL takes Reference Data and active user records (with role and Region/Area mappings) from **APEX** (which has its own legacy schema), transforms them into **RAM Pathfinder's own (independently-designed) shape**, and **loads them via the RAM Pathfinder Reference Data API and Authorisation API**. Migrated user records are keyed to HMCTS IdP principals (email primary, employee number fallback). Phase 0 deliverable with named-owner sign-off; unmatched user records are flagged for explicit handling (drop / hold / manual map). The ETL is *not* a Flyway database-seeding migration — Flyway in RAM Pathfinder manages RAM Pathfinder's own DDL only; the APEX-to-RAM Pathfinder data transform is a separate programme-level activity that lives in `ram-architecture/migration/` and runs against running RAM Pathfinder services. *(Framing clarified 2026-05-06; see architecture changelog v1.9.)*
- **FR58** *(scoped 2026-05-15 per D10)*: RAM Pathfinder supports per-region phased activation — a region's user accounts can be activated for RAM Pathfinder use only when that region's feature-parity gate is passed; activation is a flag flip on `auth_user_activation_flags`, not a data migration. **In MVP**: initial flag state is set by the Phase 0 Users/Roles ETL (all FALSE); cutover flips happen per region by a DBA running `UPDATE auth_user_activation_flags SET activated = TRUE WHERE region = ...` per the Phase 9+ rollout runbook (no UI). **Post-MVP**: activation toggle UI in `ram-admin-ui` for system administrators (see Growth Features).
- **FR59**: Every RAM Pathfinder service exposes a versioned API contract, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details for errors, and a published OpenAPI specification. Deprecation signalling uses the `Deprecation` header per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) and the `Sunset` header per [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594).
- **FR60**: Every RAM Pathfinder service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- **FR61**: Every RAM Pathfinder domain service has a **manual user acceptance test (UAT) script** that captures the workflows and edge cases an APEX-experienced user is expected to verify against the existing APEX application before that service's region rollout. The UAT is performed by users from the in-region applicable roles (RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI) and recorded with explicit per-role sign-off. There is no automated APEX-comparison test harness; APEX-comparison parity is a manual UAT activity, not a CI gate. *Revised 2026-05-06; supersedes earlier wording about real APEX running as an automated comparison reference.*

## Non-Functional Requirements

### Performance

Page-level NFRs are carried from the APEX baseline (`functional-modules.md` cross-cutting NFRs); RAM Pathfinder must match or exceed each.

- **NFR1 — Static page load:** ≤ 3 s for static UI loads (e.g. Home initial render).
- **NFR2 — Dashboard refresh:** ≤ 5 s when Region/Area selection changes.
- **NFR3 — List / filter operations:** ≤ 10 s for typical operational lists (judges, absences, vacancies, bookings, sittings, payments) at Region scope.
- **NFR4 — Batch / annual operations:** ≤ 15 s (e.g. annual itinerary render, batch payment-request processing).
- **NFR5 — Reports / Forward Look:** ≤ 30 s for standard report parameters and for the Forward Look view at Region scope.
- **NFR6 — Single-resource API read:** ≤ 500 ms p95 (e.g. `GET /judges/{id}`).
- **NFR7 — Domain write API:** ≤ 1 s p95 for typical write operations (excluding orchestrated cross-service calls like Booking → Vacancy.markFilled).
- **NFR8 — Federated read (Itinerary, Forward Look):** ≤ 30 s p95 under Strategy A. Strategy C cache fallback is pre-designed and switched on if measurement shows the p95 breached (Risk #9).
- **NFR9 — Capacity (rough order-of-magnitude):** concurrent users per region ~50–100; national concurrent users ~200–500 once all regions migrated. Burst capacity for monthly verification deadlines accounted for.

### Security

- **NFR10 — Transport encryption:** Latest TLS only on every endpoint; HTTP-only endpoints rejected.
- **NFR11 — Data-at-rest encryption:** All personal data (judge records, user/role records, working patterns, payroll numbers, payment metadata) encrypted at rest.
- **NFR12 — Authentication** *(revised v2.6, 2026-05-07)*: All human users authenticated via HMCTS IdP SSO (per FR1). **Inter-service authentication for user-initiated calls is via JWT propagation** — the user's JWT (issued by HMCTS IdP) is forwarded by the upstream service's outbound HTTP client and validated by the downstream service's `JWTFilter` against the IdP's JWKS endpoint. **Inter-service authentication for batch / scheduled components** (initially: the payment batch `ram-payment-batch`) is via OAuth 2.0 `client_credentials` against `ram-mock-auth` in non-prod; production issuer is a deferred decision per architecture `gaps.md` G7.1 (default recommendation: Azure Workload Identity, given the AKS deployment).
- **NFR13 — Authorisation enforcement:** Every API call resolves the principal's roles + Region/Area scope through the Authorisation service; no operation bypasses this check.
- **NFR14 — Forbidden data scope:** No bank details stored or exposed by any service (PAY-NFR-05). No case-level data in any read model or report (REP-BR-NFR-03).
- **NFR15 — Government Functional Standard 7 alignment:** RAM Pathfinder aligns with HMCTS / MoJ Government Functional Standard 7 — Security, including protective marking, access control, and secure development practices.
- **NFR16 — Secret management:** Service credentials, signing keys, and integration secrets stored in a managed secret store (Azure Key Vault or equivalent); never in source control or environment-baked images.

### Accessibility

- **NFR17 — WCAG 2.2 Level AA:** Every UI page meets WCAG 2.2 Level AA accessibility standards; tested per UI page in each domain phase before that phase's gate is passed.
- **NFR18 — Assistive technology compatibility:** Keyboard navigation, ARIA labels for tabbed and dynamic content, and screen-reader compatibility per HMCTS accessibility standards.
- **NFR19 — Public Sector Bodies Accessibility Regulations 2018:** RAM Pathfinder complies with the Public Sector Bodies (Websites and Mobile Applications) (No. 2) Accessibility Regulations 2018, including publication of an accessibility statement.

### Integration

- **NFR20 — HMCTS IdP integration:** Hard Phase 0 dependency. RAM Pathfinder integrates with whichever AuthN protocol the HMCTS IdP exposes (OIDC or SAML).
- **NFR21 — JFEPS / Liberata integration unchanged:** Payment schedule format (JFEPS-compatible Excel), email-to-Authoriser delivery, and authoriser-forwards-to-Liberata workflow are preserved exactly as in APEX. No format change for finance.
- **NFR22 — HMCTS email infrastructure:** Outbound transactional emails (booking ack, absence ack, payment schedules) dispatch via HMCTS email; delivery is reliable but not low-latency-critical (overnight batch acceptable for booking acknowledgements).
- **NFR23 — DA&I MI Feed:** Aggregate-only REST API contract; no case-level data exposed under any consumer authorisation.
- **NFR24 — eLinks / HR systems:** No automated integration in MVP scope; manual data entry by RSU continues, matching the APEX-era pattern.

### Observability (MVP minimum per D7)

- **NFR25 — Structured logging:** Every service emits structured logs with consistent fields, correlation IDs threaded through service-to-service calls, and a defined error-categorisation taxonomy. Logging schema is a Phase 0 deliverable.
- **NFR26 — Log retention:** Logs retained sufficient for pilot incident triage; specific retention period set in Phase 0 within HMCTS data-retention policy.
- **NFR27 — Log ingestion:** Logs ingested into Azure-native logging (Application Insights / Log Analytics).
- **NFR28 — Health and readiness probes:** Every service exposes Kubernetes-compatible liveness and readiness endpoints (Spring Actuator).
- **NFR29 — Roadmap commitments (post-MVP, not in MVP):** Structured user-action auditing (who-did-what-when with before/after values for write operations) is a post-MVP roadmap commitment per D7. Metrics and trace observability beyond logs is post-MVP.

### Data Privacy & Sovereignty

- **NFR30 — UK GDPR / Data Protection Act 2018 compliance:** Personal data scope is limited to user/judge identity, contact details, payroll numbers, and operational metadata. No case-level data anywhere in RAM Pathfinder.
- **NFR31 — Data residency:** All RAM Pathfinder services and data hosted in Azure UK regions only. No personal data leaves the UK.
- **NFR32 — Retention:** Data retention per HMCTS retention schedules. Migrated transactional history remains in APEX (D3); RAM Pathfinder retains only data created in RAM Pathfinder from migration onward.
- **NFR33 — FOI scope:** Aggregate operational data exposable per FOI requests; case-level data is forbidden by contract (REP-BR-NFR-03) and therefore outside FOI scope by construction.

### Reliability & Availability

- **NFR34 — Operational availability:** RAM Pathfinder is available during HMCTS operational hours (typically 07:00–19:00 UK weekdays). Out-of-hours availability is best-effort, not contracted.
- **NFR35 — Payment-cycle continuity:** Zero failed JFEPS payment cycles attributable to RAM Pathfinder deployment, rollout, or runtime issues. Payment generation can fall back to manual handling within a payment cycle if RAM Pathfinder is unavailable, but this is an operational contingency, not a normal-mode expectation.
- **NFR36 — Per-wave rollback:** Each rollout wave (Phase 9, 10, …) has a documented rollback path returning the affected region to APEX within one operational cycle if the wave's gate is breached post-cutover.
- **NFR37 — Strategy A degraded-mode contract:** If federated read latency breaches NFR8, RAM Pathfinder degrades to Strategy C cached projection rather than failing; cache freshness window is published in the service's OpenAPI spec metadata and surfaced in response headers (e.g. `Cache-Control`, `Age`).
- **NFR38 — HMCTS-judicial-region rollout isolation:** A wave activation or feature change targeting one HMCTS judicial region (e.g. Northern, Western) does not affect users in other HMCTS regions. *("Region" here means HMCTS judicial region per D8 — not Azure region. Architectural enforcement is at the application tier via per-user `auth_user_activation_flags` (FR58), not at the infrastructure tier. Production runs in a single Azure region — UK South — with multi-AZ HA. Disaster-recovery scope and design are an open gap — see `architecture/gaps.md` G3.6. Wording clarified 2026-05-06 — earlier "Region-isolated deployments" framing was ambiguous between the two senses of "region" and is now disambiguated.)*

### Maintainability

- **NFR39 — API-as-Product standards:** Every service exposes versioned contracts, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details error envelopes, and a published OpenAPI specification (per FR59). Versioning and deprecation policy is a Phase 0 deliverable; deprecation signalling uses [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) `Deprecation` + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) `Sunset` headers.
- **NFR40 — Per-service deployment unit:** Each of the 11 services is independently deployable on Kubernetes; rolling updates per service per region without coupling.
- **NFR41 — Behavioural-parity UAT suite:** Every domain service has a **manual UAT script** (per FR61) maintained alongside the service. APEX-experienced users walk through the script comparing RAM Pathfinder vs APEX before each rollout wave's cutover; sign-off (per role per region) is the wave gate. There is no automated parity test suite — automated CI tests are unit, integration (Testcontainers), and contract tests only.
- **NFR42 — Postman collections:** Each phase produces a Postman collection that exercises the phase's endpoints; collections are versioned alongside the services.

## Decisions Log (D1–D9)

These are the 9 locked decisions taken during the 2026-05-05 brainstorming follow-up. Each is referenced inline throughout the PRD; the consolidated list is here for navigability.

| ID | Decision | Implication |
|---|---|---|
| **D1** | Phase 0 Foundations scope locked: Reference Data, Authorisation (with SSO), Notification, API contracts, deployment platform, structured logging conventions, shared `configuration_values` infrastructure table (no dedicated configuration service per v2.2). Audit & metrics/trace observability post-MVP. | Sets what must be in place before any domain service is built. |
| **D2** | Cutover strategy: phased rollout. Migrated users do not use APEX; non-migrated users do not use RAM Pathfinder. | No dual-write coexistence; risk amortised across waves. |
| **D3** | Data migration: **Reference Data only (extended by D9)**. No transactional data migration. The migration is a Phase 0 ETL — read APEX dumps → transform to RAM Pathfinder shape → load via RAM Pathfinder Reference Data API. RAM Pathfinder tables are RAM Pathfinder's own design; APEX's schema is the data source, not the target shape. | Each region migrates onto a clean transactional state; historical data stays in APEX. The ETL lives at `ram-architecture/migration/` and is separate from Flyway DDL. |
| **D4** | Feature-parity gate is functional + UI-replicates-APEX (modern UI stack, no redesign). | UX/visual_design/user_journeys are in scope (override on `api_backend` classification). |
| **D5** | APEX is the behavioural reference, verified by **manual UAT performed by APEX-experienced users**, not a migration host. *(Revised 2026-05-06 — earlier framing of real APEX as an automated comparison reference retracted.)* | Per-service manual UAT scripts are walked through by users (RSU, Court, Judge, Clerks, Finance, MI) comparing RAM Pathfinder vs APEX; sign-off per role per region is the wave gate. No automated APEX-comparison harness. |
| **D6** | APEX maintenance is out of project scope. | APEX is a stable external system in the project plan; not co-managed. |
| **D7** | Audit / Observability MVP minimum: log-based (request, error). User-action audit on the post-MVP roadmap. | Structured logging is a Phase 0 deliverable; metrics/traces deferred. |
| **D8** | Rollout boundary: by region, all applicable user roles. | A region migrates only when every in-region role's functionality is complete. |
| **D9** *(amended by D10, 2026-05-15)* | Active users + role/scope mappings are extracted from APEX, transformed, and loaded into the RAM Pathfinder Authorisation tables (`auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`) **via direct SQL INSERT (per D10, revised from "via the RAM Pathfinder Authorisation API")** in Phase 0. Each RAM Pathfinder user record is keyed to an HMCTS IdP principal (email primary; employee number fallback). | Authorisation is testable end-to-end with realistic data from day 1; per-wave activation is a flag flip on `auth_user_activation_flags`. The migration is the Phase 0 ETL described in D3 + the architecture document. |
| **D10** *(new 2026-05-15)* | **Admin UI is removed from MVP scope and pushed to post-MVP.** The `ram-admin-ui` repo, Reference Data admin module, Users/Roles admin module, Migration Reports module, Activation Toggle, and Admin Send-Test-Email all become post-MVP roadmap items. Admin-write API endpoints on `ram-reference-data` and `ram-authorisation` are likewise post-MVP — both APIs ship read-only in MVP. Reference Data and Users/Roles are loaded via **direct SQL ETLs**; ongoing maintenance in MVP is by DBAs via direct SQL per operational runbooks; named-owner sign-off happens via **versioned git commits** to `migration/reports/{stream}/signoffs/`. The `gh` CLI is **not** available in the engineering environment — all GitHub repo creation, branch-protection setup, CODEOWNERS configuration, and PR workflow happen via the GitHub web UI manually. | Reduces MVP scope and timeline; pushes ~6 stories' worth of admin-UI work post-MVP. Adjusts FR4, FR6, FR56, FR58 wording to reflect data-layer-in-MVP vs UI-surface-post-MVP. Affects the Phase 0 epic plan: stories drop from 18 → 11 (admin UI stories removed; OAuth `client_credentials` flow moved to Phase 6 with `ram-payment-batch`). All Phase 0+ stories with GitHub-repo-creation ACs are reworded to require manual web-UI steps. See `epics/phase-0/validation-report-2026-05-15.md` for the revised validation. |

## Glossary

| Term | Meaning |
|---|---|
| **APEX** | Oracle Application Express; the legacy platform JI runs on today |
| **DA&I** | Data, Analysis & Insight; HMCTS analytics / MI team consuming JI data |
| **DJ** | District Judge |
| **DJ(MC)** | District Judge (Magistrates' Courts) |
| **FOI** | Freedom of Information Act 2000 |
| **FPB** | Fee-paid and other Bookings (APEX module name) |
| **GDS** | Government Digital Service (UK Cabinet Office) |
| **HMCTS** | His Majesty's Courts and Tribunals Service |
| **IdP** | Identity Provider (HMCTS's SSO / authentication system) |
| **JFEPS** | Judicial Fee Payment System (HMCTS finance system) |
| **JFL** | Judges Forward Look (sub-module of Judge Itinerary) |
| **JI** | Judicial Itineraries (the existing APEX system) |
| **Liberata** | HMCTS's payment processing partner |
| **MI** | Management Information |
| **MoJ** | Ministry of Justice |
| **RAM Pathfinder** | RAM Pathfinder — the API-driven rebuild this PRD describes |
| **NTBF** | Not To Be Filled (an absence flag — cover not required) |
| **OIDC** | OpenID Connect (an authentication protocol) |
| **OPT** | One Performance Truth; the broader Oracle/APEX platform JI sits on |
| **[RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457)** | IETF specification for Problem Details for HTTP APIs (current; obsoletes RFC 7807) |
| **[RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745)** | IETF specification for the HTTP `Deprecation` response header (March 2025) |
| **[RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)** | IETF specification for the HTTP `Sunset` response header |
| **RSU** | Regional Support Unit (HMCTS regional admin teams) |
| **S&L** | Scheduling & Listing reforms (HMCTS programme) |
| **SAML** | Security Assertion Markup Language (an authentication protocol) |
| **SSO** | Single Sign-On |
| **TBD** | To Be Determined (programme-management or architecture-phase decision) |
| **UK GDPR** | UK General Data Protection Regulation (post-Brexit equivalent of EU GDPR) |
| **WCAG** | Web Content Accessibility Guidelines |

## References

Source documents consulted during PRD generation (also recorded in this PRD's `inputDocuments` frontmatter):

- `_bmad-output/brainstorming/brainstorming-session-2026-05-05-1600.md` — the 9 locked decisions, 11-service decomposition, migration table, and risk register
- `docs/architecture/asis/functional-modules.md` — catalogue of the 12 functional modules in the existing Oracle APEX JI system
- `docs/architecture/asis/data-dependencies.md` — JI's external data dependencies (eLinks, HR, JFEPS, Liberata, DA&I, HMCTS Email)
- `docs/architecture/asis/integration-dependencies.md` — JI's integration flows and mechanisms

The 1600 brainstorming session itself supersedes lines 139–149 of the 2026-05-01 brainstorming session (migration sequencing) and the entirety of the 2026-05-05-1500 brainstorming draft (which was based on a strangler-fig assumption that has been retracted).
