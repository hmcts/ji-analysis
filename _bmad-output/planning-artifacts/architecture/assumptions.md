---
parent: ../architecture.md
title: Assumptions (A1–A35)
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Assumptions (A1–A35)

> Sibling of [`../architecture.md`](../architecture.md). Linked from *Architecture Validation Results*.

Each assumption is either:

- An external precondition (verifiable with the named owner before Phase 0 or pre-Phase-9), or
- A simplifying choice that can be revisited if wrong.

Assumptions that affect implementation correctness (not just convenience) are flagged **load-bearing**.

| ID | Assumption | Type | Verification |
|---|---|---|---|
| **A1** | HMCTS IdP supports OIDC for human-user authentication | Load-bearing **for Phase 9+ only** | Pre-Phase-9 prerequisite (G1.1) |
| **A2** *(reopened v2.6, 2026-05-07)* | HMCTS IdP supports OAuth 2.0 `client_credentials` grant for service principals — needed in production for the **payment-processing batch** (introduced in v2.6). At MVP this is satisfied by `nji-mock-auth` (non-prod only); production issuer is a deferred decision (G7.1, with Azure Workload Identity as the default recommendation). | Pre-Phase-9 decision per G7.1; mock covers Phase 0–8 |
| **A3** | HMCTS IdP supports principal export / query API for pre-Phase-9 reconciliation | Load-bearing **for Phase 9+ only** | Pre-Phase-9 prerequisite (G1.3); manual fallback documented |
| **A4** | HMCTS Crime SpringBoot template (`hmcts/service-hmcts-crime-springboot-template`) is the appropriate scaffold for NJI. Template confirmed (2026-05-06) to provide Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, OpenTelemetry, Logstash JSON logging, custom JWTFilter, Lombok/MapStruct/OWASP encoder, JaCoCo, CycloneDX, and Swagger Core. **Helm chart and Spring Cloud Azure Key Vault are NOT in the template baseline** — NJI scaffolding script adds them. | Load-bearing | Confirmed (G1.4); Helm + Key Vault gaps tracked (G1.4a, G1.4b) |
| **A5** | HMCTS Email infrastructure is reachable from AKS-hosted Notification service via documented transport | Load-bearing | Phase 0 prerequisite (G1.5) |
| **A6** | HMCTS / MoJ approves Microsoft Azure as cloud platform with UK regions for personal data | Load-bearing | Programme assumption (G3.1) |
| **A7** | HMCTS / MoJ approves PostgreSQL on Azure Database for PostgreSQL Flexible Server | Reversible | G3.2 |
| **A8** | HMCTS / MoJ approves Azure API Management for ingress and rate limiting | Reversible | G3.3 |
| **A9** | HMCTS / MoJ approves React + TypeScript with GOV.UK Design System | Reversible | G3.4 |
| **A10** | Azure-managed encryption keys are sufficient for HMCTS data residency | Load-bearing | HMCTS security review |
| **A11** | The 12 user roles documented in `functional-modules.md` line 497 are the authoritative role set for NJI Authorisation | Load-bearing | Verified against PRD |
| **A12** *(revised 2026-05-06)* | APEX is accessible to the APEX-experienced UAT panel for the duration of build and per-wave UAT cycles, via existing logins. (Earlier assumption that APEX must be reachable from build-time CI for an automated parity harness was retracted with FR61 / NFR41.) | Load-bearing for UAT scheduling, not for CI | D5 + D6; verify APEX user-account availability per wave |
| **A13** *(revised 2026-05-06)* | APEX behaviour is stable for the duration of the build, as observed by UAT users. If APEX changes, UAT scripts and NJI behaviour are updated in lockstep. | Reversible | Risk |
| **A14** | APEX continues to be operable during the phased rollout window (12 months read-only post-cutover per region) | Load-bearing | Per Step 4; programme to confirm |
| **A15** | HMCTS retention policy is satisfied by 30-day hot + 90-day cold log retention | Reversible | Pre-GA review |
| **A16** | Order-of-magnitude capacity (~50–100 per region, ~200–500 national) is broadly correct | Reversible | Programme to confirm |
| **A17** | DA&I and future programmes adopt API-based integration post-MVP | Aspirational | Programme dependency |
| **A18** | UK GDPR + DPA 2018 are the binding privacy regimes; no EU GDPR cross-border concerns | Load-bearing | UK-only deployment |
| **A19** | No bank details, no case-level data invariants from APEX continue to apply to NJI | Load-bearing | Per PRD |
| **A20** | Azure subscription is provisioned per HMCTS / MoJ standard with appropriate RBAC | Reversible | Phase 0 prerequisite |
| **A21** | CI/CD platform is Azure DevOps Pipelines or GitHub Actions per HMCTS standard | Reversible | HMCTS standard |
| **A22** | HMCTS-approved security tooling is available and integrated at platform level | Reversible | HMCTS infrastructure |
| **A23** | The locked decisions D1–D9 from the PRD are programme-approved and binding | Load-bearing | Per PRD |
| **A24** | The 11-service decomposition (revised v2.2, 2026-05-07 — `nji-configuration` dropped in favour of Spring profiles + Key Vault and a shared `configuration_values` infrastructure table) is programme-approved and binding | Load-bearing | Per PRD |
| **A25** | The team has Java + Spring Boot + Kubernetes + React + TypeScript skills available, or budget for upskilling | Reversible | Programme staffing |
| **A26** *(widened v2.6, 2026-05-07)* | Mock auth (Spring Authorization Server) provides full OIDC contract parity with the production issuer for (a) human `authorization_code` and (b) `client_credentials` for batch service principals (initially `nji-payment-batch`). | Load-bearing | Phase 0 deliverable; integration tests verify human + service-principal contract parity |
| **A27** | Mock auth never runs in production; CI lint and Spring profile validation prevent this | Load-bearing — critical for production security | Phase 0 deliverable; enforced by CI rules |
| **A28** | One global PostgreSQL Flexible Server instance is sufficient for the full bounded NJI workload (~hundreds of concurrent users, read-mostly patterns, indexed joins) | Load-bearing | Phase 0 sizing decision; reversible — can introduce read replicas post-MVP per Principle 2 |
| **A29** | Schema evolution: Flyway, per the HMCTS Crime SpringBoot template (`spring-boot-starter-flyway` + `flyway-core` + `flyway-database-postgresql`). Flyway owns NJI's own DDL — table creation, column add/drop, grants. **Not** APEX-to-NJI data movement; the Phase 0 ETL (see [`../architecture.md`](../architecture.md)) loads NJI data via the Reference Data and Authorisation APIs. | Confirmed via template review (2026-05-06) |
| **A30** | "No premature optimization" principle holds for MVP — no caching, no distributed cache, no service mesh, no read replicas, no async messaging unless measurement post-MVP justifies the complexity | Load-bearing principle | Self-enforced by architecture; review post-MVP per measured performance |
| **A31** | The shared-schema cross-service access model (table-name convention + per-service DB roles + explicit grants + fitness functions) is operationally maintainable with PR-coordination between services. | Reversible | If maintenance burden grows: retreat to API-only writes (reads-via-direct-SQL stays). If isolation needs grow: introduce schema-per-service — per-service DB roles already make this a grants-and-tables refactor, not a connection-layer change. |
| **A32** *(revised 2026-05-06)* | Phase 0 Reference Data + Users/Roles migration is an ETL: read APEX SQL exports → transform to NJI shape → load via NJI Reference Data API and Authorisation API. Operationally feasible with named-owner sign-off. | Load-bearing | Phase 0 deliverable; reconciliation per D3 + Risk #13. Tool at `nji-architecture/migration/`. |
| **A33** *(revised 2026-05-06)* | The Authoritative Table Ownership Mapping (39 NJI tables in [`./data-tables.md`](./data-tables.md)) is NJI's design, fixed by NJI; not revalidated against APEX shape. What is revalidated in Phase 0 is the migration tool's APEX-side input mapping: when the dump arrives, verify the tool covers every APEX field NJI needs and every APEX value lands in a known NJI vocabulary row (new values added via the Reference Data API; no schema change). An unmapped APEX structure raises an architectural PR. | Load-bearing for migration correctness | Phase 0 deliverable (G4.6); architecture changes only if an unmapped APEX structure surfaces. |
| **A34** | Azure UK South provides three availability zones with zone-redundant managed services (AKS multi-zone node pools, PostgreSQL Flexible Server zone-redundant HA, Key Vault Premium, APIM Premium, ACR Premium). | Load-bearing | Phase 0 infra-provisioning verification; if any zone-redundant SKU is unavailable, the component degrades to single-zone HA + accepted-risk note. |
| **A35** *(softened v2.6, 2026-05-07)* | Most MVP runtime requests are user-initiated. One exception: the payment-processing batch (`nji-payment-batch`), which runs on a schedule and authenticates as a service principal. User-initiated inter-service auth: JWT propagation. Batch inter-service auth: OAuth `client_credentials` against `nji-mock-auth` in non-prod; production issuer per G7.1. Other non-user-initiated flows (DA&I service-consumer calls, scheduled aggregations, async messaging) are out of MVP scope and would reuse the service-principal pattern. Phase 0 production migration runs operator-initiated (G4.7); dev/CI seeding via one-off scripts. | Load-bearing | The payment batch is the only non-user-initiated runtime flow at MVP. Adding more reopens the production service-auth choice (G7.1). |
