---
parent: ../architecture.md
title: Documented Gaps (G1–G6)
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Documented Gaps (G1–G6)

> Sibling of [`../architecture.md`](../architecture.md). This is the authoritative gap register; the parent file links here from its *Architecture Validation Results* section.

This is the authoritative gap register for the architecture. Every gap is named, categorised, owned, and has a documented mitigation or fallback. The architecture is **READY WITH DOCUMENTED GAPS** — implementation can begin while these gaps are tracked and resolved in parallel.

## Critical Gaps

**None.** No gap blocks implementation. Each gap below has a documented mitigation, fallback, or post-completion plan.

## G1 — External Verification Dependencies (HMCTS infrastructure)

| ID | Gap | Mitigation / Fallback | Owner |
|---|---|---|---|
| **G1.1** | HMCTS IdP support for OIDC human-user authentication is assumed but not verified. | **No longer Phase 0 blocking** — mock auth covers Phase 0–8. Verification needed before pre-Phase-9 cutover. If SAML-only: swap protocol library at the integration boundary; pattern unchanged. | Pre-Phase-9 prerequisite — IdP team confirmation |
| **G1.2** *(reopened v2.6, 2026-05-07)* | HMCTS IdP support for OAuth 2.0 `client_credentials` grant — needed in production for the **payment-processing batch service principal** (`nji-payment-batch`). At MVP this is provided by `nji-mock-auth` for dev/CI/integration; production decision deferred — options sketched in G7.1 (NJI-internal issuer, Azure Workload Identity, mTLS, or HMCTS IdP `client_credentials`). *(v2.5 closed this gap on the assumption all calls were user-initiated; v2.6 introduces the payment batch as a documented exception, so the gap reopens for production.)* | Pre-Phase-9 prerequisite — IdP team confirmation OR adopt one of the alternatives from G7.1 |
| **G1.3** | HMCTS IdP principal export or query API for migration reconciliation is assumed. | **No longer Phase 0 blocking** — mock auth users mirror migrated APEX records in Phase 0; real reconciliation deferred to pre-Phase-9 cutover. If unsupported: fallback to manual reconciliation report compiled by IdP team out of band. | Pre-Phase-9 prerequisite — IdP team confirmation |
| **G1.4** | HMCTS Crime SpringBoot template (`hmcts/service-hmcts-crime-springboot-template`) is assumed to be the appropriate starter for NJI. **Confirmed via template review (2026-05-06):** Java 25, Spring Boot 4.0.6, Gradle Groovy DSL, Flyway, PostgreSQL, Logstash JSON logging, OpenTelemetry, Testcontainers, Lombok, MapStruct, OWASP encoder, JaCoCo, CycloneDX, Swagger Core, JWTFilter pattern. | Confirmed. Residual risk: NJI may want to fork or use a closer-fit HMCTS judicial-services template if one exists. | NJI architecture team |
| **G1.4a** *(new)* | **Helm chart for AKS deployment is not included in the HMCTS Crime template.** The architecture assumes per-service Helm charts. | NJI scaffolding script must include Helm chart templates; verify whether HMCTS provides Helm charts via a separate mechanism (shared chart library, Bicep templates) or whether each team provides its own. | Phase 0 deliverable — NJI architecture team |
| **G1.4b** *(new)* | **Spring Cloud Azure Key Vault integration is not in the template baseline.** | Add per service via `com.azure.spring:spring-cloud-azure-starter-keyvault-secrets`. Phase 0 scaffolding includes this. | Phase 0 deliverable — NJI architecture team |
| **G1.5** | HMCTS Email infrastructure (SMTP / Microsoft Graph) availability and authentication mechanism for AKS-hosted services is assumed. | If unavailable in expected form: alternate transport (Azure Communication Services Email) is a documented fallback; Notification service contract unchanged. | Phase 0 prerequisite — HMCTS infrastructure team |
| **G1.6** | Mock-to-real-IdP cutover plan must be operationally rehearsed before pre-Phase-9. | Cutover is a Spring profile change (no code change); rehearse on staging environment with real IdP credentials before scheduling pilot wave 1. | Pre-Phase-9 deliverable — NJI team |

## G2 — Programme-Management Dependencies (out of architecture scope but block implementation)

These are tracked in the PRD's open-items list. Restated here because they affect when the architecture can proceed even though they are not architectural decisions.

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
| **G3.6** *(new 2026-05-06)* | **UK West DR scope decision (cold-standby).** NJI's HA topology is same-Azure-region multi-AZ in UK South; UK West is reserved for disaster recovery (cold-standby, manual failover playbook). Whether DR is in **MVP scope** is a programme decision. | If DR is in scope: PostgreSQL geo-redundant backup with UK West restore target; AKS cluster Helm definitions (`values-dr-uk-west.yaml`) held but cluster *not* pre-provisioned (cost saving); Azure Front Door / Traffic Manager DNS failover playbook documented; RTO/RPO targets agreed with HMCTS. If DR is post-MVP: programme accepts the residual full-region-UK-South-unavailability risk for the MVP and pilot waves; revisits before broad GA. **Default position: post-MVP** — confirm with programme. |

## G4 — Post-Completion Refinement Tasks (not blocking, scheduled after Step 8)

| ID | Gap | Owner |
|---|---|---|
| **G4.1** | Mermaid / C4 diagrams in `nji-architecture/diagrams/` to replace ASCII-art representations of internal communication, data flow, and deployment topology | NJI architecture team post-completion |
| **G4.2** | Sample ADRs (`ADR-001-greenfield-not-strangler.md`, `ADR-002-no-shared-library.md`, `ADR-003-rest-first-no-event-bus.md`, etc.) capturing locked decisions in formal ADR shape | NJI architecture team post-completion |
| **G4.3** | Per-service OpenAPI snippets seeded as Phase 0 paper contracts (per D1) for Itinerary and MI Feed at minimum, plus skeleton specs for the 6 domain services | Phase 0 deliverable |
| **G4.4** | ArchUnit fitness function ruleset codified for the per-service convention checks | Phase 0 deliverable as part of scaffolding |
| **G4.5** | Spectral OpenAPI lint ruleset codified for the API-as-Product standards (consistent error envelope, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details references, versioning prefix, deprecation headers per [RFC 9745](https://datatracker.ietf.org/doc/html/rfc9745) + [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594)) | Phase 0 deliverable as part of scaffolding |
| **G4.6** *(new; revised 2026-05-06)* | **Phase 0 Data Migration ETL — APEX-side input mapping needs validation against the APEX SQL dump.** NJI's table inventory in [`./data-tables.md`](./data-tables.md) (39 tables across 11 owning services + 1 dev-only) is **NJI's design** and is not under revalidation; what is under revalidation is the **migration tool's mapping from APEX shape to NJI shape**. When the APEX SQL dump arrives, verify: (a) every APEX field the tool expects is present, (b) every APEX value falls into an existing NJI vocabulary row or triggers a new vocabulary row insertion via the Reference Data API, (c) no APEX-side data structure is left without a transform path. New vocabulary values land as Reference Data rows (no schema change); a fundamentally unmapped APEX structure raises an architectural PR. | Phase 0 deliverable — NJI architecture team + Reference Data sign-off owner (see G2.5). Closes when the ETL successfully runs end-to-end against the real APEX dump and named owners sign off the loaded data. |
| **G4.7** *(new v2.5, 2026-05-07)* | **Production data-migration pattern (operator-initiated ETL) needs post-MVP refinement.** At MVP, the production / pilot-region migration runs **operator-initiated**: a named programme operator authenticates at HMCTS IdP and runs the ETL with their JWT. This is acceptable for MVP because (a) it's a one-off-per-region activity, (b) it preserves the "all calls user-initiated" assumption, (c) it has a clean audit trail (the operator's identity). It is **flagged for post-MVP refinement** to address: better automation (less manual orchestration), explicit audit-trail capture, possible service-identity for the ETL tool (would re-open the service-auth question per G7), and the dev/CI-script vs production-API divergence at MVP. | Post-MVP refinement task — NJI architecture team. Not blocking; revisit before broad GA. |

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
| **G6.2** *(refined 2026-05-06)* | **Single-DB blast radius.** A PostgreSQL outage affects every NJI service simultaneously (vs per-service DBs where one DB outage affects only one service). | Mitigation refined: PostgreSQL Flexible Server **zone-redundant HA** within UK South — primary + standby in different AZs, synchronous replication, automatic failover (<60 s typical). Single-AZ failure inside UK South is tolerated transparently. Point-in-time restore retained. **Full-region UK South loss is the residual risk**, addressed by UK West DR if approved (G3.6); without DR, the residual risk is accepted for MVP and pilot waves. Acceptable trade for the operational simplicity of one DB at NJI's bounded scale. |
| **G6.3** | **Cross-region rollout with global DB.** All regions share one DB instance, so Region B's data is visible to Region A immediately on cutover (no APEX-bridge needed for cross-region NJI data). However, during phased rollout, non-migrated regions still have data only in APEX, not in the shared DB. | Mitigation: per-region DB writes only happen for migrated regions; cross-region workflows during partial rollout still rely on the APEX read-only bridge for non-migrated regions' data (Risk #1 unchanged). |
| **G6.4** | **DB role grant maintenance.** Each cross-service grant is a piece of operational state (`GRANT SELECT ON vacancies TO nji_booking;`) that must be applied via Flyway migrations owned by the granting service. Adding/removing grants requires PR coordination between services. | Mitigation: grants codified in the table-owning service's Flyway migrations; PR template includes "grants checklist"; ArchUnit-style fitness function in CI verifies declared grants match actual code-level cross-service table access. |
| **G6.5** | **Flyway migration versioning across services.** When Service A's table has consumers, A's migration that drops or renames a column must coordinate with consumer updates. | Mitigation: deprecation-then-remove pattern — A first adds the new column in `V*__add_*.sql`, both A and consumers transition, then A removes the old column in a later `V*__remove_*.sql`. Same pattern as API versioning. |
| **G6.6** *(new)* | **Table-name collision risk.** Without schema isolation, two services could create tables with the same name in the shared schema. | Mitigation: ArchUnit-style fitness function in CI verifies no two services' Flyway migrations create overlapping table names. Authoritative table-ownership mapping documented in [`./data-tables.md`](./data-tables.md). Code review backs the fitness function. |

## G7 — Service-identity question (post-MVP open item)

| ID | Gap | Notes |
|---|---|---|
| **G7.1** *(revised v2.6, 2026-05-07 — now MVP-relevant for the payment batch)* | **Service-identity mechanism for non-user-initiated flows.** v2.6 introduces the **payment-processing batch** (`nji-payment-batch`) as a scheduled service principal — the first MVP non-user-initiated runtime flow. **At MVP** the batch authenticates against `nji-mock-auth` via OAuth `client_credentials` (mock issues both human and service-principal tokens). **For production**, the issuer choice is still deferred. Other future triggers that would also need a service identity: (a) DA&I post-MVP integration; (b) async messaging / event-bus patterns; (c) other scheduled background jobs (MI Feed pre-aggregation, reconciliation feed); (d) Phase 0 ETL evolving from operator-initiated to automated (per G4.7). | **Pre-Phase-9 decision needed** for production service-auth issuer. Options: <br/>(A) **NJI-internal service-auth issuer** — production-harden the mock-auth Spring Authorization Server; runs as a real (non-mock) service. JWTFilter configured for multi-issuer (HMCTS IdP for humans + nji-service-auth for services). <br/>(B) **Azure Workload Identity / Managed Identity** — cloud-native; no shared secrets; tokens issued by Entra ID and validated via its JWKS. **Likely the default given NJI is on AKS.** <br/>(C) **mTLS** — per-service certs at TLS layer; operationally heavy. <br/>(D) **HMCTS IdP `client_credentials`** — only if HMCTS IdP supports it (G1.2). <br/>Default recommendation: **(B) Azure Workload Identity** for the AKS pod that runs the batch — zero shared secrets, cloud-managed, fits the existing Azure stack. |
| **G7.2** *(new v2.5, 2026-05-07)* | **DA&I post-MVP integration auth model is undecided.** When DA&I starts consuming NJI's MI Feed API post-MVP, it needs an authentication mechanism. If DA&I has a human-user identity at HMCTS IdP it can use the same OIDC flow as other users; if DA&I is a service consumer it needs a service-identity mechanism (see G7.1). | **Open question for post-MVP.** Resolve as part of DA&I onboarding work, alongside G7.1. |
