---
stepsCompleted: ['step-01-init', 'step-02-context', 'step-03-starter', 'step-04-decisions', 'step-05-patterns', 'step-06-structure', 'step-07-validation', 'step-08-complete']
lastStep: 8
status: 'complete'
completedAt: '2026-05-06'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-05-05-1600.md'
  - 'docs/architecture/asis/functional-modules.md'
  - 'docs/architecture/asis/data-dependencies.md'
  - 'docs/architecture/asis/integration-dependencies.md'
workflowType: 'architecture'
project_name: 'ji-analysis'
productCodename: 'NJI'
user_name: 'Ramnish'
date: '2026-05-06'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## System context — at a glance

![NJI System Context — high-level service map and key interactions](./architecture/diagrams/system-context.png)

*Birds-eye view of the NJI service set, key interactions, and external integrations. The diagram is intentionally high-level — for low-level detail (controllers, JPA entities, DB columns, JWT claim shapes) consult the relevant section in this document or its siblings.*

## How this document is structured

`architecture.md` is the **architectural index**. Implementation-detail content (full code-tree inventories, dependency lists, gap and assumption registers, the per-service convention catalogue, the changelog history, the per-table inventory) lives in sibling files under [`./architecture/`](./architecture/) and is referenced from this file in place. Read this file for the *what and why* (decisions, principles, validation, integration points); follow links into the siblings for the *how* (file paths, code shape, exhaustive registers).

| Sibling file | Contents |
|---|---|
| [`./architecture/starter-template.md`](./architecture/starter-template.md) | HMCTS Crime SpringBoot starter — initialisation flow, Gradle build tool rationale, dependency inventory, per-service NJI conventions overlaid by the scaffolding script |
| [`./architecture/data-tables.md`](./architecture/data-tables.md) | Authoritative Table Ownership Mapping — 39 NJI tables (37 production + 2 dev-only) grouped by owning service; provisional pending APEX SQL dump validation |
| [`./architecture/conventions.md`](./architecture/conventions.md) | Implementation Patterns & Consistency Rules (originally Step 5) — naming, structure, format, communication, process, enforcement, examples |
| [`./architecture/repo-structure.md`](./architecture/repo-structure.md) | Per-service / UI / `nji-architecture` repo directory structures, file organisation patterns, local development workflow, deployment-pipeline ASCII diagram |
| [`./architecture/gaps.md`](./architecture/gaps.md) | Documented Gaps register — G1–G6 series with mitigations and owners |
| [`./architecture/assumptions.md`](./architecture/assumptions.md) | Assumptions register — A1–A33 with type (load-bearing / reversible / aspirational) and verification path |
| [`./architecture/changelog.md`](./architecture/changelog.md) | Version history v1.0 → v2.2, including a *pre-v1.8 anchor → current location* table for older changelog entries that reference moved sections |

Refactor history: the single-file `architecture.md` was split into the index + sibling structure above in v1.8 (Strategy B). Pre-v1.8 changelog entries reference section anchors that moved to siblings; the [`./architecture/changelog.md`](./architecture/changelog.md) header has a redirect table.

## Project Context Analysis

### Requirements Overview

**Functional Requirements (61 across 9 capability areas):**

NJI's functional surface is the **11-service decomposition** locked in the brainstorming session (revised v2.2 2026-05-07 — `nji-configuration` was dropped; per-service config now lives in Spring profiles + Key Vault, with a shared `configuration_values` infrastructure table for cross-service policy values), organised in three clusters:

- **Domain services (write surfaces)** — Judge, Absence, Vacancy, Booking, Sitting, Payment. These own state, enforce business rules, and form the canonical operational chain (Manage Judges → Absence → Vacancy → Booking → Sitting → Payment → Reconciliation).
- **Cross-cutting services** — Reference Data (single-writer), Authorisation (gates every call), Notification (transactional email). *(Per-service config is Spring profiles + Key Vault; cross-service policy values live in a shared `configuration_values` table — no dedicated configuration service.)*
- **Read-model services** — Itinerary, MI Feed (SQL-based reads via JOINs over the shared database).

Architectural implications of the FR set:

- **Synchronous cross-service coordination at one point**: `POST /bookings` marks the linked vacancy as filled within the same transaction (FR30, R5) — implemented as a direct DB UPDATE on `vacancies.filled` / `vacancies.filled_at` (per Principle 1, Booking has UPDATE grant on those columns). REST-first synchronous coordination remains the pattern for *workflow* APIs. Booking-creation retry safety is provided by **PostgreSQL row-level locking** (`SELECT vacancies WHERE id=? FOR UPDATE` for the duration of the booking transaction) plus the **`uq_bookings_vacancy_judge_session_date_type` unique constraint** — both native DB primitives — not by a custom idempotency-key table.
- **Read-model federation is via SQL JOINs over the shared global database.** Itinerary's Forward Look NFR (≤ 30 s p95 at Region scope) is trivially achievable with indexed SQL joins over `judges`, `absences`, `vacancies`, `bookings`, `sittings` (all in the shared schema). No parallel API fan-out, no Strategy A latency stacking.
- **Working-pattern-driven sitting generation** (FR13, FR35) requires a deterministic generator running up to 31st March horizon, preserving prior absences. Working pattern is associated with Judge; the generator is owned by Judge and produces records that Sitting's service surface manages from Phase 5 onwards.
- **Versioned content-type negotiation** is first-class for the Payment schedule (FR44 — `application/vnd.hmcts.jfeps+json` vs `+xlsx`). The shape is owned externally (JFEPS) and may evolve; the architecture must treat it as a versioned product surface, not an internal implementation detail.
- **Per-service authorisation enforcement** (FR2, NFR13) is non-negotiable; every API call resolves the principal's role + Region/Area scope through the Authorisation service before authorising the action. This is a cross-cutting middleware concern, not a per-service feature.

**Non-Functional Requirements (42 across 8 categories):**

- **Performance** — page-level NFRs carry from the APEX baseline (≤ 5 s dashboard, ≤ 10 s list, ≤ 15 s batch, ≤ 30 s reports/Forward Look); API NFRs are tighter (≤ 500 ms p95 single-resource read, ≤ 1 s p95 write, ≤ 30 s p95 federated read with cache fallback). Capacity is bounded (~50–100 per region; ~200–500 national once fully migrated).
- **Security** — TLS-only, encryption-at-rest for personal data, AuthN delegated to HMCTS IdP via SSO, AuthZ owned by JI, no bank details and no case-level data anywhere by contract, alignment with HMCTS / MoJ Government Functional Standard 7.
- **Accessibility** — WCAG 2.2 AA mandatory; tested per UI page per phase; assistive-tech compatibility per HMCTS standards; Public Sector Bodies Accessibility Regulations 2018 compliance.
- **Integration** — OIDC issuer (mock auth `nji-mock-auth` in Phase 0–8; HMCTS IdP from pre-Phase-9), JFEPS/Liberata (unchanged from APEX — Excel via email, manual upload), HMCTS email, DA&I MI Feed, no eLinks/HR automated integration in MVP.
- **Observability** — log-based MVP only (D7); structured logging + correlation IDs + Spring Actuator probes; ingestion into Azure Application Insights / Log Analytics; structured user-action audit and metrics/traces are post-MVP roadmap.
- **Data privacy & sovereignty** — Azure UK regions only; UK GDPR + Data Protection Act 2018; no case-level data; FOI scope by contract.
- **Reliability** — operational availability during HMCTS hours; per-wave rollback within one operational cycle; **single Azure region (UK South) with multi-AZ HA** at application and database tiers (AKS multi-zone node pools; PostgreSQL Flexible Server zone-redundant HA); UK West reserved for DR (cold-standby, post-MVP scope decision); HMCTS-judicial-region rollout isolation enforced at application tier via FR58 activation flags, *not* via infrastructure partitioning.
- **Maintainability** — API-as-Product (versioned, `/capabilities`, RFC 7807 errors, OpenAPI); per-service Kubernetes deployment; **manual UAT scripts per domain service**, walked through by APEX-experienced users (RSU, Court, Judge, Clerks, Finance, MI) who compare NJI vs APEX as a wave-cutover gate (per FR61 / NFR41 revised 2026-05-06); per-phase Postman collections.

**Scale & Complexity:**

- **Primary domain:** API backend (11 services) with first-class UI (modern stack replacing APEX layouts per D4).
- **Complexity level:** High — driven by financial integration criticality (JFEPS / Liberata, where errors mean unpaid judges), 11 services with cross-cutting authorisation, multi-region phased rollout, regulatory environment (judicial, UK government), and behavioural-parity demand (verified by manual UAT) on a brownfield rebuild.
- **Estimated architectural components:** 11 services + 1 modern UI + cross-cutting platform layer (deployment, observability, secret management) + per-service deployment artefacts.

### Technical Constraints & Dependencies

**Locked from PRD (binding):**

- **Stack:** Java 25 (LTS) + Spring Boot 4 + Kubernetes + Microsoft Azure (UK regions only).
- **Coordination:** REST-first synchronous; no domain event stream; no message bus; no webhook fabric.
- **Read-model strategy:** SQL JOINs over the shared schema in the global database; no API federation, no cache fallback.
- **Identity:** OIDC issuer (mock auth `nji-mock-auth` in Phase 0–8; HMCTS IdP from pre-Phase-9 cutover, OIDC or SAML — IdP-side choice); JI owns Authorisation; password/session/account lifecycle wholly external to NJI.
- **Data residency:** Azure UK South / UK West only; no personal data leaves the UK.
- **No bank details, no case-level data** anywhere in the system, by contract.
- **No automated eLinks/HR integration** in MVP scope.

**Inputs from external systems (not controlled by NJI):**

- **HMCTS IdP** for user authentication. **Pre-Phase-9 hard dependency**; mock auth (`nji-mock-auth`) covers Phase 0–8 dev/CI/integration per the mock-first phasing in Step 4.
- **JFEPS-compatible Excel format** for Payment. Output shape is owned externally; treated as a versioned content-type.
- **HMCTS email infrastructure** for transactional notifications (booking ack, absence ack, payment schedules).
- **DA&I MI Feed consumers** post-MVP — they call NJI APIs; NJI does not push or pre-aggregate.
- **APEX (behavioural reference, manually used during UAT only)** — APEX-experienced users open APEX side-by-side with NJI and compare behaviour as part of per-service UAT (D5 revised 2026-05-06; FR61 / NFR41 revised); APEX has no programmatic linkage to NJI's CI or runtime, and is not co-managed by the project (D6).

**Migration constraints (Phase 0 only):**

- **Reference Data + Users/Roles** migrate from APEX (D3 + D9). No transactional data migration.
- **APEX ⇄ IdP identity mapping** — every active APEX user must reconcile to an IdP principal; unmatched records require explicit handling rules (drop / hold / manual map).

### Cross-Cutting Concerns Identified

These functional concerns recur across most or all services and must be addressed at the platform/architecture layer, not per-service:

- **Authorisation enforcement.** Every API call resolves principal → roles + Region/Area scope through the Authorisation service before authorising the action (FR2, FR3). Implementation as middleware applied uniformly to every domain service.
- **Reference Data is single-writer.** Reference Data is the only source of truth for Regions, Offices, judicial vocabularies, and calendar / financial-year boundaries (FR6, FR7). **Reads** go directly against the 15 Reference Data tables (see *Authoritative Table Ownership Mapping* in Step 4) via SQL (per-service DB roles have SELECT grants); no caching at MVP per Principle 2. **Writes** (seed and admin updates) go via the Reference Data **API** — the API is the seeding mechanism and the only path for changes. No service holds duplicate reference data.
- **Per-region scoping of queries and writes.** Domain operations default-scope by Region/Area derived from the principal's Authorisation context (FR49 example pattern). Cross-region operations are explicit and rare.
- **Per-region phased activation.** Per D8, a principal's NJI access is gated by a per-region activation flag (FR58). Authorisation must support per-principal "active in NJI" state, distinct from "exists in NJI."
- **Retry safety via native DB primitives, not custom idempotency tables.** Write operations subject to retry (Booking creation, Payment processing — FR45, FR30) are made safe by: (a) **natural-key unique constraints** (`uq_bookings_*`, `uq_payments_*`) at the DB layer rejecting duplicate creates with `409 Conflict`; (b) **JPA `@Version` optimistic locking** on every domain entity for the lost-update problem (`412 Precondition Failed` on stale writes); (c) **PostgreSQL pessimistic row locking** (`SELECT ... FOR UPDATE` via Spring Data JPA `@Lock(PESSIMISTIC_WRITE)`) on related rows during cross-row workflows. No per-service `*_idempotency_keys` tables. See [`./architecture/conventions.md` → "Retry safety and concurrency control"](./architecture/conventions.md) for the pattern.
- **API-as-Product compliance.** Every service exposes a versioned contract, a `/capabilities` endpoint, RFC 7807 problem-details for errors, and a published OpenAPI specification (FR59). This is the platform contract; every service is bound by it from Phase 0 onwards.
- **Behavioural-parity manual UAT (FR61 / NFR41 revised 2026-05-06).** Every domain service has a **manual UAT script** authored alongside the service. APEX-experienced users (RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI) open APEX side-by-side with NJI and compare behaviour, signing off per role per region before the wave's cutover. There is **no automated APEX-comparison test harness** in NJI's CI — automated CI tests are unit, integration (Testcontainers PostgreSQL), and contract tests only. UAT scripts and Postman collections are platform-level deliverables maintained per phase.
- **Forbidden-data invariants.** No bank details (FR47) and no case-level data (FR54) anywhere in the system. Enforced at schema definition (no fields exist) and at API boundary (validation rejects). Cross-cutting because it applies to every service that touches Payment- or Reporting-shaped data.

### Architecture-phase decisions still open

The PRD surfaces 12 explicit TBDs. The 5 that are programme-management decisions (capacity numbers, ops hours, pilot region, cross-region wave handling, migration owners) are tracked in the PRD and brainstorming risk register, not here. The 7 architecture-phase decisions to be resolved during this workflow:

| # | TBD | Step where resolved |
|---|---|---|
| 1 | Rate limit policy (default ceilings, MI Feed-specific, burst protection) | Step 4 (API & Communication) |
| 2 | UI framework family (React / Vue / Angular / Svelte / etc.) | Step 4 (Frontend Architecture) |
| 3 | Service-to-service authentication mechanism (mTLS vs service token) | Step 4 (Authentication & Security) |
| 4 | Log retention period | Step 4 (Infrastructure & Deployment) |
| 5 | API versioning specifics (URI prefix vs header; deprecation period) | Step 4 (API & Communication) |
| 6 | Historical-data access policy for migrated users | Step 4 (Infrastructure & Deployment) |
| 7 | APEX ⇄ IdP identity-key scheme | Step 4 (Authentication & Security) |

## Starter Template Evaluation

### Foundational Principles

Before evaluating starter options, this architecture takes two foundational principles that constrain the design:

#### Principle 1: API for Workflows, Shared Database for Simple Data Access

**API is the boundary for workflow operations. The shared database is the integration mechanism for simple cross-service data access and read-model federation.** Not "API as the only boundary" — that rule is too rigid for NJI's bounded scale and tightly-related domain. The pragmatic split:

- **Workflows go via API.** Multi-step operations involving business rules, state transitions, validation, or orchestration are exposed as APIs by the owning service and consumed by other services as REST calls. Examples: full Booking creation lifecycle, Payment processing, Absence approval.
- **Simple field-level cross-service updates can be direct DB writes.** A single field change on another service's table — without business-rule cascades — is acceptable as a direct UPDATE within the writing service's transaction. Examples: Booking marks `vacancies.filled = true`; Payment updates `bookings.payment_status`. Each owning service authorises which of its tables / columns may be written by which other services via explicit DB role grants.
- **Cross-service reads are direct SQL JOINs.** Read-model federation (Itinerary, MI Feed) is implemented as SQL joins across tables in the shared schema, not as parallel API fan-out. Reference Data is read directly from its tables, not via API + cache.

The shared database is **one global PostgreSQL instance with a single shared schema** (per Step 4 Data Architecture). Cross-service access is gated by **per-service DB roles with explicit grants on tables**. Table ownership is encoded by a **table-name convention** (entity-plural for primary domain tables, service-prefix for service-internal tables) and enforced by ArchUnit-style fitness functions in CI. The "API as only boundary" pattern is preserved for everything that isn't a single-field update or a cross-service read — i.e. for everything where coupling on the data shape is more expensive than coupling on the contract.

**Why one schema, not schema-per-service:** schema-per-service was originally proposed as architectural isolation for "future independent service evolution." For 11 services owned by one team operating in one tightly-related judicial-scheduling domain, that future is hypothetical. Schema-per-service would be premature optimisation — paying upfront cost (11 schemas + 11 sets of grants + cross-schema FK overhead + per-PR coordination) for a problem we may never have. Single shared schema is simpler Day 1 and supports the same DB-level access control via per-service roles.

**Why per-service DB roles, not a single shared role:** per-service roles are the **forward-compatibility hook** if we ever need to introduce schema-per-service or extract a service. They cost ~10 minutes per role to set up Day 1; retrofitting them later requires auditing every service's actual table access (which is more expensive than starting with them). Per-service roles also give us:

- Defense-in-depth against bugs (a misconfigured Spring Data repository in Sitting can't accidentally write to Payment's tables — the DB rejects).
- DB-layer signal for the post-MVP user-action audit (D7 roadmap) — every change carries the calling service's role identity.
- A reversible decision: grants start broad and tighten as code makes the actual access patterns visible.

There is **no shared runtime code library**. Each service owns its own implementation of cross-cutting concerns, even when that means boilerplate duplication. The cost of duplicated code is accepted in exchange for the property that **changing a cross-cutting concern in one service never forces redeployment of any other service**.

This rules out the common pattern of a "platform library" or "shared kernel" that several services depend on, because such a library creates redeployment-coupling: a change to the library forces every consuming service to consume the new version, retest, and redeploy. That coupling is incompatible with NJI's per-service deployment unit (NFR40).

What is shared:

- **The PostgreSQL database** (one global instance, single shared schema, per-service DB roles with explicit table grants) — for simple data access and read-model federation.
- **API contracts** (OpenAPI documents per service, RFC 7807 error envelope conventions, content-type negotiation patterns) — shared by specification, not by runtime code.
- **API spec Maven artefacts.** Each NJI service publishes its OpenAPI spec (and optionally generated server interfaces) as a Maven artefact (`uk.gov.hmcts.nji:api-nji-{service}:{version}`). Consumers pull in the artefact at compile time for type-safe contract consumption. **This is consistent with the principle**: the artefact is contract, not runtime code. (Pattern adopted from HMCTS Crime template's `uk.gov.hmcts.cp:api-hmcts-crime-template:2.0.2` artefact.)
- **Runtime infrastructure services** (Authorisation, Reference Data, Notification) — shared by API call (workflows) and by direct DB read (simple lookups), not by code. *(Per-service configuration uses Spring profiles + Key Vault; a shared `configuration_values` table holds cross-service policy values, schema-managed by `nji-architecture`'s Flyway baseline.)*
- **Scaffolding templates** (the HMCTS Crime SpringBoot template described below) — shared at scaffold time, then forked into per-service copies.
- **CI/CD and operational conventions** (Gradle build idioms, OpenTelemetry → Application Insights ingestion contract, Flyway migration baseline) — shared by convention and tooling, not by library.

What is duplicated, by design:

- Per-service custom `JWTFilter` (per HMCTS template) that calls `POST /authz/check`.
- Per-service `@ControllerAdvice` that emits RFC 7807 problem-details.
- Per-service `CapabilitiesController` (`@RestController` at root `/capabilities`).
- Per-service structured-logging configuration (Logback patterns, correlation-ID filter).
- Per-service `@ControllerAdvice` translating `DataIntegrityViolationException` (unique-violation kind) → `409 Conflict` and `OptimisticLockingFailureException` → `412 Precondition Failed` for retry safety. *(No idempotency-key store; native DB constructs.)*
- *(removed 2026-05-06)* Per-service behavioural-parity automated test harness — retracted. Behavioural-parity verification is **manual UAT performed by APEX-experienced users** (FR61 / NFR41 revised); UAT scripts live under `docs/uat/` per service, not as runtime test code.

Estimated duplication: ~300–500 lines of boilerplate per service × 11 services. Mitigation: the HMCTS starter encodes most of this; new services start with the boilerplate already present and tailor it as needed.

#### Principle 2: No Premature Optimization

**Performance optimisations are introduced when measurement justifies them, not by default.** This applies to caching, distributed caching, service meshes, async messaging, read replicas, denormalisation, and any other complexity that exists primarily to handle scale or latency. NJI's bounded user population (~hundreds of concurrent users) and read-mostly workload patterns mean that direct database reads are sufficient for MVP performance NFRs.

Specifically:

- **No Reference Data cache (Caffeine, Redis) at MVP.** Each service reads Reference Data directly from Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables) via SQL. If measurement post-MVP shows performance degradation, caching is added per-service at that point — not before.
- **No distributed cache (Redis) at MVP.** Per-service in-memory caching is also avoided unless a measured need surfaces.
- **No service mesh (Istio / Linkerd) at MVP.** Spring Security + AKS DNS + service tokens are sufficient.
- **No read replicas at MVP.** Single PostgreSQL instance is adequate for NJI's bounded concurrent-user count.
- **No async messaging.** REST-first synchronous coordination remains the default.

Each of these tools is introduced if and only if a measurement-backed need appears. The architecture is built for the simplest workable model first; complexity is added in response to evidence, not anticipation.

### Primary Technology Domain

API backend (Java + Spring Boot 4) on Kubernetes (Azure Kubernetes Service), deployed to Azure UK regions. The 11-service decomposition produces **11 independently-deployable Spring Boot services**, each scaffolded once from the HMCTS starter and thereafter owned independently.

UI framework is a separate decision (Step 4 Frontend Architecture) and uses its own starter.

### Starter Options Considered

| Option | Verdict |
|---|---|
| **HMCTS internal Java/Spring Boot starter** (`hmcts/service-hmcts-crime-springboot-template`) | ✅ **Selected.** Confirmed via review (2026-05-06). Encodes HMCTS-standard logging (Logstash JSON), health checks, OpenTelemetry → Application Insights, IdP integration patterns (custom `JWTFilter`), and security defaults that the team would otherwise reinvent. **Helm chart and Spring Cloud Azure Key Vault are not in the template baseline** — NJI scaffolding script adds them (G1.4a, G1.4b). |
| **Spring Initializr (start.spring.io)** | Fallback only. Use if the HMCTS starter is unavailable. Same per-service-fork model; the team would need to add HMCTS-specific patterns manually. |
| **JHipster** | ❌ Rejected. Heavyweight; bundles identity, frontend, database, Docker, and CI/CD — most of which conflicts with locked NJI decisions or implies a shared-library pattern. |
| **Spring Cloud Microservices archetype** | ❌ Rejected. Opinionated towards service discovery, config server, circuit breakers — none needed under REST-first synchronous + Kubernetes orchestration. Also tends to encourage shared-library patterns. |
| **Custom NJI Platform Library** | ❌ Rejected on the foundational principle above. Would create cross-service redeployment coupling. |

### Selected Starter: HMCTS Internal Java/Spring Boot Starter

**Rationale for Selection:**

- **HMCTS-standard patterns out of the box.** Logstash JSON logging, correlation ID conventions, OpenTelemetry → Application Insights, custom `JWTFilter` integration scaffolding, security headers — all encoded once by HMCTS and inherited per service. (Helm chart and Spring Cloud Azure Key Vault are not in the template baseline; NJI scaffolding script adds them — see G1.4a, G1.4b.)
- **Scaffold-time inheritance, not runtime dependency.** Each service is forked from the starter at scaffold time and thereafter owns its own copy. The starter is a template, not a library. Subsequent starter changes do not propagate into existing services.
- **Aligns with the foundational principles** in this Step 3 — API as boundary for workflows + shared DB for simple data access; no shared runtime library; no premature optimization.

### Initialisation Flow, Build Tool, Dependency Inventory, Per-service Conventions

> **Moved to [`./architecture/starter-template.md`](./architecture/starter-template.md) in v1.8.**
>
> What lives there: per-service `git clone` / scaffolding flow; Gradle Groovy DSL rationale; the full dependency inventory the HMCTS Crime template provides (Spring Boot 4.0.6, Gradle plugins, Testcontainers, OpenTelemetry, Logstash encoder, custom `JWTFilter`, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, gradle-git-properties, Swagger Core); per-service NJI conventions overlaid by the scaffolding script (group ID, Azure UK region, `CapabilitiesController`, `JWTFilter` + `AuthDetails`, RFC 7807 `@ControllerAdvice`).
>
> What stays here in `architecture.md`: the *Starter Options Considered* comparison table and the *Selected Starter: HMCTS Internal Java/Spring Boot Starter* rationale (above).

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**

- Database technology and table-ownership / per-service-role model
- Service-to-service authentication mechanism
- API versioning specifics (URI vs header)
- UI framework family
- API gateway / rate-limiting layer

**Important Decisions (Shape Architecture):**

- Migration tooling for schema changes
- APEX ⇄ IdP identity-key scheme
- Log retention period
- Historical-data access policy for migrated users
- HA topology — same-Azure-region multi-AZ in UK South; UK West DR scope (post-MVP); HMCTS-judicial-region rollout isolation at application tier (see *Deployment topology* below)

**Deferred Decisions (Post-MVP per Principle 2 — added only when measurement justifies):**

- Caching for Reference Data or any service (per Principle 2; not at MVP)
- Distributed cache (Redis or equivalent)
- Service mesh (Istio / Linkerd) — only if observability or mTLS demands exceed what custom JWTFilter + AKS DNS provide
- Read replicas for PostgreSQL — only if measured load justifies
- API Management advanced features (developer portal, analytics) — basic gateway in MVP

### Data Architecture

**Database technology: PostgreSQL on Azure Database for PostgreSQL Flexible Server, UK regions only.**

- **Rationale:** the domain is relational (judges, absences, vacancies, bookings, sittings, payments — all interrelated). PostgreSQL is mature, well-supported on Azure, lower-cost than Azure SQL, and aligns with HMCTS open-source preferences. PostgreSQL 17 is current stable; Azure offers 16/17 on Flexible Server.
- **Version assumption:** PostgreSQL 17 (latest GA on Azure Flexible Server). Verify at provisioning; downgrade to 16 acceptable if HMCTS infrastructure prefers it.

**Database topology: one global shared instance, single shared schema, per-service DB roles.**

- **One global PostgreSQL Flexible Server instance** for the entire NJI application (not per-region, not per-service). Sized for the full bounded user population.
- **One logical database** within that instance.
- **One shared schema** (e.g. `nji` or the default `public`) containing all NJI tables. **No schema-per-service.** Rationale: 11 services built sequentially by one team operating in one tightly-related domain do not need schema-level isolation; the upfront cost (11 schemas, cross-schema grants, cross-schema FK overhead, per-PR coordination) buys nothing concrete at MVP. Future schema-per-service is a reversible refactor if/when evidence justifies it.
- **Table ownership encoded by table-name convention** (see *Table naming and ownership* below).
- **Per-service DB roles with explicit grants** (see *Per-service DB roles* below).

**Table naming and ownership convention:**

- **Primary domain tables** use entity-plural names without prefix: e.g. `judges`, `working_patterns`, `absences`, `vacancies`, `bookings`, `sittings`, `payments`, `payment_schedules`, `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables (`judge_types`, `work_types`, `court_types`, `ticket_types`, `session_types`, `absence_types`, `working_pattern_types`, `booking_statuses`, `sitting_outcomes`, `fee_payment_statuses`, `payment_statuses`, `reconciliation_statuses`). Authoritative inventory in *Authoritative Table Ownership Mapping* below.
- **Service-internal or potentially-ambiguous tables** are prefixed with the owning service: `payment_reconciliations`, `notification_dispatches`, `auth_user_roles`.
- **Authoritative ownership table** in the architecture document maps every table to its owning service-role. This is the source of truth for "who can write."
- **The team that writes the Flyway migration creating the table is the owning team for that table.** Ownership is encoded in code (the `V*__*.sql` file lives in the owning service's repo).

**ArchUnit-style fitness functions enforce the convention** (in CI):

- No two services' Flyway migrations create tables with overlapping names.
- DB role grants align with the documented ownership mapping.
- Each service's DB role has `ALL` (or appropriately narrowed) privileges on tables it owns, and only the explicitly-granted privileges on tables owned by other services.

**Cross-service access (Principle 1 applied to the data layer):**

| Access pattern | Allowed | Mechanism |
|---|---|---|
| Service reads its own tables | ✅ Always | Via Spring Data JPA repositories |
| Service writes its own tables | ✅ Always | Via Spring Data JPA |
| Service reads another service's tables | ✅ For SELECT-granted tables | Direct SQL JOIN in the shared schema; no API roundtrip |
| Service writes a single field on another service's table | ✅ For UPDATE-granted columns | Direct UPDATE within the writer's transaction; pessimistic row lock (`SELECT … FOR UPDATE`) on the target row recommended for cross-row workflow safety |
| Service performs a workflow on another service's data (multi-step, business rule, state transition) | ❌ Direct DB; ✅ via API | Owning service's REST endpoint; the API encapsulates the workflow |
| Service writes to non-granted columns or tables of another service | ❌ Forbidden | DB role lacks the grant; attempt will fail at the DB layer |

**Foreign keys within the shared schema: allowed and encouraged.** `bookings.judge_id REFERENCES judges(id)` for database-level referential integrity. No cross-schema FK overhead because there is one schema.

**Per-service DB roles with explicit grants.**

- Each service connects with its own role: `nji_judge`, `nji_booking`, `nji_payment`, `nji_reference_data`, etc. (one role per service, plus `nji_mock_auth` for the mock authentication service in dev/integration).
- Each role has `ALL` privileges on the tables that service owns (per the table-ownership mapping).
- Cross-table access is granted explicitly: `GRANT SELECT ON vacancies TO nji_booking; GRANT UPDATE (filled, filled_at) ON vacancies TO nji_booking;`
- Grants are codified in Flyway migrations (`V*__*.sql`) owned by the table-owning service.
- A service that needs new cross-table access raises a PR against the owning service's repo; the owning service grants (or refuses) the grant.
- **Day 1 stance:** start with broad grants (e.g. `GRANT SELECT ON ALL TABLES IN SCHEMA nji TO nji_*`) and tighten as code makes the actual access patterns visible. The role infrastructure exists from Day 1 even when grants are broad — this is the cheap-Day-1, expensive-to-retrofit position.

**Forward-compatibility framing:** per-service DB roles are the seam that supports a future migration to schema-per-service or service-extraction *without* code changes to the connection layer. If post-MVP evidence justifies schema-per-service, the role-per-service hooks are already in place; only the schema layout changes.

### Authoritative Table Ownership Mapping

> **Per-table inventory moved to [`./architecture/data-tables.md`](./architecture/data-tables.md) in v1.8.**
>
> What lives there: the per-service breakdown of NJI-owned tables (15 Reference Data including the 12 vocabulary tables; 5 Authorisation; 1 Notification; 5 Judge; 1 Absence; 2 Vacancy; 1 Booking; 1 Sitting; 3 Payment; 0 Itinerary; 0 MI Feed; 2 dev-only Mock auth) plus 1 shared infrastructure table (`configuration_values`, schema-managed by `nji-architecture` Flyway baseline) with column-level grant notes and consumer mapping.
>
> What stays here in `architecture.md`: the architectural framing — single shared schema, per-service DB roles with explicit grants, table-name convention (entity-plural for primary; service-prefix for ambiguous), ArchUnit-style fitness functions enforcing ownership. The fitness function operates against the [`./architecture/data-tables.md`](./architecture/data-tables.md) inventory: every table created by Flyway must appear there with the matching owning service.
>
> **NJI tables are NJI design.** APEX has its own (different) schema; NJI's 39 tables are designed independently. The Phase 0 ETL (see *Phase 0 Data Migration from APEX* below) maps APEX data into NJI's shape via NJI APIs. APEX's schema is *not* in this inventory and is *not* owned by any NJI service. Revalidation against the APEX SQL dump (G4.6 in [`./architecture/gaps.md`](./architecture/gaps.md); A33 in [`./architecture/assumptions.md`](./architecture/assumptions.md)) confirms the migration tool's mapping is complete, not whether NJI's shape is "correct."

**Data modelling approach: Spring Data JPA + Hibernate.**

- Each service defines its entities, repositories, and queries within its own bounded context.
- No shared entity classes, no shared repositories. Per the no-shared-library principle, common patterns (e.g. base auditable entity with `createdAt` / `updatedAt`) are duplicated per service rather than inherited from a shared library.
- Entities representing read-only views of another service's whitelisted tables are defined as `@Immutable` JPA entities in the consuming service.

**Schema-evolution tooling: Flyway (per HMCTS Crime SpringBoot template).**

Flyway here is the **schema-evolution mechanism for NJI's own tables** — DDL only. It is *not* the mechanism for loading data from APEX into NJI; that is a separate Phase 0 activity (see *Phase 0 Data Migration from APEX* below).

- Per-service `src/main/resources/db/migration/V*__*.sql` files versioned within the service's own repo.
- Dependencies (per HMCTS template): `spring-boot-starter-flyway`, `flyway-core`, `flyway-database-postgresql`.
- Migrations run on application startup against the shared schema; each service's migrations operate only on the tables it owns (per the ownership mapping). Grants on tables it owns to other services are part of the owning service's migration files.
- No cross-service migrations; each service evolves its own tables independently. Table changes follow a deprecation policy parallel to API versioning (G6.1) — add new columns first, deprecate old ones, remove after consumers transition.
- **NJI table shape is determined by NJI design.** APEX's table shape is *not* a constraint on NJI's table shape. The 39 NJI tables enumerated in [`./architecture/data-tables.md`](./architecture/data-tables.md) are NJI's design choices; APEX's schema is the *source of historical data*, not the source of the target shape.
- **Flyway operates on the shared schema; ownership is enforced by which service's migration creates the table** — not by which schema the table lives in. The fitness function in CI checks no two services attempt to migrate the same table.

**Phase 0 Data Migration from APEX (a separate ETL activity, distinct from Flyway).**

The Phase 0 migration is an **extract-transform-load (ETL) activity** that takes data from APEX (which has its own legacy schema) and lands it into NJI tables (which have NJI's own schema, designed independently of APEX). The two schemas are different; the migration is the mapping between them.

- **Source:** APEX SQL dumps for Reference Data (controlled lists, regions, offices, calendar periods) and APEX user records + role/scope assignments. APEX schema is whatever it is; NJI does not own it and does not constrain its shape.
- **Target:** NJI tables (`regions`, `offices`, `calendar_periods`, the 12 vocabulary tables, `auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags` — all per [`./architecture/data-tables.md`](./architecture/data-tables.md), all owned by NJI services, all designed by NJI).
- **Mechanism:** the migration tool reads APEX dumps, transforms each row into the NJI shape (extract distinct values, normalise enums, reconcile users against IdP principals, etc.), and **loads via the NJI service APIs** — `POST /v1/regions`, `POST /v1/judge-types` and the other Reference Data write endpoints; `POST /authz/users` and the other Authorisation write endpoints. The API is the seeding mechanism (per the v1.6 Reference Data write decision); the migration tool is the bulk caller.
- **Mechanism is *not* Flyway data-seeding.** No `V*__seed_apex_data.sql` Flyway file ingests APEX rows directly. The reasons: (a) APEX's shape and NJI's shape differ; the transform is non-trivial and lives in code, not in a SQL script; (b) per the v1.6 decision, writes go via the API so that validation, idempotency, and audit-logging hooks fire; (c) the migration is a one-shot programme deliverable, not part of the per-service schema-evolution timeline.
- **Tool location and ownership:** the migration tool lives at `nji-architecture/migration/` (a CLI/script under the architecture repo, owned by the NJI architecture team plus the named owners per Risk #13 — RSU / judicial-team owners for Reference Data; RSU + OPT Support for Users/Roles). It is a Phase 0 deliverable. Once Phase 0 is complete, the tool is retained for re-runs per rollout wave (e.g. user activation flag changes per wave).
- **What gets migrated, in scope:** Reference Data (D3) and active APEX users + their role/Region-Area scope mappings (D9). **No transactional data migration** (no judges, absences, vacancies, bookings, sittings, payments are migrated from APEX). NJI tables for those are empty at region cutover and accumulate from there.
- **Reconciliation and sign-off:** per Risk #13 — every Reference Data list signed off by RSU / judicial-team owners; every migrated user reconciled against an IdP principal (per D9 + Risk #14) with explicit handling for unmatched records (drop / hold / manual map). Reconciliation report is produced before each rollout wave; the tool re-runs against updated APEX dumps as needed.
- **APEX revalidation scope:** the architecture's Authoritative Table Ownership Mapping and the migration tool's input-output schema are revalidated against the **APEX SQL dump when it lands** — not to confirm NJI's shape (NJI's shape is fixed by NJI design) but to confirm the migration tool's mapping covers every APEX field NJI needs and to surface any APEX values the NJI vocabularies do not yet anticipate. If new vocabulary values surface, the appropriate vocabulary table in NJI gains a row via the Reference Data API; the table itself does not change shape. Tracked as G4.6 / A33.

**Read-model strategy: SQL JOINs across the shared schema (replaces Strategy A federation).**

- Itinerary and MI Feed services execute SQL queries that join across `judges`, `absences`, `vacancies`, `bookings`, `sittings`, `payments` (read-only via SELECT grants on those tables).
- No parallel API fan-out, no Strategy A latency stacking, no Strategy C cache fallback needed.
- Itinerary and MI Feed services remain distinct (operational read vs aggregate analytics; different consumer audiences) but become very thin — primarily SQL → JSON translation.
- The ≤ 30 s Forward Look NFR (NFR8) is trivially achievable with indexed SQL joins; Risk #9 (Strategy A NFR breach) retires.

**Caching strategy: none at MVP (per Principle 2).**

- **No Caffeine cache on Reference Data or any other service.** Direct SELECT from Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables) is the default.
- **No distributed cache (Redis).**
- Caching may be added per-service post-MVP if measurement shows performance degradation.

**Validation strategy: JSR-380 (Bean Validation 3.0) annotations on request DTOs and entity fields, enforced by Spring Web's `@Valid` integration.** Service-specific validation logic lives in the service's domain layer.

### Authentication & Security

#### Phasing of Authentication: Mock-First, Real IdP Later

NJI's pre-production phases (0 through 8) use a **Mock Authentication Service** for all authentication needs. Real HMCTS IdP integration is a discrete **pre-Phase-9 deliverable**, executed as a configuration cutover before pilot rollout.

**Mock Authentication Service (`nji-mock-auth`, Phase 0 deliverable):**

- Exposes the OIDC contract used by NJI services: `/oauth2/authorize`, `/oauth2/token`, `/oauth2/jwks`, `/oauth2/userinfo`.
- Issues JWTs for a fixed roster of test users covering all 11 user roles × representative Region/Area combinations.
- Supports OAuth 2.0 `client_credentials` grant for service-to-service tokens.
- Mirrors the user records that the Phase 0 ETL has loaded into NJI Authorisation (or a representative subset) to exercise Authorisation flows realistically.
- Implemented as a Spring Authorization Server-based service; deployed to AKS dev / integration clusters alongside other Phase 0 services.
- **Production safeguard:** the mock service refuses to start when the `production` Spring profile is active. CI lint enforces that production deployment manifests reference the real-IdP issuer URL only.

**Use across environments:**

| Environment | Authentication source |
|---|---|
| Local development | Mock auth (always) |
| CI build / unit + integration tests | Mock auth (always) |
| Integration environment | Mock auth initially; switches to real HMCTS IdP at the pre-Phase-9 cutover |
| Staging environment | Mirrors integration's choice; real HMCTS IdP from cutover onwards |
| Production environment | Real HMCTS IdP only — required for Phase 9 pilot rollout |

**Why mock-first:**

- **Decouples NJI build from HMCTS IdP team's roadmap and integration availability.** Build proceeds on the architectural plan regardless of when IdP feature confirmation lands.
- **Enables full local development and CI without IdP credentials per developer.** No bottleneck on IdP team for dev account provisioning.
- **Allows full Phase 0–8 build to proceed regardless of HMCTS IdP feature confirmation timing.** Risk #6 from the brainstorming session (HMCTS IdP integration timing) is materially reduced — it stops being a Phase 0 blocker and becomes a pre-Phase-9 prerequisite with a contained scope.

**Real HMCTS IdP integration (pre-Phase-9 deliverable):**

- **Cutover triggers** (must be confirmed before integration begins):
  - HMCTS IdP confirmed to support OIDC for human-user authentication (G1.1).
  - HMCTS IdP confirmed to support OAuth 2.0 `client_credentials` grant for service principals (G1.2).
  - HMCTS IdP confirmed to expose principal export / query API for migration reconciliation (G1.3).
- **Cutover mechanism:** a configuration change. Every NJI service's OIDC `issuer-url` switches from mock auth to HMCTS IdP via Spring profile flip — **no code change**. The OIDC client library and JWT validation are issuer-agnostic.
- **Migration alignment:** the user records that the Phase 0 ETL loads into the NJI Authorisation tables (per D9 + identity-key scheme) are keyed by email and employee number. These keys are issuer-agnostic; switching from mock to real IdP requires only that real IdP principals carry the same email / employee number values. The migration is the ETL described in *Phase 0 Data Migration from APEX* — APEX records are read, transformed, and loaded into NJI's `auth_users` / `auth_user_roles` / `auth_user_region_scopes` via the NJI Authorisation API.
- **Reconciliation pass:** before staging cutover, a verification job confirms every migrated user record maps to a real IdP principal. Unmatched records get the same handling rules as in Phase 0 (drop / hold / manual map per Risk #14 mitigation).
- **Test suite handover:** every automated test suite (unit, integration with Testcontainers, contract) that ran against mock auth must pass against real IdP in staging before Phase 9 pilot can begin. Manual UAT against APEX (FR61 / NFR41 revised) is also re-walked in staging with real IdP-backed accounts before Phase 9 pilot opens.

#### End-user Authentication

**End-user authentication: OIDC (locked from PRD).**

**End-user authorisation: NJI Authorisation service** (locked).

- Each NJI service implements its own **custom JWT filter** (per HMCTS Crime template's `JWTFilter` pattern, `io.jsonwebtoken:jjwt` based). The filter:
  1. Validates the JWT signature and issuer (mock auth in Phase 0–8; HMCTS IdP from pre-Phase-9).
  2. Extracts the principal identity (sub, email, employee number) from JWT claims.
  3. Calls `POST /authz/check` against the NJI Authorisation service to resolve the principal's NJI roles + Region/Area scope + per-region phased activation flag (FR58). **This step diverges from the HMCTS Crime template's claims-only authorisation** — NJI's authz state lives in Authorisation, not in the IdP, so per-request lookup is required.
  4. Stores the resolved authz context in a request-scoped `AuthDetails` bean (matching HMCTS Crime template's pattern).
- Filter caches authorisation decisions for the request lifecycle (avoids duplicate calls within a single request); does not cache across requests by default. Cache TTL is a per-service tuning parameter.
- Implementation pattern (custom filter) follows HMCTS Crime template; behaviour (per-request authz lookup) is NJI-specific and required by FR58.

**Service-to-service authentication: OAuth 2.0 client_credentials flow against the OIDC issuer. (Resolves PRD TBD #3.)**

- The issuer is **mock auth (`nji-mock-auth`) in Phase 0–8** dev/CI/integration; **HMCTS IdP from pre-Phase-9** cutover onwards. The flow is identical against either issuer.
- Each NJI service is registered as a service principal in the active issuer (mock initially; HMCTS IdP after cutover).
- At startup (and on token expiry) each service obtains a service token via `client_credentials` grant.
- Service-to-service calls include `Authorization: Bearer <service-token>`.
- Receiving services validate the token signature against the issuer's public keys and resolve the calling service's authorisation through the same Authorisation service path used for human users (with service-principal-specific permissions).
- **Why this over mTLS:** piggybacks on the existing OIDC investment, keeps service identities and human identities in the same trust store, no separate certificate management, no AKS service-mesh complexity. mTLS is a fallback if HMCTS IdP cannot issue service principals at cutover.
- **Dependency:** HMCTS IdP must support client_credentials grant **before pre-Phase-9 cutover**; mock auth provides client_credentials in the meantime.

**APEX ⇄ IdP identity-key scheme: email primary, employee number fallback. (Resolves PRD TBD #7.)**

- During the Phase 0 ETL: for each active APEX user record, the migration tool attempts to match by email against HMCTS IdP principals. If no match, attempt match by employee number. If neither matches, flag for manual review. The matched/unmatched outcome travels with the row into NJI's `auth_users` (or is held back for manual handling).
- Reconciliation report (Risk #14 mitigation) produced as a Phase 0 deliverable: lists matched / employee-number-matched / unmatched records with handling decision per record.
- **Pre-Phase-9 dependency:** real-IdP reconciliation requires the HMCTS IdP principal list to be available. Confirm IdP supports principal export or query API. In Phase 0 the ETL reads APEX exports and loads via the NJI Authorisation API; the mock-auth roster mirrors this set per G5.2.

**API security strategy:**

- TLS-only on every endpoint; HTTP rejected at the ingress layer.
- Custom `JWTFilter` (per HMCTS template) on every NJI service, ordered: ① TLS / header normalisation ② JWT signature + issuer validation (`jjwt`) ③ NJI Authorisation service call (`POST /authz/check`) ④ populate request-scoped `AuthDetails` bean ⑤ business logic.
- Secret management: Azure Key Vault. Spring Cloud Azure Key Vault integration retrieves secrets at startup; refreshable via Spring Boot's actuator `/actuator/refresh` if needed.

**Encryption:**

- In transit: TLS 1.3 minimum; TLS 1.2 acceptable as fallback for legacy clients (none anticipated).
- At rest: Azure-managed encryption keys for PostgreSQL (default at Flexible Server level). Customer-managed keys (CMK) only if HMCTS security policy requires.

### API & Communication Patterns

**API style: REST-first synchronous** (locked from PRD). No event bus, no message queue, no webhook fabric.

**API versioning: URI prefix major versioning. (Resolves PRD TBD #5.)**

- Major versions in URI: `/v1/judges`, `/v2/judges`. Backwards-compatible additions stay within the major version (no new path).
- Deprecation policy:
  - Deprecated endpoints emit `Deprecation: true` and `Sunset: <RFC 1123 date>` headers per RFC 8594.
  - Minimum 6-month deprecation window before removal for internal consumers; 12 months for external consumers (DA&I, future programmes).
  - Removed only after the `Sunset` date has passed and consumers have confirmed migration.
- Per-service **`/capabilities` endpoint** — consumer-facing API-as-Product contract metadata. Distinct from Spring Actuator's operational endpoints (see Step 4 *Infrastructure & Deployment / Observability*).

  **Path:** root-path `/capabilities` (Option B), implemented as a regular `@RestController`. Rationale: API-as-Product framing makes `/capabilities` part of the consumer-facing contract surface; APIM routes `/{service}/capabilities` to consumers without exposing the broader `/actuator/*` namespace; Spring Actuator base path remains `/actuator` for ops endpoints.

  **Response shape (suggested):**

  ```json
  {
    "service": "nji-judge",
    "currentVersion": "v1",
    "supportedVersions": ["v1"],
    "deprecatedVersions": [],
    "build": {
      "version": "1.4.2",
      "commit": "a3f7b21",
      "builtAt": "2026-05-06T14:30:00Z"
    },
    "contentTypes": {
      "default": "application/json",
      "negotiated": ["application/json", "application/problem+json"]
    },
    "optionalFeatures": [],
    "deprecationPolicy": {
      "internalConsumerNoticeMonths": 6,
      "externalConsumerNoticeMonths": 12
    }
  }
  ```

  **Build metadata source:** the `build.*` fields come from `gradle-git-properties` (the same plugin that feeds `/actuator/info`). Per-service-defined fields (`supportedVersions`, `deprecatedVersions`, `optionalFeatures`) are configured in `application.yml` and exposed by the `CapabilitiesController`.

  **Versioning:** the `/capabilities` response shape is itself part of the API-as-Product contract and follows the same deprecation policy if it ever evolves.

**Rate limiting: Azure API Management (APIM) at the ingress layer. (Resolves PRD TBD #1.)**

- Default per-endpoint ceiling: 100 req/sec/principal (sensible default for bounded user population).
- MI Feed (DA&I, future programmes) gets a per-service-principal limit: 10 req/sec/principal at MVP, raise as consumers integrate.
- Burst protection: 200 req/sec/principal across all endpoints, sliding 1-second window.
- 429 responses include `Retry-After` header per RFC 6585.
- APIM policies versioned in source control alongside the service whose endpoints they protect (no cross-service APIM policies).

**Error handling: RFC 7807 problem-details** (locked from PRD).

- Each service implements its own `@ControllerAdvice` that converts domain exceptions to RFC 7807 `application/problem+json` responses.
- Standard problem `type` URIs: `https://api.nji.hmcts.gov.uk/errors/validation`, `/errors/authorisation`, `/errors/business-rule`, `/errors/dependency`, `/errors/conflict`. Each service uses these standard types; service-specific extensions allowed.
- Correlation ID echoed in problem-detail response for traceability.

**API documentation: Swagger Core + HMCTS-published API spec artefact pattern (per HMCTS Crime SpringBoot template).**

- Each NJI service's OpenAPI 3.x spec is **published as a Maven artefact** to a HMCTS-managed Maven registry — e.g. `uk.gov.hmcts.nji:api-nji-judge:{version}`. The artefact contains the OpenAPI YAML and (optionally) generated server interfaces.
- Consumers (other NJI services, the UI, external HMCTS programmes) pull in the API spec artefact at compile time for type-safe contract consumption.
- Underlying tooling: `io.swagger.core.v3:swagger-core` (matches HMCTS Crime template; `2.2.x` series at time of writing).
- Per-phase Postman collections derived from the OpenAPI spec (FR42 / NFR42).
- **Foundational principle reminder:** API spec artefacts may be shared via Maven (they are *contract*, not runtime code). Runtime code is never shared.

**Service-to-service communication:**

- REST over HTTPS, service-token authenticated.
- Service discovery via Kubernetes DNS — `http://nji-judge.{namespace}.svc.cluster.local:8080`. No service mesh, no Eureka, no Consul.
- Synchronous coordination only (no async). Workflow examples: Absence approval → Vacancy creation (POST `/v1/vacancies` per R4); Payment processing → Notification email dispatch. (Note: `Booking → Vacancy.markFilled` is *not* a service-to-service API call — it's a direct in-transaction DB UPDATE per Principle 1.)
- Retry safety: writes that may be retried (Booking creation, Payment processing) are made safe by **native DB primitives** — natural-key unique constraints (`409 Conflict` on duplicate create), JPA `@Version` optimistic locking (`412 Precondition Failed` on stale update), and PostgreSQL pessimistic row locking (`SELECT … FOR UPDATE`) on related rows. No `Idempotency-Key` HTTP header dedup at MVP; no custom dedup tables. See [`./architecture/conventions.md` → "Retry safety and concurrency control"](./architecture/conventions.md).

### Frontend Architecture

**UI framework family: React + TypeScript. (Resolves PRD TBD #2.)**

- **Rationale:** dominant choice in HMCTS internal applications; mature ecosystem; large pool of React-skilled engineers; aligns with GOV.UK Design System component libraries (`govuk-react` and similar). Predictable, conventional fit. Alternatives (Vue, Angular, Svelte) carry less HMCTS precedent and require more tooling justification.
- **React 18.x** (current stable; React 19 if GA at implementation time and HMCTS has adopted it).
- **TypeScript 5.x** for type safety, especially against generated API clients.

**Component library: GOV.UK Design System.**

- Use the official GOV.UK Design System component library for React (`govuk-react` or HMCTS-internal equivalent if available).
- This is mandatory for accessibility (WCAG 2.2 AA per NFR17) — the GOV.UK Design System is the canonical accessible pattern library for UK government services.
- HMCTS-specific extensions (where the GOV.UK Design System doesn't cover an HMCTS-internal pattern) live in NJI's UI repo, not in a shared library.

**State management:**

- **TanStack Query (formerly React Query)** for server state — handles caching, refetching, mutation, optimistic updates. Aligns naturally with NJI's REST APIs.
- **Zustand or React Context** for UI-only state (modal open/closed, form state where Hook Form isn't sufficient). Avoid Redux unless complexity demands it (it doesn't, at MVP).
- **React Hook Form** for form state management — pairs well with JSR-380 backend validation via OpenAPI-generated TypeScript client.

**Routing: React Router 6.x.**

**API client generation:**

- Per backend service, generate a TypeScript client from the service's OpenAPI 3.x spec using `openapi-typescript-codegen` (or `orval` for TanStack Query integration).
- Generated clients live in the UI repo, regenerated from updated OpenAPI specs as part of the UI's CI pipeline. **No shared client library across services or repos** — each generated client is a UI-internal artefact.

**Build tool: Vite 5.x.**

- Fast dev server, modern bundling, native TypeScript and React support.
- Builds production static SPA artefacts.

**Styling:**

- GOV.UK Design System CSS (Sass-compiled) is the foundation.
- Per-component CSS modules for component-specific styling extensions.
- No Tailwind (would clash with GOV.UK CSS conventions).

**Performance optimisation:**

- Route-based code splitting via React.lazy + Suspense.
- Vite's default tree-shaking and minification.
- Service-worker / PWA capabilities not required at MVP (per `api_backend` skip-list reasonable retention).

**Testing:**

- Vitest for unit tests (Vite-native).
- React Testing Library for component tests.
- Playwright for end-to-end tests (one E2E suite per phase, gated before rollout).
- Accessibility testing: axe-core (`@axe-core/react`) integrated into Vitest + Playwright runs.

### Infrastructure & Deployment

**Hosting: Azure Kubernetes Service (AKS), single cluster in UK South, multi-AZ node pools** (locked).

- **One production AKS cluster** in **UK South**. Node pools span **all three UK South availability zones** for HA. Pod anti-affinity (`topology.kubernetes.io/zone`) keeps each service's replicas distributed across AZs. Min 2 replicas per service; HPA tunes upward.
- **UK West for DR only** (post-MVP scope decision; G3.6) — cold-standby, manual failover playbook, *not* active/active.
- **No per-Azure-region clusters and no per-HMCTS-region clusters.** HMCTS-judicial-region rollout isolation (NFR38) is enforced at the application tier via `auth_user_activation_flags` (FR58), not at the infrastructure tier. See *Deployment topology — single Azure region, multi-AZ HA, UK West cold-DR* below.

**Database hosting: Azure Database for PostgreSQL Flexible Server**, **one global instance, zone-redundant HA in UK South** (per the Data Architecture decision above).

- **Single instance** for the entire NJI application (not per-region, not per-service).
- **Zone-redundant HA configuration** within UK South: primary node in one AZ, standby in another AZ, **synchronous replication**, automatic failover on AZ failure (typically <60 s).
- Microsoft-managed continuous backup; point-in-time restore; encryption-at-rest by default.
- Geo-redundant backup with UK West as restore target if DR is in scope (G3.6).

**UI hosting: Azure Static Web Apps** (or Azure Blob Storage + Azure CDN if Static Web Apps is operationally complex for HMCTS). Static SPA artefact built by Vite; deployed as a static site.

**Secret management: Azure Key Vault.** Each NJI service has its own Key Vault namespace; secrets mounted at startup via Spring Cloud Azure Key Vault integration.

**CI/CD: per-service Azure DevOps Pipelines or GitHub Actions** (per HMCTS standard). Each service has its own pipeline; no shared pipeline definitions across services. Pipelines emit Docker images to Azure Container Registry, then deploy via Helm to AKS.

**Environment configuration:**

- Spring Boot profiles: `dev`, `staging`, `production`.
- Per-environment configuration via Azure App Configuration (centralised key-value store) **or** per-environment `application-{profile}.yml` overrides committed to source control with secrets externalised to Key Vault. The App Configuration option is preferred for runtime tuning without redeployment; the YAML option is simpler.
- Recommendation: **Spring profiles + Key Vault for secrets** at MVP; introduce App Configuration only if runtime tuning needs justify it.

**Observability (per D7, log-based MVP; per HMCTS Crime template):**

- **Logback with Logstash JSON encoder** (`net.logstash.logback:logstash-logback-encoder`) for structured JSON logs. Async appender for performance.
- **OpenTelemetry** (`spring-boot-starter-opentelemetry`) as the observability abstraction layer. Logs and traces export to Azure Application Insights via the OpenTelemetry Collector. App Insights becomes the export target, not the direct ingestion path.
- Structured log fields: `timestamp`, `level`, `service`, `correlation-id`, `principal-id`, `event-type`, `message`, `error-category`, `error-code`.
- **Spring Boot Actuator (operational endpoints, ops-managed):** `/actuator/health` (liveness/readiness probe consumer; UP/DOWN with optional component breakdown), `/actuator/info` (build metadata: version, git commit, build date — populated via `gradle-git-properties`), `/actuator/readiness` (Kubernetes readiness probe). `/actuator/metrics` and Prometheus endpoint not exposed at MVP per D7. The `/actuator/*` namespace is ops-restricted at the ingress layer (Azure API Management policy).
- **`/capabilities` (product / contract endpoint, service-team-managed):** distinct from Actuator — answers *"what does this service's API contract currently support"* for API consumers (other NJI services, the UI, future programmes). See Step 4 *API Documentation* below for path choice and response shape. Consumer-facing; routed through APIM without ops restriction.
- OTel trace sampling probability defaults to 100% in dev / staging; tunable in production.

**Log retention: 30 days hot in Application Insights; 90 days cold via Log Analytics archive. (Resolves PRD TBD #4.)**

- Hot tier: queryable, immediate search, indexed.
- Cold tier: cheaper, slower queries, supports incident investigation post-30-days.
- Pre-GA review: HMCTS data-retention policy may require longer retention (e.g. 1 year for FOI evidence or judicial retention requirements). Decision is reversible — extend the cold tier without service redeployment.

**Historical-data access policy: read-only APEX bridge for 12 months post-region-cutover. (Resolves PRD TBD #6, partial — programme to confirm window length.)**

- When a region cuts over, that region's users retain **read-only access to APEX** for 12 months from cutover date.
- Purpose: consult historical absences, bookings, sittings, payments that pre-date cutover.
- Mechanism: APEX continues to run for the migrated region's data scope; access is gated by HMCTS IdP roles unchanged from pre-cutover.
- After 12 months: HMCTS produces a one-shot data extract for ongoing reference (Excel / CSV per consumer's needs); APEX read-only access for that region is decommissioned.
- APEX retires fully when all regions have passed their 12-month read-only window.
- **Programme decision:** the 12-month window length is recommended; programme should confirm based on operational use of historical data (audit, FOI, judicial retention).

**Scaling: Kubernetes HPA (Horizontal Pod Autoscaler) per service.**

- CPU and memory triggers; min 2 replicas per service per region for redundancy; max replicas tuned per service after capacity numbers stabilise.
- Manual review at each rollout wave to adjust HPA thresholds based on observed load.

### Deployment topology — single Azure region, multi-AZ HA, UK West cold-DR

NJI follows a **same-Azure-region multi-AZ** high-availability model — production runs in **one Azure region (UK South)** with services spread across that region's three availability zones. **UK West is reserved for disaster recovery only** (cold-standby, manual failover playbook), not active/active.

Two distinct meanings of "region" run through this architecture and the PRD; keeping them apart is essential to read the rest of this section correctly:

| Concept | What it means | How it's enforced |
|---|---|---|
| **Azure region** | Geographic Azure deployment region (UK South, UK West). Each Azure region contains multiple **availability zones** (AZs) — physically separate datacentres on independent power/network. | Infrastructure decision: production = UK South; DR = UK West (post-MVP scope decision). HA via multi-AZ within UK South. |
| **HMCTS judicial region** | NJI's per-region phased-rollout boundary — the *business* region used by D8 (e.g. Northern Region, Western Region — HMCTS jurisdictional regions). | Application-tier concern: per-user activation flag in `auth_user_activation_flags` (FR58); migrated HMCTS regions' users authenticate, non-migrated regions' users are rejected. **No infrastructure isolation per HMCTS region.** |

NFR38 ("region-isolated deployments") refers to the **HMCTS judicial region** sense — a wave activation in HMCTS Region B does not disrupt Region A's users. That isolation is enforced at the application tier (per-user activation flag, scoped queries in domain services, feature-flag-gated endpoints). It is *not* enforced by separate Azure clusters or separate DNS endpoints.

#### HA topology — multi-AZ within UK South

| Component | Multi-AZ posture |
|---|---|
| **AKS** | One production cluster in UK South with **node pools spanning all three AZs**. Pod anti-affinity (`topology.kubernetes.io/zone`) ensures each service's replicas are scheduled across zones. Min 2 replicas per service so a single-AZ failure leaves the service running on the surviving AZs. AKS control plane is Microsoft-managed and zone-redundant. |
| **PostgreSQL Flexible Server** | **Zone-redundant HA configuration** within UK South — primary node in one AZ, standby in another, **synchronous replication**, automatic failover on AZ failure (typically <60 s; promotes the standby, no client reconfiguration needed because the connection string targets the failover endpoint). Point-in-time restore retained. The single global PostgreSQL instance (per Step 4 *Data Architecture*) is therefore *not* a single-AZ point of failure within UK South — it is single-instance + zone-redundant. (G6.2 mitigation refined.) |
| **Azure Key Vault** | Microsoft-managed zone-redundancy in UK South (default for the Premium tier; verify Standard tier matches). One Key Vault per service (or per service-environment) within UK South. |
| **Application Insights / Log Analytics** | Microsoft-managed regional service in UK South — Microsoft handles AZ-level redundancy internally. One workspace shared by all NJI services for correlation-ID tracing and structured-log search. |
| **Azure API Management** | **Premium SKU with zone-redundancy enabled** in UK South for ingress (resolves PRD TBD #1 capacity sizing — Premium is needed for zone-redundancy regardless of rate-limit tier). |
| **Azure Static Web Apps (UI)** | Microsoft-managed regional service in UK South; CDN-fronted globally for static assets. Microsoft handles AZ-level resilience internally. |
| **Azure Container Registry** | Zone-redundant in UK South (Premium SKU). |
| **Azure Front Door / DNS** | Single global DNS endpoint (e.g. `nji.production.hmcts.gov.uk` — illustrative) routes to the UK South ingress. *Not* per-Azure-region, *not* per-HMCTS-region. |

A single-AZ failure within UK South is tolerated transparently for AKS (pods reschedule to the surviving zones) and for PostgreSQL (automatic failover to the standby AZ). Service-level disruption from a single-AZ event is bounded by the AKS reschedule time + PostgreSQL failover time.

#### DR topology — UK West cold-standby (post-MVP scope decision)

UK West is **not active in MVP**. Whether DR is in MVP scope is a programme decision, tracked as G3.6 in [`./architecture/gaps.md`](./architecture/gaps.md).

If DR is approved in scope:

- PostgreSQL **geo-redundant backup** with UK West as the restore target (Microsoft-managed continuous backup; RPO ≈ minutes; RTO ≈ hours).
- AKS cluster definitions held as Helm values for rapid stand-up (`values-dr-uk-west.yaml`); cluster itself is *not* pre-provisioned (cost saving) but can be brought up from infrastructure-as-code in well-defined time.
- Azure Front Door / Traffic Manager DNS failover playbook documented.
- DR activation is a **manual playbook**, not an automated active/active flip. RTO and RPO targets to be agreed with HMCTS at the point DR is approved for scope.

This is a deliberate choice over Azure-region active/active because: (a) NJI's bounded user population (~hundreds of concurrent users national) does not warrant cross-region active/active operational complexity; (b) the shared-global PostgreSQL instance (Principle 2 simplification) is incompatible with cross-region active/active without multi-master replication or a write-leader concept — both premature optimisation at MVP; (c) cross-region DR addresses the residual full-region-UK-South-unavailability risk without paying the active/active cost.

#### HMCTS-judicial-region rollout isolation — application tier only

| Concern | Mechanism |
|---|---|
| Migrated HMCTS Region B users authenticate; non-migrated HMCTS Region A users do not | `auth_user_activation_flags` per FR58; `JWTFilter` rejects non-activated users with an explicit "region not yet on NJI" error |
| One HMCTS region's wave deployment doesn't disrupt another HMCTS region | Rolling deployments are per-service across the whole AKS cluster (all HMCTS regions share infrastructure). The deployment cadence is co-ordinated with the per-wave plan; the activation flag does the per-region containment |
| Cross-HMCTS-region workflow during partial rollout | Per-wave decision per Risk #1 (brainstorming session); some workflows operable mixed-mode, some gated until both ends migrate, some fall back to manual coordination |

**Consequences of this clarification:**

- **No per-HMCTS-region AKS clusters, no per-HMCTS-region DNS, no per-HMCTS-region Key Vault, no per-HMCTS-region Helm values files.** That topology was previously implied by "per-region AKS clusters (or namespaces); region-specific DNS" wording and has been retracted (see changelog v2.0).
- **A *single* production DNS endpoint** serves all HMCTS regions: `nji.production.hmcts.gov.uk` (illustrative). The application discriminates per-user / per-HMCTS-region scope via Authorisation, not via DNS.
- **Per-service Helm values files** are now per-environment (`values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`) with an optional `values-dr-uk-west.yaml` if DR is in scope — *not* `values-production-uk-south.yaml` and `values-production-uk-west.yaml` as per the v1.x repo trees.
- **An application-tier failure in one HMCTS region does not affect other HMCTS regions** — but for a different reason than before: it doesn't because *there is no separate application tier per HMCTS region*; HMCTS regions are app-level scope, not infra-level partitions. The actual failure-isolation domain is the AZ within UK South (single-AZ failure → other AZs serve traffic).

### Decision Impact Analysis

**Implementation Sequence:**

1. **Phase 0 prerequisites** — Azure subscription + UK regions provisioned; shared global PostgreSQL Flexible Server provisioned with single shared schema and per-service DB roles (broad grants Day 1; tighten as code matures); HMCTS Crime SpringBoot template forked into NJI scaffolding script with Gradle (Groovy DSL), Flyway migration baseline, Spring profiles defaults, OpenTelemetry → Application Insights ingestion, GOV.UK Design System UI baseline. *(HMCTS IdP feature confirmation deferred to pre-Phase-9; see point 8.)*
2. **Phase 0 mock authentication** — `nji-mock-auth` deployed as a Spring Authorization Server-based service issuing OIDC tokens for a fixed roster of test users mirroring representative APEX users + roles + Region/Area scopes. Used by all subsequent phases for all authentication.
3. **Phase 0 services** — Reference Data, Authorisation, Notification — built per the HMCTS starter pattern, each with its own DB role + table set (in the shared schema), OpenAPI spec, Postman collection, Helm chart. All services configured to validate JWTs against the mock auth issuer. *(A shared `configuration_values` table is created by an `nji-architecture` Flyway baseline migration in the same shared schema; SELECT-granted to every NJI service role; no API service.)*
4. **Phase 0 Authorisation seeded** via the **Phase 0 Data Migration ETL** (`nji-architecture/migration/`) — reads APEX user-record and role-mapping dumps, transforms each row into NJI shape, reconciles each APEX user to an HMCTS IdP principal by email + employee number (TBD #7 resolved), and **loads via the Authorisation API**. Phase 0 reconciliation report produced. Mock auth users mirror this migrated set so that Authorisation testing exercises realistic data.
5. **Phase 0 API gateway** — Azure API Management deployed with default rate-limit policies (TBD #1). Configured to forward bearer tokens transparently; APIM is issuer-agnostic.
6. **Phase 0 UI shell** — Vite + React + GOV.UK Design System scaffolding deployed to Azure Static Web Apps as a stub Home / navigation shell. UI's OIDC client points at mock auth in dev/integration.
7. **Phases 1–8** — domain services per the brainstorming-session phase sequence (Judge → Absence → Vacancy → Booking → Sitting → Payment → Itinerary → MI Feed); each adds its own tables (in the shared schema, owned via Flyway DDL migrations and DB role grants), OpenAPI spec, Postman collection, UI module replicating its APEX equivalent. **No further APEX-data migration in Phases 1–8** — D3 caps data migration at Reference Data + Users/Roles only; all transactional data starts fresh on NJI per region cutover. All authentication continues to flow through mock auth.
8. **Pre-Phase-9 — Real HMCTS IdP integration cutover** — confirm G1.1, G1.2, G1.3 (HMCTS IdP supports OIDC + client_credentials + principal export). Switch staging environment's OIDC `issuer-url` from mock auth to HMCTS IdP via Spring profile change. Run reconciliation pass against real IdP principals. Re-execute the full automated test suite (unit + integration + contract) against staging with real IdP, **and re-walk the per-service manual UAT scripts (FR61 / NFR41 revised) with APEX-experienced users** before opening pilot region.
9. **Phase 9+** — per-region rollout waves on production with real HMCTS IdP. Application Insights log retention and APEX read-only bridge activated per region.

**Cross-Component Dependencies:**

- **Authorisation service** is depended upon by every other service (every request's `JWTFilter` calls it). Outage of Authorisation → outage of NJI. Mitigations: Authorisation runs with min-3 replicas; per-service `JWTFilter` caches authz decisions for the request lifetime; circuit-breaker pattern in each service's authz client (open circuit if Authorisation is down) — fail closed (deny request) for safety.
- **Reference Data tables** are read directly via SQL JOINs by every other service. No caching at MVP per Principle 2. Outage of Reference Data *service* (the API surface) does not block reads against Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables); only writes are blocked. Mitigation: PostgreSQL Flexible Server HA configuration; the DB itself is the dependency, not the service.
- **HMCTS IdP** — every authentication and every service-to-service call depends on it. IdP outage is an HMCTS-wide problem, not NJI-specific.
- **Azure API Management** — every external client request flows through it. APIM outage = NJI inaccessible to external clients. Mitigation: APIM **Premium SKU with zone-redundancy enabled** in UK South (Microsoft handles AZ-level resilience).
- **PostgreSQL (one shared global instance)** — DB outage affects every NJI service simultaneously (G6.2). Mitigation: PostgreSQL Flexible Server **zone-redundant HA configuration** within UK South — primary + standby in different AZs, synchronous replication, automatic failover (<60 s typical). Point-in-time restore. Geo-redundant backup with UK West restore target if DR is approved (G3.6). **Per-service blast radius is contained at the application tier (each service is independently deployable), and at the data tier the dominant failure mode (single-AZ failure) is tolerated transparently by the zone-redundant standby.** Full-region (UK South) loss is the residual risk, addressed by DR.

### TBDs Resolved by This Step

| # | TBD | Resolution |
|---|---|---|
| 1 | Rate limit policy | Azure API Management at ingress; 100 req/sec/principal default per endpoint; 10 req/sec/principal for MI Feed at MVP; 200 req/sec burst protection |
| 2 | UI framework family | React + TypeScript with GOV.UK Design System component library and Vite build tooling |
| 3 | Service-to-service auth | OAuth 2.0 client_credentials against HMCTS IdP; mTLS as fallback if IdP cannot issue service principals |
| 4 | Log retention | 30 days hot in Application Insights; 90 days cold in Log Analytics archive; pre-GA review against HMCTS retention policy |
| 5 | API versioning | URI prefix major versioning (`/v1/...`); 6-month internal / 12-month external deprecation windows; `Deprecation` + `Sunset` headers per RFC 8594 |
| 6 | Historical-data access | Read-only APEX bridge for 12 months post-region-cutover; one-shot extract thereafter; programme to confirm window length |
| 7 | APEX ⇄ IdP identity-key | Email primary, employee number fallback, manual review for unmatched; Phase 0 reconciliation report |

## Implementation Patterns & Consistency Rules

> **Moved to [`./architecture/conventions.md`](./architecture/conventions.md) in v1.8.** The full Step 5 catalogue (~30 conflict-point patterns) lives in the sibling.
>
> What lives there: naming patterns (database, API endpoints, Java code, TypeScript code); structure patterns (per-service Java structure, UI repo module-per-domain); format patterns (JSON `camelCase`, ISO 8601, booleans, null vs missing, pagination, response envelope, HTTP status codes); communication patterns (service-to-service clients, correlation-ID propagation, error categorisation taxonomy, native-DB retry safety via natural-key unique constraints + `@Version` + pessimistic row locking); process patterns (controller-layer error handling, UI loading states, form validation, test conventions, logging conventions, git conventions); enforcement guidelines (CI lint, ArchUnit, Spectral, Pact, JaCoCo); pattern examples and anti-patterns.
>
> What stays here in `architecture.md`: nothing from Step 5 — every pattern is enforced by code review, CI, fitness functions, and contract tests. The stub remains here so Step 5 readers know where to go.

<!-- Step-5 placeholder — actual content is in architecture/conventions.md -->

This section is the consistency contract. Every NJI service follows these patterns; consistency is enforced by code review, CI lint, contract tests, and ArchUnit fitness functions — *not* by a shared library. The full catalogue (naming / structure / format / communication / process / enforcement / examples) is in [`./architecture/conventions.md`](./architecture/conventions.md).
<!-- STEP5-DROP -->

## Project Structure & Boundaries

### Repository Strategy: Polyrepo

**Decision: 12 service repos + 1 UI repo + 1 architecture/scaffolding repo. No monorepo, no Gradle root project.**

Rationale follows directly from the Step 3 foundational principle. A monorepo would either:

- Share `build.gradle` config across services (violates no-shared-coupling), or
- Coordinate releases (violates per-region phased rollout independence), or
- Add Bazel-style hermetic build complexity that none of our requirements justify.

Polyrepo gives each service:

- Its own repo, its own pipeline, its own release cadence.
- Its own CODEOWNERS, branch protection, review policy.
- True independence — a Judge release does not even reach the Booking team's CI runner.

What stays cross-repo:

- API contracts published as OpenAPI specs.
- This architecture document and ADRs.
- The scaffolding script that generates new services from the HMCTS starter.
- The Phase 0 Data Migration ETL (`nji-architecture/migration/`) — see *Phase 0 Data Migration from APEX* under Step 4.

### Repository List

| Repo | Phase | Purpose | Key Functions |
|---|---|---|---|
| **`nji-architecture`** | 0 | Architecture index + siblings, ADRs, programme-level diagrams, scaffolding script, **Phase 0 Data Migration ETL** under `migration/`. | Maintain architecture docs and ADRs; generate new service repos from HMCTS starter via `nji-scaffold.sh`; run the APEX → NJI ETL (Reference Data + Users/Roles via NJI APIs); produce Phase 0 reconciliation reports; re-run ETL per rollout wave. |
| **`nji-mock-auth`** | 0 | OIDC issuer for dev / CI / integration. **Never deployed to production.** | Issue JWTs for a fixed test-user roster; honour OAuth 2.0 `client_credentials` for service principals; expose `/oauth2/authorize`, `/oauth2/token`, `/oauth2/jwks`, `/oauth2/userinfo`; refuse to start with `production` Spring profile (G5.3). |
| **`nji-reference-data`** | 0 | Owns the 15 Reference Data tables (regions, offices, calendar periods + 12 vocabularies). | CRUD for `regions` / `offices` / `calendar_periods`; CRUD for the 12 vocabulary tables (judge / work / court / ticket / session / absence / working-pattern types; booking / sitting / fee-payment / payment / reconciliation statuses); accept Phase 0 ETL writes; reads happen via direct SQL by other services (not via this API). |
| **`nji-authorisation`** | 0 | Owns the 5 Authorisation tables; **the per-request authz authority** for every NJI service. | Manage `auth_users`, the 12 `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`; expose `POST /authz/check` (called by every service's `JWTFilter` per request); enforce per-region phased activation (FR58); reconcile principals to HMCTS IdP by email + employee number (D9); accept Phase 0 ETL writes. |
| **`nji-notification`** | 0 | Outbound transactional email dispatch. | Send booking acknowledgement emails (FR32); send absence acknowledgement emails; send JFEPS-shaped payment-schedule emails to Payment Authorisers (FR43); record dispatch log; retry on transient failure. |
| **`nji-judge`** | 1 | Judge profile + working patterns + tickets + jurisdictional split. | CRUD judge profiles (FR10, FR11); manage working patterns and per-day breakdown (FR12); generate forward sittings from working patterns; manage judge tickets (FR15); manage jurisdictional splits with 100% sum constraint (FR16); fee-payment-status maintenance. |
| **`nji-absence`** | 2 | Absence records + approval workflow. | Create / approve / NTBF-flag / sickness-extend absences (FR19–FR22); on approval, call Vacancy service to create cover-required vacancies (R4); send acknowledgements via Notification. |
| **`nji-vacancy`** | 3 | Cover-requirement records + per-day breakdown. | Create vacancies (standalone or absence-derived, FR23, FR24); manage `vacancy_days` + cancel individual days with reason (FR25); expose vacancy state to RSU; accept `filled` / `filled_at` UPDATEs from Booking (per Principle 1, in-transaction). |
| **`nji-booking`** | 4 | Fee-paid bookings + verification. | Create / verify / cancel fee-paid bookings (FR29, FR31); within booking creation transaction, take pessimistic row lock on the target vacancy (`SELECT … FOR UPDATE`) and mark it filled via direct DB UPDATE (R5, Principle 1); natural-key unique constraint + `@Version` optimistic locking provide retry safety (no custom idempotency table); accept `payment_status` UPDATEs from Payment. |
| **`nji-sitting`** | 5 | Salaried-judge sittings + verification. | Maintain sitting records (generated from Judge working patterns; confirmed by Court); confirm and verify sittings (FR37); AM/PM session split (FR38); RFC unlock (FR40); work-type override on confirmation (FR37). |
| **`nji-payment`** | 6 | Payment processing + reconciliation. JFEPS-shaped Excel output. | Process payments (generate JFEPS-compatible Excel schedules — FR41-FR44); SQL JOIN read across confirmed bookings + sittings; dispatch schedules to Payment Authoriser via Notification (FR43); manage reconciliation lifecycle (FR46); natural-key unique constraint on `(payment_cycle_id, run_date)` + `@Version` optimistic locking provide FR45 retry safety (no custom idempotency table); **never store bank details** (NFR14). |
| **`nji-itinerary`** | 7 | Operational read model. **No own tables** — SQL JOINs across judges, absences, vacancies, bookings, sittings. | Court itinerary view; Judge itinerary view (scoped to own profile per R2); Forward Look (≤ 30 s p95 — NFR8); per-day / per-region / per-office filters; Strategy C cache pre-designed as fallback if NFR8 breaches. |
| **`nji-mi-feed`** | 8 | Aggregate management-information read model. **No own tables** — SQL JOINs across all NJI domain tables. | Standard reports (utilisation, sittings, payments) with the same parameter shape as APEX; aggregate-only contract — **no case-level data** (NFR23 / REP-BR-NFR-03); copy-to-Excel and PDF export; DA&I consumer interface (post-MVP). |
| **`nji-ui`** | 0–8 | Single SPA repo, modules per domain (per Step 5 layout). | Per-phase UI module replicating APEX functional surface (Judge / Absence / Vacancy / Booking / Sitting / Payment / Itinerary / Reports); role-scoped Home dashboard with Outstanding-Actions tiles (FR55); SSO via HMCTS IdP / mock auth; GOV.UK Design System with WCAG 2.2 AA (NFR17); module-per-domain so each phase ships UI + API end-to-end (D4). |

**14 repos total** (11 production services + UI + architecture + mock-auth). The `nji-architecture` repo holds the scaffolding script, the Phase 0 Data Migration ETL, and the Flyway baseline that creates shared infrastructure tables (e.g. `configuration_values`). `nji-mock-auth` is a development/integration-only service and never deploys to production.

**Where the Phase 0 ETL is *not* found:** it is not a Spring Boot service, not a deployed runtime, not in any per-service `db/migration/V*__*.sql` Flyway file, and not co-owned by any single domain service. It is a Phase 0 programme deliverable with named owners per Risk #13.

### Complete Project Directory Structures (per-service / UI / nji-architecture)

> **Moved to [`./architecture/repo-structure.md`](./architecture/repo-structure.md) in v1.8.**
>
> What lives there: full directory inventories for the per-service backend repo, the UI repo, and the `nji-architecture` repo (including `architecture/` siblings); plus *File Organisation Patterns* and *Development Workflow Integration* (local-dev commands, build/deploy pipeline ASCII flow).
>
> What stays here in `architecture.md`: the polyrepo decision, the repository list (above), and the architectural boundaries / data flow / integration points / region-rollout flow (below).

### Architectural Boundaries

**API Boundaries (the canonical boundary):**

- Every NJI service exposes its API at `https://api.nji.{environment}.hmcts.gov.uk/{service-name}/v1/...` (or per HMCTS DNS conventions). Routed through Azure API Management.
- Within the AKS cluster, services call each other via Kubernetes DNS: `http://nji-judge.{namespace}.svc.cluster.local:8080/v1/...`. Internal traffic is in-cluster TLS.
- External traffic is always TLS via APIM ingress; no service is reachable directly from outside the cluster.

**Service Boundaries:**

- One Spring Boot application per service.
- One container image per service.
- One Helm chart per service.
- **One shared PostgreSQL Flexible Server instance** (global) with a **single shared schema** containing all NJI tables. Table ownership encoded by table-name convention (entity-plural for primary tables; service-prefix for service-internal tables) and the team that writes the Flyway migration. Cross-service access is gated by per-service DB roles with explicit grants on tables.
- One Azure Key Vault namespace per service.
- One Application Insights resource shared by all services in a region (correlation-ID joins them).

**Data Boundaries:**

- **A service owns its tables (within the shared schema).** Each service is the only writer of its own tables (with the explicit exception of cross-service single-field updates permitted via DB role grants per Principle 1).
- **Cross-service reads via SQL JOINs** are permitted on whitelisted tables (per-service DB role grants `SELECT` on the published table list). No API roundtrip needed for simple reads.
- **Cross-service writes via direct SQL** are permitted only for whitelisted columns where the granting service has issued an explicit `UPDATE` grant. Workflows go via API.
- **FKs within the shared schema** are encouraged for database-level referential integrity (e.g. `bookings.judge_id REFERENCES judges(id)`). No cross-schema FK overhead because there is one schema.
- Reference Data is the single writer for Regions, Offices, vocabularies, and calendar; every other service reads Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables) directly via SQL. No caching at MVP per Principle 2.
- Forbidden-data invariants enforced at the schema level (no bank-detail columns, no case-level identifier columns anywhere).
- Migrated transactional history stays in APEX; NJI tables are empty at region cutover and accumulate from that point forward.

**UI Boundaries:**

- Single SPA, multiple per-domain modules.
- Each module imports its generated API client from `api-clients/{service}-client/`.
- Cross-module communication: TanStack Query cache (server state); React Context (UI state). No prop-drilling across modules.
- IdP integration in `shared/auth/`; every protected route uses `<ProtectedRoute>`.

**External System Boundaries:**

- **HMCTS IdP** — every authentication request and every service-to-service token flow.
- **JFEPS / Liberata** — outbound only, via Notification → email with JFEPS-Excel attachment to a Payment Authoriser.
- **HMCTS Email** — outbound only, transactional notifications.
- **APEX (during build + pre-rollout)** — accessed manually by APEX-experienced UAT users (RSU, Court, Judge, Clerks, Finance, MI) who open APEX side-by-side with NJI to compare behaviour per FR61 / NFR41 (revised 2026-05-06). APEX has no programmatic linkage to NJI — no test scraping, no DB reads, no CI hook.
- **APEX (during rollout window)** — read-only for migrated users for 12 months post-cutover (per Step 4 historical-data policy).
- **DA&I** — inbound only (DA&I calls MI Feed), post-MVP.

### Requirements to Structure Mapping

| Capability area (FR group) | Lives in |
|---|---|
| Identity & Authorisation (FR1–FR5) | `nji-authorisation` repo + per-service `config/JWTFilter.java`, `config/AuthDetails.java`, and `client/AuthorisationClient.java` |
| Foundational Data Management (FR6–FR9) | `nji-reference-data`, `nji-notification` repos + per-service direct JPA reads from the 15 Reference Data tables (see *Authoritative Table Ownership Mapping* in Step 4); no client class needed for Reference Data — reads-via-SQL, writes-via-API. **Configuration**: per-service via Spring profiles + Key Vault; shared `configuration_values` table (no API) for cross-service policy values, schema-managed by `nji-architecture` Flyway baseline. |
| Judge Records & Working Patterns (FR10–FR18) | `nji-judge` repo |
| Absence Workflow (FR19–FR22) | `nji-absence` repo |
| Vacancy & Cover (FR23–FR28) | `nji-vacancy` repo. Booking marks `vacancies.filled = true` (and `filled_at`) via direct DB UPDATE within Booking's transaction — Booking has UPDATE grant on those columns of `vacancies` (per Principle 1, this is a "simple cross-service write"). No `markFilled` API endpoint at MVP. |
| Booking Management (FR29–FR34) | `nji-booking` repo |
| Sitting Management (FR35–FR40) | `nji-sitting` repo |
| Payment & Reconciliation (FR41–FR47) | `nji-payment` repo (including reconciliation lifecycle) |
| Itineraries & Reporting (FR48–FR54) | `nji-itinerary` and `nji-mi-feed` repos |
| Platform Operations & Migration (FR55–FR61) | Cross-cutting: per-service implementations, supported by `nji-architecture` scaffolding script |

### Cross-Cutting Concerns to File Locations

| Concern | Per-service file location |
|---|---|
| Custom `JWTFilter` + `AuthDetails` request-scoped bean (FR2) | `src/main/java/.../config/JWTFilter.java` + `config/AuthDetails.java` (HMCTS template pattern) |
| Authorisation client called by `JWTFilter` (FR2 — NJI variance from template) | `src/main/java/.../client/AuthorisationClient.java` |
| Reference Data direct SQL access (FR7) | JPA repositories pointing at whitelisted Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables); no client class needed (read direct from DB) |
| Per-region scoping middleware | `src/main/java/.../config/RegionScopeFilter.java` |
| Per-region phased activation check (FR58) | `src/main/java/.../config/JWTFilter.java` (the AuthZ resolution path includes the activation flag) |
| Retry safety (FR45, FR30, lost-update prevention) | DB-native — `uq_*` natural-key unique constraints in `db/migration/V*__*.sql`; `@Version` integer column on every domain entity; Spring Data JPA `@Lock(PESSIMISTIC_WRITE)` on repository methods that touch related rows. No filter, no custom table, no client class. |
| RFC 7807 error handling (FR59) | `src/main/java/.../error/GlobalExceptionHandler.java` |
| `/capabilities` consumer-facing endpoint (FR59) | `src/main/java/.../controller/CapabilitiesController.java` (`@RestController` at root path `/capabilities`); build metadata from `gradle-git-properties` (same source as `/actuator/info`); per-service version/deprecation/feature fields driven by `application.yml`; **distinct from Actuator endpoints** (see *Observability* in Step 4 — Actuator is ops-managed, `/capabilities` is product/contract) |
| OpenAPI 3.x generation (FR59) | `src/main/java/.../config/OpenApiConfig.java` (Swagger Core); per-service OpenAPI spec published as a Maven artefact (`uk.gov.hmcts.nji:api-nji-{service}`) |
| Structured logging (FR60) | `src/main/resources/logback-spring.xml` + `config/CorrelationIdFilter.java` |
| Manual UAT scripts: APEX-vs-NJI behavioural-parity walkthroughs (FR61 / NFR41 revised) | `docs/uat/` per service (domain services only); not in `src/test/`. There is no automated parity harness. |
| Forbidden-data invariants (FR47, FR54) | DB schema (no relevant columns) + DTO validation in `dto/` |

### Integration Points — Internal Communication

```
              ┌───────────────────┐
              │   nji-ui (SPA)    │
              └─────────┬─────────┘
                        │ HTTPS
              ┌─────────▼─────────┐
              │ Azure API         │
              │ Management        │   ←─── rate limits applied here
              └─────────┬─────────┘
                        │
   ┌────────────────────┼────────────────────┐
   │                    │                    │
   ▼                    ▼                    ▼
┌─────────┐        ┌─────────┐         ┌──────────┐
│ Domain  │        │ Domain  │   ...   │ Read-    │
│ services│        │ services│         │ models   │
└─────┬───┘        └─────┬───┘         └────┬─────┘
      │                  │                  │
      │ HTTPS within AKS (Kubernetes DNS, service-token)
      │                  │                  │
      ▼                  ▼                  ▼
┌──────────────────────────────────────────────┐
│  Authorisation (gates every call)            │
│  Reference Data (read direct from Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables))│
│  configuration_values (shared infra table;    │
│    read-only via direct SQL; no API)         │
│  Notification (write-only, email send)       │
└──────────────────────────────────────────────┘
```

**Synchronous call patterns by frequency:**

- Every service → Authorisation API (per-request, cached for request lifetime).
- Every service → Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables) — direct SQL reads in the shared schema; no caching at MVP per Principle 2.
- Booking → `vacancies.filled` direct UPDATE (per booking creation; in-transaction; no API roundtrip per Principle 1).
- Itinerary read-model → SQL JOIN across `judges`, `absences`, `vacancies`, `bookings`, `sittings` tables in the shared schema (single query, indexed joins; no API fan-out).
- MI Feed read-model → SQL JOIN across all NJI tables in the shared schema (single aggregate query; no API fan-out, no cache fallback).

### Integration Points — External

| External system | Direction | NJI service interacting | Pattern |
|---|---|---|---|
| HMCTS IdP | inbound (AuthN) + token issuance for service-to-service | All services (token validation); Authorisation (authz mapping) | OIDC; client_credentials grant for service-to-service. **Pre-Phase-9 dependency only** — mock auth (`nji-mock-auth`) covers Phase 0–8 dev/CI/integration. |
| JFEPS / Liberata | outbound | Payment + Notification | JFEPS-Excel via email to Payment Authoriser; manual upload by authoriser |
| HMCTS email | outbound | Notification | SMTP / Microsoft Graph (per HMCTS standard) |
| Azure Application Insights | outbound (logs + traces) | All services | OpenTelemetry → OTel Collector → Application Insights as export target (per HMCTS Crime template) |
| Azure Key Vault | inbound (secrets) | All services | Spring Cloud Azure Key Vault at startup |
| APEX (manual UAT only) | n/a (no programmatic NJI integration) | UAT users from Domain services' user roles | APEX-experienced users open APEX side-by-side with NJI and compare behaviour as part of per-service manual UAT (FR61 / NFR41 revised 2026-05-06). No HTTP scraping, no DB read, no CI hook. |
| APEX (during rollout window) | inbound (read-only for migrated users) | None — APEX served separately via existing HMCTS auth | Out-of-band; not an NJI integration |
| DA&I | inbound (post-MVP) | MI Feed | REST API calls; service-token authenticated |

### Data Flow — Canonical Operational Cycle (Journey 1 from PRD)

All services share one global PostgreSQL DB (shared schema). Each service writes its own tables; cross-service simple writes go via DB role grants (per Principle 1). Workflows go via API.

```
[Court user]                    raise absence (FR19)
       │
       ▼
[Absence service] ── INSERT into absences ──→ [shared DB]
       │
       │  (RSU approves; FR21 confirmation)
       ▼
[Absence service] ──POST /v1/vacancies (R4)──→ [Vacancy service]
                                                       │
                                                       ▼
                                              INSERT into vacancies (FR23)
                                              → [shared DB]

[RSU user]                  POST /v1/bookings (with vacancyId)
       │
       ▼
[Booking service]
       │
       ├─ INSERT into bookings (FR29)
       └─ UPDATE vacancies SET filled = true, filled_at = now() WHERE id = vacancyId
          (direct DB UPDATE per Principle 1 — Booking has UPDATE grant on
           the `filled` and `filled_at` columns of `vacancies`. FR30, R5.)
       │
       ▼
[Notification service] ──POST /v1/notifications/send──> booking ack email (FR32)
       │
       ▼
[HMCTS Email] ─── delivered to fee-paid judge

(Court confirms after sitting; FR37 / FR31 → bookings.status = 'confirmed')

       │
       ▼
[RSU user]                  POST /v1/payments/process
       │
       ▼
[Payment service]
       │
       ├─ SQL JOIN over bookings + sittings (direct read; SELECT grants in place)
       ├─ generate JFEPS-Excel
       └─ INSERT into payment_schedules
       │
       ▼
[Notification service] ──→ email to Payment Authoriser (FR43)
       │
       ▼
[Payment Authoriser] ─── forwards to Liberata (out-of-system)
```

### File Organisation, Development Workflow, Deployment Pipeline

> **Moved to [`./architecture/repo-structure.md`](./architecture/repo-structure.md) in v1.8.**
>
> What lives there: configuration / test / asset organisation patterns; local-dev commands per backend service and per UI repo; full deployment-pipeline ASCII diagram (build → CI → dev → staging → production with manual UAT gate).
>
> What stays here in `architecture.md`: the *Region rollout flow (Phase 9+)* below — the per-region production gate and rollback path are architectural decisions, not pipeline configuration.

### Region rollout flow (Phase 9+)

- Per-region production deployment is gated on:
  1. All automated FR/NFR tests (unit, integration, contract, E2E) passing for the in-scope user roles.
  2. **Manual UAT signed off** — APEX-experienced users for every applicable in-region role have walked the per-service UAT scripts comparing NJI vs APEX side-by-side and signed off (FR61 / NFR41 revised 2026-05-06).
  3. Phase 0 migration verified for the region (Reference Data + Users/Roles).
  4. Programme sign-off (operational readiness, communication to migrating users).
- Rollback path: revert region's user activation flag (FR58) → users return to APEX.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**

All locked decisions work together without contradictions. The full chain holds:

- **Stack** (Java 25 + Spring Boot 4.0.6 + Gradle Groovy DSL + PostgreSQL 17 + Flyway + AKS + Azure UK regions + OpenTelemetry → Application Insights + Key Vault + APIM, per HMCTS Crime SpringBoot template) — every component is current GA, mutually compatible, and Azure-native or first-class on Azure.
- **Foundational principles** (Principle 1: API for workflows + shared DB for simple data access; Principle 2: no premature optimization; no shared runtime library) are consistent with polyrepo, per-service Spring Boot apps, per-service Helm charts, **single shared PostgreSQL DB with per-service roles + table ownership**, per-service OpenAPI specs (published as Maven artefacts), and the boilerplate-duplication pattern in Step 5.
- **REST-first synchronous (for workflows) + SQL-based read-model federation (for reads over the shared DB)** are coherent: workflows traverse APIs; read models query the shared DB directly. The no-event-bus locked decision is preserved.
- **Mock-first authentication + OIDC + client_credentials for service-to-service** — provides one consistent authentication model used by both human users and service principals across all environments. The OIDC contract is issuer-agnostic; switching from mock auth (Phase 0–8) to real HMCTS IdP (pre-Phase-9) is a configuration change. Coherent if HMCTS IdP supports OIDC + client_credentials at cutover; mTLS is the documented fallback.
- **GOV.UK Design System + WCAG 2.2 AA + axe-core** — coherent set; GDS components are built to WCAG 2.2 AA and pair naturally with axe-core automated testing.

**Pattern Consistency:**

Step 5 patterns align with Step 4 decisions:

- Database naming (`snake_case`, plural tables, `uuid` PKs, `created_at`/`updated_at`) supports the PostgreSQL choice (predictable identifiers; helpful for manual UAT verification).
- API naming (`camelCase` JSON, plural resources, `/v1/` versioning, RFC 7807 errors, ISO 8601 dates) matches the locked API-as-Product standards.
- Java package layout (`uk.gov.hmcts.nji.{service}.{layer}`) matches the per-service repo strategy.
- Communication patterns (typed clients, correlation-ID propagation, native-DB retry safety via unique constraints + `@Version` + pessimistic row locking) implement the cross-cutting concerns named in Step 2 without requiring a shared library.

**Structure Alignment:**

Step 6 project structure realises every Step 4 decision:

- Per-service repos enable per-region phased rollout and per-service deployment independence.
- Per-service Helm charts with per-environment values files (`values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`, optional `values-dr-uk-west.yaml`) and zone-redundant AKS node pools in UK South provide HA for NFR34/NFR35/NFR37. NFR38 ("region-isolated") is satisfied at the **application tier** via `auth_user_activation_flags` per FR58 (HMCTS judicial regions), not via per-region Helm values.
- Per-service Postman collections support per-phase API testing (NFR42).
- `nji-architecture` repo holds ADRs and the scaffolding script, enabling cross-team discoverability without runtime coupling.
- `nji-mock-auth` repo isolates the mock authentication service so that production deployment manifests never reference it.

No contradictions found.

### Requirements Coverage Validation ✅

**Functional Requirements Coverage** (61 FRs, 9 capability areas):

| FR group | Covered by |
|---|---|
| Identity & Authorisation (FR1–FR5) | Authorisation service + per-service custom `JWTFilter` (HMCTS template pattern) + OIDC integration (mock auth in Phase 0–8; real HMCTS IdP from pre-Phase-9) + service-token client_credentials flow |
| Foundational Data Management (FR6–FR9) | Reference Data, Configuration, Notification services + direct SQL access to Reference Data tables (15 in total — see *Authoritative Table Ownership Mapping* in Step 4: `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables) from every other service (no caching at MVP per Principle 2) |
| Judge Records & Working Patterns (FR10–FR18) | Judge service (Phase 1); working-pattern engine owned by Judge per Step 2 |
| Absence Workflow (FR19–FR22) | Absence service (Phase 2); approval workflow with auto-vacancy creation per R4 |
| Vacancy & Cover (FR23–FR28) | Vacancy service (Phase 3); Booking marks `vacancies.filled = true` via direct in-transaction DB UPDATE (per Principle 1; Booking has UPDATE grant on those columns) — no `markFilled` API endpoint at MVP |
| Booking Management (FR29–FR34) | Booking service (Phase 4); natural-key unique constraint + `@Version` + pessimistic row lock on target vacancy provide retry safety natively |
| Sitting Management (FR35–FR40) | Sitting service (Phase 5); generated from Judge working patterns; verification gates downstream edits |
| Payment & Reconciliation (FR41–FR47) | Payment service (Phase 6) with JFEPS-Excel versioned content-type via Notification |
| Itineraries & Reporting (FR48–FR54) | Itinerary + MI Feed services (Phases 7–8); SQL-based read models via JOINs over the shared schema in the global database |
| Platform Operations & Migration (FR55–FR61) | Per-service implementations (HMCTS starter scaffolding) + Phase 0 migration sequence |

**Non-Functional Requirements Coverage** (42 NFRs, 8 categories):

| NFR group | Covered by |
|---|---|
| Performance (NFR1–NFR9) | APEX-baseline page-level NFRs achievable on Java/Spring Boot stack; Forward Look NFR8 trivially achievable via indexed SQL JOINs over the shared DB; AKS HPA for capacity NFR9 |
| Security (NFR10–NFR16) | TLS 1.3 ingress; PostgreSQL encryption-at-rest; per-service custom `JWTFilter` (HMCTS template pattern) + per-service DB roles; Azure Key Vault; GFS-7 alignment via HMCTS starter security defaults |
| Accessibility (NFR17–NFR19) | GOV.UK Design System; axe-core in CI; React Hook Form for accessible form validation |
| Integration (NFR20–NFR24) | OIDC integration via mock auth (Phase 0–8) and HMCTS IdP (Phase 9+); JFEPS-Excel via email unchanged; HMCTS email; MI Feed REST contract; no eLinks integration |
| Observability (NFR25–NFR29) | Logstash JSON encoder → OpenTelemetry → Application Insights (per HMCTS Crime template); correlation-ID MDC; Spring Actuator probes; user-action audit + metrics deferred per D7 |
| Data Privacy & Sovereignty (NFR30–NFR33) | Azure UK regions only; PostgreSQL Flexible Server in UK South; case-level data forbidden by schema; FOI scope by contract |
| Reliability & Availability (NFR34–NFR38) | Operational hours availability; per-wave rollback via region activation flag (FR58); **single AKS cluster in UK South with multi-AZ node pools** (zone-redundant HA at app tier); **PostgreSQL Flexible Server zone-redundant HA** in UK South (zone-redundant DB tier); UK West cold-DR (post-MVP scope per G3.6); HMCTS-judicial-region isolation (NFR38) enforced at the application tier via FR58 activation flags |
| Maintainability (NFR39–NFR42) | API-as-Product standards (versioned, /capabilities, OpenAPI, RFC 7807); per-service deployment unit; **manual UAT scripts per domain service** (FR61 / NFR41 revised — APEX-experienced users compare NJI vs APEX side-by-side, sign-off per role per region as wave-cutover gate); Postman collections per phase |

All 61 FRs and 42 NFRs have architectural support. None unaddressed.

### Implementation Readiness Validation ✅

**Decision Completeness:**

All 7 architecture-phase TBDs from the PRD are resolved:

| # | TBD | Resolved in Step 4 |
|---|---|---|
| 1 | Rate limit policy | Azure API Management; 100 req/sec/principal default; 10 req/sec/principal MI Feed; 200 req/sec burst |
| 2 | UI framework family | React + TypeScript + GOV.UK Design System + Vite |
| 3 | Service-to-service auth | OAuth client_credentials (via mock auth Phase 0–8; HMCTS IdP from pre-Phase-9); mTLS as fallback |
| 4 | Log retention | 30 days hot in App Insights; 90 days cold in Log Analytics archive |
| 5 | API versioning | URI prefix major versioning (`/v1/`); 6-month internal / 12-month external deprecation |
| 6 | Historical-data access | Read-only APEX bridge for 12 months post-region-cutover |
| 7 | APEX ⇄ IdP identity-key | Email primary, employee number fallback, manual review for unmatched |

**Structure Completeness:**

- Complete polyrepo layout defined: 14 repos with per-repo directory trees.
- Per-service standard layout defined down to file level (controllers, services, repositories, config, error, exception, dto, client, helm, postman, api-spec, docs).
- UI repo layout defined with per-domain modules and shared utilities.
- Architecture repo layout defined for ADRs, scaffolding, and aggregated API specs.
- Mock auth repo identified as a separate development/integration-only artefact.
- Integration points mapped (internal: APIM → services → cross-cutting; external: IdP, JFEPS, email, App Insights, Key Vault, APEX, DA&I).
- Requirements-to-structure mapping table covers all 9 FR capability areas.

**Pattern Completeness:**

- Naming conventions: database, API, Java, TypeScript — all defined with examples.
- Structure conventions: per-service Java layout, per-domain UI module, file organisation across config/test/asset.
- Format conventions: JSON casing, ISO 8601, HTTP status codes, pagination, error envelope.
- Communication conventions: service-to-service client pattern, correlation-ID propagation, error categorisation taxonomy, native-DB retry safety (natural-key unique constraints + `@Version` + pessimistic row locking).
- Process conventions: error handling, loading states, form validation, test conventions, logging conventions, Git conventions.
- Enforcement mechanisms named: CI lint, ArchUnit fitness functions, Spectral OpenAPI lint, Pact contract tests, code review checklist.

### Documented Gaps

> **Moved to [`./architecture/gaps.md`](./architecture/gaps.md) in v1.8.**
>
> The authoritative gap register lives in the sibling: G1 (External Verification Dependencies — HMCTS infrastructure), G2 (Programme-Management Dependencies), G3 (HMCTS Technology Approval), G4 (Post-Completion Refinement Tasks), G5 (Mock-First Authentication Scope), G6 (Shared Database Topology Risks). Every gap is named, categorised, owned, and has a documented mitigation or fallback. **Critical gaps: none** — no gap blocks implementation.

### Assumptions

> **Moved to [`./architecture/assumptions.md`](./architecture/assumptions.md) in v1.8.**
>
> The authoritative assumption register (A1–A33) lives in the sibling. Each assumption is flagged as load-bearing, reversible, or aspirational, with the verification path (Phase 0 / pre-Phase-9 prerequisite, programme confirmation, etc.) named. Load-bearing examples: A1–A3 HMCTS IdP capabilities (Phase 9+ only); A4 HMCTS Crime template; A12 APEX accessibility for UAT panel; A23 D1–D9 PRD decisions; A28 single global PostgreSQL instance; A33 Authoritative Table Ownership Mapping correctness pending APEX SQL dump validation.

### Validation Issues Addressed

No issues were found that required resolution. The architecture is internally coherent. The gaps listed above are either:

- External dependencies (HMCTS infrastructure) that the architecture surfaces explicitly with documented fallbacks; or
- Programme-management decisions tracked separately; or
- Post-completion refinement tasks that improve quality but are not blockers; or
- Mock-auth scope items contained within Phase 0 deliverables.

### Architecture Completeness Checklist

**Requirements Analysis**

- [x] Project context thoroughly analyzed (Step 2)
- [x] Scale and complexity assessed (Step 2 — high complexity, 11 services, ~11 user roles)
- [x] Technical constraints identified (Step 2 — locked stack, locked architecture decisions, external system dependencies)
- [x] Cross-cutting concerns mapped (Step 2 — 8 functional cross-cutting concerns)

**Architectural Decisions**

- [x] Critical decisions documented with versions (Step 4 — Java 25, Spring Boot 4.0.6, PostgreSQL 17, Flyway, React 18.x, Vite 5.x, Gradle Groovy DSL per HMCTS Crime SpringBoot template)
- [x] Technology stack fully specified (Step 3 + Step 4 — backend, database, UI, infrastructure all named)
- [x] Integration patterns defined (Step 4 + Step 6 — internal via Kubernetes DNS + service tokens; external via APIM, email, IdP, App Insights)
- [x] Performance considerations addressed (Step 4 — SQL-based read models, indexed joins; HPA tuning per service; capacity numbers documented; "no premature optimization" principle applied)

**Implementation Patterns**

- [x] Naming conventions established (Step 5 — database, API, Java, TypeScript)
- [x] Structure patterns defined (Step 5 — per-service Java, per-domain UI, layered architecture)
- [x] Communication patterns specified (Step 5 — typed service clients, correlation-ID propagation, native-DB retry safety, error taxonomy)
- [x] Process patterns documented (Step 5 — error handling, loading states, form validation, test conventions, logging, Git)

**Project Structure**

- [x] Complete directory structure defined (Step 6 — per-service tree, UI tree, architecture repo tree)
- [x] Component boundaries established (Step 6 — API, service, data, UI, external)
- [x] Integration points mapped (Step 6 — internal communication diagram + external integration table)
- [x] Requirements to structure mapping complete (Step 6 — capability area → repo + cross-cutting concern → file location)

**All 16 items checked.**

### Architecture Readiness Assessment

**Overall Status:** **READY WITH DOCUMENTED GAPS**

All 16 checklist items are checked. No critical gaps block implementation. **All gaps and assumptions are documented above** in the *Documented Gaps* and *Assumptions* sections so that implementation can begin while gaps are tracked and resolved in parallel.

The mock-first authentication decision **strengthens the readiness verdict** because it materially reduces what blocks Phase 0:

- The largest cluster of external dependencies (G1.1, G1.2, G1.3 — HMCTS IdP features) **no longer blocks Phase 0**. They are reclassified as pre-Phase-9 prerequisites, giving the IdP team's roadmap and the NJI build's roadmap room to operate independently.
- Phase 0 unblockers reduce from "5 HMCTS dependencies" to "2 HMCTS dependencies" (G1.4 starter, G1.5 email).
- Risk #6 (HMCTS IdP integration timing) from the brainstorming session is materially mitigated: the IdP integration becomes a contained late-phase deliverable rather than a Phase 0 blocker.

The "with documented gaps" qualifier reflects that the architecture has external verification dependencies on HMCTS infrastructure (G1), programme-management decisions (G2), HMCTS technology approval (G3), post-completion refinement tasks (G4), and mock-first authentication scope items (G5). Each gap has either a fallback path, a named owner, or a documented schedule.

**Confidence Level:** **High** — and higher than before the mock-first decision, because the load-bearing IdP assumptions are now deferred to a phase where their failure modes have a smaller blast radius (a configuration cutover rehearsal rather than a Phase 0 redesign).

Drivers of high confidence:

- Tight alignment with the PRD's locked decisions; the architecture phase formalised those decisions and resolved the 7 architecture-phase TBDs without contradiction.
- The two foundational principles (Principle 1: API for workflows + shared DB for simple data access; Principle 2: no premature optimization) and the no-shared-library rule were articulated explicitly and applied consistently through Steps 3–6.
- The pattern definitions in Step 5 are concrete and enforceable via CI tooling (Spotless, ArchUnit, Spectral, Pact, axe-core).
- The polyrepo structure aligns with per-region phased rollout (D8) and per-service deployment independence (NFR40), which were already locked.
- Mock-first authentication eliminates IdP-team-roadmap dependency from the Phase 0–8 critical path.

**Key Strengths:**

- **Decisive simplification.** The architecture rejected three classes of complexity (event bus, shared library, monorepo) on principled grounds. Each rejection eliminates a category of operational and cognitive load.
- **Same-Azure-region multi-AZ HA + per-HMCTS-region rollout independence at the application tier.** Production runs in UK South with AKS node pools spanning all three AZs and PostgreSQL Flexible Server zone-redundant HA — single-AZ failure is tolerated transparently. HMCTS-judicial-region rollout independence (NFR38) is enforced at the application tier via `auth_user_activation_flags` per FR58, not via per-region infrastructure. UK West reserved for cold-DR (post-MVP scope per G3.6). The earlier framing of "per-region AKS clusters" conflated Azure regions and HMCTS regions; that has been retracted (changelog v2.0).
- **Explicit cross-cutting handling without inheritance.** The 8 functional cross-cutting concerns are addressed via per-service implementation patterns, eliminating the redeployment-coupling that a shared library would create.
- **API-as-Product enforcement.** Versioning, `/capabilities`, RFC 7807, OpenAPI, deprecation policy — all defined as enforceable conventions with CI tooling, not as a vague aspiration.
- **Behavioural-parity verification built into the rollout gate.** Per FR61 / NFR41 (revised 2026-05-06), every domain service ships with a manual UAT script under `docs/uat/` that APEX-experienced users walk through against APEX side-by-side; sign-off (per role per region) is the wave-cutover gate. There is no automated APEX-comparison harness in CI — automated tests are unit, integration (Testcontainers), contract, and Playwright E2E only.
- **Mock-first authentication.** Decouples the NJI build from HMCTS IdP-team roadmap and reduces Phase 0 external dependencies from 5 to 2.

**Areas for Future Enhancement (post-MVP, not blocking implementation):**

- Mermaid / C4 diagrams in `nji-architecture/diagrams/`.
- Sample ADRs capturing the brainstorming decisions in formal ADR shape.
- Sample OpenAPI snippets per service to seed the Phase 0 paper contracts.
- Service mesh adoption (Istio / Linkerd) — only if observability or mTLS demands grow beyond what Spring Security + AKS DNS provide.
- Caching (per-service in-memory, or distributed Redis) for any service whose direct-DB read-pattern post-MVP measurement shows cannot meet performance NFRs.
- App Configuration centralised runtime-tuning if config-without-redeployment becomes important.

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all architectural decisions exactly as documented in Steps 3–6.
- Use implementation patterns from Step 5 consistently across all 11 services and the UI.
- Respect the two foundational principles (Step 3): **(1) API for workflows; shared DB for simple data access**, with cross-service writes governed by per-service DB role grants on tables; **(2) No premature optimization**. No shared runtime library; boilerplate duplication is acceptable.
- Per-service work happens in the service's own repo; cross-service work happens via API contracts.
- All authentication in Phase 0–8 flows through `nji-mock-auth`; never integrate against real HMCTS IdP until pre-Phase-9 cutover.
- Refer to this document for any architectural question; raise gaps via PR against this document, not via shared-library backdoors.

**First Implementation Priority:**

1. **Confirm Phase 0 prerequisites** (Azure subscription + UK regions; HMCTS Java/Spring Boot starter availability; HMCTS Email infrastructure transport).
2. **Build the NJI scaffolding script** in `nji-architecture/scaffolding/nji-scaffold.sh`, layered on top of the HMCTS starter, with NJI conventions baked in.
3. **Scaffold and ship `nji-mock-auth`** as the first Phase 0 service. Spring Authorization Server-based; refuses to start with production profile.
4. **Scaffold and ship the three Phase 0 cross-cutting services in order:** Reference Data, Authorisation, Notification. *(Configuration is not a service — it's per-service Spring profiles + Key Vault, plus a shared `configuration_values` table created by `nji-architecture`'s Flyway baseline migration.)* **In parallel, build the Phase 0 Data Migration ETL** (`nji-architecture/migration/`) that reads APEX dumps and loads NJI Reference Data + Users/Roles via the Reference Data API and Authorisation API. The mock-auth user roster is generated from the same migration output (a sanitised subset, per G5.2).
5. **Deploy Phase 0 to dev**, exercise the API-as-Product standards (versioning, `/capabilities`, RFC 7807, OpenAPI), validate Postman collections, and run the automated test suite (unit, integration, contract). Manual APEX-vs-NJI UAT (FR61 / NFR41 revised) begins per domain service from Phase 1 onwards — Phase 0 capabilities are platform-level and have no APEX equivalent to compare against.
6. **Resolve programme-management dependencies** (pilot region selection, capacity numbers, ops hours, migration owners) before Phase 9 readiness.
7. **Begin Phase 1 (Judge service)** following the same scaffolding pattern, expanding the per-service implementation across Phases 2–8 in dependency order.
8. **Pre-Phase-9: Real HMCTS IdP integration cutover** — verify G1.1, G1.2, G1.3; configure staging issuer-url to HMCTS IdP; rehearse cutover; re-run full test suite against real IdP before opening pilot region.

## Changelog

> **Moved to [`./architecture/changelog.md`](./architecture/changelog.md) in v1.8.**
>
> The full version history (v1.0 → v1.8) lives in the sibling. The changelog file also includes a *pre-v1.8 anchor → current location* redirect table for older changelog entries that reference section anchors that moved into siblings.
>
> **Latest version:** v2.2 — Dropped the dedicated `nji-configuration` service; `configuration_values` demoted to a shared infrastructure table (no API). Per-service config now uses Spring profiles + Key Vault. **Decomposition: 12 → 11 services; repos: 15 → 14.** Same design rule as v2.1: use native platform constructs over custom services. See the sibling for the full row.
