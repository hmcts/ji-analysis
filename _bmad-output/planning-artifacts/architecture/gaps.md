---
parent: ../architecture.md
title: Documented Gaps (G1–G7)
last_updated: 2026-05-08
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Documented Gaps (G1–G7)

> Sibling of [`../architecture.md`](../architecture.md). Linked from *Architecture Validation Results*.

Every gap is named, categorised, owned, and has a mitigation or fallback. Implementation can begin while these are tracked and resolved in parallel.

## Critical Gaps

None. No gap blocks implementation.

## G1 — External Verification Dependencies (HMCTS infrastructure)

| ID | Gap | Mitigation / Fallback | Owner |
|---|---|---|---|
| **G1.1** | HMCTS IdP support for OIDC human-user authentication is assumed but not verified. | **No longer Phase 0 blocking** — mock auth covers Phase 0–8. Verification needed before pre-Phase-9 cutover. If SAML-only: swap protocol library at the integration boundary; pattern unchanged. | Pre-Phase-9 prerequisite — IdP team confirmation |
| **G1.2** *(reopened v2.6, 2026-05-07)* | HMCTS IdP support for OAuth 2.0 `client_credentials` grant — needed in production for the payment-batch service principal (`nji-payment-batch`). `nji-mock-auth` covers dev/CI/integration. Production options in G7.1: NJI-internal issuer, Azure Workload Identity, mTLS, or HMCTS IdP `client_credentials`. | Pre-Phase-9 — IdP team confirmation, or adopt an alternative from G7.1 |
| **G1.3** | HMCTS IdP principal export or query API for migration reconciliation is assumed. | **No longer Phase 0 blocking** — mock auth users mirror migrated APEX records in Phase 0; real reconciliation deferred to pre-Phase-9 cutover. If unsupported: fallback to manual reconciliation report compiled by IdP team out of band. | Pre-Phase-9 prerequisite — IdP team confirmation |
| **G1.4** | HMCTS Crime SpringBoot template (`hmcts/service-hmcts-crime-springboot-template`) is assumed to be the appropriate starter for NJI. **Confirmed via template review (2026-05-06):** Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, PostgreSQL, Logstash JSON logging, OpenTelemetry, Testcontainers, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, Swagger Core, JWTFilter pattern. | Confirmed. Residual risk: NJI may want to fork or use a closer-fit HMCTS judicial-services template if one exists. | NJI architecture team |
| **G1.4a** *(new)* | **Helm chart for AKS deployment is not included in the HMCTS Crime template.** The architecture assumes per-service Helm charts. | NJI scaffolding script must include Helm chart templates; verify whether HMCTS provides Helm charts via a separate mechanism (shared chart library, Bicep templates) or whether each team provides its own. | Phase 0 deliverable — NJI architecture team |
| **G1.4b** *(new)* | **Spring Cloud Azure Key Vault integration is not in the template baseline.** | Add per service via `com.azure.spring:spring-cloud-azure-starter-keyvault-secrets`. Phase 0 scaffolding includes this. | Phase 0 deliverable — NJI architecture team |
| **G1.5** | HMCTS Email infrastructure (SMTP / Microsoft Graph) availability and authentication mechanism for AKS-hosted services is assumed. | If unavailable in expected form: alternate transport (Azure Communication Services Email) is a documented fallback; Notification service contract unchanged. | Phase 0 prerequisite — HMCTS infrastructure team |
| **G1.6** | Mock-to-real-IdP cutover plan must be operationally rehearsed before pre-Phase-9. | Cutover is a Spring profile change (no code change); rehearse on staging environment with real IdP credentials before scheduling pilot wave 1. | Pre-Phase-9 deliverable — NJI team |

## G2 — Programme-Management Dependencies (out of architecture scope but block implementation)

Tracked in the PRD's open-items list. Restated here because they affect when the architecture can proceed.

| ID | Gap | Notes |
|---|---|---|
| **G2.1** | Pilot region selection for Phase 9 wave 1 | Affects capacity sizing for first deployment; programme decision |
| **G2.2** | Cross-region workflow handling per wave | Per-wave decision; programme template needed (Risk #1 from brainstorming) |
| **G2.3** | Operational availability hours (assumed 07:00–19:00 UK weekdays) | Programme to confirm; affects on-call expectations |
| **G2.4** | Capacity numbers (~50–100 per region, ~200–500 national assumed) | Programme to confirm; affects HPA tuning and PostgreSQL sizing |
| **G2.5** | Phase 0 migration owners (Reference Data sign-off, Users/Roles sign-off) | Programme to name owners; affects Phase 0 deliverable acceptance |
| **G2.6** | Historical-data 12-month window length | Programme to confirm; recommended in Step 4 (TBD #6 partial resolution) |

## G3 — HMCTS Technology Approval

| ID | Gap | Notes |
|---|---|---|
| **G3.1** | Azure as cloud platform (UK regions) — assumed approved per programme guidance | Confirm with HMCTS architecture/security review |
| **G3.2** | Azure Database for PostgreSQL Flexible Server — recommended; HMCTS may prefer Azure SQL | Confirm with HMCTS data team; switch is reversible at Phase 0 cost |
| **G3.3** | Azure API Management for ingress and rate limiting | Confirm with HMCTS infrastructure; Spring Cloud Gateway is named alternative |
| **G3.4** | GOV.UK Design System for React (`govuk-react` or HMCTS-internal equivalent) | Verify HMCTS-internal version exists and is preferred; otherwise use community `govuk-react` |
| **G3.5** | Azure Static Web Apps for UI hosting | Alternative: Azure Blob Storage + CDN; both viable |
| **G3.6** *(open; consolidated v2.8, 2026-05-08)* | **Disaster recovery (DR) — open gap.** MVP runs in a single Azure region (UK South) with multi-AZ HA. All DR design and scope is held here; no DR detail is asserted elsewhere. Decision points: (a) **DR in MVP scope?** Programme decision; default post-MVP (programme accepts full-region-UK-South-unavailability risk for MVP and pilot waves). (b) **Target region** — UK West is the natural candidate (data-residency-compliant per NFR31); not committed. (c) **Posture** — cold-standby (manual failover) vs warm-standby vs active/active. Working assumption: cold-standby. Active/active is incompatible with the shared global PostgreSQL without multi-master replication (premature per Principle 2). (d) **PostgreSQL geo-redundant backup** with the chosen DR region as restore target. (e) **AKS Helm definitions** for the DR region held in source control; cluster not pre-provisioned until activation. (f) **DNS failover** (Azure Front Door / Traffic Manager) and runbook. (g) **RTO/RPO targets** agreed with HMCTS. | Programme (in/out of MVP) + NJI architecture team (design once in scope). Pre-broad-GA at the latest. |

## G4 — Post-Completion Refinement Tasks (not blocking, scheduled after Step 8)

| ID | Gap | Owner |
|---|---|---|
| **G4.1** | Mermaid / C4 diagrams in `nji-architecture/diagrams/` to replace ASCII-art representations of internal communication, data flow, and deployment topology | NJI architecture team post-completion |
| **G4.2** | Sample ADRs (`ADR-001-greenfield-not-strangler.md`, `ADR-002-no-shared-library.md`, `ADR-003-rest-first-no-event-bus.md`, etc.) capturing locked decisions in formal ADR shape | NJI architecture team post-completion |
| **G4.3** | Per-service OpenAPI snippets seeded as Phase 0 paper contracts (per D1) for Itinerary and MI Feed at minimum, plus skeleton specs for the 6 domain services | Phase 0 deliverable |
| **G4.4** | ArchUnit fitness function ruleset codified for the per-service convention checks | Phase 0 deliverable as part of scaffolding |
| **G4.5** | Spectral OpenAPI lint ruleset codified for the API-as-Product standards (consistent error envelope, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details references, versioning prefix, deprecation headers per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) | Phase 0 deliverable as part of scaffolding |
| **G4.6** *(revised 2026-05-06)* | **Phase 0 ETL — APEX-side input mapping needs validation against the APEX SQL dump.** NJI's 39 tables in [`./data-tables.md`](./data-tables.md) are NJI's design, not under revalidation. The migration tool's APEX → NJI mapping is. When the dump arrives, verify: (a) every APEX field the tool expects is present; (b) every APEX value lands in an existing NJI vocabulary row, or triggers a new row via the Reference Data API; (c) no APEX structure lacks a transform path. New vocabulary values are inserted as rows; an unmapped APEX structure raises an architectural PR. | Phase 0 deliverable — NJI architecture team + Reference Data sign-off owner (G2.5). Closes when the ETL runs end-to-end against the real APEX dump and named owners sign off. |
| **G4.7** *(v2.5, 2026-05-07)* | **Operator-initiated ETL — post-MVP refinement.** At MVP, the production / pilot-region migration runs operator-initiated: a named programme operator authenticates at HMCTS IdP and runs the ETL with their JWT. Acceptable at MVP: one-off per region; preserves "all calls user-initiated"; clean audit trail (operator identity). To refine post-MVP: better automation; explicit audit-trail capture; possible service-identity for the ETL tool (would reopen G7 service-auth); resolve the dev/CI-script vs production-API divergence. | Post-MVP refinement — NJI architecture team. Not blocking; revisit before broad GA. |

## G5 — Mock-First Authentication Scope

| ID | Gap | Notes |
|---|---|---|
| **G5.1** | Mock auth must implement enough of the OIDC contract to be issuer-substitutable for HMCTS IdP. | Implement using Spring Authorization Server (provides full OIDC support out of the box). OIDC-contract parity is covered by automated integration / contract tests at the IdP-client level (per A26 in [`./assumptions.md`](./assumptions.md)), not by APEX-comparison UAT. |
| **G5.2** | Mock auth user roster must remain in sync with migrated APEX user/role data so that Phase 0–8 testing exercises realistic flows. | Mock auth seed-data generated from the same Phase 0 migration reconciliation report (or a sanitised subset). Refreshed when migration data changes. |
| **G5.3** | Production safeguard: mock auth must never run in production; production deployment manifests must never reference mock-auth issuer URLs. | Spring profile validation at mock-auth startup (refuses to start with `production` profile); CI lint enforces production Helm values reference real-IdP issuer. |

## G6 — Shared Database Topology Risks

| ID | Gap | Notes |
|---|---|---|
| **G6.1** | **Schema-evolution coordination across whitelisted tables.** When Service A reads or writes Service B's whitelisted tables, schema changes to those columns affect A. The owning service (B) must maintain a deprecation policy on whitelisted columns parallel to API versioning. | Mitigation: schema changes to whitelisted columns follow the same deprecation cadence as API versioning (deprecate, sunset header on the published data contract, remove no sooner than 6 months for internal consumers). Whitelist documentation lives in the owning service's repo alongside its API contract. |
| **G6.2** *(refined 2026-05-06; 2026-05-08)* | **Single-DB blast radius.** A PostgreSQL outage affects every NJI service simultaneously (vs per-service DBs where one DB outage affects only one service). | Mitigation: PostgreSQL Flexible Server **zone-redundant HA** within UK South — primary + standby in different AZs, synchronous replication, automatic failover (<60 s typical). Single-AZ failure inside UK South is tolerated transparently. Point-in-time restore retained. **Full-region UK South loss is the residual risk** — addressed by DR (see G3.6) if/when approved; without DR, the residual risk is accepted for MVP and pilot waves. Acceptable trade for the operational simplicity of one DB at NJI's bounded scale. |
| **G6.3** | **Cross-region rollout with global DB.** All regions share one DB instance, so Region B's data is visible to Region A immediately on cutover (no APEX-bridge needed for cross-region NJI data). However, during phased rollout, non-migrated regions still have data only in APEX, not in the shared DB. | Mitigation: per-region DB writes only happen for migrated regions; cross-region workflows during partial rollout still rely on the APEX read-only bridge for non-migrated regions' data (Risk #1 unchanged). |
| **G6.4** | **DB role grant maintenance.** Each cross-service grant is a piece of operational state (`GRANT SELECT ON vacancies TO nji_booking;`) that must be applied via Flyway migrations owned by the granting service. Adding/removing grants requires PR coordination between services. | Mitigation: grants codified in the table-owning service's Flyway migrations; PR template includes "grants checklist"; ArchUnit-style fitness function in CI verifies declared grants match actual code-level cross-service table access. |
| **G6.5** | **Flyway migration versioning across services.** When Service A's table has consumers, A's migration that drops or renames a column must coordinate with consumer updates. | Mitigation: deprecation-then-remove pattern — A first adds the new column in `V*__add_*.sql`, both A and consumers transition, then A removes the old column in a later `V*__remove_*.sql`. Same pattern as API versioning. |
| **G6.6** *(new)* | **Table-name collision risk.** Without schema isolation, two services could create tables with the same name in the shared schema. | Mitigation: ArchUnit-style fitness function in CI verifies no two services' Flyway migrations create overlapping table names. Authoritative table-ownership mapping documented in [`./data-tables.md`](./data-tables.md). Code review backs the fitness function. |

## G7 — Service-identity question (post-MVP open item)

| ID | Gap | Notes |
|---|---|---|
| **G7.1** *(revised v2.6, 2026-05-07 — now MVP-relevant for the payment batch)* | **Service-identity mechanism for non-user-initiated flows.** v2.6 introduces the **payment-processing batch** (`nji-payment-batch`) as a scheduled service principal — the first MVP non-user-initiated runtime flow. **At MVP** the batch authenticates against `nji-mock-auth` via OAuth `client_credentials` (mock issues both human and service-principal tokens). **For production**, the issuer choice is still deferred. Other future triggers that would also need a service identity: (a) DA&I post-MVP integration; (b) async messaging / event-bus patterns; (c) other scheduled background jobs (MI Feed pre-aggregation, reconciliation feed); (d) Phase 0 ETL evolving from operator-initiated to automated (per G4.7). | **Pre-Phase-9 decision needed** for production service-auth issuer. Options: <br/>(A) **NJI-internal service-auth issuer** — production-harden the mock-auth Spring Authorization Server; runs as a real (non-mock) service. JWTFilter configured for multi-issuer (HMCTS IdP for humans + nji-service-auth for services). <br/>(B) **Azure Workload Identity / Managed Identity** — cloud-native; no shared secrets; tokens issued by Entra ID and validated via its JWKS. **Likely the default given NJI is on AKS.** <br/>(C) **mTLS** — per-service certs at TLS layer; operationally heavy. <br/>(D) **HMCTS IdP `client_credentials`** — only if HMCTS IdP supports it (G1.2). <br/>Default recommendation: **(B) Azure Workload Identity** for the AKS pod that runs the batch — zero shared secrets, cloud-managed, fits the existing Azure stack. |
| **G7.2** *(new v2.5, 2026-05-07)* | **DA&I post-MVP integration auth model is undecided.** When DA&I starts consuming NJI's MI Feed API post-MVP, it needs an authentication mechanism. If DA&I has a human-user identity at HMCTS IdP it can use the same OIDC flow as other users; if DA&I is a service consumer it needs a service-identity mechanism (see G7.1). | **Open question for post-MVP.** Resolve as part of DA&I onboarding work, alongside G7.1. |
