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

`architecture.md` is the **architectural index**. Implementation-detail content (code-tree inventories, gap and assumption registers, the per-service convention catalogue, per-table inventory, sequence diagrams, changelog history) lives in sibling files under [`./architecture/`](./architecture/) and is referenced from this file in place. Read this file for the *what and why*; follow links into the siblings for the *how*.

## Contents

- [System context — at a glance](#system-context--at-a-glance)
- [How this document is structured](#how-this-document-is-structured)
- [Project Context Analysis](#project-context-analysis)
  - [Requirements Overview](#requirements-overview)
  - [Technical Constraints & Dependencies](#technical-constraints--dependencies)
  - [Cross-Cutting Concerns Identified](#cross-cutting-concerns-identified)
  - [Architecture-phase decisions still open](#architecture-phase-decisions-still-open)
- [Starter Template Evaluation](#starter-template-evaluation)
  - [Foundational Principles](#foundational-principles)
  - [Primary Technology Domain](#primary-technology-domain)
  - [Starter Options & Selection](#starter-options--selection)
  - [Initialisation Flow, Build Tool, Dependency Inventory, Per-service Conventions](#initialisation-flow-build-tool-dependency-inventory-per-service-conventions)
- [Core Architectural Decisions](#core-architectural-decisions)
  - [Decision Priority Analysis](#decision-priority-analysis)
  - [Data Architecture](#data-architecture)
  - [Authoritative Table Ownership Mapping](#authoritative-table-ownership-mapping)
  - [Authentication & Security](#authentication--security)
  - [API & Communication Patterns](#api--communication-patterns)
  - [Frontend Architecture](#frontend-architecture)
  - [Infrastructure & Deployment](#infrastructure--deployment)
  - [Deployment topology — single Azure region, multi-AZ HA, UK West cold-DR](#deployment-topology--single-azure-region-multi-az-ha-uk-west-cold-dr)
  - [Decision Impact Analysis](#decision-impact-analysis)
  - [TBDs Resolved by This Step](#tbds-resolved-by-this-step)
- [Implementation Patterns & Consistency Rules](#implementation-patterns--consistency-rules)
- [Project Structure & Boundaries](#project-structure--boundaries)
  - [Repository Strategy & List](#repository-strategy--list)
  - [Complete Project Directory Structures](#complete-project-directory-structures-per-service--ui--nji-architecture)
  - [Architectural Boundaries](#architectural-boundaries)
  - [Requirements to Structure Mapping](#requirements-to-structure-mapping)
  - [Cross-Cutting Concerns to File Locations](#cross-cutting-concerns-to-file-locations)
  - [Integration Points — Internal](#integration-points--internal-communication)
  - [Integration Points — External](#integration-points--external)
  - [Data Flow — Canonical Operational Cycle](#data-flow--canonical-operational-cycle-journey-1-from-prd)
  - [File Organisation, Development Workflow, Deployment Pipeline](#file-organisation-development-workflow-deployment-pipeline)
  - [Region rollout flow (Phase 9+)](#region-rollout-flow-phase-9)
- [Architecture Validation Results](#architecture-validation-results)
  - [Coherence Validation](#coherence-validation-)
  - [Requirements Coverage Validation](#requirements-coverage-validation-)
  - [Implementation Readiness Validation](#implementation-readiness-validation-)
  - [Documented Gaps](#documented-gaps)
  - [Assumptions](#assumptions)
  - [Architecture Readiness Assessment](#architecture-readiness-assessment)
  - [Implementation Handoff](#implementation-handoff)
- [External References](#external-references)
- [Changelog](#changelog)

## System context — at a glance

![NJI System Context — high-level service map and key interactions](./architecture/diagrams/system-context.png)

*Birds-eye view of the NJI service set, key interactions, and external integrations. For low-level detail consult the relevant section in this document or its siblings.*

## How this document is structured

| Sibling file | Contents |
|---|---|
| [`./architecture/starter-template.md`](./architecture/starter-template.md) | HMCTS Crime SpringBoot starter — initialisation flow, Gradle build tool rationale, dependency inventory, per-service NJI conventions overlaid by the scaffolding script |
| [`./architecture/data-tables.md`](./architecture/data-tables.md) | Authoritative Table Ownership Mapping — 39 NJI tables grouped by owning service |
| [`./architecture/conventions.md`](./architecture/conventions.md) | Implementation Patterns & Consistency Rules — naming, structure, format, communication, process, enforcement |
| [`./architecture/repo-structure.md`](./architecture/repo-structure.md) | Per-service / UI / `nji-architecture` directory structures, file organisation, deployment pipeline |
| [`./architecture/repository-strategy.md`](./architecture/repository-strategy.md) | Polyrepo strategy + the 14-repo list (per-service purpose and key functions) |
| [`./architecture/functional-requirements-coverage.md`](./architecture/functional-requirements-coverage.md) | All 61 FRs listed by capability area, with architectural support per group |
| [`./architecture/non-functional-requirements-coverage.md`](./architecture/non-functional-requirements-coverage.md) | All 42 NFRs listed by category, with architectural support per group |
| [`./architecture/sequence-diagrams/`](./architecture/sequence-diagrams/) | Mermaid sequence diagrams: user-initiated absence-to-reconciliation flow; scheduled payment-batch flow |
| [`./architecture/gaps.md`](./architecture/gaps.md) | Documented Gaps register — G1–G7 series with mitigations and owners |
| [`./architecture/assumptions.md`](./architecture/assumptions.md) | Assumptions register — A1–A35 with type and verification path |
| [`./architecture/changelog.md`](./architecture/changelog.md) | Version history v1.0 → v2.6 with pre-v1.8 anchor → current location redirect table |

Refactor history: the single-file `architecture.md` was split into the index + sibling structure above in v1.8 (Strategy B).

## Project Context Analysis

### Requirements Overview

**Functional Requirements (61 across 9 capability areas).** NJI's functional surface is the **11-service decomposition** locked in the brainstorming session (revised v2.2 — `nji-configuration` dropped; per-service config now lives in Spring profiles + Key Vault, with a shared `configuration_values` table for cross-service policy values), in three clusters:

- **Domain services (write surfaces)** — Judge, Absence, Vacancy, Booking, Sitting, Payment. Canonical chain: Manage Judges → Absence → Vacancy → Booking → Sitting → Payment → Reconciliation.
- **Cross-cutting services** — Reference Data (single-writer), Authorisation (gates every call), Notification (transactional email).
- **Read-model services** — Itinerary, MI Feed (SQL JOINs over the shared database).

Architectural implications:

- **Synchronous cross-service coordination at one point**: `POST /bookings` marks the linked vacancy as filled within the same transaction (FR30, R5) — direct DB UPDATE on `vacancies.filled` per Principle 1; retry safety from `SELECT … FOR UPDATE` + `uq_bookings_*` unique constraint.
- **Read-model federation** is via SQL JOINs over the shared schema. Itinerary's Forward Look NFR (≤ 30 s p95, NFR8) is trivially achievable with indexed joins. No API fan-out, no Strategy A latency stacking.
- **Working-pattern-driven sitting generation** (FR13, FR35) is owned by Judge; produces records that Sitting manages from Phase 5 onwards.
- **Versioned content-type negotiation** is first-class for Payment (FR44 — `application/vnd.hmcts.jfeps+json` vs `+xlsx`); JFEPS shape is externally owned.
- **Per-service authorisation enforcement** (FR2, NFR13) — every API call resolves principal → role + Region/Area scope through Authorisation. Cross-cutting middleware concern.

**Non-Functional Requirements (42 across 8 categories):**

- **Performance** — APEX-baseline page-level NFRs (≤ 5 s dashboard, ≤ 30 s reports/Forward Look); API NFRs tighter (≤ 500 ms p95 read, ≤ 1 s p95 write). Bounded capacity (~50–100/region; ~200–500 national).
- **Security** — TLS-only, encryption-at-rest, AuthN delegated to HMCTS IdP via SSO, AuthZ owned by JI, no bank details, no case-level data, GFS-7 alignment.
- **Accessibility** — WCAG 2.2 AA mandatory; tested per UI page per phase.
- **Integration** — OIDC issuer (mock auth Phase 0–8; HMCTS IdP from pre-Phase-9), JFEPS/Liberata unchanged, HMCTS email, DA&I MI Feed, no eLinks integration in MVP.
- **Observability** — log-based MVP only (D7); structured logging + correlation IDs; OpenTelemetry → Application Insights.
- **Data privacy & sovereignty** — Azure UK regions only; UK GDPR + DPA 2018; no case-level data.
- **Reliability** — operational availability during HMCTS hours; per-wave rollback; **single Azure region (UK South) with multi-AZ HA**; UK West cold-DR (post-MVP); HMCTS-judicial-region rollout isolation at app tier via FR58 activation flags.
- **Maintainability** — API-as-Product (versioned, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details); per-service deployment; **manual UAT scripts per domain service** (FR61 / NFR41 revised 2026-05-06); per-phase Postman collections.

**Scale & Complexity:** API backend (11 services) + first-class UI; **high complexity** driven by financial-integration criticality (JFEPS/Liberata), 11 services with cross-cutting authorisation, multi-region phased rollout, judicial regulatory environment, and behavioural-parity demand on a brownfield rebuild.

### Technical Constraints & Dependencies

**Locked from PRD:**

- **Stack:** Java 25 (LTS) + Spring Boot 4 + Kubernetes + Microsoft Azure (UK regions only).
- **Coordination:** REST-first synchronous; no event stream, no message bus, no webhook fabric.
- **Read-model strategy:** SQL JOINs over the shared schema; no API federation, no cache fallback.
- **Identity:** OIDC issuer (mock auth Phase 0–8; HMCTS IdP from pre-Phase-9 cutover); JI owns Authorisation; password/session/account lifecycle external.
- **Data residency:** Azure UK South / UK West only.
- **No bank details, no case-level data** anywhere by contract.
- **No automated eLinks/HR integration** in MVP scope.

**External system inputs (not controlled by NJI):**

- **HMCTS IdP** — pre-Phase-9 hard dependency; mock auth covers Phase 0–8.
- **JFEPS-compatible Excel format** for Payment — externally owned, treated as versioned content-type.
- **HMCTS email infrastructure** for transactional notifications.
- **DA&I MI Feed consumers** post-MVP — they call NJI APIs.
- **APEX (manual UAT only)** — APEX-experienced users compare side-by-side; no programmatic linkage to NJI's CI or runtime.

**Migration constraints (Phase 0 only):** Reference Data + Users/Roles migrate from APEX (D3 + D9). No transactional data migration. APEX ⇄ IdP identity reconciliation: every active APEX user must reconcile to an IdP principal; unmatched records require explicit handling (drop / hold / manual map).

### Cross-Cutting Concerns Identified

These functional concerns recur across most services and are addressed at the platform/architecture layer:

- **Authorisation enforcement** — every API call resolves principal → roles + Region/Area scope through Authorisation (FR2, FR3); middleware applied uniformly.
- **Reference Data is single-writer** — sole source of truth for Regions, Offices, vocabularies, calendar (FR6, FR7). Reads via direct SQL on the 15 Reference Data tables (no caching at MVP per Principle 2); writes via the Reference Data API (the seeding mechanism).
- **Per-region scoping** — domain operations default-scope by Region/Area derived from Authorisation context (FR49). Cross-region operations explicit and rare.
- **Per-region phased activation** — per D8, NJI access gated by per-region activation flag (FR58). Authorisation supports per-principal "active in NJI" state distinct from "exists in NJI."
- **Retry safety via native DB primitives** — natural-key unique constraints (`uq_*`), JPA `@Version` optimistic locking, and `SELECT … FOR UPDATE` pessimistic locks. No custom `*_idempotency_keys` tables. See [`./architecture/conventions.md` → "Retry safety and concurrency control"](./architecture/conventions.md).
- **API-as-Product compliance** — every service exposes a versioned contract, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, OpenAPI (FR59).
- **Behavioural-parity manual UAT** (FR61 / NFR41 revised) — APEX-experienced users compare NJI vs APEX side-by-side per service per region; sign-off is the wave-cutover gate. **No automated APEX-comparison harness in CI.**
- **Forbidden-data invariants** — no bank details (FR47), no case-level data (FR54). Enforced at schema definition and API boundary.

### Architecture-phase decisions still open

The PRD surfaces 12 explicit TBDs. Programme-management decisions (capacity numbers, ops hours, pilot region, cross-region wave handling, migration owners) are tracked in the PRD/brainstorming risk register, not here. The 7 architecture-phase decisions resolved during this workflow:

| # | TBD | Step where resolved |
|---|---|---|
| 1 | Rate limit policy | Step 4 (API & Communication) |
| 2 | UI framework family | Step 4 (Frontend Architecture) |
| 3 | Service-to-service authentication mechanism | Step 4 (Authentication & Security) |
| 4 | Log retention period | Step 4 (Infrastructure & Deployment) |
| 5 | API versioning specifics | Step 4 (API & Communication) |
| 6 | Historical-data access policy | Step 4 (Infrastructure & Deployment) |
| 7 | APEX ⇄ IdP identity-key scheme | Step 4 (Authentication & Security) |

## Starter Template Evaluation

### Foundational Principles

#### Principle 1: API for Workflows, Shared Database for Simple Data Access

**API is the boundary for workflow operations. The shared database is the integration mechanism for simple cross-service data access and read-model federation.**

- **Workflows go via API** — multi-step operations with business rules / state transitions / orchestration (full Booking creation, Payment processing, Absence approval).
- **Simple field-level cross-service updates can be direct DB writes** — single field changes without business-rule cascades (Booking marks `vacancies.filled = true`; Payment updates `bookings.payment_status`). Each owning service authorises which tables/columns may be written by which other services via explicit DB role grants.
- **Cross-service reads are direct SQL JOINs** — read-model federation (Itinerary, MI Feed) and Reference Data lookups go directly against the shared schema, not via API + cache.

The shared database is **one global PostgreSQL instance with a single shared schema**. Cross-service access is gated by **per-service DB roles with explicit grants**. Table ownership is encoded by a **table-name convention** (entity-plural for primary tables; service-prefix for service-internal) and enforced by ArchUnit-style fitness functions in CI.

**Why one schema, not schema-per-service:** for 11 services owned by one team in one tightly-related domain, schema-per-service is premature optimisation — paying upfront cost (11 schemas + grants + cross-schema FK overhead + per-PR coordination) for a hypothetical future. Single shared schema supports the same DB-level access control via per-service roles.

**Why per-service DB roles, not a single shared role:** per-service roles are the **forward-compatibility hook** for any future schema-per-service or service extraction (~10 minutes/role to set up Day 1; expensive to retrofit). They also give defense-in-depth (a misconfigured Sitting repository can't write to Payment's tables — DB rejects), DB-layer signal for the post-MVP user-action audit (D7), and a reversible decision (grants start broad, tighten as patterns become visible).

**There is no shared runtime code library.** Each service owns its own implementation of cross-cutting concerns, even when that means boilerplate duplication. Cost of duplication is accepted in exchange for: **changing a cross-cutting concern in one service never forces redeployment of any other service** (NFR40).

What is shared:

- **The PostgreSQL database** (one global instance, single shared schema, per-service DB roles with explicit grants).
- **API contracts** (OpenAPI specs per service, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) envelope, content-type negotiation patterns) — by specification, not runtime code.
- **API spec Maven artefacts** (`uk.gov.hmcts.nji:api-nji-{service}:{version}`) — contract, not runtime code.
- **Runtime infrastructure services** (Authorisation, Reference Data, Notification) — by API call (workflows) or direct DB read (simple lookups).
- **Scaffolding templates** (HMCTS Crime SpringBoot template) — at scaffold time, then forked.
- **CI/CD and operational conventions** (Gradle idioms, OpenTelemetry → Application Insights ingestion contract, Flyway baseline) — by convention and tooling, not library.

What is duplicated, by design: per-service custom `JWTFilter`, per-service `@ControllerAdvice` ([RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) + retry-safety status mapping), per-service structured-logging configuration. Estimated duplication: ~300–500 lines of boilerplate per service × 11 services. Mitigation: the HMCTS starter encodes most of this.

#### Principle 2: No Premature Optimization

**Performance optimisations are introduced when measurement justifies them, not by default.** Specifically:

- **No Reference Data cache** at MVP — direct SELECT from the 15 Reference Data tables.
- **No distributed cache (Redis)** at MVP.
- **No service mesh (Istio/Linkerd)** at MVP — Spring Security + AKS DNS + JWTFilter sufficient.
- **No read replicas** at MVP — single PostgreSQL instance adequate for bounded user count.
- **No async messaging** — REST-first synchronous coordination is the default.

Each tool is introduced if and only if a measurement-backed need appears.

### Primary Technology Domain

API backend (Java + Spring Boot 4) on AKS in Azure UK regions. The 11-service decomposition produces **11 independently-deployable Spring Boot services**, each scaffolded once from the HMCTS starter and thereafter owned independently. UI framework is a separate decision (Step 4 Frontend Architecture).

### Starter Options & Selection

| Option | Verdict |
|---|---|
| **HMCTS internal Java/Spring Boot starter** (`hmcts/service-hmcts-crime-springboot-template`) | ✅ **Selected.** Confirmed via review (2026-05-06). Encodes Logstash JSON logging, health checks, OpenTelemetry → App Insights, IdP integration patterns (custom `JWTFilter`), and security defaults. **Helm chart and Spring Cloud Azure Key Vault are not in the template baseline** — NJI scaffolding script adds them (G1.4a, G1.4b). |
| **Spring Initializr** | Fallback only. Same per-service-fork model; HMCTS-specific patterns added manually. |
| **JHipster** | ❌ Rejected. Heavyweight; bundles identity/frontend/database/Docker conflicting with locked decisions. |
| **Spring Cloud Microservices archetype** | ❌ Rejected. Service discovery / config server / circuit breakers — not needed under REST-first synchronous + Kubernetes. |
| **Custom NJI Platform Library** | ❌ Rejected on the no-shared-runtime-library principle. |

**Rationale for HMCTS starter:** scaffold-time inheritance, not runtime dependency — each service is forked at scaffold time and thereafter owns its own copy. Aligns with the foundational principles.

### Initialisation Flow, Build Tool, Dependency Inventory, Per-service Conventions

See [`./architecture/starter-template.md`](./architecture/starter-template.md).

## Core Architectural Decisions

### Decision Priority Analysis

**Critical (block implementation):** Database technology + table-ownership/per-service-role model · Service-to-service authentication mechanism · API versioning · UI framework · API gateway / rate-limiting layer.

**Important (shape architecture):** Migration tooling for schema changes · APEX ⇄ IdP identity-key scheme · Log retention · Historical-data access policy · HA topology (single Azure region multi-AZ in UK South; UK West DR post-MVP; HMCTS-judicial-region rollout isolation at application tier).

**Deferred (post-MVP per Principle 2):** Reference Data caching · Distributed cache (Redis) · Service mesh · Read replicas · APIM advanced features.

### Data Architecture

**Database technology: PostgreSQL on Azure Database for PostgreSQL Flexible Server, UK regions only.** Version 17 (latest GA on Flexible Server; downgrade to 16 acceptable). Rationale: relational domain, mature, lower-cost than Azure SQL, HMCTS open-source preference.

**Database topology: one global shared instance, single shared schema, per-service DB roles.**

- **One global PostgreSQL Flexible Server instance** (not per-region, not per-service); sized for the full bounded user population.
- **One logical database**, **one shared schema** (e.g. `nji`).
- **Table ownership encoded by table-name convention** (below) + **per-service DB roles with explicit grants** (below).

**Table naming and ownership convention:**

- **Primary domain tables** — entity-plural without prefix: `judges`, `absences`, `vacancies`, `bookings`, `sittings`, `payments`, `payment_schedules`, `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables.
- **Service-internal or ambiguous tables** — service-prefixed: `payment_reconciliations`, `notification_dispatches`, `auth_user_roles`.
- **Authoritative ownership table** in [`./architecture/data-tables.md`](./architecture/data-tables.md).
- **The team that writes the Flyway migration creating the table is the owning team** (encoded in code: the `V*__*.sql` lives in the owning service's repo).

**ArchUnit-style fitness functions enforce in CI:**

- No two services' migrations create overlapping tables.
- DB role grants align with the documented ownership mapping.
- Each service's role has appropriate privileges on owned tables and only explicitly-granted privileges on others.

**Cross-service access (Principle 1 applied to data layer):**

| Access pattern | Allowed | Mechanism |
|---|---|---|
| Service reads its own tables | ✅ Always | Spring Data JPA |
| Service writes its own tables | ✅ Always | Spring Data JPA |
| Service reads another service's tables | ✅ For SELECT-granted | Direct SQL JOIN; no API roundtrip |
| Service writes a single field on another service's table | ✅ For UPDATE-granted columns | Direct UPDATE in writer's transaction; pessimistic row lock recommended |
| Service performs a workflow on another service's data | ❌ Direct DB; ✅ via API | Owning service's REST endpoint |
| Service writes non-granted columns/tables | ❌ Forbidden | DB rejects |

**Foreign keys within the shared schema: allowed and encouraged** (e.g. `bookings.judge_id REFERENCES judges(id)`); no cross-schema FK overhead.

**Per-service DB roles with explicit grants** — `nji_judge`, `nji_booking`, etc. (one per service, plus `nji_mock_auth` for dev/integration). `ALL` privileges on owned tables; cross-table access granted explicitly (`GRANT SELECT ON vacancies TO nji_booking; GRANT UPDATE (filled, filled_at) ON vacancies TO nji_booking;`). Grants codified in Flyway migrations owned by the table-owning service. **Day 1 stance: start broad, tighten as code makes patterns visible.**

**Forward-compatibility framing:** per-service DB roles are the seam supporting a future schema-per-service or service-extraction *without* connection-layer code changes.

**Data modelling: Spring Data JPA + Hibernate.** Per-service entities/repositories/queries; no shared entity classes. Read-only views of another service's whitelisted tables are `@Immutable` JPA entities in the consuming service.

**Schema evolution: Flyway** (per HMCTS Crime template — `spring-boot-starter-flyway`, `flyway-core`, `flyway-database-postgresql`). Per-service `src/main/resources/db/migration/V*__*.sql`. Migrations run on application startup. **Flyway here is for NJI's own DDL only — it is *not* the mechanism for loading APEX data into NJI** (see Phase 0 ETL below).

**Phase 0 Data Migration from APEX (a separate ETL activity, distinct from Flyway):**

- **Source:** APEX SQL dumps for Reference Data and APEX user records + role/scope assignments. APEX schema is whatever it is; NJI does not own or constrain it.
- **Target:** NJI tables (regions, offices, calendar_periods, the 12 vocabulary tables, `auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`) — all designed by NJI.
- **Mechanism:** the migration tool reads APEX dumps, transforms each row into the NJI shape, and **loads via NJI service APIs** (`POST /v1/regions`, `POST /authz/users`, etc.). API is the seeding mechanism (per v1.6 decision); the migration tool is the bulk caller.
- **Mechanism is *not* Flyway data-seeding** — APEX shape ≠ NJI shape; transform lives in code; per the v1.6 decision, writes go via the API so validation/idempotency/audit hooks fire; the migration is a Phase 0 deliverable, not part of per-service schema evolution.
- **Tool location:** `nji-architecture/migration/` (CLI/script under the architecture repo). Phase 0 deliverable; retained for re-runs per rollout wave.
- **Scope:** Reference Data (D3) + active APEX users with role/Region-Area scope (D9). **No transactional data migration.**
- **Reconciliation:** every Reference Data list signed off by RSU/judicial-team owners (Risk #13); every migrated user reconciled against an IdP principal with explicit handling for unmatched (drop/hold/manual map per Risk #14).
- **APEX revalidation scope:** the migration tool's APEX-side input mapping is revalidated against the APEX SQL dump when it lands — to confirm the tool covers every APEX field NJI needs, not to reshape NJI's tables. New APEX vocabulary values gain rows via the Reference Data API. Tracked as G4.6 / A33.

**Read-model strategy: SQL JOINs across the shared schema.** Itinerary and MI Feed services execute joins across `judges`, `absences`, `vacancies`, `bookings`, `sittings`, `payments` (read-only via SELECT grants). The ≤ 30 s Forward Look NFR (NFR8) is trivially achievable with indexed joins.

**Caching strategy: none at MVP** (per Principle 2). May be added per-service post-MVP if measurement shows degradation.

**Validation strategy: JSR-380 (Bean Validation 3.0)** annotations on request DTOs and entity fields, enforced by Spring Web's `@Valid` integration.

### Authoritative Table Ownership Mapping

See [`./architecture/data-tables.md`](./architecture/data-tables.md). The fitness function operates against this inventory: every table created by Flyway must appear there with the matching owning service.

### Authentication & Security

#### Phasing of Authentication: Mock-First, Real IdP Later

NJI's pre-production phases (0–8) use a **Mock Authentication Service** for all authentication needs. Real HMCTS IdP integration is a discrete **pre-Phase-9 deliverable**, executed as a configuration cutover.

**Mock Authentication Service (`nji-mock-auth`, Phase 0 deliverable):**

- Exposes OIDC `authorization_code` flow for human users (`/oauth2/authorize`, `/oauth2/token`, `/oauth2/jwks`, `/oauth2/userinfo`).
- **Issues service tokens via OAuth `client_credentials` grant** for batch/scheduled components (initially `nji-payment-batch`) — restored v2.6 to support the payment batch, which has no upstream user context.
- Issues JWTs for a fixed roster of test users covering all 11 user roles × representative Region/Area combinations.
- Mirrors the user records seeded by Phase 0 dev/CI scripts into NJI Authorisation.
- Spring Authorization Server-based; deployed to AKS dev/integration alongside other Phase 0 services.
- **Production safeguard:** refuses to start when the `production` Spring profile is active. CI lint enforces production manifests reference the real-IdP issuer URL only.

**Use across environments:** local dev / CI / unit + integration tests = mock auth always; integration & staging start on mock then switch to real HMCTS IdP at the pre-Phase-9 cutover; production = real HMCTS IdP only.

**Why mock-first:** decouples NJI build from HMCTS IdP team's roadmap; enables full local/CI development without IdP credentials per developer; Risk #6 (HMCTS IdP integration timing) reduces from a Phase 0 blocker to a contained pre-Phase-9 prerequisite.

**Real HMCTS IdP integration (pre-Phase-9):**

- **Cutover triggers:** G1.1 (HMCTS IdP supports OIDC for human authN), G1.2 (HMCTS IdP supports OAuth `client_credentials` for batch service principals — *or* an alternative production issuer per G7.1), G1.3 (principal export/query API for migration reconciliation).
- **Cutover mechanism:** Spring profile flip — every NJI service's OIDC `issuer-url` switches from mock auth to HMCTS IdP. **No code change.**
- **Migration alignment:** user records loaded by Phase 0 ETL are keyed by email + employee number — issuer-agnostic.
- **Reconciliation pass:** before staging cutover, a verification job confirms every migrated user maps to a real IdP principal.
- **Test suite handover:** every automated suite (unit, integration with Testcontainers, contract) and per-service manual UAT must pass against real IdP in staging before Phase 9 pilot.

#### End-user Authentication

**End-user authentication: OIDC.** **End-user authorisation: NJI Authorisation service.**

Each NJI service implements its own **custom `JWTFilter`** (per HMCTS Crime template's `JWTFilter` pattern, `io.jsonwebtoken:jjwt`):

1. Validates JWT signature and issuer **by fetching the issuer's JWKS public keys** (mock auth in Phase 0–8; HMCTS IdP from pre-Phase-9). Public keys cached per the issuer's headers.
2. Extracts principal identity (sub, email, employee number) from JWT claims.
3. Calls `POST /authz/check` against NJI Authorisation to resolve roles + Region/Area scope + per-region phased activation flag (FR58). **This step diverges from the HMCTS Crime template's claims-only authorisation** — NJI's authz state lives in Authorisation, not the IdP.
4. Stores resolved authz context in a request-scoped `AuthDetails` bean.

Filter caches authorisation decisions for the request lifecycle only.

#### Inter-service Authentication — Two Patterns at MVP

*Revised v2.6 (2026-05-07; v2.5 had narrowed this to JWT propagation only — v2.6 widened it back to support the payment batch.)*

**Pattern 1 — JWT propagation** (for user-initiated cross-service calls):

- The upstream service's outbound HTTP client copies the inbound `Authorization: Bearer <user-jwt>` header to the outbound call. The downstream service's `JWTFilter` validates the same user JWT against the IdP's JWKS and resolves authz via `POST /authz/check`.
- Implementation: per-service Spring Boot 4 `RestClient` interceptor (~10 lines per service repo). See [`./architecture/conventions.md` → "JWT propagation"](./architecture/conventions.md).

**Pattern 2 — Service-principal authentication** (for batch / scheduled components without an upstream user):

- The MVP-relevant case is the **payment-processing batch** (`nji-payment-batch`) — runs on a schedule, picks up bookings ready for payment, generates the JFEPS Excel, dispatches via Notification.
- Authenticates via OAuth 2.0 `client_credentials` grant against the OIDC issuer (`nji-mock-auth` in Phase 0–8 dev/CI/integration; **production issuer per [`./architecture/gaps.md` G7.1](./architecture/gaps.md), default recommendation Azure Workload Identity**).
- Service token attached as `Authorization: Bearer <service-token>` on outbound calls. The receiving service's `JWTFilter` validates via the same JWKS path used for human user JWTs.
- Service-principal records live in `auth_users` alongside humans (with a `principal_kind` flag); `nji-authorisation` resolves their permissions the same way. Service-principal registrations live in `mock_oauth_clients` at MVP.

**Other non-runtime exceptions:** Phase 0 dev/CI seeding via one-off scripts (no runtime API call); Phase 0 production data migration via operator-initiated ETL with the operator's user JWT (MVP-acceptable; flagged for post-MVP refinement at G4.7).

**Resolves PRD TBD #3:** JWT propagation for user-initiated calls; service principals (via mock-auth in non-prod) for the payment batch; production service-auth issuer per G7.1.

#### Identity-key Scheme

**APEX ⇄ IdP identity-key scheme: email primary, employee number fallback. (Resolves PRD TBD #7.)** During the Phase 0 ETL: match by email; fallback by employee number; flag unmatched for manual review. Reconciliation report (Risk #14 mitigation) is a Phase 0 deliverable.

#### API Security Strategy

- TLS-only on every endpoint; HTTP rejected at the ingress layer.
- Custom `JWTFilter` order: ① TLS / header normalisation ② JWT signature + issuer validation ③ `POST /authz/check` ④ populate `AuthDetails` ⑤ business logic.
- Secret management: Azure Key Vault via Spring Cloud Azure Key Vault (startup-time + actuator `/actuator/refresh`).

**Encryption:** TLS 1.3 minimum (TLS 1.2 fallback acceptable); Azure-managed encryption keys for PostgreSQL by default; CMK only if HMCTS security policy requires.

### API & Communication Patterns

**API style: REST-first synchronous.** No event bus, no message queue, no webhook fabric.

**API versioning: URI prefix major versioning. (Resolves PRD TBD #5.)** `/v1/judges`, `/v2/judges`. Backwards-compatible additions stay within the major version. Deprecation signalling: `Deprecation` header per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) (date-stamp value, e.g. `Deprecation: @1735689600`) + `Sunset` header per [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) (RFC-date value); minimum 6-month internal / 12-month external window before removal.

**Build / version metadata** is exposed only via Spring Boot Actuator's `/actuator/info` endpoint (populated by `gradle-git-properties`), gated to ops at the APIM layer. NJI does **not** publish a runtime API-discovery / capabilities endpoint at MVP — there is no IETF or OpenAPI standard for one (OpenAPI's static spec document is the contract surface), and the API-as-Product standards we mandate (versioning, OpenAPI spec, RFC 9457 errors, deprecation signalling via RFC 9745 + RFC 8594) are sufficient without one.

**Rate limiting: Azure API Management at ingress. (Resolves PRD TBD #1.)** 100 req/sec/principal default; 10 req/sec/principal for MI Feed; 200 req/sec burst (sliding 1-second window). The `429 Too Many Requests` status code is per [RFC 6585](https://datatracker.ietf.org/doc/html/rfc6585); the `Retry-After` response header is per [RFC 9110 §10.2.3](https://datatracker.ietf.org/doc/html/rfc9110#section-10.2.3).

**Error handling: [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details** (formerly [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807); RFC 9457 obsoletes 7807 — `application/problem+json` content type and field shape unchanged). Per-service `@ControllerAdvice` converts domain exceptions; standard `type` URIs `/errors/validation`, `/errors/authorisation`, `/errors/business-rule`, `/errors/dependency`, `/errors/conflict`. Correlation ID echoed for traceability.

**API documentation: Swagger Core + HMCTS API spec artefact pattern.** Each NJI service's OpenAPI 3.x spec is published as a Maven artefact (`uk.gov.hmcts.nji:api-nji-{service}:{version}`); consumers pull at compile time for type-safe contract consumption. Per-phase Postman collections derived from the spec (FR42 / NFR42). API spec artefacts may be shared via Maven (they are *contract*, not runtime code).

**Service-to-service communication:** REST over HTTPS; service discovery via Kubernetes DNS (`http://nji-judge.{namespace}.svc.cluster.local:8080`); no service mesh, no Eureka/Consul. Synchronous workflows only. Retry safety via native DB primitives (unique constraints + `@Version` + `SELECT … FOR UPDATE`).

### Frontend Architecture

**UI framework: React 18.x + TypeScript 5.x. (Resolves PRD TBD #2.)** Rationale: dominant in HMCTS internal applications; mature ecosystem; aligns with GOV.UK Design System component libraries (`govuk-react`).

**Component library: GOV.UK Design System** — mandatory for accessibility (WCAG 2.2 AA per NFR17).

**State management:** TanStack Query (server state — caching, refetching, mutation, optimistic updates); Zustand or React Context (UI-only state); React Hook Form (form state, pairs with JSR-380 backend validation via OpenAPI-generated clients).

**Routing:** React Router 6.x.

**API client generation:** per backend service, generate a TypeScript client from the OpenAPI spec (`openapi-typescript-codegen` or `orval`). Generated clients live in the UI repo, regenerated as part of UI CI. **No shared client library across services or repos.**

**Build tool:** Vite 5.x.

**Styling:** GOV.UK Design System CSS (Sass-compiled) foundation; per-component CSS modules for extensions. No Tailwind.

**Testing:** Vitest (unit, Vite-native) + React Testing Library (components) + Playwright (E2E, one suite per phase) + axe-core for accessibility.

**Performance:** route-based code splitting via `React.lazy` + Suspense; Vite tree-shaking and minification. No PWA at MVP.

### Infrastructure & Deployment

**Hosting: Azure Kubernetes Service (AKS), single cluster in UK South, multi-AZ node pools.** Pod anti-affinity (`topology.kubernetes.io/zone`) keeps each service's replicas distributed across AZs. Min 2 replicas/service; HPA tunes upward. UK West reserved for DR only (post-MVP, G3.6). HMCTS-judicial-region rollout isolation enforced at app tier via FR58 activation flags, not infrastructure.

**Database hosting: Azure Database for PostgreSQL Flexible Server**, **one global instance, zone-redundant HA in UK South.** Primary in one AZ, standby in another, synchronous replication, automatic failover (<60 s typical). Microsoft-managed continuous backup; PITR; encryption-at-rest by default. Geo-redundant backup with UK West restore target if DR is in scope (G3.6).

**UI hosting:** Azure Static Web Apps (or Blob Storage + CDN if Static Web Apps is operationally complex for HMCTS).

**Secret management:** Azure Key Vault, one namespace per service; secrets mounted at startup via Spring Cloud Azure Key Vault.

**CI/CD:** per-service Azure DevOps Pipelines or GitHub Actions (HMCTS standard); each service has its own pipeline. Pipelines emit Docker images to ACR, then deploy via Helm to AKS.

**Environment configuration:** Spring profiles (`dev`, `staging`, `production`); secrets externalised to Key Vault. App Configuration only if runtime tuning without redeployment becomes important.

**Observability (D7 log-based MVP, per HMCTS Crime template):**

- **Logback with Logstash JSON encoder** for structured logs; async appender.
- **OpenTelemetry** as observability abstraction; exports to Application Insights via OTel Collector.
- Structured fields: `timestamp`, `level`, `service`, `correlation-id`, `principal-id`, `event-type`, `message`, `error-category`, `error-code`.
- **Spring Boot Actuator** (`/actuator/health`, `/actuator/info` populated from `gradle-git-properties`, `/actuator/readiness`) — `/actuator/*` namespace ops-restricted at the APIM layer. `/actuator/metrics` and Prometheus endpoint not exposed at MVP per D7.
- OTel trace sampling 100% in dev/staging; tunable in production.

**Log retention: 30 days hot in App Insights; 90 days cold in Log Analytics archive. (Resolves PRD TBD #4.)** Pre-GA review against HMCTS retention policy may extend.

**Historical-data access policy: read-only APEX bridge for 12 months post-region-cutover. (Resolves PRD TBD #6, partial.)** When a region cuts over, that region's users retain read-only APEX access for 12 months. After 12 months: HMCTS produces a one-shot extract; APEX read-only for that region is decommissioned. APEX retires fully when all regions have passed their 12-month window. 12-month window length pending programme confirmation.

**Scaling:** Kubernetes HPA per service — CPU/memory triggers, min 2 replicas/service for redundancy, max replicas tuned per service after capacity numbers stabilise.

### Deployment topology — single Azure region, multi-AZ HA, UK West cold-DR

NJI follows a **same-Azure-region multi-AZ** HA model — production in **UK South**, services across that region's three availability zones. **UK West is reserved for DR** (cold-standby, manual failover playbook), not active/active.

Two distinct meanings of "region" run through this architecture and the PRD:

| Concept | What it means | How it's enforced |
|---|---|---|
| **Azure region** | Geographic Azure deployment region (UK South, UK West). Each contains multiple **availability zones** (AZs) — physically separate datacentres on independent power/network. | Infrastructure decision: production = UK South; DR = UK West (post-MVP). HA via multi-AZ within UK South. |
| **HMCTS judicial region** | NJI's per-region phased-rollout boundary — the *business* region used by D8 (e.g. Northern, Western HMCTS jurisdictional regions). | Application-tier concern: per-user activation flag in `auth_user_activation_flags` (FR58). **No infrastructure isolation per HMCTS region.** |

NFR38 ("region-isolated deployments") refers to the **HMCTS judicial region** sense — wave activation in HMCTS Region B does not disrupt Region A's users. Enforced at the application tier, *not* by separate Azure clusters or DNS endpoints.

#### HA topology — multi-AZ within UK South

| Component | Multi-AZ posture |
|---|---|
| **AKS** | One production cluster, **node pools spanning all three AZs**. Pod anti-affinity (`topology.kubernetes.io/zone`); min 2 replicas/service. AKS control plane Microsoft-managed and zone-redundant. |
| **PostgreSQL Flexible Server** | **Zone-redundant HA** — primary + standby in different AZs, synchronous replication, automatic failover (<60 s typical). Single global instance is therefore *not* a single-AZ point of failure within UK South. (G6.2 mitigation refined.) |
| **Azure Key Vault** | Microsoft-managed zone-redundancy in UK South (Premium tier; verify Standard). One Key Vault per service (or per service-environment). |
| **Application Insights / Log Analytics** | Microsoft-managed regional service; Microsoft handles AZ-level redundancy. One workspace shared across NJI services. |
| **Azure API Management** | **Premium SKU with zone-redundancy enabled.** |
| **Azure Static Web Apps (UI)** | Microsoft-managed regional service; CDN-fronted globally. |
| **Azure Container Registry** | Zone-redundant in UK South (Premium SKU). |
| **Azure Front Door / DNS** | Single global DNS endpoint (e.g. `nji.production.hmcts.gov.uk`) routes to UK South ingress. *Not* per-Azure-region, *not* per-HMCTS-region. |

A single-AZ failure within UK South is tolerated transparently — AKS reschedules pods; PostgreSQL fails over to the standby AZ.

#### DR topology — UK West cold-standby (post-MVP scope decision, G3.6)

If approved in scope: PostgreSQL geo-redundant backup with UK West as restore target (RPO ≈ minutes; RTO ≈ hours); AKS cluster definitions held as Helm values for rapid stand-up (`values-dr-uk-west.yaml`); DNS failover playbook. **DR activation is a manual playbook**, not automated active/active. Rationale: bounded user population doesn't warrant cross-region active/active; shared global PostgreSQL is incompatible with active/active without multi-master replication (premature optimisation).

#### HMCTS-judicial-region rollout isolation — application tier only

| Concern | Mechanism |
|---|---|
| Migrated HMCTS Region B users authenticate; non-migrated Region A users do not | `auth_user_activation_flags` per FR58; `JWTFilter` rejects non-activated users |
| One HMCTS region's wave deployment doesn't disrupt another | Rolling deployments per-service across the cluster; activation flag does the per-region containment |
| Cross-HMCTS-region workflow during partial rollout | Per-wave decision per Risk #1; some workflows operable mixed-mode, some gated, some manual |

**Consequences:** no per-HMCTS-region AKS clusters, no per-HMCTS-region DNS, no per-HMCTS-region Key Vault. Per-service Helm values files are per-environment (`values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`, optional `values-dr-uk-west.yaml`).

### Decision Impact Analysis

**Implementation Sequence:**

1. **Phase 0 prerequisites** — Azure subscription + UK regions; shared global PostgreSQL Flexible Server (single shared schema, per-service DB roles); HMCTS Crime SpringBoot template forked into NJI scaffolding script. *(HMCTS IdP feature confirmation deferred to pre-Phase-9; see point 8.)*
2. **Phase 0 mock authentication** — `nji-mock-auth` deployed as Spring Authorization Server-based service. Issues OIDC tokens for human user roster; **issues service tokens via `client_credentials` for `nji-payment-batch`**.
3. **Phase 0 services** — Reference Data, Authorisation, Notification — built per HMCTS starter pattern, each with own DB role + table set, OpenAPI spec, Postman collection, Helm chart. *(A shared `configuration_values` table is created by `nji-architecture` Flyway baseline; SELECT-granted to every NJI service role.)*
4. **Dev/CI environments seeded by one-off scripts** — Reference Data + a representative user roster. *(For pilot-region production seeding, the **Phase 0 Data Migration ETL** at `nji-architecture/migration/` runs operator-initiated; flagged for post-MVP refinement at G4.7.)*
5. **Phase 0 API gateway** — Azure API Management with default rate-limit policies (TBD #1 resolution).
6. **Phase 0 UI shell** — Vite + React + GOV.UK Design System scaffolding deployed to Azure Static Web Apps.
7. **Phases 1–8** — domain services per the brainstorming sequence (Judge → Absence → Vacancy → Booking → Sitting → Payment → Itinerary → MI Feed); each adds its own tables, OpenAPI spec, Postman collection, UI module. **No further APEX-data migration in Phases 1–8** — D3 caps data migration at Reference Data + Users/Roles only.
8. **Pre-Phase-9 — Real HMCTS IdP integration cutover** — confirm G1.1, G1.2 (client_credentials for batch — re-opened v2.6), G1.3. Switch staging `issuer-url` from mock auth to HMCTS IdP via Spring profile. Run reconciliation pass. Re-execute full automated test suite + per-service manual UAT scripts before opening pilot region.
9. **Phase 9+** — per-region rollout waves on production with real HMCTS IdP. App Insights retention and APEX read-only bridge activated per region.

**Cross-Component Dependencies:**

- **Authorisation service** — every service's `JWTFilter` calls it. Outage → outage of NJI. Mitigations: min-3 replicas; per-request lifetime caching; circuit-breaker fail-closed (deny for safety).
- **Reference Data tables** — read directly via SQL JOINs by every service; no caching at MVP. Outage of Reference Data *service* (the API) does not block reads against the tables; only writes blocked. Mitigation: PostgreSQL HA.
- **HMCTS IdP** — every authentication depends on it. IdP outage is HMCTS-wide.
- **Azure API Management** — every external client request flows through it. Mitigation: Premium SKU with zone-redundancy.
- **PostgreSQL (one shared global instance)** — DB outage affects every service simultaneously (G6.2). Mitigation: zone-redundant HA + automatic failover (<60 s typical). Full UK-South-region loss is the residual risk, addressed by DR.

### TBDs Resolved by This Step

| # | TBD | Resolution |
|---|---|---|
| 1 | Rate limit policy | Azure API Management at ingress; 100 req/sec/principal default; 10 req/sec/principal for MI Feed; 200 req/sec burst |
| 2 | UI framework family | React + TypeScript + GOV.UK Design System + Vite |
| 3 | Service-to-service auth | **Two patterns at MVP**: JWT propagation (forward inbound user JWT) for user-initiated calls; OAuth `client_credentials` (via `nji-mock-auth` in non-prod; production issuer per G7.1) for the payment-processing batch service principal |
| 4 | Log retention | 30 days hot in App Insights; 90 days cold in Log Analytics archive |
| 5 | API versioning | URI prefix major versioning (`/v1/`); 6-month internal / 12-month external deprecation; `Deprecation` header per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745); `Sunset` header per [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) |
| 6 | Historical-data access | Read-only APEX bridge for 12 months post-region-cutover; one-shot extract thereafter |
| 7 | APEX ⇄ IdP identity-key | Email primary, employee number fallback, manual review for unmatched |

## Implementation Patterns & Consistency Rules

See [`./architecture/conventions.md`](./architecture/conventions.md). Every pattern is enforced by code review, CI lint, contract tests, and ArchUnit fitness functions — *not* by a shared library.

## Project Structure & Boundaries

### Repository Strategy & List

See [`./architecture/repository-strategy.md`](./architecture/repository-strategy.md).

### Complete Project Directory Structures (per-service / UI / nji-architecture)

See [`./architecture/repo-structure.md`](./architecture/repo-structure.md).

### Architectural Boundaries

**API Boundaries:** every service exposed at `https://api.nji.{environment}.hmcts.gov.uk/{service-name}/v1/...` via APIM. Within AKS, services call each other via Kubernetes DNS. External traffic always TLS via APIM ingress; no service is reachable directly from outside the cluster.

**Service Boundaries:** one Spring Boot app per service; one container image; one Helm chart; **one shared PostgreSQL Flexible Server with single shared schema**; one Azure Key Vault namespace per service; one Application Insights resource shared by all services (correlation-ID joins).

**Data Boundaries:**

- **A service owns its tables** — only writer of its own tables (with explicit cross-service single-field exceptions per Principle 1).
- **Cross-service reads via SQL JOINs** on whitelisted tables.
- **Cross-service writes via direct SQL** only for whitelisted columns (explicit `UPDATE` grants).
- **FKs within the shared schema** are encouraged.
- **Reference Data** is single-writer; every service reads directly via SQL.
- **Forbidden-data invariants** enforced at schema level (no bank-detail / case-level columns anywhere).
- Migrated transactional history stays in APEX; NJI tables are empty at region cutover.

**UI Boundaries:** single SPA, multiple per-domain modules; each module imports its generated API client; cross-module communication via TanStack Query cache + React Context.

**External System Boundaries:** HMCTS IdP (every authentication request); JFEPS / Liberata (outbound only via Notification → email); HMCTS Email (outbound only); APEX during build (manual UAT only — no programmatic linkage); APEX during rollout (read-only for migrated users for 12 months, served separately); DA&I (inbound only post-MVP).

### Requirements to Structure Mapping

| Capability area (FR group) | Lives in |
|---|---|
| Identity & Authorisation (FR1–FR5) | `nji-authorisation` repo + per-service `config/JWTFilter.java`, `config/AuthDetails.java`, `client/AuthorisationClient.java` |
| Foundational Data Management (FR6–FR9) | `nji-reference-data`, `nji-notification` repos + per-service direct JPA reads from the 15 Reference Data tables. **Configuration**: per-service Spring profiles + Key Vault; shared `configuration_values` table (no API) for cross-service policy values, schema-managed by `nji-architecture` Flyway baseline. |
| Judge Records & Working Patterns (FR10–FR18) | `nji-judge` repo |
| Absence Workflow (FR19–FR22) | `nji-absence` repo |
| Vacancy & Cover (FR23–FR28) | `nji-vacancy` repo. Booking marks `vacancies.filled = true` via direct DB UPDATE within Booking's transaction (per Principle 1). |
| Booking Management (FR29–FR34) | `nji-booking` repo |
| Sitting Management (FR35–FR40) | `nji-sitting` repo |
| Payment & Reconciliation (FR41–FR47) | `nji-payment` repo (batch component + reconciliation API) |
| Itineraries & Reporting (FR48–FR54) | `nji-itinerary` and `nji-mi-feed` repos |
| Platform Operations & Migration (FR55–FR61) | Cross-cutting: per-service implementations + `nji-architecture` scaffolding script |

### Cross-Cutting Concerns to File Locations

| Concern | Per-service file location |
|---|---|
| Custom `JWTFilter` + `AuthDetails` request-scoped bean (FR2) | `src/main/java/.../config/JWTFilter.java` + `config/AuthDetails.java` |
| Authorisation client called by `JWTFilter` (FR2 — NJI variance from template) | `src/main/java/.../client/AuthorisationClient.java` |
| Reference Data direct SQL access (FR7) | JPA repositories pointing at whitelisted Reference Data tables |
| Per-region scoping middleware | `src/main/java/.../config/RegionScopeFilter.java` |
| Per-region phased activation check (FR58) | Resolved in `JWTFilter` via authz path |
| Retry safety (FR45, FR30) | DB-native — `uq_*` unique constraints in `db/migration/V*__*.sql`; `@Version` on every domain entity; `@Lock(PESSIMISTIC_WRITE)` on repositories that touch related rows. No filter, no custom table, no client class. |
| [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details error handling (FR59) | `src/main/java/.../error/GlobalExceptionHandler.java` |
| OpenAPI 3.x generation (FR59) | `src/main/java/.../config/OpenApiConfig.java` (Swagger Core); spec published as Maven artefact (`uk.gov.hmcts.nji:api-nji-{service}`) |
| Structured logging (FR60) | `src/main/resources/logback-spring.xml` + `config/CorrelationIdFilter.java` |
| Manual UAT scripts (FR61 / NFR41 revised) | `docs/uat/` per service (domain services only); not in `src/test/` |
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
   ▼                    ▼                    ▼
┌─────────┐        ┌─────────┐         ┌──────────┐
│ Domain  │        │ Domain  │   ...   │ Read-    │
│ services│        │ services│         │ models   │
└─────┬───┘        └─────┬───┘         └────┬─────┘
      │ HTTPS within AKS (Kubernetes DNS, JWT propagation or service-token)
      ▼                  ▼                  ▼
┌──────────────────────────────────────────────┐
│  Authorisation (gates every call)            │
│  Reference Data (read direct from tables)    │
│  configuration_values (shared infra table)   │
│  Notification (write-only, email send)       │
└──────────────────────────────────────────────┘
```

**Synchronous call patterns by frequency:**

- Every service → Authorisation API (per-request, request-lifetime cache).
- Every service → Reference Data tables (direct SQL; no caching at MVP).
- Booking → `vacancies.filled` direct UPDATE (in-transaction, no API roundtrip per Principle 1).
- Itinerary read-model → SQL JOIN across `judges`, `absences`, `vacancies`, `bookings`, `sittings` (single indexed query).
- MI Feed read-model → SQL JOIN across all NJI tables (single aggregate query).

### Integration Points — External

| External system | Direction | NJI service interacting | Pattern |
|---|---|---|---|
| HMCTS IdP | inbound (human authN) | Every service's `JWTFilter` validates user JWTs via JWKS; **Authorisation** maps to NJI roles | OIDC `authorization_code` for human users; JWT signature validation via JWKS (`io.jsonwebtoken:jjwt`); cross-service calls forward the user's JWT (Pattern 1). **Pre-Phase-9 dependency only** — mock auth covers Phase 0–8; cutover is a Spring profile change. |
| HMCTS IdP / Azure Workload Identity (production issuer per G7.1) | inbound (service-principal authN for batch) | `JWTFilter` validates batch service tokens via the same JWKS path | OAuth 2.0 `client_credentials` for `nji-payment-batch`; **non-prod via `nji-mock-auth` (mock_oauth_clients)**. (Pattern 2.) |
| JFEPS / Liberata | outbound | Payment + Notification | JFEPS-Excel via email to Payment Authoriser; manual upload by authoriser |
| HMCTS email | outbound | Notification | SMTP / Microsoft Graph (HMCTS standard) |
| Azure Application Insights | outbound (logs + traces) | All services | OpenTelemetry → OTel Collector → App Insights as export target |
| Azure Key Vault | inbound (secrets) | All services | Spring Cloud Azure Key Vault at startup |
| APEX (manual UAT only) | n/a | UAT users from domain services' user roles | APEX-experienced users compare side-by-side per FR61 / NFR41. No HTTP scraping, DB read, or CI hook. |
| APEX (during rollout window) | inbound (read-only for migrated users) | None — APEX served separately | Out-of-band; not an NJI integration |
| DA&I | inbound (post-MVP) | MI Feed | REST API calls; service-token authenticated |

### Data Flow — Canonical Operational Cycle (Journey 1 from PRD)

All services share one global PostgreSQL DB (shared schema). Each service writes its own tables; cross-service simple writes go via DB role grants (Principle 1). Workflows go via API.

The end-to-end operational cycle has **two halves** — a user-initiated half (Court User and RSU driving the workflow) and a batch / external half (the payment-processing batch + Liberata). Each is documented as its own Mermaid sequence diagram.

**User-initiated half** — see [`./architecture/sequence-diagrams/absence-to-reconciliation.md`](./architecture/sequence-diagrams/absence-to-reconciliation.md)

1. **Court User** logs an absence with cover requested — `POST /v1/absences` (FR19); ack email to the judge.
2. **RSU** approves the absence — `POST /v1/absences/{id}/approve` (FR21). Approval triggers vacancy auto-creation per **R4** — `POST /v1/vacancies` (FR23).
3. **RSU** records a fee-paid booking against the vacancy — `POST /v1/bookings` (FR29). Pessimistic row lock on the vacancy + UPDATE `vacancies.filled = true` in-transaction per **R5** (FR30); ack email (FR32).
4. **Court User** confirms the sitting after the day — `POST /v1/bookings/{id}/confirm` (FR31, FR37). Booking is now confirmed and **eligible for payment** (no synchronous payment trigger — the batch picks it up).
5. **RSU** reconciles after Liberata has paid — `POST /v1/payments/{id}/reconcile` (FR46); manual at MVP, automated reconciliation feed is post-MVP.

**Batch / external half** — see [`./architecture/sequence-diagrams/payment-batch-flow.md`](./architecture/sequence-diagrams/payment-batch-flow.md)

1. **Scheduler** (Kubernetes CronJob or Spring `@Scheduled`) triggers `nji-payment-batch` on its configured cadence.
2. The batch authenticates as a service principal via OAuth `client_credentials` against `nji-mock-auth` (non-prod; production issuer per [`./architecture/gaps.md` G7.1](./architecture/gaps.md)).
3. The batch SQL-JOINs over confirmed bookings + sittings without an existing payment record, generates the JFEPS Excel, and persists `payments` + `payment_schedules` (FR41–FR45). Bookings flagged `payment_requested`.
4. The batch calls Notification (with bearer service token) to dispatch the schedule to the configured Payment Authoriser (FR43).
5. The **Payment Authoriser** uploads the schedule to JFEPS / Liberata (out-of-band).
6. **Liberata** processes the payment and pays the judge.

### File Organisation, Development Workflow, Deployment Pipeline

See [`./architecture/repo-structure.md`](./architecture/repo-structure.md).

### Region rollout flow (Phase 9+)

Per-region production deployment is gated on:

1. All automated FR/NFR tests (unit, integration, contract, E2E) passing for the in-scope user roles.
2. **Manual UAT signed off** — APEX-experienced users for every applicable in-region role have walked the per-service UAT scripts (FR61 / NFR41 revised).
3. Phase 0 migration verified for the region (Reference Data + Users/Roles).
4. Programme sign-off (operational readiness, communication to migrating users).

Rollback path: revert the region's user activation flag (FR58) → users return to APEX.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**

- **Stack** (Java 25 + Spring Boot 4.0.6 + Gradle Groovy DSL + PostgreSQL 17 + Flyway + AKS + Azure UK regions + OpenTelemetry → App Insights + Key Vault + APIM, per HMCTS Crime SpringBoot template) — every component is current GA, mutually compatible, Azure-native or first-class on Azure.
- **Foundational principles** (API for workflows + shared DB for simple data access; no premature optimisation; no shared runtime library) are consistent with polyrepo, per-service Spring Boot, per-service Helm, single shared PostgreSQL with per-service roles, per-service OpenAPI specs as Maven artefacts, and the boilerplate-duplication pattern.
- **REST-first synchronous + SQL-based read-model federation** — workflows traverse APIs; read models query the shared DB directly. No event bus.
- **Mock-first authentication + OIDC for human users; two inter-service patterns (JWT propagation + service-principal `client_credentials` for batch)** — coherent. The OIDC contract is issuer-agnostic; switching from mock auth to real HMCTS IdP is a configuration change.
- **GOV.UK Design System + WCAG 2.2 AA + axe-core** — coherent set; GDS components are built to WCAG 2.2 AA.

**Pattern Consistency:** Step 5 patterns align with Step 4 decisions — DB naming (`snake_case`, plural tables, `uuid` PKs); API naming (`camelCase` JSON, plural resources, `/v1/`, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, ISO 8601); Java package layout (`uk.gov.hmcts.nji.{service}.{layer}`); communication patterns (typed clients, correlation-ID propagation, native-DB retry safety).

**Structure Alignment:** per-service repos enable per-region phased rollout and per-service deployment independence; per-environment Helm values + zone-redundant AKS in UK South provide HA for NFR34/NFR35/NFR37; NFR38 satisfied at app tier via FR58; per-service Postman collections for NFR42; `nji-architecture` repo holds ADRs and scaffolding without runtime coupling; `nji-mock-auth` isolated so production never references it.

No contradictions found.

### Requirements Coverage Validation ✅

- **Functional Requirements Coverage (FR1–FR61)** — see [`./architecture/functional-requirements-coverage.md`](./architecture/functional-requirements-coverage.md).
- **Non-Functional Requirements Coverage (NFR1–NFR42)** — see [`./architecture/non-functional-requirements-coverage.md`](./architecture/non-functional-requirements-coverage.md).

All 61 FRs and 42 NFRs have explicit architectural support.

### Implementation Readiness Validation ✅

All 7 architecture-phase TBDs from the PRD are resolved (see *TBDs Resolved by This Step* table above).

**Structure Completeness:** complete polyrepo layout (14 repos with per-repo trees); per-service standard layout to file level; UI repo with per-domain modules; architecture repo with ADRs/scaffolding/aggregated specs; mock-auth repo isolated; integration points mapped; requirements-to-structure mapping covers all 9 FR capability areas.

**Pattern Completeness:** naming, structure, format, communication, and process conventions all defined with examples; enforcement mechanisms named (CI lint, ArchUnit, Spectral OpenAPI lint, Pact, code review checklist).

### Documented Gaps

See [`./architecture/gaps.md`](./architecture/gaps.md). Critical gaps: none — no gap blocks implementation.

### Assumptions

See [`./architecture/assumptions.md`](./architecture/assumptions.md).

### Architecture Readiness Assessment

**Overall Status:** **READY WITH DOCUMENTED GAPS**. **Confidence: High.**

All checklist items pass. No critical gaps block implementation. Mock-first authentication materially reduces what blocks Phase 0 — the largest cluster of HMCTS IdP dependencies (G1.1, G1.2, G1.3) is reclassified from Phase 0 blocker to pre-Phase-9 prerequisite. Phase 0 unblockers reduce from 5 HMCTS dependencies to 2 (G1.4 starter, G1.5 email). Risk #6 (HMCTS IdP integration timing) is materially mitigated.

**Drivers of high confidence:**

- Tight alignment with the PRD's locked decisions; the architecture phase formalised those decisions and resolved the 7 architecture-phase TBDs without contradiction.
- The two foundational principles and the no-shared-library rule were articulated explicitly and applied consistently through Steps 3–6.
- Step 5 pattern definitions are concrete and enforceable via CI tooling (Spotless, ArchUnit, Spectral, Pact, axe-core).
- Polyrepo structure aligns with per-region phased rollout (D8) and per-service deployment independence (NFR40).
- Mock-first authentication eliminates IdP-team-roadmap dependency from the Phase 0–8 critical path.

**Key Strengths:**

- **Decisive simplification** — rejected three classes of complexity (event bus, shared library, monorepo) on principled grounds.
- **Same-Azure-region multi-AZ HA + per-HMCTS-region rollout independence at the application tier** — single-AZ failure tolerated transparently; HMCTS-region rollout independence (NFR38) at app tier via FR58, not per-region infrastructure.
- **Explicit cross-cutting handling without inheritance** — addressed via per-service patterns, eliminating shared-library redeployment-coupling.
- **API-as-Product enforcement** — versioning, OpenAPI spec, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, deprecation policy ([RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) `Deprecation` + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594) `Sunset`) — all enforceable conventions with CI tooling.
- **Behavioural-parity verification built into the rollout gate** — manual UAT under `docs/uat/` per service walked by APEX-experienced users; sign-off per role per region is the wave-cutover gate.
- **Mock-first authentication** decouples the build from the HMCTS IdP roadmap.

**Areas for Future Enhancement (post-MVP, not blocking):** Mermaid / C4 diagrams in `nji-architecture/diagrams/`; sample ADRs; sample OpenAPI snippets per service; service mesh adoption (only if observability/mTLS demands grow); caching (only if measurement justifies); App Configuration centralised runtime tuning.

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all architectural decisions exactly as documented in Steps 3–6.
- Use [`./architecture/conventions.md`](./architecture/conventions.md) patterns consistently across all 11 services and the UI.
- Respect the two foundational principles: **(1) API for workflows; shared DB for simple data access**; **(2) No premature optimisation**. No shared runtime library.
- Per-service work happens in the service's own repo; cross-service work happens via API contracts.
- All authentication in Phase 0–8 flows through `nji-mock-auth` (human users via `authorization_code`; the payment batch via `client_credentials`); never integrate against real HMCTS IdP until pre-Phase-9 cutover.
- Raise gaps via PR against this document, not via shared-library backdoors.

**First Implementation Priority:**

1. **Confirm Phase 0 prerequisites** (Azure subscription + UK regions; HMCTS Java/Spring Boot starter availability; HMCTS Email infrastructure transport).
2. **Build the NJI scaffolding script** at `nji-architecture/scaffolding/nji-scaffold.sh`, layered on the HMCTS starter, with NJI conventions baked in.
3. **Scaffold and ship `nji-mock-auth`** as the first Phase 0 service. Spring Authorization Server-based; refuses to start with production profile; supports both `authorization_code` (human) and `client_credentials` (batch).
4. **Scaffold and ship the three Phase 0 cross-cutting services in order:** Reference Data, Authorisation, Notification. *(A shared `configuration_values` table is created by `nji-architecture`'s Flyway baseline migration.)* **In parallel, build the Phase 0 Data Migration ETL** (`nji-architecture/migration/`) that loads NJI Reference Data + Users/Roles via the corresponding APIs.
5. **Deploy Phase 0 to dev**, exercise the API-as-Product standards (versioning, OpenAPI spec, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details, deprecation signalling), validate Postman collections, run automated tests. Manual UAT begins per domain service from Phase 1 onwards.
6. **Resolve programme-management dependencies** before Phase 9 readiness.
7. **Begin Phase 1 (Judge service)** following the same scaffolding pattern; expand across Phases 2–8 in dependency order.
8. **Pre-Phase-9: Real HMCTS IdP integration cutover** — verify G1.1, G1.2, G1.3; configure staging issuer-url to HMCTS IdP (and resolve the production service-principal issuer per G7.1); rehearse cutover; re-run full test suite + manual UAT against real IdP before opening pilot region.

## External References

Every IETF / standards reference cited in this architecture, with a verifiable canonical link:

| Reference | Title / Subject | Link |
|---|---|---|
| RFC 9457 | Problem Details for HTTP APIs (current; obsoletes RFC 7807 — `application/problem+json` content type and field shape unchanged) | [datatracker.ietf.org/doc/html/rfc9457](https://datatracker.ietf.org/doc/html/rfc9457) |
| RFC 7807 | Problem Details for HTTP APIs (obsoleted by RFC 9457; retained for historical citations) | [datatracker.ietf.org/doc/html/rfc7807](https://datatracker.ietf.org/doc/html/rfc7807) |
| RFC 9745 | The Deprecation HTTP Response Header Field (March 2025; `Deprecation` header value is a date timestamp, e.g. `Deprecation: @1735689600`) | [datatracker.ietf.org/doc/html/rfc9745](https://datatracker.ietf.org/doc/html/rfc9745) |
| RFC 8594 | The Sunset HTTP Header Field (defines `Sunset: <RFC-date>`) | [datatracker.ietf.org/doc/html/rfc8594](https://datatracker.ietf.org/doc/html/rfc8594) |
| RFC 9110 | HTTP Semantics (defines `Retry-After` in §10.2.3; obsoletes RFC 7231) | [datatracker.ietf.org/doc/html/rfc9110](https://datatracker.ietf.org/doc/html/rfc9110) |
| RFC 6585 | Additional HTTP Status Codes (defines `429 Too Many Requests` in §4) | [datatracker.ietf.org/doc/html/rfc6585](https://datatracker.ietf.org/doc/html/rfc6585) |
| RFC 6648 | Deprecating the "X-" Prefix and Similar Constructs in Application Protocols | [datatracker.ietf.org/doc/html/rfc6648](https://datatracker.ietf.org/doc/html/rfc6648) |
| RFC 1123 | Requirements for Internet Hosts — Application and Support (the "RFC 1123 date" format used by HTTP-date / `Sunset` header) | [datatracker.ietf.org/doc/html/rfc1123](https://datatracker.ietf.org/doc/html/rfc1123) |
| OpenAPI Specification 3.1 | Standard, programming-language-agnostic interface description for HTTP APIs | [spec.openapis.org/oas/v3.1.0](https://spec.openapis.org/oas/v3.1.0.html) |
| WCAG 2.2 AA | Web Content Accessibility Guidelines 2.2, Level AA | [www.w3.org/TR/WCAG22/](https://www.w3.org/TR/WCAG22/) |

> **No IETF or OpenAPI standard defines a runtime API capabilities / discovery endpoint.** NJI does not publish a `/capabilities` endpoint. Build / version metadata is exposed only via Spring Boot Actuator `/actuator/info` (ops-restricted at the APIM layer).

## Changelog

See [`./architecture/changelog.md`](./architecture/changelog.md). **Latest:** v2.7 — `/capabilities` endpoint convention removed (no IETF/OpenAPI standard backs it); RFC citations updated to current RFCs (RFC 7807 → RFC 9457 problem-details; `Deprecation` header correctly cited to RFC 9745; `Retry-After` to RFC 9110); External References appendix added with verifiable datatracker links. Earlier: v2.6 — payment processing reframed as a scheduled batch; OAuth `client_credentials` restored for the batch service principal only; two new sequence diagrams added; FR41–FR45 reframed; A2/A26/A35 + G1.2/G7.1 reopened.
