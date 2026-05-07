---
title: NJI Architecture Summary
description: Target-state architectural reference for NJI (New Judicial Itineraries) — the *what*, not the *why* or the *how-we-got-here*.
last_updated: 2026-05-07
---

# NJI Architecture Summary

A concise, target-state architectural overview of **NJI (New Judicial Itineraries)** — HMCTS's API-driven greenfield rebuild of the Oracle APEX (OPT) Judicial Itineraries platform.

This file describes **what is built and how it runs**. For decision rationale, alternatives considered, retracted approaches, gap and assumption registers, full data-table inventory, conventions, repo structure, changelog, and step-by-step build sequence, see [`./architecture.md`](./architecture.md) and the sibling files under [`./architecture/`](./architecture/).

## System context

![NJI System Context — high-level service map and key interactions](./architecture/diagrams/system-context.png)

## Service decomposition (11 services + UI)

### Domain services

| Service | Responsibility |
|---|---|
| `nji-judge` | Judges, working patterns, tickets, jurisdictional split |
| `nji-absence` | Absence records + approval workflow; triggers vacancy creation |
| `nji-vacancy` | Cover-required vacancies; `filled` flag UPDATE-granted to Booking |
| `nji-booking` | Fee-paid bookings + verification; row-locks target vacancy in-transaction |
| `nji-sitting` | Salaried-judge sittings; verification; AM/PM split |
| `nji-payment` | Payments + reconciliation; JFEPS-shaped Excel schedule via Notification |

### Cross-cutting services

| Service | Responsibility |
|---|---|
| `nji-authorisation` | Per-request authz authority; users, roles, Region/Area scope, activation flags |
| `nji-reference-data` | Regions, offices, calendar periods, 12 vocabularies (read directly via SQL by other services; written via API) |
| `nji-notification` | Outbound transactional email (booking / absence acks; JFEPS schedule emails) |

### Read-model services

| Service | Responsibility |
|---|---|
| `nji-itinerary` | Court + Judge itinerary; Forward Look; SQL JOINs over the shared schema (no own tables) |
| `nji-mi-feed` | Aggregate reports; DA&I consumer feed (post-MVP); SQL JOINs over the shared schema (no own tables); aggregate-only — no case-level data |

### Frontend

| Component | Description |
|---|---|
| `nji-ui` | Single SPA; per-domain modules; GOV.UK Design System; WCAG 2.2 AA; HMCTS IdP SSO |

### Non-production support

| Component | Description |
|---|---|
| `nji-mock-auth` | OIDC issuer for dev / CI / integration environments only — **never deployed to production** |

## Technology stack

| Layer | Choice |
|---|---|
| Language & runtime | Java 25 (LTS) + Spring Boot 4.0.6 |
| Build | Gradle (Groovy DSL); HMCTS Crime SpringBoot template as scaffold |
| Database | PostgreSQL 17 on Azure Database for PostgreSQL Flexible Server (single global instance; single shared schema; zone-redundant HA in UK South) |
| Schema evolution | Flyway (NJI DDL only) |
| Container orchestration | Azure Kubernetes Service — single production cluster in UK South with multi-AZ node pools |
| Ingress | Azure API Management — Premium SKU, zone-redundant |
| Identity provider | HMCTS IdP via OIDC `authorization_code` (production, human users only); `nji-mock-auth` in dev / CI / integration; JWKS endpoint provides JWT-signature public keys to every NJI service |
| Service-to-service auth | **User-initiated**: JWT propagation via `RestClient` interceptor (forward inbound user JWT). **Batch / scheduled** (payment batch only at MVP): OAuth `client_credentials` against `nji-mock-auth`; production issuer per G7.1 (default recommendation: Azure Workload Identity). |
| Per-request auth | Custom `JWTFilter` (HMCTS Crime template pattern, `io.jsonwebtoken:jjwt`) — validates JWT signature against IdP JWKS, then calls `nji-authorisation` for authz |
| Secrets | Azure Key Vault (zone-redundant) |
| Observability | Logback + Logstash JSON encoder → OpenTelemetry → Azure Application Insights / Log Analytics |
| Frontend stack | React + TypeScript + Vite + GOV.UK Design System |
| Static hosting | Azure Static Web Apps |

## Data tier

- **One global PostgreSQL Flexible Server instance** in UK South; **single shared schema**; **zone-redundant HA** (primary + standby in different UK South AZs; synchronous replication; automatic <60 s failover).
- **37 tables**: 34 service-owned production + 1 shared infrastructure (`configuration_values`) + 2 dev-only (mock-auth).
- **Per-service DB roles** (`nji_judge`, `nji_booking`, `nji_payment`, …) with explicit grants. A service has `ALL` privileges on its own tables and only the specific grants it requires on others' tables.
- **Cross-service reads** — direct SQL JOIN against the shared schema using SELECT grants. No caching at MVP.
- **Cross-service simple writes** — direct UPDATE on UPDATE-granted columns within the writing service's transaction (e.g. Booking writes `vacancies.filled`).
- **Cross-service workflows** — REST API call to the owning service.
- **Read-model federation** — SQL JOIN over the shared schema, not API fan-out.

Full per-table inventory: [`./architecture/data-tables.md`](./architecture/data-tables.md).

## Authentication & Authorisation

**MVP assumption (revised v2.6):** *most* runtime requests into NJI services are user-initiated, with one documented exception — the **payment-processing batch** (`nji-payment-batch`), which runs on a schedule and authenticates as a service principal. The auth model is therefore:

1. **User authenticates at HMCTS IdP** (SSO) → IdP issues a JWT.
2. **User uses the JWT** to call the NJI UI; UI forwards the bearer token through APIM to the target NJI service.
3. **Each NJI service's `JWTFilter` validates the JWT** against HMCTS IdP's JWKS endpoint before the request reaches a controller, then resolves authz scope via `nji-authorisation`.
4. **Cross-service calls forward the user's JWT** — the upstream service copies the inbound `Authorization` header to its outbound HTTP client when calling a downstream NJI service. The downstream service's `JWTFilter` validates the same user JWT. No separate service identities are issued.

In detail:

- **End-user authentication** — HMCTS IdP via OIDC `authorization_code` flow; single sign-on; JWT issued. Mock auth (`nji-mock-auth`, Spring Authorization Server) is the OIDC issuer in non-production environments; cutover to real HMCTS IdP is a Spring profile change (issuer-url + JWKS URL flip — no code change).
- **JWT signature validation against HMCTS IdP** — every NJI service's custom `JWTFilter` (per HMCTS Crime template, `io.jsonwebtoken:jjwt` based) validates the JWT signature and issuer by fetching public keys from the IdP's **JWKS endpoint** (`/oauth2/jwks` on mock auth; HMCTS IdP's published JWKS URL in production). Validation happens **before the request reaches the service's controller** — it is the gate that enforces "user has a valid authenticated session" before any NJI API resource is exposed. Public keys are cached per the issuer's cache headers.
- **End-user authorisation** — after JWT validation, the same `JWTFilter` calls `POST /authz/check` against `nji-authorisation` to resolve role + Region/Area scope + per-region activation flag (FR58). Authorisation context lives in a request-scoped `AuthDetails` bean.
- **Inter-service authentication for user-initiated calls — JWT propagation** — the per-service Spring Boot `RestClient` interceptor copies the inbound `Authorization: Bearer <user-jwt>` header to outbound calls. Downstream service's `JWTFilter` validates the same user JWT.
- **Inter-service authentication for batch / scheduled components — OAuth `client_credentials`** — the payment batch (`nji-payment-batch`) authenticates as a service principal against `nji-mock-auth` (non-prod) using OAuth `client_credentials`, then includes the resulting service JWT as `Authorization: Bearer …` on its outbound calls (e.g. to Notification). Production service-auth issuer is a deferred decision (default recommendation: Azure Workload Identity — see `architecture/gaps.md` G7.1).
- **APEX ⇄ IdP identity reconciliation** — email primary, employee number fallback. Performed by the Phase 0 data-seeding scripts (dev/CI) and the operator-initiated production ETL.

**MVP non-user-initiated flow** (the one in scope at MVP):

- **Payment-processing batch** (`nji-payment-batch`) — runs on a schedule (cron, e.g. weekly), authenticates as a service principal, picks up confirmed bookings/sittings without payment records, generates the JFEPS Excel, and dispatches via Notification → HMCTS Email → Payment Authoriser. End-to-end sequence diagram: [`./architecture/sequence-diagrams/payment-batch-flow.md`](./architecture/sequence-diagrams/payment-batch-flow.md).

**Out of scope at MVP** (post-MVP open items):

- Other non-user-initiated runtime flows (additional scheduled jobs, async messaging, event bus) — would use the same service-principal pattern as the payment batch.
- DA&I post-MVP MI Feed integration — auth model TBD; see [`./architecture/gaps.md` G7.2](./architecture/gaps.md).
- Production data migration via the operator-initiated ETL pattern — works for MVP but flagged for post-MVP refinement (better automation, audit trail) — see [`./architecture/gaps.md` G4.7](./architecture/gaps.md).
- Production service-auth issuer — `nji-mock-auth` covers Phase 0–8; production decision deferred per G7.1 (default recommendation: Azure Workload Identity).

## API patterns

| Pattern | Detail |
|---|---|
| Coordination | REST-first synchronous; no domain event stream, no message bus, no webhook fabric |
| Versioning | URI prefix major version (`/v1/…`); 6-month internal / 12-month external deprecation windows; `Deprecation` + `Sunset` headers (RFC 8594) |
| Error envelope | RFC 7807 `application/problem+json` |
| Capabilities | `/capabilities` per service (`@RestController` at root path); product / contract metadata; **distinct from Spring Actuator** |
| OpenAPI | Generated via Swagger Core; published per-service as Maven artefacts (`uk.gov.hmcts.nji:api-nji-{service}:{version}`) |
| Pagination | Cursor-based for large or chronological lists; offset-based for small filtered lists |
| Field naming | JSON fields `camelCase`; ISO 8601 dates / instants; UTC stored, UK local for display |
| Identifiers | UUID primary keys throughout |
| Idempotency / retry safety | Natural-key unique constraints (`uq_*`) → `409 Conflict`; JPA `@Version` optimistic locking → `412 Precondition Failed`; `SELECT … FOR UPDATE` pessimistic row locking for cross-row workflows. No custom idempotency-key tables. |

## Cross-service interaction patterns

| Pattern | Mechanism |
|---|---|
| User authentication | User → HMCTS IdP (SSO) → JWT issued |
| User request | User (with JWT) → `nji-ui` → APIM (rate limits, routing) → service |
| Per-request JWT validation | Each NJI service's `JWTFilter` validates the inbound JWT signature against **HMCTS IdP's JWKS endpoint** before any controller is invoked |
| Cross-service call (within a user request) | Upstream service's outbound `RestClient` interceptor copies the inbound `Authorization: Bearer <user-jwt>` header to the downstream call; downstream service's `JWTFilter` validates the same user JWT (token propagation / forwarding pattern). No separate service identity. |
| Batch / scheduled flow (no user context) | Batch component (e.g. `nji-payment-batch`) authenticates as a service principal via OAuth `client_credentials` against the OIDC issuer (`nji-mock-auth` non-prod); attaches the resulting service JWT to outbound calls (Notification, etc.); receiving services validate via the same JWKS path. **MVP scope: payment batch only.** |
| Per-request authz | After JWT validation, the same `JWTFilter` calls `POST /authz/check` against `nji-authorisation` |
| Reference Data reads | Direct SQL (per-service `SELECT` grant); no API call |
| Reference Data writes | Via `nji-reference-data` API (admin / Phase 0 seeding) |
| Cross-service workflow | REST call to the owning service |
| Cross-row workflow safety | `SELECT … FOR UPDATE` on the related row + natural-key unique constraint on the new row |
| Read-model federation | SQL JOIN over the shared schema (no API fan-out) |
| Outbound email | Domain service → `nji-notification` → HMCTS Email → recipient (or, for Payment, → JFEPS via authoriser upload) |
| Configuration | Per-service: Spring profiles + `application.yml` + Azure Key Vault. Cross-service policy values: shared `configuration_values` infrastructure table (read-only via direct SQL; no API). |

## Deployment topology

- **Production region** — Azure UK South.
- **HA** — multi-AZ within UK South for every component:
  - AKS node pools span all three UK South AZs with pod anti-affinity (zone topology spread).
  - PostgreSQL Flexible Server zone-redundant HA (synchronous replication; automatic failover).
  - APIM Premium, Key Vault, Azure Container Registry — all zone-redundant.
- **DR** — UK West reserved for cold-standby disaster recovery; manual failover playbook.
- **Per-service unit** — independently-deployable Spring Boot service; per-service Helm chart with per-environment values files (`values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`, optional `values-dr-uk-west.yaml`).
- **CI/CD** — per-service pipeline (Azure DevOps Pipelines or GitHub Actions). Build → Docker image → Azure Container Registry → Helm upgrade to AKS.
- **Logging** — structured JSON logs (Logstash encoder) with correlation IDs; OpenTelemetry export to Application Insights; 30 days hot in App Insights + 90 days cold in Log Analytics archive.

## Phased rollout

- **Boundary** — per HMCTS judicial region (Northern, Western, etc.), with all applicable user roles in that region migrating together.
- **Mechanism** — per-user activation flag in `auth_user_activation_flags` (FR58). Migrated regions' users authenticate; non-migrated regions' users are rejected at the `JWTFilter` boundary. Flag flip activates a region; flag flip-off rolls back.
- **Wave gates** — automated tests passing (unit, integration with Testcontainers PostgreSQL, contract); manual UAT signed off by APEX-experienced users; per-region migration verified; programme sign-off.
- **Build sequence** — Phase 0 cross-cutting services + UI shell + Phase 0 Data Migration ETL; Phases 1–6 domain services in dependency order (Judge → Absence → Vacancy → Booking → Sitting → Payment); Phases 7–8 read-models (Itinerary, MI Feed); Pre-Phase-9 real-IdP cutover; Phase 9+ per-region rollout waves.

## Phase 0 Data Migration ETL

A standalone programme deliverable, **not a runtime service**:

- Lives at `nji-architecture/migration/`.
- Reads APEX SQL dumps; transforms each row into NJI's (independently-designed) shape; loads into NJI via the Reference Data API and the Authorisation API.
- Migrates **only Reference Data and active user records + role / Region-Area scope mappings**. No transactional data migration.
- Re-runs per rollout wave for incremental user activation.
- APEX schema is the data source; NJI's schema is fixed by NJI design.

## External integrations

| System | Direction | Purpose |
|---|---|---|
| HMCTS IdP | inbound (human authN only) + JWKS used by NJI services for JWT signature validation | OIDC `authorization_code` flow for human users; every NJI service's `JWTFilter` validates inbound user JWTs against IdP JWKS before allowing access to NJI APIs. **Service-principal token issuance** for the payment batch is handled by `nji-mock-auth` in non-prod; production decision per G7.1. |
| HMCTS Email | outbound | Booking / absence acknowledgements; JFEPS payment schedules |
| JFEPS / Liberata | outbound (via authoriser email upload) | Payment processing |
| DA&I | inbound (post-MVP REST) | MI consumer for aggregate reports |
| APEX (legacy) | inbound (read-only) | 12-month historical-data bridge for migrated users in each region post-cutover |

## Foundational principles

1. **API for workflows; shared database for simple data access.** Multi-step operations involving business rules and state transitions are exposed as APIs by the owning service. Single-field cross-service updates (where DB grants permit) and read-model federation (SQL JOINs over the shared schema) bypass the API. **No shared runtime code library** — each service owns its own implementation of cross-cutting concerns.
2. **No premature optimization.** Caching, distributed cache, service mesh, read replicas, async messaging are introduced only when measurement post-MVP justifies the complexity. Native platform constructs (PostgreSQL row locking, JPA `@Version`, unique constraints, Spring profiles + Key Vault) are preferred over custom entities for problems already solved by the platform.

## Where to find more detail

| Topic | Location |
|---|---|
| Architectural rationale, decision history, alternatives, retractions, full validation | [`./architecture.md`](./architecture.md) |
| Implementation patterns & consistency rules — naming, structure, format, communication, process, enforcement, examples | [`./architecture/conventions.md`](./architecture/conventions.md) |
| Per-service / UI / `nji-architecture` repo directory trees, file organisation, local dev workflow, deployment-pipeline diagram | [`./architecture/repo-structure.md`](./architecture/repo-structure.md) |
| Authoritative table ownership mapping — every NJI table grouped by service | [`./architecture/data-tables.md`](./architecture/data-tables.md) |
| HMCTS Crime SpringBoot starter walkthrough, dependency inventory, NJI conventions overlay | [`./architecture/starter-template.md`](./architecture/starter-template.md) |
| Documented gaps register (G1–G6 with mitigations and owners) | [`./architecture/gaps.md`](./architecture/gaps.md) |
| Assumptions register (A1–A34 with type and verification path) | [`./architecture/assumptions.md`](./architecture/assumptions.md) |
| Version history and pre-v1.8 anchor redirect table | [`./architecture/changelog.md`](./architecture/changelog.md) |
| PRD (FRs, NFRs, locked decisions D1–D9, glossary) | [`./prd.md`](./prd.md) |
