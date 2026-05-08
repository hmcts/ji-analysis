---
stepsCompleted: ['step-01-document-discovery', 'step-02-prd-analysis', 'step-03-epic-coverage-validation', 'step-04-ux-alignment', 'step-05-epic-quality-review', 'step-06-final-assessment']
projectName: 'ji-analysis'
productCodename: 'NJI'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
inputDocumentsMissing:
  - 'epics.md / stories.md'
  - 'ux-design.md'
date: '2026-05-06'
workflowCompleted: true
supersedes: 'implementation-readiness-report-2026-05-05.md'
---

# Implementation Readiness Assessment Report (Re-run)

**Date:** 2026-05-06
**Project:** ji-analysis (NJI — New JI)
**Supersedes:** the 2026-05-05 readiness report

## What changed since the previous run

The 2026-05-05 readiness report concluded **NEEDS WORK — for downstream artefact generation**, with three of four expected artefacts missing (Architecture, UX, Epics). Since then:

- **Architecture document landed** at `_bmad-output/planning-artifacts/architecture.md` (1,826 lines, 6 top-level sections, 50 subsections). All 8 architecture-workflow steps completed; the architecture's own validation verdict is **READY WITH DOCUMENTED GAPS** (high confidence). The document resolves the 7 architecture-phase TBDs from the PRD, locks the technology stack against the verified HMCTS Crime SpringBoot template (Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, PostgreSQL 17, Flyway, OpenTelemetry → Application Insights, Swagger Core, custom JWTFilter, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, Logstash logging), and adopts a shared-DB topology (one global PostgreSQL instance, schema-per-service, explicit grants).
- **UX Design** still not produced.
- **Epics & Stories** still not produced.

This re-run reflects the Architecture's arrival and updates the verdict accordingly.

## Document Inventory

### PRD Documents

**Whole Documents:**
- `prd.md` (73 KB; 12 PRD-workflow steps complete; 61 FRs, 42 NFRs, 9 locked decisions D1–D9)

### Architecture Documents

**Whole Documents:**
- `architecture.md` (136 KB; 8 architecture-workflow steps complete; verdict READY WITH DOCUMENTED GAPS / High confidence)

### Epics & Stories Documents

⚠️ **Required document not found** — no epics or stories document exists. Epic coverage cannot be validated.

### UX Design Documents

⚠️ **Required document not found** — no UX design artefact exists. UX alignment cannot be validated.

### Other files

- `prd_tmp.html`, `prd.pdf` — auto-generated renderings of the PRD; not assessment inputs.
- `implementation-readiness-report-2026-05-05.md` — superseded by this report.

## Critical Issues

**Duplicates requiring resolution:** None.

**Missing artefacts:** Two of four expected inputs (UX, Epics) are still absent. Down from three at the previous run.

## PRD Analysis

The PRD's 61 FRs (across 9 capability areas) and 42 NFRs (across 8 categories) are unchanged since the 2026-05-05 extraction. The full FR/NFR text is captured in the prior readiness report and in `prd.md` itself; this report references them by ID rather than re-extracting verbatim.

**FR capability areas (counts):**

- Identity & Authorisation (FR1–FR5): 5
- Foundational Data Management (FR6–FR9): 4
- Judge Records & Working Patterns (FR10–FR18): 9
- Absence Workflow (FR19–FR22): 4
- Vacancy & Cover (FR23–FR28): 6
- Booking Management (FR29–FR34): 6
- Sitting Management (FR35–FR40): 6
- Payment & Reconciliation (FR41–FR47): 7
- Itineraries & Reporting (FR48–FR54): 7
- Platform Operations & Migration (FR55–FR61): 7

**NFR categories (counts):**

- Performance (NFR1–NFR9): 9
- Security (NFR10–NFR16): 7
- Accessibility (NFR17–NFR19): 3
- Integration (NFR20–NFR24): 5
- Observability (NFR25–NFR29): 5
- Data Privacy & Sovereignty (NFR30–NFR33): 4
- Reliability & Availability (NFR34–NFR38): 5
- Maintainability (NFR39–NFR42): 4

**Additional Requirements (PRD-level non-FR/NFR commitments):**

The PRD's 9 locked decisions (D1–D9) and the technology / domain compliance constraints listed in the prior readiness report's *Additional Requirements* section remain authoritative. Twelve TBDs were originally surfaced; **seven are now resolved by the Architecture** (see Architecture Analysis below); the remaining five are programme-management decisions tracked separately.

## Architecture Analysis (new section since last run)

### Decisions formalised

The Architecture document resolves the 7 architecture-phase TBDs from the PRD:

| TBD | PRD status | Architecture resolution |
|---|---|---|
| Rate limit policy | TBD | Azure API Management at ingress; 100 req/sec/principal default; 10 req/sec/principal for MI Feed; 200 req/sec burst |
| UI framework family | TBD | React + TypeScript + GOV.UK Design System + Vite |
| Service-to-service auth | Resolved v2.6 (2026-05-07) | **Two patterns at MVP**: (1) **JWT propagation** for user-initiated flows — outbound calls forward the inbound user JWT; (2) **Service-principal OAuth `client_credentials`** for the **payment-processing batch** (`nji-payment-batch`) which has no upstream user — non-prod via `nji-mock-auth` (`mock_oauth_clients`), production issuer per `gaps.md` G7.1 (default recommendation: Azure Workload Identity). No mTLS at MVP. *(v2.5 had narrowed this to JWT propagation only; v2.6 widened it again to support the batch.)* |
| Log retention | TBD | 30 days hot in App Insights; 90 days cold in Log Analytics archive |
| API versioning specifics | TBD | URI prefix major versioning (`/v1/`); 6-month internal / 12-month external deprecation; `Deprecation` header per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745); `Sunset` header per [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) |
| Historical-data access | TBD | Read-only APEX bridge for 12 months post-region-cutover; one-shot extract thereafter |
| APEX ⇄ IdP identity-key | TBD | Email primary, employee number fallback, manual review for unmatched; Phase 0 reconciliation report |

### Architecture's coverage of FRs

The Architecture's Step 7 validation table maps every PRD FR capability area to specific architectural support. Cross-checked here:

| FR group | Architectural support |
|---|---|
| Identity & Authorisation (FR1–FR5) | Authorisation service + per-service custom JWTFilter (HMCTS template pattern) + OIDC integration for human users (mock auth in Phase 0–8; real HMCTS IdP from pre-Phase-9) + JWT propagation interceptor on outbound HTTP clients for user-initiated flows + OAuth `client_credentials` (via `nji-mock-auth`) for the payment batch service principal (`nji-payment-batch`) per v2.6. FR5 (full programmatic service-account directory) remains post-MVP. |
| Foundational Data Management (FR6–FR9) | Reference Data and Notification services; direct SQL access to Reference Data tables (no caching at MVP per Principle 2). Configuration: per-service Spring profiles + Key Vault; shared `configuration_values` infrastructure table (no API) for cross-service policy values, schema-managed by `nji-architecture` Flyway baseline. *(Revised v2.2, 2026-05-07.)* |
| Judge Records & Working Patterns (FR10–FR18) | Judge service (Phase 1); working-pattern engine owned by Judge |
| Absence Workflow (FR19–FR22) | Absence service (Phase 2); approval workflow with auto-vacancy creation per R4 |
| Vacancy & Cover (FR23–FR28) | Vacancy service (Phase 3); `markFilled` direct DB UPDATE (per Principle 1 simple-cross-service-write rule) |
| Booking Management (FR29–FR34) | Booking service (Phase 4); idempotency-key handling for retryable creates |
| Sitting Management (FR35–FR40) | Sitting service (Phase 5); generated from Judge working patterns |
| Payment & Reconciliation (FR41–FR47) | Payment service (Phase 6) — **scheduled batch** (`nji-payment-batch`) authenticates as a service principal via OAuth `client_credentials`, picks up confirmed-but-unpaid bookings/sittings, generates the JFEPS-shaped Excel, dispatches it to the Payment Authoriser via Notification → HMCTS Email; reconciliation marked manually by RSU at MVP (per v2.6 reframing — FR41–45 are batch-driven, not user-initiated). See `architecture/sequence-diagrams/payment-batch-flow.md`. |
| Itineraries & Reporting (FR48–FR54) | Itinerary + MI Feed services (Phases 7–8); SQL JOINs across schemas (replaces Strategy A) |
| Platform Operations & Migration (FR55–FR61) | Per-service implementations (HMCTS Crime SpringBoot template scaffolding) + Phase 0 migration via Flyway |

### Architecture's coverage of NFRs

| NFR group | Architectural support |
|---|---|
| Performance (NFR1–NFR9) | APEX-baseline page-level NFRs achievable; Forward Look NFR8 trivially achievable via indexed SQL JOINs over the shared DB; AKS HPA for capacity NFR9 |
| Security (NFR10–NFR16) | TLS 1.3 ingress; PostgreSQL encryption-at-rest; custom JWTFilter; Azure Key Vault; GFS-7 alignment via HMCTS template defaults; NFR12 (auth) covers both inter-service patterns — JWT propagation for user-initiated, service-principal `client_credentials` for the payment batch (per v2.6) |
| Accessibility (NFR17–NFR19) | GOV.UK Design System; axe-core in CI; React Hook Form |
| Integration (NFR20–NFR24) | OIDC (mock + real); JFEPS unchanged; HMCTS email; MI Feed REST contract; no eLinks integration |
| Observability (NFR25–NFR29) | Logstash JSON logs + OpenTelemetry → Application Insights; correlation-ID MDC; Spring Actuator probes |
| Data Privacy & Sovereignty (NFR30–NFR33) | Azure UK regions only; PostgreSQL Flexible Server in UK South; case-level data forbidden by schema; FOI scope by contract |
| Reliability & Availability (NFR34–NFR38) | Operational hours availability; per-wave rollback via region activation flag (FR58); region-isolated AKS clusters; PostgreSQL HA configuration |
| Maintainability (NFR39–NFR42) | API-as-Product standards (versioned, OpenAPI spec, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) `Deprecation` + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) `Sunset` for deprecation signalling); per-service deployment unit; **manual UAT scripts per domain service** (FR61 / NFR41 revised 2026-05-06 — APEX-experienced users compare NJI vs APEX side-by-side, sign-off per role per region as wave-cutover gate); Postman collections per phase. *(There is no automated APEX-comparison test suite — automated CI tests are unit, integration with Testcontainers, and contract tests only. `/capabilities` runtime endpoint convention retired v2.7, 2026-05-08 — no standard backs it.)* |

**All 61 FRs and 42 NFRs have explicit architectural support.** None unaddressed.

### Architecture-introduced foundational principles

Two principles formalised in the Architecture that shape downstream work:

- **Principle 1: API for workflows; shared DB for simple data access.** Cross-service reads via SQL JOINs over the shared DB; cross-service simple writes via DB role grants on whitelisted columns; cross-service workflows via API. Single global PostgreSQL instance, schema-per-service.
- **Principle 2: No premature optimization.** No caching, no distributed cache, no service mesh, no read replicas, no async messaging at MVP — added only when measurement post-MVP justifies the complexity.

### Architecture's documented gaps (carry forward)

The Architecture's Step 7 surfaces 27 gaps across 6 categories (G1–G6), each with mitigation, fallback, and named owner. None are critical (none block implementation). Most pertinent to this readiness assessment:

- **G1.4** confirmed via HMCTS Crime template review (2026-05-06) — Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, OpenTelemetry, Logstash, JWTFilter, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, Swagger Core all present.
- **G1.4a** Helm chart not in template baseline; NJI scaffolding script must add.
- **G1.4b** Spring Cloud Azure Key Vault not in template baseline; NJI scaffolding script must add.
- **G6.1–G6.5** Shared-DB topology risks (schema-evolution coordination, single-DB blast radius, cross-region rollout, DB role grant maintenance, Flyway migration versioning across schema boundaries).

### Architecture's documented assumptions (carry forward)

32 assumptions (A1–A32), classified as Load-bearing / Reversible / Aspirational, each with verification owner. Mock-first authentication reclassifies HMCTS IdP assumptions (A1, A2, A3) from Phase 0 to Phase 9+ blockers, materially reducing Phase 0 risk.

## Epic Coverage Validation

### Coverage Matrix

⚠️ **Epics & Stories document still not present.** Coverage validation cannot be performed.

By definition, **none of the 61 PRD FRs are currently traced to epic coverage**, because no epics have been authored. This was already the case at the previous run; the situation is unchanged.

### Coverage Statistics

- **Total PRD FRs:** 61
- **FRs covered in epics:** 0 (no epics document exists)
- **Coverage percentage:** 0% — *not* a defect; epics workflow has not run yet
- **Status:** ❌ Cannot validate — Epics & Stories artefact missing

### What's improved vs prior run

The Architecture provides a **candidate epic mapping** (in its Step 6 *Requirements to Structure Mapping* table) that the Epics workflow can use as a starting point. Each FR capability area maps to a specific repo, build phase, and per-service file location. This is significantly more concrete guidance than was available at the prior run.

### Recommendation

Run `bmad-create-epics-and-stories` to author the epics. The architecture's Phase 0 → 9+ build sequence + repo-per-service structure provides the natural epic boundaries. UX should ideally come first (so stories can include UI acceptance criteria).

## UX Alignment Assessment

### UX Document Status

❌ **Not Found.** No `*ux*.md` artefact exists. Unchanged since prior run.

### Is UX implied?

Yes — strongly. Per D4, modern UI replication of APEX layouts is in scope. FR55, FR56 specify UI surface; NFR17–NFR19 specify accessibility (WCAG 2.2 AA). The Architecture's Step 4 Frontend Architecture has resolved the framework family (React + TypeScript + GOV.UK Design System + Vite); the UX workflow now needs to derive component patterns, screen flows, and interaction models within those constraints.

### Alignment Issues

Cannot validate alignment between UX, PRD, and Architecture because the UX artefact is missing. The PRD and Architecture are internally consistent on UX expectations:

- **PRD:** UI replicates APEX functional layouts; modern UI stack; WCAG 2.2 AA; user-experience uplift.
- **Architecture:** React + TypeScript + GOV.UK Design System + Vite; per-domain UI modules; TanStack Query for server state; React Hook Form + Zod for form state; axe-core integrated in CI.

### Recommendation

Run `bmad-create-ux-design` to produce the UX artefact. The PRD's 5 user journeys, FR55/FR56, and the Architecture's Frontend Architecture decisions are sufficient input.

## Epic Quality Review

### Status

❌ **Cannot perform epic quality review.** Epics & Stories artefact does not exist (per Epic Coverage Validation above).

### Pre-emptive guidance for the upcoming Epic & Stories workflow (refreshed)

The candidate-epic mapping is now better-grounded thanks to the Architecture. When `bmad-create-epics-and-stories` runs, the natural epic boundaries derived from PRD + Architecture are:

| Candidate epic | Maps to | Phase | Architecture support |
|---|---|---|---|
| Identity & Authorisation (incl. Phase 0 user/role migration) | FR1–FR5, FR57, FR58 | Phase 0 | `nji-authorisation` repo + per-service `JWTFilter` + `nji-mock-auth` repo |
| Reference Data + Notification + shared `configuration_values` table | FR6–FR9 | Phase 0 | `nji-reference-data`, `nji-notification` repos + shared infrastructure table managed by `nji-architecture` Flyway baseline (no separate configuration service per arch v2.2) |
| API Platform + Deployment + Logging | FR59, FR60, NFR25–NFR28, NFR39, NFR40 | Phase 0 | NJI scaffolding script + per-service Helm + OpenTelemetry config |
| Judge Records & Working Patterns | FR10–FR18 | Phase 1 | `nji-judge` repo |
| Absence Workflow | FR19–FR22 | Phase 2 | `nji-absence` repo |
| Vacancy & Cover | FR23–FR28 | Phase 3 | `nji-vacancy` repo |
| Booking Management | FR29–FR34 | Phase 4 | `nji-booking` repo |
| Sitting Management | FR35–FR40 | Phase 5 | `nji-sitting` repo |
| Payment & Reconciliation | FR41–FR47 | Phase 6 | `nji-payment` repo |
| Itineraries (Court, Judge, Forward Look) | FR48–FR52 | Phase 7 | `nji-itinerary` repo with SQL-based read model |
| Reports + MI Feed | FR53, FR54 | Phase 8 | `nji-mi-feed` repo with SQL-based read model |
| Real HMCTS IdP Integration | A1, A2, A3, G1.1, G1.2, G1.3 | Pre-Phase-9 | Mock-to-real-IdP cutover playbook (G1.6) |
| Pilot Rollout (per-region cutover playbook) | FR58 (activation flag), Risk #1 mitigation | Phase 9+ | Per-region application-tier deployment with shared DB |

Each candidate epic has at least one repo and a defined per-service file layout. The Epics workflow should be substantially less ambiguous than it would have been at the prior run.

### Pre-emptive failure-mode flags (refreshed)

When epics are authored, watch for:

- **Phase 0 cross-cutting epics** (Identity & Authorisation, Reference Data, API Platform) tend to look like technical milestones. Frame them as user-value (e.g. "RSU users can log in to NJI via SSO and see their authorised regions" rather than "Setup SSO").
- **Mock-to-real-IdP cutover** belongs in its own pre-Phase-9 epic, not bolted onto Phase 9 rollout.
- **Behavioural-parity UAT stories** (FR61 / NFR41 revised 2026-05-06): per-service manual UAT script authoring (under `docs/uat/`) and per-wave UAT execution belong inside each domain epic, not as a separate technical epic. UAT is performed by APEX-experienced users (RSU, Court, Judge, Clerks, Finance, MI) comparing NJI vs APEX side-by-side; sign-off per role per region is the wave-cutover gate. There is no automated APEX-comparison test work to schedule.
- **UI replication stories** (per D4) should be co-located with the API stories of the same phase.
- **Data migration stories** (Reference Data + Users/Roles) belong in Phase 0; stories should reference the APEX-export → Flyway migration sequence.
- **Whitelisted-table grant stories** (per Architecture Principle 1) belong in the table-owning service's epic — when Service B grants Service A access to one of its tables, Service B owns the grant story.

## Summary and Recommendations

### Overall Readiness Status

🟢 **READY WITH DOCUMENTED GAPS** — for the architecture and PRD layers; **NEEDS WORK** for the UX and Epics layers.

This is an upgrade from the prior run's "NEEDS WORK" verdict. The PRD + Architecture combination is now ready for downstream work; the UX and Epics workflows are the named next steps.

The Architecture has done substantial readiness lift since the prior run:

- **All 61 FRs and 42 NFRs have explicit architectural support** (validated in Architecture Step 7).
- **All 7 architecture-phase TBDs from the PRD are resolved.**
- **Technology stack confirmed against the HMCTS Crime SpringBoot template** (Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, PostgreSQL 17, OpenTelemetry, Logstash, JWTFilter, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, Swagger Core) — reducing Phase 0 unknowns considerably.
- **Mock-first authentication** decouples Phase 0–8 build from HMCTS IdP roadmap.
- **Shared-DB topology with explicit grants** simplifies read-model federation and retires Strategy A NFR breach risk (formerly Risk #9).
- **Two foundational principles** (API-for-workflows + No-premature-optimization) anchor downstream decisions.
- **27 documented gaps + 32 assumptions** carry full traceability into the next workflows.

### Critical Issues Requiring Immediate Action

1. **UX Design artefact missing.** Run `bmad-create-ux-design`. The PRD's 5 user journeys, FR55/FR56, NFR17–NFR19, and the Architecture's Frontend Architecture decisions are sufficient input.
2. **Epics & Stories artefact missing.** Run `bmad-create-epics-and-stories` after UX. The candidate-epic mapping in this report's *Pre-emptive guidance* section is the recommended starting point; the architecture's Step 6 *Requirements to Structure Mapping* table is authoritative for repo-per-epic boundaries.

### Recommended Next Steps

1. **Run `bmad-create-ux-design`** — derive component patterns, screen flows, and interaction models from the 5 user journeys and FR55/FR56, constrained by D4 (replicate APEX layouts), NFR17–NFR19 (WCAG 2.2 AA), and the Architecture's locked stack (React + TypeScript + GOV.UK Design System + Vite). UX produces the binding UI design contract.
2. **Run `bmad-create-epics-and-stories`** — translate the 61 FRs into deliverable epics aligned with Phase 0 → 9+ build sequence; use the candidate-epic mapping in this report and the Architecture's repo-per-service structure as a starting point. Each story includes UI acceptance criteria where relevant (informed by UX).
3. **Re-run `bmad-check-implementation-readiness`** once UX and Epics artefacts exist. The next verdict should reflect a complete artefact set; remaining gaps would then be programme-management decisions (G2 series) and external HMCTS dependencies (G1 series).
4. **Phase 0 prerequisite checks** can begin in parallel with UX/Epics work:
   - Verify HMCTS Crime SpringBoot template (or judicial-services equivalent) is appropriate (G1.4).
   - Verify Helm chart provision mechanism within HMCTS (G1.4a).
   - Verify Spring Cloud Azure Key Vault availability (G1.4b).
   - Verify HMCTS Email transport for AKS-hosted services (G1.5).

### Findings on the PRD + Architecture combination (positive signals)

Strengths surfaced during this re-run:

- **End-to-end traceability.** Every PRD FR/NFR has an architectural mechanism. The architecture's validation matrix is concrete (specific repos, file paths, dependencies).
- **Decisive simplification.** The architecture rejected three classes of complexity (event bus, shared library, monorepo) on principled grounds, plus added Principle 2 (no premature optimization) which retired multiple complexity vectors (caching, service mesh, async messaging, read replicas).
- **Template-grounded technology stack.** All major library choices verified against the HMCTS Crime SpringBoot template — significantly reduces "discovery" work in Phase 0.
- **Mock-first authentication.** Removes HMCTS IdP roadmap dependency from Phase 0–8 critical path.
- **Shared-DB pragmatism.** Cross-service simple data access via DB JOINs and explicit grants; workflows still go via API. Strategy A federation retires; Forward Look NFR becomes trivial.
- **Documented gaps and assumptions.** 27 + 32 = 59 explicit traceability items across the architecture document — every external dependency or simplifying choice is named, classified, and owned.

### Final Note

This assessment identified **2 critical issues** (UX missing, Epics missing). Both are next-workflow tasks rather than defects in the current artefacts.

The PRD + Architecture pair is ready to support the next workflows. Run `bmad-create-ux-design` and `bmad-create-epics-and-stories` (in that order), then re-run readiness for a final verdict. At that point, only programme-management decisions and HMCTS infrastructure verification will remain as documented gaps — no architectural blockers.

**Assessment complete.**

**Report:** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-06.md`
**Date:** 2026-05-06
**Assessor:** PRD + Architecture Validator (bmad-check-implementation-readiness, second run)
**Supersedes:** the 2026-05-05 readiness report
