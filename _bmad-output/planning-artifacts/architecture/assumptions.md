---
parent: ../architecture.md
title: Assumptions (A1–A33)
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Assumptions (A1–A33)

> Sibling of [`../architecture.md`](../architecture.md). The parent file links here from its *Architecture Validation Results* section.

This is the authoritative assumption register for the architecture. Each assumption is either:

- An external precondition expected to hold (verifiable with the named owner before Phase 0 or pre-Phase-9), or
- A simplifying choice that can be revisited if it turns out to be wrong.

Assumptions that affect implementation correctness (rather than just convenience) are flagged as **load-bearing**.

| ID | Assumption | Type | Verification |
|---|---|---|---|
| **A1** | HMCTS IdP supports OIDC for human-user authentication | Load-bearing **for Phase 9+ only** | Pre-Phase-9 prerequisite (G1.1) |
| **A2** | HMCTS IdP supports OAuth 2.0 client_credentials grant for service principals | Load-bearing **for Phase 9+ only** | Pre-Phase-9 prerequisite (G1.2); mTLS fallback documented |
| **A3** | HMCTS IdP supports principal export / query API for pre-Phase-9 reconciliation | Load-bearing **for Phase 9+ only** | Pre-Phase-9 prerequisite (G1.3); manual fallback documented |
| **A4** | HMCTS Crime SpringBoot template (`hmcts/service-hmcts-crime-springboot-template`) is the appropriate scaffold for NJI. Template confirmed (2026-05-06) to provide Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, OpenTelemetry, Logstash JSON logging, custom JWTFilter, Lombok/MapStruct/OWASP encoder, JaCoCo, CycloneDX, and Swagger Core. **Helm chart and Spring Cloud Azure Key Vault are NOT in the template baseline** — NJI scaffolding script adds them. | Load-bearing | Confirmed (G1.4); Helm + Key Vault gaps tracked (G1.4a, G1.4b) |
| **A5** | HMCTS Email infrastructure is reachable from AKS-hosted Notification service via documented transport | Load-bearing | Phase 0 prerequisite (G1.5) |
| **A6** | HMCTS / MoJ approves Microsoft Azure as cloud platform with UK regions for personal data | Load-bearing | Programme assumption (G3.1) |
| **A7** | HMCTS / MoJ approves PostgreSQL on Azure Database for PostgreSQL Flexible Server | Reversible | G3.2 |
| **A8** | HMCTS / MoJ approves Azure API Management for ingress and rate limiting | Reversible | G3.3 |
| **A9** | HMCTS / MoJ approves React + TypeScript with GOV.UK Design System | Reversible | G3.4 |
| **A10** | Azure-managed encryption keys are sufficient for HMCTS data residency | Load-bearing | HMCTS security review |
| **A11** | The 12 user roles documented in `functional-modules.md` line 497 are the authoritative role set for NJI Authorisation | Load-bearing | Verified against PRD |
| **A12** | APEX is accessible (via the same logins users have today) to the APEX-experienced UAT panel for the duration of build and per-wave UAT cycles. *(Revised 2026-05-06 — earlier load-bearing assumption that APEX must be reachable from build-time CI for an automated parity harness has been retracted with FR61 / NFR41; manual UAT replaces it.)* | Load-bearing for UAT scheduling, not for CI | D5 (revised) + D6; verify APEX user-account availability for the UAT panel per wave |
| **A13** | APEX behavioural surface is stable for the duration of the build, **as observed by APEX-experienced UAT users**. *(Revised 2026-05-06 — no automated parity harness to "adjust"; if APEX behaviour changes, the UAT scripts and the NJI implementation are updated in parallel.)* | Reversible | Risk; if APEX changes, UAT scripts and NJI behaviour are adjusted in lockstep |
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
| **A26** | Mock auth implementation (Spring Authorization Server-based) provides full OIDC contract parity with HMCTS IdP for the AuthN paths NJI services use, including `client_credentials` for service principals | Load-bearing | Phase 0 deliverable; integration tests verify contract parity |
| **A27** | Mock auth never runs in production; CI lint and Spring profile validation prevent this | Load-bearing — critical for production security | Phase 0 deliverable; enforced by CI rules |
| **A28** | One global PostgreSQL Flexible Server instance is sufficient for the full bounded NJI workload (~hundreds of concurrent users, read-mostly patterns, indexed joins) | Load-bearing | Phase 0 sizing decision; reversible — can introduce read replicas post-MVP per Principle 2 |
| **A29** | HMCTS schema-evolution tooling is **Flyway** per the HMCTS Crime SpringBoot template (`spring-boot-starter-flyway` + `flyway-core` + `flyway-database-postgresql`). Flyway here owns **NJI's own DDL** — table creation, column add/drop, grants — *not* APEX-to-NJI data movement. The Phase 0 Data Migration from APEX is a separate ETL activity (see [`../architecture.md` → *Phase 0 Data Migration from APEX*](../architecture.md)) that loads NJI data via the Reference Data and Authorisation APIs, not via Flyway. | Confirmed via template review (2026-05-06); ETL/Flyway separation clarified 2026-05-06 |
| **A30** | "No premature optimization" principle holds for MVP — no caching, no distributed cache, no service mesh, no read replicas, no async messaging unless measurement post-MVP justifies the complexity | Load-bearing principle | Self-enforced by architecture; review post-MVP per measured performance |
| **A31** | The shared-schema cross-service access model (table-name convention + per-service DB roles + explicit table grants + fitness functions) is operationally maintainable with PR-coordination between services | Reversible | If maintenance burden grows: retreat to API-only access for cross-service writes; reads-via-direct-SQL likely stays. If service isolation needs grow: introduce schema-per-service (per-service DB roles already in place make this a refactor of grants + table moves, not a connection-layer change) |
| **A32** | Phase 0 Reference Data + Users/Roles migration is **an ETL activity**: read APEX SQL exports → transform to NJI shape → load via NJI Reference Data API and Authorisation API. Operationally feasible with named owners signing off the resulting load. *(Revised 2026-05-06 — earlier framing as "APEX SQL exports → Flyway migrations" conflated the ETL with Flyway DDL; corrected.)* | Load-bearing | Phase 0 deliverable; reconciliation per D3 + Risk #13. Tool lives at `nji-architecture/migration/`. |
| **A33** | The Authoritative Table Ownership Mapping (39 NJI tables in [`./data-tables.md`](./data-tables.md)) is **NJI's design** and is fixed by NJI; it does not require revalidation *against APEX shape*. What does require validation in Phase 0 is the **migration tool's APEX-side input mapping** — when the dump arrives, verify the tool covers every APEX field NJI needs and that every APEX value lands in a known NJI vocabulary row (new values gain rows via the Reference Data API; no schema change). A fundamentally unmapped APEX structure (rare) raises an architectural PR. *(Revised 2026-05-06 — earlier framing of "revalidation against APEX SQL dump" risked treating APEX shape as a constraint on NJI shape; corrected.)* | Load-bearing for migration correctness | Phase 0 deliverable (G4.6); architecture document is updated only if a fundamentally unmapped APEX structure surfaces |
| **A34** | Azure UK South provides **three availability zones** with zone-redundant managed services (AKS multi-zone node pools, PostgreSQL Flexible Server zone-redundant HA, Key Vault Premium zone-redundancy, APIM Premium zone-redundancy, Azure Container Registry Premium zone-redundancy). NJI's HA topology depends on these zone-redundant offerings being available in UK South. *(Per Microsoft's published Azure regions documentation — UK South has 3 AZs as of GA.)* | Load-bearing | Phase 0 verification at infra-provisioning time; if any zone-redundant SKU is unavailable, the relevant component degrades to single-zone HA + accepted-risk note. |
