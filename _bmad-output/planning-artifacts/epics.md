---
stepsCompleted: ['step-01-validate-prerequisites']
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/architecture/starter-template.md'
  - '_bmad-output/planning-artifacts/architecture/repo-structure.md'
  - '_bmad-output/planning-artifacts/architecture/repository-strategy.md'
projectName: 'ji-analysis'
productCodename: 'NJI'
uxDocument: 'not-present-accepted-gap'
date: '2026-05-11'
---

# ji-analysis (NJI) — Epic Breakdown

## Section Navigation

| Section | Sub-sections |
|---|---|
| [Overview](#overview) | — |
| [Requirements Inventory](#requirements-inventory) | [Functional Requirements](#functional-requirements) · [NonFunctional Requirements](#nonfunctional-requirements) · [Additional Requirements](#additional-requirements) · [UX Design Requirements](#ux-design-requirements) · [FR Coverage Map](#fr-coverage-map) |
| [Functional Requirements](#functional-requirements) | [Identity & Authorisation](#identity--authorisation) · [Foundational Data Management](#foundational-data-management) · [Judge Records & Working Patterns](#judge-records--working-patterns) · [Absence Workflow](#absence-workflow) · [Vacancy & Cover](#vacancy--cover) · [Booking Management](#booking-management) · [Sitting Management](#sitting-management) · [Payment & Reconciliation](#payment--reconciliation) · [Itineraries & Reporting](#itineraries--reporting-read-models) · [Platform Operations & Migration](#platform-operations--migration) |
| [NonFunctional Requirements](#nonfunctional-requirements) | [Performance](#performance) · [Security](#security) · [Accessibility](#accessibility) · [Integration](#integration) · [Observability](#observability-mvp-minimum-per-d7) · [Data Privacy & Sovereignty](#data-privacy--sovereignty) · [Reliability & Availability](#reliability--availability) · [Maintainability](#maintainability) |
| [Additional Requirements](#additional-requirements) | [Repository strategy](#repository-strategy) · [Starter template](#starter-template-story-1-of-every-service-epic) · [Locked technology stack](#locked-technology-stack-carried-from-prd-enumerated-here-as-architecture-confirmed-dependency-versions) · [Build / supply-chain tooling](#build--supply-chain-tooling-per-hmcts-crime-template) · [Testing framework](#testing-framework-per-hmcts-crime-template) · [Data architecture](#data-architecture) · [Infrastructure / deployment](#infrastructure--deployment) · [CI / CD pipeline](#ci--cd-pipeline-per-service) · [Observability (MVP per D7)](#observability-mvp-per-d7) · [Security implementation](#security-implementation) · [API surface / standards](#api-surface--standards) · [UI stack](#ui-stack-architecture-decisions-on-top-of-prd-d4) · [Phase 0 Data Migration ETL](#phase-0-data-migration-etl-not-a-runtime-service) · [Manual UAT](#manual-uat-fr61--nfr41-revised-2026-05-06) |
| [Epic List](#epic-list) | [Phase × Area Summary](#epic-phase--area-summary) · [Phase 0](#phase-0--foundations) · [Phase 1](#phase-1--judge) · [Phase 2](#phase-2--absence) · [Phase 3](#phase-3--vacancy) · [Phase 4](#phase-4--booking) · [Phase 5](#phase-5--sitting) · [Phase 6](#phase-6--payment) · [Phase 7](#phase-7--itineraries) · [Phase 8](#phase-8--mi-feed--reporting) · [Phase 9+](#phase-9--pilot-rollout-wave-1-and-subsequent-waves) |

## Overview

This document provides the complete epic and story breakdown for **NJI (New JI)** — the greenfield rebuild of HMCTS's Judicial Itineraries system — decomposing the requirements from the PRD (61 FRs, 42 NFRs, D1–D9) and the Architecture (HMCTS Crime SpringBoot starter, polyrepo, shared-DB + per-service DB roles, Kubernetes on Azure AKS) into implementable stories.

UX Design document is not present; downstream epics inherit UI requirements directly from PRD FRs (FR55, FR56) and architecture conventions (GOV.UK Design System base, WCAG 2.2 AA per NFR17). This gap is documented in the 2026-05-06 readiness report.

## Requirements Inventory

### Functional Requirements

#### Identity & Authorisation

- FR1: Authenticated users access NJI via HMCTS IdP single sign-on; password, session, and account lifecycle are owned by the IdP and not duplicated in NJI.
- FR2: NJI's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- FR3: Authorised users can retrieve their effective permissions for their authenticated session.
- FR4: System administrators can update role and Region/Area assignments for migrated and new users.
- FR5 *(post-MVP per v2.5)*: External machine-to-machine consumers require an authentication mechanism. At MVP, no machine-to-machine consumers are in scope; mechanism for genuine service-principal authentication is a post-MVP open question (see `architecture/gaps.md` G7).

#### Foundational Data Management

- FR6: RSU users can view and maintain Reference Data lists — Regions, Offices, judicial vocabularies, calendar / financial-year boundaries — with named-owner sign-off on changes.
- FR7 *(revised 2026-05-11)*: Every NJI service reads Reference Data via **direct SQL** on the shared schema's Reference Data tables (15 tables, SELECT-granted to each service's DB role) — no client class, no API fan-out, no cache (per architecture Principle 2). Reference Data is the **single writer** — all writes (Phase 0 ETL load + ongoing RSU maintenance per FR6) go through the versioned Reference Data API. No service holds duplicate or cached copies of Reference Data in its own tables.
- FR8 *(revised v2.2)*: Cross-service runtime policy values are stored in a shared `configuration_values` infrastructure table, schema-managed by `nji-architecture`'s Flyway baseline migration and SELECT-granted to every NJI service DB role. Per-service config uses Spring profiles + `application.yml` + Azure Key Vault.
- FR9: NJI dispatches transactional emails (booking acknowledgements, absence acknowledgements, payment schedules) via HMCTS email infrastructure, with a delivery log retained.

#### Judge Records & Working Patterns

- FR10: RSU users can search and filter judges by name, base location, location type, and judge type.
- FR11: RSU users can maintain judge profiles, including personal details, judge type, base office, active/inactive status, and role-specific data (payroll number, retirement date, fee entitlement, London weighting, name-for-itinerary, heading).
- FR12: Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- FR13: NJI auto-populates judge itineraries up to the next 31st March from the working pattern, preserving any prior absences.
- FR14: RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- FR15: RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- FR16: NJI validates that jurisdictional split percentages total 100% before saving.
- FR17: RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- FR18: Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

#### Absence Workflow

- FR19: Authorised users (RSU, Court, Judges where permitted) can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- FR20: NJI distinguishes auto-confirmed absences (from judicial teams) from those requiring confirmation (from Courts or judges); confirmation can trigger an acknowledgement email.
- FR21: Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- FR22: Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

#### Vacancy & Cover

- FR23: NJI auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- FR24: Authorised users can create standalone vacancies independent of any absence.
- FR25: Authorised users can edit a vacancy's daily breakdown — cancel individual days with a captured reason; extend or shorten the period.
- FR26: NJI marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- FR27: NJI surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is performed out-of-system by judicial teams.
- FR28: Authorised users can cancel or close vacancies (e.g. when a parent absence becomes NTBF).

#### Booking Management

- FR29: Authorised users can create fee-paid bookings (linked to a vacancy or standalone), capturing judge, court, date, session type (full / AM / PM / evening / reserved-matter), booking type, and work type.
- FR30: Booking creation marks the linked vacancy as filled within the same transaction when a `vacancyId` is supplied (in-process direct DB update on the `vacancies` row using a per-service DB role grant, per architecture Principle 1).
- FR31: NJI tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- FR32: NJI sends booking acknowledgement emails to fee-paid judges, batched overnight or sent immediately via *Create and Email Now*.
- FR33: NJI requires a Y/N answer at booking time when a judge's fee entitlement is *Ask when booking*.
- FR34: NJI prevents double-booking of fee-paid judges for overlapping sessions.

#### Sitting Management

- FR35: NJI generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- FR36: Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- FR37: Authorised users can confirm that a sitting actually took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- FR38: Authorised users can split a sitting into AM/PM with different work types within a single day.
- FR39: Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- FR40 *(revised 2026-05-11)*: Verifiers can verify confirmed sittings; once verified, the data is read-only. Amendments after verification require **re-opening** via a UI re-open action gated by a distinct authorised role — different from the original confirmer (SIT-NFR-02) and from a standard Verifier (at MVP, the permission is granted to RSU Admin only). The action captures a mandatory justification field and is fully audited. No external Request-for-Change ticketing — re-open is a first-class UI action with RBAC controls.

#### Payment & Reconciliation

- FR41 *(revised v2.6)*: Authorised users can list confirmed bookings and salaried sittings, filterable by Region/Office, judge, date range, and payment lifecycle status (pending, requested, paid, reconciled).
- FR42 *(revised v2.6)*: NJI's payment-processing batch (`nji-payment-batch`, scheduled cron — typically end-of-week) automatically marks eligible bookings as *payment requested* and creates the corresponding `payments` + `payment_schedules` records via SQL JOIN; no user click required.
- FR43 *(revised v2.6)*: The payment batch generates JFEPS-compatible payment schedules and dispatches them as Excel attachments to a configured Payment Authoriser via email (using its service-principal identity to call the Notification API).
- FR44: NJI exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`); the JFEPS shape evolves independently of Payment internals.
- FR45: NJI prevents double submission of the same booking for payment via natural-key unique constraint on `(payment_cycle_id, booking_id)`; re-runs of the same cycle are idempotent.
- FR46: Authorised users (Finance, RSU) can flag payments as reconciled, capturing notes for mismatches; once fully reconciled, a payment cannot be re-requested.
- FR47: NJI does not store or expose bank details for any judge — those remain in the finance system.

#### Itineraries & Reporting (Read Models)

- FR48: Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month, showing sittings, bookings, vacancies, and NTBF absences for each day.
- FR49: Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation (judges see only their own; courts see their office; RSU sees their region).
- FR50: Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- FR51: Itinerary cells are clickable and drill into the underlying record (Sitting, Absence, Vacancy, or Booking).
- FR52: Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- FR53: NJI provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report.
- FR54: NJI exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); MI Feed responses contain no case-level data and are aggregate-only by contract.

#### Platform Operations & Migration

- FR55: Authenticated users land on a Home page showing role-scoped navigation, Region/Area selector, summary tiles for the selected scope (judges, absences, vacancies, pending payments, payments made, unreconciled), and contextual help.
- FR56: NJI's UI replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA accessibility standards.
- FR57: A Phase 0 Data Migration ETL takes Reference Data and active user records from APEX, transforms them into NJI's own shape, and loads them via the NJI Reference Data API and Authorisation API. Migrated user records are keyed to HMCTS IdP principals (email primary, employee number fallback). Phase 0 deliverable with named-owner sign-off; unmatched records flagged for explicit handling.
- FR58: NJI supports per-region phased activation — a region's user accounts can be activated for NJI use only when that region's feature-parity gate is passed; activation is a flag flip on `auth_user_activation_flags`, not a data migration.
- FR59: Every NJI service exposes a versioned API contract, RFC 9457 problem-details for errors, and a published OpenAPI specification. Deprecation signalling uses `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) headers.
- FR60: Every NJI service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- FR61 *(revised 2026-05-06)*: Every NJI domain service has a manual user acceptance test (UAT) script capturing the workflows and edge cases an APEX-experienced user verifies against APEX before that service's region rollout. UAT performed by users from in-region applicable roles, recorded with explicit per-role sign-off. No automated APEX-comparison harness.

### NonFunctional Requirements

#### Performance

- NFR1 — Static page load: ≤ 3 s for static UI loads (e.g. Home initial render).
- NFR2 — Dashboard refresh: ≤ 5 s when Region/Area selection changes.
- NFR3 — List / filter operations: ≤ 10 s for typical operational lists at Region scope.
- NFR4 — Batch / annual operations: ≤ 15 s (e.g. annual itinerary render, batch payment-request processing).
- NFR5 — Reports / Forward Look: ≤ 30 s for standard report parameters and for the Forward Look view at Region scope.
- NFR6 — Single-resource API read: ≤ 500 ms p95.
- NFR7 — Domain write API: ≤ 1 s p95 for typical write operations.
- NFR8 — Federated read (Itinerary, Forward Look): ≤ 30 s p95 under Strategy A (SQL JOIN over shared schema).
- NFR9 — Capacity: concurrent users per region ~50–100; national ~200–500 once all regions migrated.

#### Security

- NFR10 — Transport encryption: Latest TLS only on every endpoint; HTTP-only endpoints rejected.
- NFR11 — Data-at-rest encryption: All personal data encrypted at rest.
- NFR12 *(revised v2.6)*: Human users authenticated via HMCTS IdP SSO (per FR1). Inter-service authentication for user-initiated calls is JWT propagation, validated by `JWTFilter` against IdP JWKS. Batch / scheduled components use OAuth 2.0 `client_credentials` against `nji-mock-auth` in non-prod; production issuer is deferred per gaps.md G7.1.
- NFR13 — Authorisation enforcement: Every API call resolves principal's roles + Region/Area scope through the Authorisation service; no operation bypasses this check.
- NFR14 — Forbidden data scope: No bank details stored or exposed (PAY-NFR-05). No case-level data in any read model or report (REP-BR-NFR-03).
- NFR15 — Government Functional Standard 7 alignment: protective marking, access control, secure development practices.
- NFR16 — Secret management: Service credentials, signing keys, integration secrets in Azure Key Vault; never in source control or env-baked images.

#### Accessibility

- NFR17 — WCAG 2.2 Level AA: Every UI page meets WCAG 2.2 Level AA; tested per UI page in each domain phase before that phase's gate is passed.
- NFR18 — Assistive technology compatibility: Keyboard navigation, ARIA labels, screen-reader compatibility per HMCTS accessibility standards.
- NFR19 — Public Sector Bodies Accessibility Regulations 2018: compliance including publication of an accessibility statement.

#### Integration

- NFR20 — HMCTS IdP integration: Hard Phase 0 dependency. NJI integrates with whichever AuthN protocol the HMCTS IdP exposes (OIDC or SAML).
- NFR21 — JFEPS / Liberata unchanged: Payment schedule format (JFEPS-compatible Excel), email-to-Authoriser delivery, authoriser-forwards-to-Liberata preserved exactly as APEX.
- NFR22 — HMCTS email infrastructure: Outbound transactional emails dispatch via HMCTS email; overnight batch acceptable for booking acks.
- NFR23 — DA&I MI Feed: Aggregate-only REST API contract; no case-level data under any consumer authorisation.
- NFR24 — eLinks / HR systems: No automated integration in MVP scope.

#### Observability (MVP minimum per D7)

- NFR25 — Structured logging: Every service emits structured logs with consistent fields, correlation IDs threaded through service-to-service calls, defined error-categorisation taxonomy.
- NFR26 — Log retention: Logs retained sufficient for pilot incident triage; specific period set in Phase 0 within HMCTS data-retention policy.
- NFR27 — Log ingestion: Logs ingested into Azure-native logging (Application Insights / Log Analytics).
- NFR28 — Health and readiness probes: Every service exposes Kubernetes-compatible liveness/readiness endpoints (Spring Actuator).
- NFR29 — Roadmap commitments (post-MVP, not MVP): Structured user-action auditing per D7. Metrics and trace observability beyond logs is post-MVP.

#### Data Privacy & Sovereignty

- NFR30 — UK GDPR / DPA 2018 compliance: Personal data scope limited to user/judge identity, contact details, payroll numbers, operational metadata. No case-level data anywhere.
- NFR31 — Data residency: All NJI services and data hosted in Azure UK regions only.
- NFR32 — Retention: Per HMCTS retention schedules. Migrated transactional history remains in APEX (D3).
- NFR33 — FOI scope: Aggregate operational data exposable per FOI; case-level data forbidden by contract.

#### Reliability & Availability

- NFR34 — Operational availability: Available during HMCTS operational hours (typically 07:00–19:00 UK weekdays).
- NFR35 — Payment-cycle continuity: Zero failed JFEPS payment cycles attributable to NJI. Manual handling is operational contingency, not normal-mode expectation.
- NFR36 — Per-wave rollback: Each rollout wave has a documented rollback path within one operational cycle if the wave's gate is breached post-cutover.
- NFR37 — Strategy A degraded-mode contract: If federated read latency breaches NFR8, NJI degrades to Strategy C cached projection.
- NFR38 — HMCTS-judicial-region rollout isolation: Wave activation targeting one HMCTS judicial region does not affect users in other HMCTS regions. Enforcement via per-user `auth_user_activation_flags`. Production runs in a single Azure region (UK South) with multi-AZ HA. DR scope is an open gap per gaps.md G3.6.

#### Maintainability

- NFR39 — API-as-Product standards: Versioned contracts, RFC 9457 problem-details, OpenAPI per service. Deprecation via RFC 9745 + RFC 8594.
- NFR40 — Per-service deployment unit: Each of the 11 services is independently deployable on Kubernetes; rolling updates per service per region without coupling.
- NFR41 — Behavioural-parity UAT suite: Every domain service has a manual UAT script. Sign-off per role per region is the wave gate. No automated parity test suite — automated CI is unit, integration (Testcontainers), and contract tests only.
- NFR42 — Postman collections: Each phase produces a Postman collection that exercises the phase's endpoints; versioned alongside the services.

### Additional Requirements

**(Derived from Architecture — these are technical / platform requirements that materially impact Epic and Story shape, particularly Epic 1 Story 1 service scaffolding.)**

#### Repository strategy

- AR1 *(revised 2026-05-11)* — Polyrepo: **15 repositories** total — 11 production service repos + `nji-ui` (business-user-facing SPA) + `nji-admin-ui` (admin-facing SPA, separate from `nji-ui`) + `nji-architecture` + `nji-mock-auth`. Each repo has its own CI pipeline, CODEOWNERS, branch protection, and review policy. No monorepo, no Gradle root project. The two UI repos use the same stack and conventions but never share runtime code — admin workflows live exclusively in `nji-admin-ui` and never appear in `nji-ui`'s nav.

#### Starter template (Story 1 of every service epic)

- AR2 — Each NJI backend service is scaffolded from the **HMCTS Crime SpringBoot template** (`https://github.com/hmcts/spring-boot-template`) cloned via the `nji-scaffold.sh` script in `nji-architecture/scaffolding/`. The scaffolding script applies NJI conventions on top of the starter and is used at service-creation time only.
- AR3 — Group ID `uk.gov.hmcts.nji`; artefact `nji-{service-name}`; package `uk.gov.hmcts.nji.{service-name}`. Default port 8082.
- AR4 — Initial commit for every new service is *"Scaffold NJI {service-name} from HMCTS starter"* — this is the first implementation story per service.

#### Locked technology stack (carried from PRD; enumerated here as architecture-confirmed dependency versions)

- AR5 — Java 25 (LTS), Spring Boot 4.0.x, Gradle Groovy DSL with Gradle Wrapper, Spring Boot Gradle plugin 4.0.6, `io.spring.dependency-management:1.1.7`.
- AR6 — Lombok 1.18.46, MapStruct 1.6.3 for boilerplate reduction and DTO ↔ entity mapping.
- AR7 — `io.jsonwebtoken:jjwt:0.13.0` for JWT validation in custom `JWTFilter`; `org.owasp.encoder:encoder:1.4.0` for XSS-safe output encoding.
- AR8 — `springdoc-openapi` (Swagger Core) for OpenAPI 3.x generation. Per-service OpenAPI spec published as a Maven artefact `uk.gov.hmcts.nji:api-nji-{service}:{version}`.

#### Build / supply-chain tooling (per HMCTS Crime template)

- AR9 — JaCoCo for code coverage reports.
- AR10 — `org.cyclonedx.bom:3.2.4` for SBOM (Software Bill of Materials) — supply-chain security.
- AR11 — `com.gorylenko.gradle-git-properties:2.5.7` to embed Git metadata in `/actuator/info`.
- AR12 — `com.github.ben-manes.versions:0.54.0` for dependency-update reports.
- AR13 — `com.avast.gradle.docker-compose:0.17.21` for local development with docker-compose-managed dependencies.

#### Testing framework (per HMCTS Crime template)

- AR14 — Spring Boot Test (JUnit 5 via `junit-bom:6.0.3`), `spring-boot-testcontainers:4.0.6`, `testcontainers-postgresql:1.21.4`, `testcontainers-junit-jupiter:1.21.4` for integration tests with real PostgreSQL. AssertJ for assertions (transitive).
- AR15 — `spring-boot-starter-webmvc-test` for controller-layer testing.
- AR16 — Pact (or equivalent) for consumer-driven contract tests under `src/test/java/.../contract/` — added per service (not in HMCTS template baseline).
- AR17 — Spectral for OpenAPI lint in CI; ArchUnit for architectural fitness functions (table ownership, layer rules); Spotless + Checkstyle for code style.

#### Data architecture

- AR18 — One global PostgreSQL 17 instance, **single shared schema**. Per-service DB roles with explicit grants. Table ownership encoded in table name (entity-plural for primary tables; service-prefix for service-internal) and enforced by ArchUnit fitness functions in CI.
- AR19 — Flyway per-service for DDL (each service owns the creation of its tables, columns, indexes, grants). Flyway baseline in `nji-architecture` owns the shared `configuration_values` table.
- AR20 — 39 NJI tables total grouped by owning service (15 Reference Data tables + 5 Authorisation tables + domain tables). See `architecture/data-tables.md` for the authoritative ownership mapping.
- AR21 — Retry safety uses native DB primitives: natural-key unique constraints, optimistic locking (`@Version`), pessimistic row locking. No custom idempotency-key tables.
- AR22 — Cross-service read patterns: direct SQL on Reference Data (no client class); Itinerary and MI Feed use SQL JOINs over the shared schema (no API fan-out, no cache).

#### Infrastructure / deployment

- AR23 — Kubernetes on Azure AKS, production in UK South, multi-AZ HA. Container images → Azure Container Registry. Each of the 11 services is a containerised Spring Boot app.
- AR24 — Helm chart per service with `values-{env}.yaml` overlay per environment (`dev`, `staging`, `production`). Production values include `topologySpreadConstraints` for AZ spread, min replicas, multi-AZ node pool selection. Helm chart is **not** in HMCTS template baseline — added by `nji-scaffold.sh` per G1.4a.
- AR25 — Secrets in Azure Key Vault (via Spring Cloud Azure); no secrets in source control or env-baked images.
- AR26 — Per-environment configuration via Spring profiles + `application-{env}.yml`; cross-service runtime policy values in the shared `configuration_values` table (read-only via direct SQL).
- AR27 — Azure API Management (APIM) at the edge for rate limits, header injection, deprecation/`Sunset` policies, and ops-restricting `/actuator/*` namespace.

#### CI / CD pipeline (per service)

- AR28 — GitHub Actions workflows in `.github/workflows/`: `ci.yml` (build + test + lint + ArchUnit + Spectral + Helm lint), `deploy-dev.yml` (auto on PR merge to main), `deploy-staging.yml` (manual approval), `deploy-production.yml` (per-region per-wave gated, manual UAT sign-off as gate).
- AR29 — `PULL_REQUEST_TEMPLATE.md` includes patterns checklist; `CODEOWNERS` defines NJI team + service-specific reviewers.

#### Observability (MVP per D7)

- AR30 — Logstash Logback Encoder (`net.logstash.logback:logstash-logback-encoder:9.0`) for structured JSON logs with async appender. Logback config in `src/main/resources/logback-spring.xml`.
- AR31 — OpenTelemetry (`spring-boot-starter-opentelemetry`) for traces; OTel Collector → Azure Application Insights as the export target. Instrumentation key configured via env var `APPINSIGHTS_INSTRUMENTATIONKEY`.
- AR32 — `CorrelationIdFilter` at request entry; correlation ID propagated in service-to-service HTTP client calls and threaded through MDC into log statements.
- AR33 — Spring Boot Actuator endpoints exposed: `/actuator/health`, `/actuator/info`, `/actuator/readiness`. `/actuator/metrics` and Prometheus endpoint **not exposed at MVP** per D7. `/actuator/*` namespace ops-restricted at the APIM layer.

#### Security implementation

- AR34 — Custom `JWTFilter` in `config/JWTFilter.java` validates JWTs against the IdP's JWKS endpoint (mock-auth for Phase 0–8; HMCTS IdP from pre-Phase-9 cutover). On each request, calls `nji-authorisation` `POST /authz/check` to resolve principal → roles + Region/Area scope; populates request-scoped `AuthDetails` bean.
- AR35 — `nji-mock-auth` is the OIDC issuer for dev/CI/integration: issues human-user JWTs via `authorization_code` and service tokens via `client_credentials` for batch components. Refuses to start with `production` profile (per gaps.md G5.3). **Never deployed to production.**
- AR36 — Batch / scheduled component authentication: `nji-payment-batch` authenticates via OAuth 2.0 `client_credentials` to obtain a service-principal token; uses that token to call `nji-notification`. Production issuer for service tokens is a deferred decision per gaps.md G7.1 (default recommendation: Azure Workload Identity given AKS deployment).
- AR37 — Boilerplate `@ControllerAdvice` (`GlobalExceptionHandler.java`) emitting RFC 9457 problem-details with `ProblemDetailFactory`. Domain exceptions: `{Resource}NotFoundException`, `BusinessRuleViolation`, `DependencyException`.

#### API surface / standards

- AR38 — Versioning via URI path prefix (e.g. `/v1/judges`, `/v2/judges`) for major versions; backwards-compatible additions don't require a new path. Versioning policy itself is a Phase 0 deliverable per D1.
- AR39 — Deprecation signalling: `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) response headers; injected at APIM layer per AR27.
- AR40 — Versioned content-type for Payment: `application/vnd.hmcts.jfeps+json` (canonical) or `application/vnd.hmcts.jfeps+xlsx` (Excel for Liberata workflow). JFEPS shape evolves independently of Payment internals.
- AR41 — Postman collections per phase under `postman/` in each service repo, named `nji-{service}-phase{N}.postman_collection.json`. Each phase produces a collection that exercises the phase's endpoints (per NFR42); also serves as executable API documentation pre-UI demo.

#### UI stack (architecture decisions on top of PRD D4)

- AR42 *(revised 2026-05-11)* — **Two UI repos**, same stack, separated by audience: `nji-ui` (business-user-facing SPA) and `nji-admin-ui` (admin-facing SPA). Stack for both: React + TypeScript + Vite + Vitest (unit) + Playwright (E2E). `nji-ui` carries per-domain operational modules under `src/modules/{domain}/` (Judge, Absence, Vacancy, Booking, Sitting, Payment, Itinerary, Reports). `nji-admin-ui` carries admin modules under `src/modules/` — `reference-data/` (FR6) and `users-roles/` (FR4) at MVP; future hooks for `activation/` (FR58 admin), `migration-reports/` (FR57 viewer), `audit/` (D7 post-MVP). TanStack Query for HTTP. GOV.UK Design System base styling with HMCTS / NJI extensions; `nji-admin-ui` uses a distinct accent in the header/nav so the admin surface is visually unambiguous.
- AR43 — Auto-generated TypeScript clients per service from per-service OpenAPI specs (regenerated in CI). Clients live under `src/modules/{domain}/api/` and `api-clients/{service}-client/`. Each UI repo regenerates its own clients independently — no shared client package between `nji-ui` and `nji-admin-ui`.
- AR44 — `HmctsIdpProvider.tsx` (OIDC client wrapper) + `ProtectedRoute.tsx` + `useAuth.ts` hook in `src/shared/auth/`. HTTP client (`src/shared/api/httpClient.ts`) attaches auth header; `errorHandling.ts` translates RFC 9457 problem-details into UI display. Same pattern duplicated (not shared) across both `nji-ui` and `nji-admin-ui`. `nji-admin-ui`'s `ProtectedRoute` gates by admin role resolved via `nji-authorisation`'s `POST /authz/check`.
- AR45 *(revised 2026-05-11)* — E2E test suites: `nji-ui` has one Playwright suite per backend phase under `tests/e2e/phase-{N}-{domain}.spec.ts`; `nji-admin-ui` has one Playwright suite per admin module under `tests/e2e/{module}.spec.ts` (e.g. `reference-data.spec.ts`, `users-roles.spec.ts`). axe-core accessibility checks in each repo's `ci.yml`.
- AR45b *(new 2026-05-11)* — **Independent deployment for the two UI repos**: separate Helm charts, separate Azure Static Web Apps (or CDN) deployments, distinct hostnames (e.g. `nji.hmcts.gov.uk` for business surface; `admin.nji.hmcts.gov.uk` for admin surface). Admin surface can deploy without touching the business surface and vice versa. Both share the same backend services, same SSO, same Authorisation service.

#### Phase 0 Data Migration ETL (not a runtime service)

- AR46 — ETL lives at `nji-architecture/migration/` (not as a runtime service; not in Flyway). Reads APEX dumps, transforms to NJI shape, and **calls NJI APIs** (`nji-reference-data` and `nji-authorisation`) to load.
- AR47 — Two ETL streams: `migration/reference-data/` (Regions, Offices, calendar, 12 vocabularies; signed off by named owners per Risk #13) and `migration/users-roles/` (active users, role/scope mappings; reconciled to HMCTS IdP by email primary, employee number fallback per D9 / Risk #14).
- AR48 — Per-run reconciliation reports under `migration/reports/` for named-owner sign-off. Unmatched user records flagged in `unmatched/` bucket with explicit handling decision (drop / hold / manual map).
- AR49 — ETL re-run per wave for incremental user activation. Re-runs are idempotent.

#### Manual UAT (FR61 / NFR41 revised 2026-05-06)

- AR50 — Per-service manual UAT scripts live under `docs/uat/` in each domain service repo (markdown walkthroughs for APEX-experienced users to follow side-by-side against APEX). Not part of automated CI. Sign-off (per role per region) is the wave-cutover gate.

### UX Design Requirements

**(Not applicable — no UX design document was produced. UI requirements inherit directly from PRD FR55, FR56 and architecture decisions AR42–AR45. The 2026-05-06 readiness report documents this as an accepted gap.)**

### FR Coverage Map

*(Placeholder — populated in Step 3 once epics and stories are designed.)*

## Epic List

NJI is built in **10 sequential phases (0–9+)** per the PRD's Phase-by-Phase Journey Mapping and the architecture's Repository Strategy:

- **Phase 0** is cross-cutting foundations (multiple parallel areas).
- **Phases 1–8** each deliver one service end-to-end (backend + UI module).
- **Phase 9+** is the per-region rollout (wave 1, then subsequent waves).

The first level of grouping below is **Phase** (delivery sequence); the second level is **Area** (the capability or cross-cutting concern that anchors the epic). Within each Area, Step 2 will produce one or more concrete epics with goals, story breakdowns, and acceptance criteria.

### Epic Phase × Area Summary

| Phase | Area | Component(s) | Primary FR/NFR coverage |
|---|---|---|---|
| **0** | [Platform & DevEx](#phase-0--area-platform--devex) | `nji-architecture` (scaffolding), GitHub Actions, APIM, AKS, Application Insights, shared `configuration_values` | FR8, FR59, FR60, NFR25–NFR28, NFR40, NFR42 |
| **0** | [Identity & Authorisation](#phase-0--area-identity--authorisation) | `nji-mock-auth`, `nji-authorisation` | FR1–FR4, NFR12, NFR13 |
| **0** | [Reference Data](#phase-0--area-reference-data) | `nji-reference-data` (backend); maintenance UI in `nji-admin-ui` | FR6, FR7 *(revised)* |
| **0** | [Notification](#phase-0--area-notification) | `nji-notification` | FR9, NFR22 |
| **0** | [Phase 0 Data Migration ETL](#phase-0--area-data-migration-etl) | `nji-architecture/migration/` | FR57, FR58 *(data side)* |
| **0** | [Business UI Foundation](#phase-0--area-business-ui-foundation) | `nji-ui` (shell, auth, design system) | FR55 *(shell)*, FR56 *(stack)*, NFR17 |
| **0** | [Admin UI Foundation](#phase-0--area-admin-ui-foundation) | `nji-admin-ui` (shell, auth, design system, Reference Data maintenance, User & Role admin) | FR4 *(UI surface)*, FR6 *(UI surface)*, FR56 *(stack)*, NFR17 |
| **1** | [Judge Records & Working Patterns](#phase-1--area-judge-records--working-patterns) | `nji-judge` + UI module | FR10–FR18 |
| **2** | [Absence Workflow](#phase-2--area-absence-workflow) | `nji-absence` + UI module | FR19–FR22 |
| **3** | [Vacancy & Cover](#phase-3--area-vacancy--cover) | `nji-vacancy` + UI module | FR23–FR28 |
| **4** | [Booking Management](#phase-4--area-booking-management) | `nji-booking` + UI module | FR29–FR34 |
| **5** | [Sitting Management](#phase-5--area-sitting-management) | `nji-sitting` + UI module | FR35–FR40 |
| **6** | [Payment Processing & Reconciliation](#phase-6--area-payment-processing--reconciliation) | `nji-payment` + UI module | FR41 *(part)*, FR44, FR46, FR47, NFR21, NFR35 |
| **6** | [Payment Batch](#phase-6--area-payment-batch) | `nji-payment-batch` (scheduled) | FR42, FR43, FR45 |
| **7** | [Itineraries Read Model](#phase-7--area-itineraries-read-model) | `nji-itinerary` *(no own tables)* + UI views | FR48–FR52, NFR8, NFR37 |
| **8** | [MI Feed & Reporting](#phase-8--area-mi-feed--reporting) | `nji-mi-feed` *(no own tables)* + Reports UI module | FR53, FR54, NFR23 |
| **9+** | [Pilot Rollout & Subsequent Waves](#phase-9--area-pilot-rollout--subsequent-waves) | per-region activation, manual UAT, rollback playbook | FR58 *(activation)*, FR61, NFR36, NFR38, NFR41 |

Cross-cutting NFRs (performance NFR1–NFR9, security/data NFR10–NFR16, NFR30–NFR33, accessibility NFR17–NFR19, maintainability NFR39) are inherited by every phase; their architectural support lives in Phase 0 (Platform & DevEx) and is exercised in every domain phase.

### Phase 0 — Foundations

> Phase 0 is the platform smoke-test (per PRD Key Characteristic 4). All API-as-Product standards (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), `Deprecation`/`Sunset`) are exercised on Reference Data writes and Authorisation lookups before any domain service is built.

#### Phase 0 · Area: Platform & DevEx

**Scope**: Service scaffolding (`nji-scaffold.sh` over HMCTS Crime SpringBoot template), per-service GitHub Actions pipeline (`ci.yml` + `deploy-{env}.yml` + per-region per-wave gated production deploy), OpenAPI/Spectral/ArchUnit/Spotless/Checkstyle tooling, structured Logback JSON logging conventions, OpenTelemetry → Application Insights wiring, shared `configuration_values` infrastructure table managed by `nji-architecture` Flyway baseline, Azure API Management at the edge (rate limits, deprecation headers, `/actuator/*` restriction), AKS UK South multi-AZ HA, Helm chart conventions, Azure Key Vault integration.

**Component(s)**: `nji-architecture` (scaffolding script + ADRs), GitHub Actions workflows, shared Flyway baseline, APIM policies, Helm chart conventions.

**Primary FR/NFR coverage**: FR8, FR59, FR60, NFR25–NFR28, NFR40, NFR42; underpins every AR1–AR45.

#### Phase 0 · Area: Identity & Authorisation

**Scope**: `nji-mock-auth` OIDC issuer for non-prod (human users via `authorization_code`; batch components via `client_credentials`; refuses production profile). `nji-authorisation` service owning the 5 auth tables (`auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`). Custom `JWTFilter` pattern in every service that validates JWT against JWKS and calls `POST /authz/check` to populate request-scoped `AuthDetails`. Per-user activation flags (FR58) wired to enable per-region phased cutover. APEX → IdP principal reconciliation per D9 (email primary, employee number fallback).

**Component(s)**: `nji-mock-auth`, `nji-authorisation`.

**Primary FR/NFR coverage**: FR1, FR2, FR3, FR4, FR58 *(flags wired here; activation orchestrated in Phase 9+)*; NFR12 *(revised v2.6)*, NFR13, NFR16, NFR20. *(FR5 is reframed as post-MVP per v2.5; out of scope here.)*

#### Phase 0 · Area: Reference Data

**Scope**: `nji-reference-data` service owning the 15 Reference Data tables (`regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables). API for maintenance writes with named-owner sign-off workflow. Per-service DB SELECT grants for direct-SQL reads (per revised FR7 / Principle 2). API-as-Product standards exercised here first (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), deprecation signalling).

**Component(s)**: `nji-reference-data` (backend). The maintenance UI (FR6) lives in `nji-admin-ui` — see [Phase 0 · Area: Admin UI Foundation](#phase-0--area-admin-ui-foundation). It does **not** live in `nji-ui`.

**Primary FR/NFR coverage**: FR6 *(backend API only — UI is in admin)*, FR7 *(revised 2026-05-11)*; cross-references NFR39 (API-as-Product), AR18, AR20, AR22.

#### Phase 0 · Area: Notification

**Scope**: `nji-notification` service. Outbound transactional email dispatch to HMCTS email infrastructure (SMTP). Delivery log with retry on transient failure. Consumed in Phase 1+ for booking acks (FR32), absence acks (FR20), and the Phase 6 payment-schedule dispatch (FR43).

**Component(s)**: `nji-notification`.

**Primary FR/NFR coverage**: FR9, NFR22.

#### Phase 0 · Area: Data Migration ETL

**Scope**: `nji-architecture/migration/` two-stream ETL — `reference-data/` (Regions, Offices, calendar, 12 vocabularies; named-owner sign-off per Risk #13) and `users-roles/` (active APEX users; reconciled to HMCTS IdP by email primary + employee number fallback per D9 / Risk #14). Loads via the Reference Data API and Authorisation API (not direct DB writes; not Flyway). Per-run reconciliation reports under `migration/reports/`; `unmatched/` bucket with explicit handling decisions (drop / hold / manual map). Re-runs are idempotent and gated per wave.

**Component(s)**: `nji-architecture/migration/` (programme-level deliverable; not a runtime service).

**Primary FR/NFR coverage**: FR57; data side of FR58 (initial seed).

#### Phase 0 · Area: Business UI Foundation

**Scope**: `nji-ui` repo scaffolded (React + TypeScript + Vite + Vitest + Playwright). GOV.UK Design System base + HMCTS/NJI extensions. OIDC client wrapper (`HmctsIdpProvider`, `ProtectedRoute`, `useAuth`). HTTP client with auth header attachment and RFC 9457 error handling. Business-user Home shell with role-scoped navigation and Region/Area selector (FR55). axe-core CI for WCAG 2.2 AA gate. Per-phase E2E test suite scaffolding under `tests/e2e/`. **Excludes admin workflows** — Reference Data maintenance (FR6) and User & Role admin (FR4) live in `nji-admin-ui`, never here.

**Component(s)**: `nji-ui` (shared + business Home shell only — per-domain modules land in their respective phases).

**Primary FR/NFR coverage**: FR55 *(business Home shell)*, FR56 *(modern UI stack)*, NFR17, NFR18, NFR19.

#### Phase 0 · Area: Admin UI Foundation

**Scope** *(new 2026-05-11)*: `nji-admin-ui` repo scaffolded with the **same stack as `nji-ui`** (React + TypeScript + Vite + Vitest + Playwright; GOV.UK Design System base; OIDC client wrapper; RFC 9457 error handling) but **deployed independently** to its own Static Web App / CDN on a distinct hostname (e.g. `admin.nji.hmcts.gov.uk`). Distinct accent in the header/nav to make the admin surface visually unambiguous.

**MVP admin modules built in Phase 0:**

- **Reference Data maintenance** (FR6) — list/edit/create flows for Regions, Offices, judicial vocabularies (12 tables), calendar / financial-year boundaries. Named-owner sign-off workflow per FR6. Calls `nji-reference-data` API.
- **User & Role admin** (FR4) — list and search users (migrated + new), edit role and Region/Area scope assignments, view per-user effective permissions. Calls `nji-authorisation` API.

**Future admin surfaces reserved as module placeholders only** (not built at MVP):

- `modules/activation/` — per-region activation flag dashboard (FR58 admin side)
- `modules/migration-reports/` — Phase 0 reconciliation report viewer (FR57)
- `modules/audit/` — post-MVP user-action audit viewer (D7 roadmap)

**Why a separate repo, not just a separate route inside `nji-ui`:**

1. **Audience separation** — admin role is a system administrator, not RSU/Court/Judge/Finance/MI. Different mental model, different training, different change-management posture.
2. **Independent rollout** — admin surface changes (e.g. adding a new vocabulary table) can deploy without touching the business surface or vice versa.
3. **CODEOWNERS** — distinct review teams.
4. **No accidental nav-leakage** — admin-only screens cannot accidentally appear in a business user's navigation via misconfiguration. Authorisation gating is enforced server-side too, but the repo-level boundary is defence-in-depth.
5. **Consistency with backend polyrepo discipline** — same logic as the per-service backend repos: minimise shared code, accept duplication, gain independence.

**Component(s)**: `nji-admin-ui` (full repo: shared + Reference Data module + User & Role module at MVP).

**Primary FR/NFR coverage**: FR4 *(UI surface)*, FR6 *(UI surface)*, FR56 *(stack)*, NFR17, NFR18, NFR19. Also AR42–AR45b.

### Phase 1 — Judge

#### Phase 1 · Area: Judge Records & Working Patterns

**Scope**: `nji-judge` backend service + `judge/` UI module in `nji-ui`. Judge profile CRUD (search/filter, personal details, judge type, base office, active/inactive, role-specific data). Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split (100% sum constraint), per-day work-type pattern. Forward-sitting generation up to next 31st March from working pattern, preserving prior absences. Tickets per judge role. Full-time ↔ part-time conversion. Same-Region base-location switching (cross-Region is out-of-system). Off-circuit / cross-Region judge linking for booking purposes. Demo: Journey *(stakeholder per-module demo of Judge management)*.

**Component(s)**: `nji-judge`, `nji-ui/src/modules/judge/`.

**Primary FR/NFR coverage**: FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18.

### Phase 2 — Absence

#### Phase 2 · Area: Absence Workflow

**Scope**: `nji-absence` backend + `absence/` UI module. Absence recording (start/end date, partial-day, type from controlled list, NTBF flag). Auto-confirmed (judicial team) vs confirmation-required (Court / judge) distinction; confirmation can trigger acknowledgement email via Notification. Sickness extension (no new record) vs non-sickness (new record required). NTBF and *needs fee-paid cover* flags. Hook to Vacancy auto-creation (Vacancy itself lives in Phase 3 — Phase 2 stubs the call; Phase 3 wires it).

**Component(s)**: `nji-absence`, `nji-ui/src/modules/absence/`.

**Primary FR/NFR coverage**: FR19, FR20, FR21, FR22.

### Phase 3 — Vacancy

#### Phase 3 · Area: Vacancy & Cover

**Scope**: `nji-vacancy` backend + `vacancy/` UI module. Auto-creation from approved absence with cover (R4, pre-populated with judge type, work type, ticket, dates). Standalone vacancies. Per-day breakdown editing (cancel individual days with captured reason; extend / shorten period). `markFilled` endpoint called by Booking (Phase 4) — implemented as a direct DB UPDATE per architecture Principle 1 with explicit cross-service grants. Vacancy days locked once a booking is recorded. Fee-paid judge filter as advertising hint (advertising itself is out-of-system). Cancel / close.

**Component(s)**: `nji-vacancy`, `nji-ui/src/modules/vacancy/`.

**Primary FR/NFR coverage**: FR23, FR24, FR25, FR26, FR27, FR28.

### Phase 4 — Booking

#### Phase 4 · Area: Booking Management

**Scope**: `nji-booking` backend + `booking/` UI module. Fee-paid booking creation (linked to vacancy or standalone), capturing judge, court, date, session type, booking type, work type. Same-transaction `Vacancy.markFilled` orchestration (R5, Principle 1 — in-process direct DB UPDATE via per-service grant). Status tracking (planned / provisional / confirmed / cancelled / rejected) with cancellation reason. Booking acknowledgement emails to fee-paid judges (batched overnight or *Create and Email Now*). Y/N answer at booking time when fee entitlement is *Ask when booking*. Double-booking prevention via DB unique constraints over overlapping sessions (FR34).

**Component(s)**: `nji-booking`, `nji-ui/src/modules/booking/`.

**Primary FR/NFR coverage**: FR29, FR30, FR31, FR32, FR33, FR34.

### Phase 5 — Sitting

#### Phase 5 · Area: Sitting Management

**Scope**: `nji-sitting` backend + `sitting/` UI module. Planned-sitting generation from working patterns (court, date, work type). Region/Office/judge-type/judge/date-range filtering. Confirmation (took-place / cancelled / rejected) with actual work-type recording. AM/PM session split within a single day (different work types). Ad-hoc sittings for salaried judges (including DJ(MC)s and Legal Advisers in County Courts). Verifier sign-off; once verified, data is read-only. Post-verification amendment via a UI **re-open** action gated by RBAC (RSU Admin only at MVP, distinct from confirmer and from standard Verifier) with mandatory justification and full audit — no external RFC ticketing.

**Component(s)**: `nji-sitting`, `nji-ui/src/modules/sitting/`.

**Primary FR/NFR coverage**: FR35, FR36, FR37, FR38, FR39, FR40.

> **End-of-Phase-5 demo gate**: Journey 2 (Court daily sitting confirmation) becomes demoable.

### Phase 6 — Payment

#### Phase 6 · Area: Payment Processing & Reconciliation

**Scope**: `nji-payment` synchronous backend + `payment/` UI module. Authorised users list confirmed bookings and salaried sittings filterable by Region/Office/judge/date range/lifecycle status. Generated schedule review (pre/post dispatch). Reconciliation marking (Finance / RSU) with notes for mismatches; once fully reconciled, payment cannot be re-requested. Versioned content-type API for the payment schedule (`application/vnd.hmcts.jfeps+json` vs `+xlsx`). Hard architectural constraints: **no bank details** (FR47), **no case-level data**.

**Component(s)**: `nji-payment` (sync API), `nji-ui/src/modules/payment/`.

**Primary FR/NFR coverage**: FR41 *(list/review surface)*, FR44, FR46, FR47, NFR21, NFR35.

#### Phase 6 · Area: Payment Batch

**Scope**: `nji-payment-batch` scheduled component (configurable cron; typically end-of-week). Authenticates via OAuth `client_credentials` against `nji-mock-auth` (non-prod) — production service-principal issuer deferred per gaps.md G7.1 (default recommendation: Azure Workload Identity). SQL JOIN over confirmed bookings + sittings without an existing payment record. Generates JFEPS-compatible Excel and dispatches to Payment Authoriser via `nji-notification` (using its service-principal token). Natural-key uniqueness on `(payment_cycle_id, booking_id)` for idempotent re-runs. No user interaction. Operational contingency to fall back to manual handling within a payment cycle if NJI is unavailable.

**Component(s)**: `nji-payment-batch` (deployed alongside `nji-payment`).

**Primary FR/NFR coverage**: FR42 *(revised v2.6)*, FR43 *(revised v2.6)*, FR45.

> **End-of-Phase-6 demo gate**: Journey 1 (RSU cover-creation through payment — the canonical operational cycle) becomes demoable.

### Phase 7 — Itineraries

#### Phase 7 · Area: Itineraries Read Model

**Scope**: `nji-itinerary` backend + Itinerary UI views in `nji-ui`. **No own tables** — SQL JOINs across `judges`, `absences`, `vacancies`, `bookings`, `sittings`. Court Itinerary (monthly / annual for Office + Financial Year + Month). Judge Itinerary scoped by Authorisation per R2 (judges see only their own; courts see their office; RSU sees their region). Forward Look across Region with paged / filtered access. Clickable drill into underlying record (Sitting, Absence, Vacancy, Booking). Copy / export to Excel and PDF. Strategy A degraded-mode contract: if NFR8 (≤ 30 s p95) is breached, fall back to Strategy C cached projection (designed but not built unless Phase 7 measurement shows the breach).

**Component(s)**: `nji-itinerary`, `nji-ui/src/modules/itinerary/`.

**Primary FR/NFR coverage**: FR48, FR49, FR50, FR51, FR52, NFR8, NFR37.

> **End-of-Phase-7 demo gate**: Journey 3 (Judge views itinerary) becomes demoable.

### Phase 8 — MI Feed & Reporting

#### Phase 8 · Area: MI Feed & Reporting

**Scope**: `nji-mi-feed` backend + Reports UI module in `nji-ui`. **No own tables** — SQL JOINs over the shared schema. Fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report and same parameter shape as APEX. MI Feed REST API for external consumers (DA&I post-MVP, future programmes). **Aggregate-only by contract** (FR54, NFR23) — no case-level data in any read model or report under any consumer authorisation.

**Component(s)**: `nji-mi-feed`, `nji-ui/src/modules/reports/`.

**Primary FR/NFR coverage**: FR53, FR54, NFR23.

> **End-of-Phase-8 demo gate**: Journey 4 (DA&I MI Feed API consumer) becomes demoable post-MVP onboarding.

### Phase 9+ — Pilot Rollout (Wave 1) and Subsequent Waves

#### Phase 9+ · Area: Pilot Rollout & Subsequent Waves

**Scope**: Per-region phased activation — flip `auth_user_activation_flags` for the region's users (FR58) once that region's feature-parity gate is passed. Manual UAT execution per role per region (FR61): RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI walk through per-service UAT scripts (under `docs/uat/` in each domain service repo) side-by-side against APEX; sign-off per role per region is the wave-cutover gate. Per-wave rollback playbook (NFR36): documented path returning the region to APEX within one operational cycle if the gate is breached post-cutover. Cross-region manual coordination during partial rollout (Risk #1 mitigation; operational, not application-level). Reference Data + Users/Roles ETL re-run for incremental activation per wave (architecture/migration ownership). Wave 1 is the Pilot; Phases 10..N are subsequent regions until all regions are on NJI and APEX is retired (D8).

**Component(s)**: Programme-level (manual UAT scripts, runbooks, activation orchestration). Cross-region edge case (Journey 5) handled out-of-system per Risk #1 — no application capability built.

**Primary FR/NFR coverage**: FR58 *(activation orchestration)*, FR61, NFR36, NFR38, NFR41. Closes the MVP.

---

**Next step (Step 2 of this workflow)**: For each Phase × Area row above, design one or more concrete epics with an explicit goal, story breakdown, and Gherkin-style acceptance criteria. The phase/area framework above is the spine; Step 2 fleshes it out.
