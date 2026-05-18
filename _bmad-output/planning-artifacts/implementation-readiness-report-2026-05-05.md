---
stepsCompleted: ['step-01-document-discovery', 'step-02-prd-analysis', 'step-03-epic-coverage-validation', 'step-04-ux-alignment', 'step-05-epic-quality-review', 'step-06-final-assessment']
workflowCompleted: true
projectName: 'ji-analysis'
productCodename: 'RAM Pathfinder'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
inputDocumentsMissing:
  - 'architecture.md'
  - 'epics.md / stories.md'
  - 'ux-design.md'
date: '2026-05-05'
workflowCompleted: false
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-05
**Project:** ji-analysis (RAM Pathfinder — RAM Pathfinder)

> ⚠️ **Superseded — historical snapshot.** Superseded by [`./implementation-readiness-report-2026-05-06.md`](./implementation-readiness-report-2026-05-06.md). Areas of this report have since been revised by **architecture v2.6 (2026-05-07)** and **v2.7 (2026-05-08)** and should be read against the current PRD/architecture rather than this snapshot:
>
> 0. **FR59 / NFR39 / API-as-Product (v2.7, 2026-05-08)** — RFC citations refreshed: error envelope now [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) (obsoletes RFC 7807 — content unchanged); deprecation signalling cited correctly to [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) `Deprecation` + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) `Sunset`.
>
> 1. **FR41–FR45 (Payment)** — reframed as a **scheduled batch flow** (`ram-payment-batch`), not user-initiated. RSU/Sam confirms bookings/sittings; the batch picks up confirmed-but-unpaid records on its next scheduled run, generates the JFEPS Excel, and dispatches it to the Payment Authoriser. See `architecture/sequence-diagrams/payment-batch-flow.md`.
> 2. **NFR12 / Service-to-service auth** — v2.5 narrowed this to "JWT propagation only, no service principals." v2.6 widened it back: **two patterns at MVP** — JWT propagation for user-initiated flows AND OAuth `client_credentials` (against `ram-mock-auth` in non-prod) for the payment batch. Production issuer per `gaps.md` G7.1 (default recommendation: Azure Workload Identity).
>
> All other content in this report remains accurate as of 2026-05-05.

## Document Inventory

### PRD Documents

**Whole Documents:**
- `prd.md` (73 KB, modified 2026-05-05)

**Sharded Documents:** None

### Architecture Documents

⚠️ **WARNING: Required document not found** — no architecture document exists yet. Will significantly impact assessment completeness.

### Epics & Stories Documents

⚠️ **WARNING: Required document not found** — no epics or stories document exists yet. Will significantly impact assessment completeness.

### UX Design Documents

⚠️ **WARNING: Required document not found** — no UX design document exists yet. Will impact assessment completeness on UX-related coverage.

### Other files in planning-artifacts (not assessment inputs)

- `prd_tmp.html` — auto-generated HTML rendering of the PRD; not a duplicate requiring resolution.

## Critical Issues

**Duplicates requiring resolution:** None.

**Missing documents:** Three of four expected artefacts (Architecture, Epics & Stories, UX Design) are not yet present. The readiness assessment will produce a significantly limited verdict — predominantly a PRD-only readiness assessment with explicit gap flagging on the missing artefacts.

## PRD Analysis

### Functional Requirements

**Total FRs: 61, organised across 9 capability areas.**

#### Identity & Authorisation (5 FRs)

- **FR1**: Authenticated users access RAM Pathfinder via HMCTS IdP single sign-on; password, session, and account lifecycle are owned by the IdP and not duplicated in RAM Pathfinder.
- **FR2**: RAM Pathfinder's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- **FR3**: Authorised users can retrieve their effective permissions for their authenticated session.
- **FR4**: System administrators can update role and Region/Area assignments for migrated and new users.
- **FR5** *(reframed as post-MVP per architecture v2.5, 2026-05-07)*: External machine-to-machine consumers — no longer in MVP scope. Every MVP runtime request is user-initiated. The mechanism for genuine machine-to-machine authentication is a post-MVP open question (see architecture `gaps.md` G7).

#### Foundational Data Management (4 FRs)

- **FR6**: RSU users can view and maintain Reference Data lists — Regions, Offices, judicial vocabularies, calendar / financial-year boundaries — with named-owner sign-off on changes.
- **FR7**: Every RAM Pathfinder service can read Reference Data via a versioned API; Reference Data is the single writer (no duplicates anywhere in the system).
- **FR8** *(revised v2.2, 2026-05-07)*: Cross-service runtime policy values (e.g. session timeout warnings, batch schedules, feature flags) live in a shared `configuration_values` infrastructure table, schema-managed by `ram-architecture`'s Flyway baseline migration. Updates via Flyway / admin SQL — no API service. Per-service config that's scoped to one service uses Spring profiles + Key Vault.
- **FR9**: RAM Pathfinder dispatches transactional emails (booking acknowledgements, absence acknowledgements, payment schedules) via HMCTS email infrastructure, with a delivery log retained.

#### Judge Records & Working Patterns (9 FRs)

- **FR10**: RSU users can search and filter judges by name, base location, location type, and judge type.
- **FR11**: RSU users can maintain judge profiles, including personal details, judge type, base office, active/inactive status, and role-specific data (payroll number, retirement date, fee entitlement, London weighting, name-for-itinerary, heading).
- **FR12**: Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- **FR13**: RAM Pathfinder auto-populates judge itineraries up to the next 31st March from the working pattern, preserving any prior absences.
- **FR14**: RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- **FR15**: RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- **FR16**: RAM Pathfinder validates that jurisdictional split percentages total 100% before saving.
- **FR17**: RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- **FR18**: Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

#### Absence Workflow (4 FRs)

- **FR19**: Authorised users (RSU, Court, Judges where permitted) can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- **FR20**: RAM Pathfinder distinguishes auto-confirmed absences (from judicial teams) from those requiring confirmation (from Courts or judges); confirmation can trigger an acknowledgement email.
- **FR21**: Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- **FR22**: Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

#### Vacancy & Cover (6 FRs)

- **FR23**: RAM Pathfinder auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- **FR24**: Authorised users can create standalone vacancies independent of any absence.
- **FR25**: Authorised users can edit a vacancy's daily breakdown — cancel individual days with a captured reason; extend or shorten the period.
- **FR26**: RAM Pathfinder marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- **FR27**: RAM Pathfinder surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is performed out-of-system by judicial teams.
- **FR28**: Authorised users can cancel or close vacancies (e.g. when a parent absence becomes NTBF).

#### Booking Management (6 FRs)

- **FR29**: Authorised users can create fee-paid bookings (linked to a vacancy or standalone), capturing judge, court, date, session type (full / AM / PM / evening / reserved-matter), booking type, and work type.
- **FR30**: Booking creation orchestrates `Vacancy.markFilled` synchronously when a `vacancyId` is supplied.
- **FR31**: RAM Pathfinder tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- **FR32**: RAM Pathfinder sends booking acknowledgement emails to fee-paid judges, batched overnight or sent immediately via *Create and Email Now*.
- **FR33**: RAM Pathfinder requires a Y/N answer at booking time when a judge's fee entitlement is *Ask when booking*.
- **FR34**: RAM Pathfinder prevents double-booking of fee-paid judges for overlapping sessions.

#### Sitting Management (6 FRs)

- **FR35**: RAM Pathfinder generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- **FR36**: Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- **FR37**: Authorised users can confirm that a sitting actually took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- **FR38**: Authorised users can split a sitting into AM/PM with different work types within a single day.
- **FR39**: Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- **FR40**: Verifiers can verify confirmed sittings; once verified, the data is read-only and amendments require an RFC.

#### Payment & Reconciliation (7 FRs)

- **FR41**: Authorised users can list confirmed bookings and salaried sittings eligible for payment, filterable by Region/Office, judge, date range, and payment lifecycle status (pending, requested, paid).
- **FR42**: Authorised users can mark eligible bookings as *payment requested* individually or in bulk.
- **FR43**: RAM Pathfinder generates JFEPS-compatible payment schedules and dispatches them as Excel attachments to a chosen Payment Authoriser via email; the Payment Authoriser forwards to Liberata out-of-system.
- **FR44**: RAM Pathfinder exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`); the JFEPS shape evolves independently of Payment internals.
- **FR45**: RAM Pathfinder prevents double submission of the same booking for payment.
- **FR46**: Authorised users (Finance, RSU) can flag payments as reconciled, capturing notes for mismatches; once fully reconciled, a payment cannot be re-requested for the same booking.
- **FR47**: RAM Pathfinder does not store or expose bank details for any judge — those remain in the finance system.

#### Itineraries & Reporting (Read Models) (7 FRs)

- **FR48**: Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month, showing sittings, bookings, vacancies, and NTBF absences for each day.
- **FR49**: Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation (judges see only their own; courts see their office; RSU sees their region).
- **FR50**: Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- **FR51**: Itinerary cells are clickable and drill into the underlying record (Sitting, Absence, Vacancy, or Booking).
- **FR52**: Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- **FR53**: RAM Pathfinder provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report.
- **FR54**: RAM Pathfinder exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); MI Feed responses contain no case-level data and are aggregate-only by contract.

#### Platform Operations & Migration (7 FRs)

- **FR55**: Authenticated users land on a Home page showing role-scoped navigation, Region/Area selector, summary tiles for the selected scope (judges, absences, vacancies, pending payments, payments made, unreconciled), and contextual help.
- **FR56**: RAM Pathfinder's UI replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA accessibility standards.
- **FR57** *(reframed 2026-05-06)*: A Phase 0 Data Migration ETL takes Reference Data and active user records from APEX (legacy schema), transforms them into RAM Pathfinder's own (independently-designed) shape, and loads them via the RAM Pathfinder Reference Data API and Authorisation API. Migrated user records are keyed to HMCTS IdP principals (email primary, employee number fallback). Phase 0 deliverable with named-owner sign-off; unmatched user records flagged for explicit handling (drop / hold / manual map). The ETL is *not* Flyway data-seeding — it's a separate programme deliverable at `ram-architecture/migration/`.
- **FR58**: RAM Pathfinder supports per-region phased activation — a region's user accounts can be activated for RAM Pathfinder use only when that region's feature-parity gate is passed; activation is a flag flip, not a data migration.
- **FR59**: Every RAM Pathfinder service exposes a versioned API contract, RFC 7807 problem-details for errors, and a published OpenAPI specification. *(Note: revised v2.7, 2026-05-08 — RFC 7807 reference updated to [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457). This snapshot preserves the wording at 2026-05-05 with the RFC pointer brought current.)*
- **FR60**: Every RAM Pathfinder service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- **FR61**: Every RAM Pathfinder domain service has a manual user acceptance test (UAT) script for APEX-experienced users to walk through, comparing RAM Pathfinder vs APEX side-by-side; sign-off per role per region is the wave-cutover gate. There is no automated APEX-comparison harness. *(Revised 2026-05-06; supersedes earlier wording about real APEX running as an automated comparison reference in CI. See architecture changelog v1.7.)*

### Non-Functional Requirements

**Total NFRs: 42, organised across 8 categories.**

#### Performance (9 NFRs)

- **NFR1**: Static page load ≤ 3 s.
- **NFR2**: Dashboard refresh ≤ 5 s on Region/Area change.
- **NFR3**: List / filter operations ≤ 10 s at Region scope.
- **NFR4**: Batch / annual operations ≤ 15 s.
- **NFR5**: Reports / Forward Look ≤ 30 s for standard parameters at Region scope.
- **NFR6**: Single-resource API read ≤ 500 ms p95.
- **NFR7**: Domain write API ≤ 1 s p95.
- **NFR8**: Federated read ≤ 30 s p95 under Strategy A; Strategy C cache fallback pre-designed.
- **NFR9**: Capacity ~50–100 concurrent per region; ~200–500 national; verification-deadline burst capacity allowed for.

#### Security (7 NFRs)

- **NFR10**: Latest TLS only on every endpoint; HTTP-only rejected.
- **NFR11**: Personal data encrypted at rest.
- **NFR12** *(revised v2.5, 2026-05-07)*: Human users via HMCTS IdP SSO; **inter-service auth via JWT propagation** (no service principals, no `client_credentials`, no mTLS at MVP).
- **NFR13**: Authorisation enforcement on every API call.
- **NFR14**: No bank details, no case-level data in any service or schema.
- **NFR15**: Government Functional Standard 7 alignment.
- **NFR16**: Secrets in managed secret store (Azure Key Vault or equivalent).

#### Accessibility (3 NFRs)

- **NFR17**: WCAG 2.2 Level AA per UI page, tested per phase.
- **NFR18**: Keyboard navigation, ARIA labels, screen-reader compatibility per HMCTS standards.
- **NFR19**: Public Sector Bodies Accessibility Regulations 2018 compliance with published statement.

#### Integration (5 NFRs)

- **NFR20**: HMCTS IdP integration as Phase 0 hard dependency.
- **NFR21**: JFEPS / Liberata integration unchanged from APEX (Excel via email, manual upload).
- **NFR22**: HMCTS email infrastructure for transactional notifications.
- **NFR23**: DA&I MI Feed REST API with aggregate-only contract.
- **NFR24**: No automated eLinks / HR integration in MVP scope.

#### Observability (5 NFRs)

- **NFR25**: Structured logging with correlation IDs; logging schema is Phase 0 deliverable.
- **NFR26**: Log retention sufficient for pilot incident triage; specific period set in Phase 0.
- **NFR27**: Logs ingested into Azure-native logging (Application Insights / Log Analytics).
- **NFR28**: Health and readiness probes per service (Spring Actuator).
- **NFR29**: Structured user-action audit + metrics + traces are post-MVP roadmap items.

#### Data Privacy & Sovereignty (4 NFRs)

- **NFR30**: UK GDPR / DPA 2018 compliance; personal data scope limited; no case-level data.
- **NFR31**: Azure UK regions only; no personal data leaves the UK.
- **NFR32**: Retention per HMCTS schedules; migrated history stays in APEX.
- **NFR33**: FOI scope by contract — aggregate exposable, case-level forbidden.

#### Reliability & Availability (5 NFRs)

- **NFR34**: Operational availability during HMCTS hours (07:00–19:00 UK weekdays).
- **NFR35**: Zero failed JFEPS payment cycles attributable to RAM Pathfinder.
- **NFR36**: Per-wave rollback within one operational cycle.
- **NFR37**: Strategy A degraded-mode contract; Strategy C cache as fallback.
- **NFR38**: Region-isolated deployments — no cross-region failure propagation.

#### Maintainability (4 NFRs)

- **NFR39**: API-as-Product standards (versioning, RFC 7807, OpenAPI). *(Note: revised v2.7, 2026-05-08 — RFC 7807 → [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457). This snapshot preserves the wording at 2026-05-05.)*
- **NFR40**: Per-service deployment unit on Kubernetes; independently deployable.
- **NFR41**: Manual UAT script per domain service (revised 2026-05-06) — APEX-experienced users compare RAM Pathfinder vs APEX side-by-side; sign-off per role per region is the wave gate. No automated parity test suite.
- **NFR42**: Postman collections per phase, versioned alongside services.

### Additional Requirements

The PRD captures programme-level decisions, technical constraints, and integration commitments that operate as binding requirements alongside FRs and NFRs.

**Locked decisions (D1–D9):** documented in their own consolidated Decisions Log section; each decision is referenced inline in relevant FRs/NFRs and shapes the scope-and-approach contract.

**Domain-level compliance constraints** (UK govtech-specific): WCAG 2.2 Level AA (Public Sector Bodies Accessibility Regulations 2018); UK GDPR + Data Protection Act 2018; HMCTS / MoJ Government Functional Standard 7 — Security; FOI Act 2000 scope-by-contract; HMCTS retention schedules; GDS Service Standard alignment.

**Technology stack constraints (locked):** Java 25 + Spring Boot 4 (API layer); Kubernetes (orchestration); Microsoft Azure (cloud platform, UK regions only); modern UI stack TBD in architecture phase.

**Architecture decisions inherited from the brainstorming session** (operate as constraints):
- REST-first synchronous coordination; no event bus; no webhook surface
- Strategy A federated read models for Itinerary and MI Feed; Strategy C cache as designed fallback
- Greenfield-in-isolation; no strangler pattern; APEX continues unchanged for non-migrated regions
- Phased per-region rollout; whole-region scope per wave

**Risk register references:** the PRD references 14 risks (Risk #1–#14 from the 1600 brainstorming session) as binding context. Notable: Risk #1 (cross-region workflow during partial rollout), Risk #6 (HMCTS IdP integration timing), Risk #9 (Forward Look NFR), Risk #13 (migration correctness), Risk #14 (APEX ⇄ IdP identity mapping).

**Explicit TBDs surfaced in the PRD that must be resolved before implementation:**
- Rate limit policy (Step 7: architecture-phase decision)
- UI framework family (Step 5 and Step 7: architecture-phase decision)
- Service-to-service authentication mechanism (Step 7: mTLS or service token, architecture-phase decision)
- Capacity numbers (NFR9: order-of-magnitude estimates, programme to verify)
- Operational availability hours (NFR34: assumed 07:00–19:00; programme to confirm)
- Specific log retention period (NFR26: Phase 0 deliverable)
- API versioning policy specifics (Phase 0 deliverable per D1)
- Rollout wave selection — which region first (Step 8 open item)
- Cross-region workflow handling per wave (Step 8 open item)
- Historical-data access policy for migrated users (Step 8 open item, Risk #2)
- Phase 0 migration owners — named individuals for Reference Data and Users/Roles sign-off
- APEX ⇄ IdP identity-key scheme + reconciliation report ownership

### PRD Completeness Assessment (initial)

The PRD is structurally complete and dense. Initial signals:

- **Capability coverage:** 61 FRs across 9 areas covering all 11 services in the locked decomposition (revised v2.2, 2026-05-07 — `ram-configuration` dropped). Cross-checked in Step 11 polish against the brainstorming source — nothing dropped.
- **Quality-attribute coverage:** 42 NFRs across 8 categories. All page-level NFRs from `functional-modules.md` cross-cutting NFRs are reflected.
- **Decision traceability:** 9 locked decisions (D1–D9) consolidated in a Decisions Log section; each referenced inline where it shapes an FR/NFR.
- **Source traceability:** every section can be traced back to either the brainstorming session, the as-is functional-modules.md, the data/integration dependencies docs, or an explicit user decision in conversation.
- **TBDs explicitly surfaced:** 12 open items named above; none are silently deferred.

**Gaps the assessment will probe in subsequent steps:**
- Architecture document does not exist yet → traceability into technical design is unverifiable.
- Epics & Stories do not exist yet → FR-to-epic coverage cannot be validated.
- UX Design does not exist yet → user-journey-to-UX-flow coverage cannot be validated.

PRD analysis complete. Proceeding to epic coverage validation.

## Epic Coverage Validation

### Coverage Matrix

⚠️ **Epics & Stories document not present.** Coverage validation cannot be performed.

The expected input — a `*epic*.md` artefact in `_bmad-output/planning-artifacts/` — does not exist. By definition, **none of the 61 PRD FRs are currently traced to epic coverage**, because no epics have been authored yet. This is the expected state given the workflow ordering: readiness was invoked immediately after the PRD landed, before the `bmad-create-epics-and-stories` workflow runs.

### Missing Requirements

All 61 PRD FRs (FR1–FR61) are uncovered by epic mapping at this point in time. The full FR list is captured in the *PRD Analysis* section above. When the Epics & Stories workflow produces its artefact, this readiness assessment should be re-run to validate coverage; the FR list captured above is the authoritative input for that re-run.

### Coverage Statistics

- **Total PRD FRs:** 61
- **FRs covered in epics:** 0 (no epics document exists)
- **Coverage percentage:** 0% — *not* because epics fail to cover requirements, but because epics have not been authored
- **Status:** ❌ Cannot validate — Epics & Stories artefact missing

### Recommendation

Run `bmad-create-epics-and-stories` before re-running implementation readiness. The natural epic boundaries derived from the PRD's structure are:

- 9 capability areas in the FR list map cleanly to candidate epics (Identity & Authorisation; Foundational Data Management; Judge Records; Absence Workflow; Vacancy & Cover; Booking Management; Sitting Management; Payment & Reconciliation; Itineraries & Reporting; Platform Operations & Migration — note: Identity & Authorisation and Platform Operations & Migration are typically Phase 0 cross-cutting epics; the other 7 align with Phases 1–8 of the build sequence).
- Phase ordering (Phase 0 → 8) from the brainstorming migration table provides a natural sequencing for epic delivery.
- 5 user journeys provide candidate end-to-end story slices that span multiple epics.

Epic coverage validation skipped due to missing artefact. Proceeding to UX alignment.

## UX Alignment Assessment

### UX Document Status

❌ **Not Found.** No `*ux*.md` artefact exists in `_bmad-output/planning-artifacts/`.

### Is UX implied?

**Yes — strongly.** The PRD has explicit UI scope:

- **D4 (locked decision):** "Feature parity gate is functional + UI-replicates-APEX (modern UI stack, no redesign)." UX is not just implied; it's a binding requirement.
- **FR55, FR56:** Home page with role-scoped navigation, Region/Area selector, summary tiles, contextual help; UI replicates APEX functional surface on a modern UI stack and meets WCAG 2.2 Level AA.
- **NFR17, NFR18, NFR19:** WCAG 2.2 AA per UI page; assistive-technology compatibility; Public Sector Bodies Accessibility Regulations 2018 compliance with published statement.
- **5 user journeys** in the PRD describe role-by-role workflows that demand UI flows for RSU, Court, Judges, Finance, and MI roles.
- **Step 7 Project-Type override** explicitly re-included `ux_ui`, `visual_design`, `user_journeys` in PRD scope despite the `api_backend` classification, on the grounds that D4 makes them required.

### Alignment Issues

Cannot validate alignment between UX, PRD, and Architecture because **two of the three artefacts (UX, Architecture) are missing**. The PRD by itself is internally consistent on UX expectations: UI replicates APEX layouts on a modern stack, meets accessibility standards, supports per-role workflows.

### Warnings

⚠️ **Major warning:** UX Design artefact required but not produced. The PRD specifies UX scope (modern UI replicating APEX) and constraints (WCAG 2.2 AA), but does not specify component patterns, interaction flows, visual design language, or UI state-machines per workflow. These are properly the output of `bmad-create-ux-design`.

⚠️ **Major warning:** UI framework family is an explicit TBD in the PRD (Step 5 Technology Stack, Step 7 Client Tooling). The UX Design workflow may surface UI-stack constraints (e.g. component-library availability) that feed back into the architecture decision.

### Recommendation

Run `bmad-create-ux-design` to produce the UX artefact before re-running this readiness assessment. The PRD's 5 user journeys and FR55/FR56 are sufficient input for a UX workflow to derive component patterns, screen flows, and accessibility-compliant interaction models. The UX output should reference `functional-modules.md` for as-is layout expectations (per D4 — no redesign).

UX alignment skipped due to missing artefact. Proceeding to epic quality review.

## Epic Quality Review

### Status

❌ **Cannot perform epic quality review.** Epics & Stories artefact does not exist (per Step 3).

### What this step would otherwise check

For reference, this step would normally validate epics against the `bmad-create-epics-and-stories` standards:

- Epics deliver user value (not technical milestones)
- Epic independence (Epic N cannot require Epic N+1 to function)
- Story sizing (independently completable, no forward dependencies)
- Acceptance criteria quality (Given/When/Then, testable, complete, specific)
- Database/entity creation timing (per-story, not all-upfront)
- Greenfield vs brownfield indicators (initial setup story present for greenfield; integration / migration stories present for brownfield)

### Pre-emptive guidance for the upcoming Epic & Stories workflow

When `bmad-create-epics-and-stories` is run, the following should be expected as natural epic boundaries derived from the PRD:

| Candidate epic | Maps to | Phase |
|---|---|---|
| Identity & Authorisation (incl. Phase 0 user/role migration) | FR1–FR5, FR57, FR58, NFR12, NFR13, NFR16 | Phase 0 |
| Reference Data + Notification (Phase 0 cross-cutting) + shared `configuration_values` table | FR6–FR9 | Phase 0 |
| API Platform + Deployment (Phase 0 cross-cutting) | FR59, FR60, NFR25–NFR28, NFR39, NFR40 | Phase 0 |
| Judge Records & Working Patterns | FR10–FR18 | Phase 1 |
| Absence Workflow | FR19–FR22 | Phase 2 |
| Vacancy & Cover | FR23–FR28 | Phase 3 |
| Booking Management | FR29–FR34 | Phase 4 |
| Sitting Management | FR35–FR40 | Phase 5 |
| Payment & Reconciliation | FR41–FR47 | Phase 6 |
| Itineraries (Court, Judge, Forward Look) | FR48–FR52 | Phase 7 |
| Reports + MI Feed | FR53, FR54 | Phase 8 |
| Pilot Rollout (per-region cutover playbook) | FR58 (activation flag), Risk #1 mitigation | Phase 9+ |

Each candidate epic delivers user value (per the brownfield-rebuild pattern: a domain capability that an in-region role can use end-to-end). Phase ordering provides natural epic independence (a downstream epic can use upstream epic outputs but never vice versa). The dependency DAG from the brainstorming session is the authoritative ordering reference.

### Pre-emptive flags for epic quality

When epics are authored, watch for these likely failure modes:

- **Phase 0 cross-cutting epics** (Identity & Authorisation, Reference Data, API Platform) tend to look like technical milestones. They can be framed as user-value (e.g. "RSU users can log in to RAM Pathfinder via SSO and see their authorised regions" rather than "Setup SSO"). Frame them as user-facing capabilities even when their consumers are internal cross-cutting concerns.
- **Forward dependencies between epics** are unlikely to occur given the strict DAG ordering, but the Sitting epic can be developed in parallel with Vacancy/Booking under Variant β — when authored, Sitting must explicitly state its dependency on Judge only (not on Vacancy or Booking) to preserve parallelism.
- **Behavioural-parity UAT stories** (FR61 / NFR41 revised 2026-05-06) should appear within each domain epic, not as a separate technical epic. UAT script authoring (under `docs/uat/`) and per-wave UAT execution are owned by the service being tested. UAT is performed manually by APEX-experienced users (RSU, Court, Judge, Clerks, Finance, MI) comparing RAM Pathfinder vs APEX side-by-side; sign-off per role per region is the wave-cutover gate. There is no automated APEX-comparison test work to schedule.
- **UI replication stories** (per D4) should be co-located with the API stories of the same phase, not split into a separate UI epic. Each domain phase delivers API + UI + tests as a single increment.

Epic quality review skipped due to missing artefact. Proceeding to final assessment.

## Summary and Recommendations

### Overall Readiness Status

🟡 **NEEDS WORK** — *for downstream artefact generation, not for the PRD itself*

The PRD itself is implementation-ready in shape and content. The "needs work" verdict is solely about the missing downstream artefacts (Architecture, UX Design, Epics & Stories) that this readiness assessment is designed to validate. Three of the four expected inputs do not exist, so 4 of the 6 assessment steps could not produce coverage analysis.

If the question is *"is the PRD ready to feed the next workflows?"* — the answer is **YES, ready**. If the question is *"is the project ready to begin implementation right now?"* — the answer is **NO, three workflows must run first**.

### Critical Issues Requiring Immediate Action

1. **Architecture artefact missing.** Run `bmad-create-architecture` next. The PRD already names most architecture decisions (REST-first, Strategy A federation, Java 25 + Spring Boot 4 + Kubernetes on Azure, API-as-Product standards); the architecture phase formalises contracts and resolves remaining TBDs (rate limits, UI stack, service-to-service auth, capacity numbers).
2. **UX Design artefact missing.** Run `bmad-create-ux-design`. D4 makes UI in scope; FR55/FR56 + 5 user journeys are the natural input. UX is required before epic stories can include UI acceptance criteria.
3. **Epics & Stories artefact missing.** Run `bmad-create-epics-and-stories` after Architecture and UX. The 9 capability areas in the PRD's FR list map cleanly to candidate epics; the Phase 0 → 8 build sequence provides the epic ordering.

### Recommended Next Steps

1. **Run `bmad-create-architecture`** — formalise the 11-service contracts (revised v2.2 — `ram-configuration` dropped), resolve the 12 explicit TBDs surfaced in the PRD (rate limits, UI stack, service-to-service auth, capacity numbers, ops hours, log retention, versioning policy, pilot region, cross-region handling, historical-data access, migration owners, identity-key scheme).
2. **Run `bmad-create-ux-design`** — derive component patterns, screen flows, and interaction models from the 5 user journeys and FR55/FR56, constrained by D4 (replicate APEX layouts) and NFR17/18/19 (WCAG 2.2 AA, assistive-tech compatibility, regulatory accessibility statement).
3. **Run `bmad-create-epics-and-stories`** — translate the 61 FRs into deliverable epics aligned with Phase 0 → 9+ build sequence; use the candidate-epic mapping in this report's *Epic Quality Review* section as a starting point.
4. **Re-run `bmad-check-implementation-readiness`** once Architecture, UX, and Epics artefacts exist. The PRD's FR/NFR list captured in this report's *PRD Analysis* section is the authoritative input for the re-run.

### Findings on the PRD itself (for completeness)

The PRD shows the following positive readiness signals:

- **Capability completeness:** 61 FRs across 9 capability areas covering all 11 services (revised v2.2 — `ram-configuration` dropped); brainstorming reconciliation completed in PRD Step 11 found nothing dropped.
- **Quality-attribute completeness:** 42 NFRs across 8 categories; all page-level NFRs from the as-is functional-modules cross-cutting NFRs reflected.
- **Decision traceability:** 9 locked decisions (D1–D9) consolidated in a Decisions Log appendix and referenced inline.
- **Source traceability:** every section traceable to the brainstorming session, the as-is docs, or an explicit user decision in conversation.
- **Explicit TBDs:** 12 open items named in this report's *Additional Requirements* section; none are silently deferred.
- **Dual-audience density:** the PRD reads cleanly to both human stakeholders (Document Map, Glossary, References) and downstream LLM-driven workflows (numbered FR/NFR contract, classification metadata, decisions log).

### Final Note

This assessment identified **3 critical issues**, all of the same character: missing downstream artefacts that this readiness check is designed to validate. None of these issues reflect defects in the PRD itself.

The PRD is fit-for-purpose as input for the next three workflows. Proceed by running them in order: `bmad-create-architecture`, `bmad-create-ux-design`, `bmad-create-epics-and-stories`. Re-run readiness when those artefacts exist.

**Assessment complete.**

**Report:** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-05.md`
**Date:** 2026-05-05
**Assessor:** PRD Validator (bmad-check-implementation-readiness)
