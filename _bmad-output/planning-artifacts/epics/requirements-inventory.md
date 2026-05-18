---
parent: 'epics/index.md'
purpose: 'All Functional, Non-Functional, Architecture-derived, and UX Design requirements for RAM Pathfinder'
sourceDocuments:
  - 'planning-artifacts/prd.md'
  - 'planning-artifacts/architecture.md (whole + architecture/ folder)'
---

# Requirements Inventory

## Functional Requirements

### Identity & Authorisation

- FR1: Authenticated users access RAM Pathfinder via HMCTS IdP single sign-on; password, session, and account lifecycle are owned by the IdP and not duplicated in RAM Pathfinder.
- FR2: RAM Pathfinder's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- FR3: Authorised users can retrieve their effective permissions for their authenticated session.
- FR4: System administrators can update role and Region/Area assignments for migrated and new users.
- FR5 *(post-MVP per v2.5)*: External machine-to-machine consumers require an authentication mechanism. At MVP, no machine-to-machine consumers are in scope; mechanism for genuine service-principal authentication is a post-MVP open question (see `architecture/gaps.md` G7).

### Foundational Data Management

- FR6: RSU users can view and maintain Reference Data lists — Regions, Offices, judicial vocabularies, calendar / financial-year boundaries — with named-owner sign-off on changes.
- FR7 *(revised 2026-05-11)*: Every RAM Pathfinder service reads Reference Data via **direct SQL** on the shared schema's Reference Data tables (15 tables, SELECT-granted to each service's DB role) — no client class, no API fan-out, no cache (per architecture Principle 2). Reference Data is the **single writer** — all writes (Phase 0 ETL load + ongoing RSU maintenance per FR6) go through the versioned Reference Data API. No service holds duplicate or cached copies of Reference Data in its own tables.
- FR8 *(revised v2.2)*: Cross-service runtime policy values are stored in a shared `configuration_values` infrastructure table, schema-managed by `ram-architecture`'s Flyway baseline migration and SELECT-granted to every RAM Pathfinder service DB role. Per-service config uses Spring profiles + `application.yml` + Azure Key Vault.
- FR9: RAM Pathfinder dispatches transactional emails (booking acknowledgements, absence acknowledgements, payment schedules) via HMCTS email infrastructure, with a delivery log retained.

### Judge Records & Working Patterns

- FR10: RSU users can search and filter judges by name, base location, location type, and judge type.
- FR11: RSU users can maintain judge profiles, including personal details, judge type, base office, active/inactive status, and role-specific data (payroll number, retirement date, fee entitlement, London weighting, name-for-itinerary, heading).
- FR12: Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- FR13: RAM Pathfinder auto-populates judge itineraries up to the next 31st March from the working pattern, preserving any prior absences.
- FR14: RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- FR15: RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- FR16: RAM Pathfinder validates that jurisdictional split percentages total 100% before saving.
- FR17: RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- FR18: Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

### Absence Workflow

- FR19: Authorised users (RSU, Court, Judges where permitted) can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- FR20: RAM Pathfinder distinguishes auto-confirmed absences (from judicial teams) from those requiring confirmation (from Courts or judges); confirmation can trigger an acknowledgement email.
- FR21: Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- FR22: Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

### Vacancy & Cover

- FR23: RAM Pathfinder auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- FR24: Authorised users can create standalone vacancies independent of any absence.
- FR25: Authorised users can edit a vacancy's daily breakdown — cancel individual days with a captured reason; extend or shorten the period.
- FR26: RAM Pathfinder marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- FR27: RAM Pathfinder surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is performed out-of-system by judicial teams.
- FR28: Authorised users can cancel or close vacancies (e.g. when a parent absence becomes NTBF).

### Booking Management

- FR29: Authorised users can create fee-paid bookings (linked to a vacancy or standalone), capturing judge, court, date, session type (full / AM / PM / evening / reserved-matter), booking type, and work type.
- FR30: Booking creation marks the linked vacancy as filled within the same transaction when a `vacancyId` is supplied (in-process direct DB update on the `vacancies` row using a per-service DB role grant, per architecture Principle 1).
- FR31: RAM Pathfinder tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- FR32: RAM Pathfinder sends booking acknowledgement emails to fee-paid judges, batched overnight or sent immediately via *Create and Email Now*.
- FR33: RAM Pathfinder requires a Y/N answer at booking time when a judge's fee entitlement is *Ask when booking*.
- FR34: RAM Pathfinder prevents double-booking of fee-paid judges for overlapping sessions.

### Sitting Management

- FR35: RAM Pathfinder generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- FR36: Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- FR37: Authorised users can confirm that a sitting actually took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- FR38: Authorised users can split a sitting into AM/PM with different work types within a single day.
- FR39: Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- FR40 *(revised 2026-05-11)*: Verifiers can verify confirmed sittings; once verified, the data is read-only. Amendments after verification require **re-opening** via a UI re-open action gated by a distinct authorised role — different from the original confirmer (SIT-NFR-02) and from a standard Verifier (at MVP, the permission is granted to RSU Admin only). The action captures a mandatory justification field and is fully audited. No external Request-for-Change ticketing — re-open is a first-class UI action with RBAC controls.

### Payment & Reconciliation

- FR41 *(revised v2.6)*: Authorised users can list confirmed bookings and salaried sittings, filterable by Region/Office, judge, date range, and payment lifecycle status (pending, requested, paid, reconciled).
- FR42 *(revised v2.6)*: RAM Pathfinder's payment-processing batch (`ram-payment-batch`, scheduled cron — typically end-of-week) automatically marks eligible bookings as *payment requested* and creates the corresponding `payments` + `payment_schedules` records via SQL JOIN; no user click required.
- FR43 *(revised v2.6)*: The payment batch generates JFEPS-compatible payment schedules and dispatches them as Excel attachments to a configured Payment Authoriser via email (using its service-principal identity to call the Notification API).
- FR44: RAM Pathfinder exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`); the JFEPS shape evolves independently of Payment internals.
- FR45: RAM Pathfinder prevents double submission of the same booking for payment via natural-key unique constraint on `(payment_cycle_id, booking_id)`; re-runs of the same cycle are idempotent.
- FR46: Authorised users (Finance, RSU) can flag payments as reconciled, capturing notes for mismatches; once fully reconciled, a payment cannot be re-requested.
- FR47: RAM Pathfinder does not store or expose bank details for any judge — those remain in the finance system.

### Itineraries & Reporting (Read Models)

- FR48: Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month, showing sittings, bookings, vacancies, and NTBF absences for each day.
- FR49: Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation (judges see only their own; courts see their office; RSU sees their region).
- FR50: Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- FR51: Itinerary cells are clickable and drill into the underlying record (Sitting, Absence, Vacancy, or Booking).
- FR52: Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- FR53: RAM Pathfinder provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report.
- FR54: RAM Pathfinder exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); MI Feed responses contain no case-level data and are aggregate-only by contract.

### Platform Operations & Migration

- FR55: Authenticated users land on a Home page showing role-scoped navigation, Region/Area selector, summary tiles for the selected scope (judges, absences, vacancies, pending payments, payments made, unreconciled), and contextual help.
- FR56: RAM Pathfinder's UI replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA accessibility standards.
- FR57: A Phase 0 Data Migration ETL takes Reference Data and active user records from APEX, transforms them into RAM Pathfinder's own shape, and loads them via the RAM Pathfinder Reference Data API and Authorisation API. Migrated user records are keyed to HMCTS IdP principals (email primary, employee number fallback). Phase 0 deliverable with named-owner sign-off; unmatched records flagged for explicit handling.
- FR58: RAM Pathfinder supports per-region phased activation — a region's user accounts can be activated for RAM Pathfinder use only when that region's feature-parity gate is passed; activation is a flag flip on `auth_user_activation_flags`, not a data migration.
- FR59: Every RAM Pathfinder service exposes a versioned API contract, RFC 9457 problem-details for errors, and a published OpenAPI specification. Deprecation signalling uses `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) headers.
- FR60: Every RAM Pathfinder service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- FR61 *(revised 2026-05-06)*: Every RAM Pathfinder domain service has a manual user acceptance test (UAT) script capturing the workflows and edge cases an APEX-experienced user verifies against APEX before that service's region rollout. UAT performed by users from in-region applicable roles, recorded with explicit per-role sign-off. No automated APEX-comparison harness.

## Non-Functional Requirements

### Performance

- NFR1 — Static page load: ≤ 3 s for static UI loads (e.g. Home initial render).
- NFR2 — Dashboard refresh: ≤ 5 s when Region/Area selection changes.
- NFR3 — List / filter operations: ≤ 10 s for typical operational lists at Region scope.
- NFR4 — Batch / annual operations: ≤ 15 s (e.g. annual itinerary render, batch payment-request processing).
- NFR5 — Reports / Forward Look: ≤ 30 s for standard report parameters and for the Forward Look view at Region scope.
- NFR6 — Single-resource API read: ≤ 500 ms p95.
- NFR7 — Domain write API: ≤ 1 s p95 for typical write operations.
- NFR8 — Federated read (Itinerary, Forward Look): ≤ 30 s p95 under Strategy A (SQL JOIN over shared schema).
- NFR9 — Capacity: concurrent users per region ~50–100; national ~200–500 once all regions migrated.

### Security

- NFR10 — Transport encryption: Latest TLS only on every endpoint; HTTP-only endpoints rejected.
- NFR11 — Data-at-rest encryption: All personal data encrypted at rest.
- NFR12 *(revised v2.6)*: Human users authenticated via HMCTS IdP SSO (per FR1). Inter-service authentication for user-initiated calls is JWT propagation, validated by `JWTFilter` against IdP JWKS. Batch / scheduled components use OAuth 2.0 `client_credentials` against `ram-mock-auth` in non-prod; production issuer is deferred per gaps.md G7.1.
- NFR13 — Authorisation enforcement: Every API call resolves principal's roles + Region/Area scope through the Authorisation service; no operation bypasses this check.
- NFR14 — Forbidden data scope: No bank details stored or exposed (PAY-NFR-05). No case-level data in any read model or report (REP-BR-NFR-03).
- NFR15 — Government Functional Standard 7 alignment: protective marking, access control, secure development practices.
- NFR16 — Secret management: Service credentials, signing keys, integration secrets in Azure Key Vault; never in source control or env-baked images.

### Accessibility

- NFR17 — WCAG 2.2 Level AA: Every UI page meets WCAG 2.2 Level AA; tested per UI page in each domain phase before that phase's gate is passed.
- NFR18 — Assistive technology compatibility: Keyboard navigation, ARIA labels, screen-reader compatibility per HMCTS accessibility standards.
- NFR19 — Public Sector Bodies Accessibility Regulations 2018: compliance including publication of an accessibility statement.

### Integration

- NFR20 — HMCTS IdP integration: Hard Phase 0 dependency. RAM Pathfinder integrates with whichever AuthN protocol the HMCTS IdP exposes (OIDC or SAML).
- NFR21 — JFEPS / Liberata unchanged: Payment schedule format (JFEPS-compatible Excel), email-to-Authoriser delivery, authoriser-forwards-to-Liberata preserved exactly as APEX.
- NFR22 — HMCTS email infrastructure: Outbound transactional emails dispatch via HMCTS email; overnight batch acceptable for booking acks.
- NFR23 — DA&I MI Feed: Aggregate-only REST API contract; no case-level data under any consumer authorisation.
- NFR24 — eLinks / HR systems: No automated integration in MVP scope.

### Observability (MVP minimum per D7)

- NFR25 — Structured logging: Every service emits structured logs with consistent fields, correlation IDs threaded through service-to-service calls, defined error-categorisation taxonomy.
- NFR26 — Log retention: Logs retained sufficient for pilot incident triage; specific period set in Phase 0 within HMCTS data-retention policy.
- NFR27 — Log ingestion: Logs ingested into Azure-native logging (Application Insights / Log Analytics).
- NFR28 — Health and readiness probes: Every service exposes Kubernetes-compatible liveness/readiness endpoints (Spring Actuator).
- NFR29 — Roadmap commitments (post-MVP, not MVP): Structured user-action auditing per D7. Metrics and trace observability beyond logs is post-MVP.

### Data Privacy & Sovereignty

- NFR30 — UK GDPR / DPA 2018 compliance: Personal data scope limited to user/judge identity, contact details, payroll numbers, operational metadata. No case-level data anywhere.
- NFR31 — Data residency: All RAM Pathfinder services and data hosted in Azure UK regions only.
- NFR32 — Retention: Per HMCTS retention schedules. Migrated transactional history remains in APEX (D3).
- NFR33 — FOI scope: Aggregate operational data exposable per FOI; case-level data forbidden by contract.

### Reliability & Availability

- NFR34 — Operational availability: Available during HMCTS operational hours (typically 07:00–19:00 UK weekdays).
- NFR35 — Payment-cycle continuity: Zero failed JFEPS payment cycles attributable to RAM Pathfinder. Manual handling is operational contingency, not normal-mode expectation.
- NFR36 — Per-wave rollback: Each rollout wave has a documented rollback path within one operational cycle if the wave's gate is breached post-cutover.
- NFR37 — Strategy A degraded-mode contract: If federated read latency breaches NFR8, RAM Pathfinder degrades to Strategy C cached projection.
- NFR38 — HMCTS-judicial-region rollout isolation: Wave activation targeting one HMCTS judicial region does not affect users in other HMCTS regions. Enforcement via per-user `auth_user_activation_flags`. Production runs in a single Azure region (UK South) with multi-AZ HA. DR scope is an open gap per gaps.md G3.6.

### Maintainability

- NFR39 — API-as-Product standards: Versioned contracts, RFC 9457 problem-details, OpenAPI per service. Deprecation via RFC 9745 + RFC 8594.
- NFR40 — Per-service deployment unit: Each of the 11 services is independently deployable on Kubernetes; rolling updates per service per region without coupling.
- NFR41 — Behavioural-parity UAT suite: Every domain service has a manual UAT script. Sign-off per role per region is the wave gate. No automated parity test suite — automated CI is unit, integration (Testcontainers), and contract tests only.
- NFR42 — Postman collections: Each phase produces a Postman collection that exercises the phase's endpoints; versioned alongside the services.

## Additional Requirements

**(Derived from Architecture — these are technical / platform requirements that materially impact Epic and Story shape, particularly Epic 1 Story 1 service scaffolding.)**

### Repository strategy

- AR1 *(revised 2026-05-11)* — Polyrepo: **15 repositories** total — 11 production service repos + `ram-ui` (business-user-facing SPA) + `ram-admin-ui` (admin-facing SPA, separate from `ram-ui`) + `ram-architecture` + `ram-mock-auth`. Each repo has its own CI pipeline, CODEOWNERS, branch protection, and review policy. No monorepo, no Gradle root project. The two UI repos use the same stack and conventions but never share runtime code — admin workflows live exclusively in `ram-admin-ui` and never appear in `ram-ui`'s nav.

### Starter template (Story 1 of every service epic)

- AR2 *(revised 2026-05-15 per D10)* — Each RAM Pathfinder backend service is scaffolded from the **HMCTS Crime SpringBoot template** (`https://github.com/hmcts/spring-boot-template`) cloned via the `ram-scaffold.sh` script in `ram-architecture/scaffolding/`. The scaffolding script applies RAM Pathfinder conventions on top of the starter and is used at service-creation time only. **The `gh` CLI is NOT available in the engineering environment** — `ram-scaffold.sh` handles only local scaffolding + `git push` to a pre-created remote; all GitHub admin operations (repo creation, branch protection, team access) are performed manually via the GitHub web UI by the engineer **before** running `ram-scaffold.sh`. See AR51 + the runbook at `ram-architecture/runbooks/github-setup.md`.
- AR3 — Group ID `uk.gov.hmcts.ram`; artefact `ram-{service-name}`; package `uk.gov.hmcts.ram.{service-name}`. Default port 8082.
- AR4 — Initial commit for every new service is *"Scaffold RAM Pathfinder {service-name} from HMCTS starter"* — this is the first implementation story per service.

### Locked technology stack (carried from PRD; enumerated here as architecture-confirmed dependency versions)

- AR5 — Java 25 (LTS), Spring Boot 4.0.x, Gradle Groovy DSL with Gradle Wrapper, Spring Boot Gradle plugin 4.0.6, `io.spring.dependency-management:1.1.7`.
- AR6 — Lombok 1.18.46, MapStruct 1.6.3 for boilerplate reduction and DTO ↔ entity mapping.
- AR7 — `io.jsonwebtoken:jjwt:0.13.0` for JWT validation in custom `JWTFilter`; `org.owasp.encoder:encoder:1.4.0` for XSS-safe output encoding.
- AR8 — `springdoc-openapi` (Swagger Core) for OpenAPI 3.x generation. Per-service OpenAPI spec published as a Maven artefact `uk.gov.hmcts.ram:api-ram-{service}:{version}`.

### Build / supply-chain tooling (per HMCTS Crime template)

- AR9 — JaCoCo for code coverage reports.
- AR10 — `org.cyclonedx.bom:3.2.4` for SBOM (Software Bill of Materials) — supply-chain security.
- AR11 — `com.gorylenko.gradle-git-properties:2.5.7` to embed Git metadata in `/actuator/info`.
- AR12 — `com.github.ben-manes.versions:0.54.0` for dependency-update reports.
- AR13 — `com.avast.gradle.docker-compose:0.17.21` for local development with docker-compose-managed dependencies.

### Testing framework (per HMCTS Crime template)

- AR14 — Spring Boot Test (JUnit 5 via `junit-bom:6.0.3`), `spring-boot-testcontainers:4.0.6`, `testcontainers-postgresql:1.21.4`, `testcontainers-junit-jupiter:1.21.4` for integration tests with real PostgreSQL. AssertJ for assertions (transitive).
- AR15 — `spring-boot-starter-webmvc-test` for controller-layer testing.
- AR16 — Pact (or equivalent) for consumer-driven contract tests under `src/test/java/.../contract/` — added per service (not in HMCTS template baseline).
- AR17 — Spectral for OpenAPI lint in CI; ArchUnit for architectural fitness functions (table ownership, layer rules); Spotless + Checkstyle for code style.

### Data architecture

- AR18 — One global PostgreSQL 17 instance, **single shared schema**. Per-service DB roles with explicit grants. Table ownership encoded in table name (entity-plural for primary tables; service-prefix for service-internal) and enforced by ArchUnit fitness functions in CI.
- AR19 — Flyway per-service for DDL (each service owns the creation of its tables, columns, indexes, grants). Flyway baseline in `ram-architecture` owns the shared `configuration_values` table.
- AR20 — 39 RAM Pathfinder tables total grouped by owning service (15 Reference Data tables + 5 Authorisation tables + domain tables). See `architecture/data-tables.md` for the authoritative ownership mapping.
- AR21 — Retry safety uses native DB primitives: natural-key unique constraints, optimistic locking (`@Version`), pessimistic row locking. No custom idempotency-key tables.
- AR22 — Cross-service read patterns: direct SQL on Reference Data (no client class); Itinerary and MI Feed use SQL JOINs over the shared schema (no API fan-out, no cache).

### Infrastructure / deployment

- AR23 — Kubernetes on Azure AKS, production in UK South, multi-AZ HA. Container images → Azure Container Registry. Each of the 11 services is a containerised Spring Boot app.
- AR24 — Helm chart per service with `values-{env}.yaml` overlay per environment (`dev`, `staging`, `production`). Production values include `topologySpreadConstraints` for AZ spread, min replicas, multi-AZ node pool selection. Helm chart is **not** in HMCTS template baseline — added by `ram-scaffold.sh` per G1.4a.
- AR25 — Secrets in Azure Key Vault (via Spring Cloud Azure); no secrets in source control or env-baked images.
- AR26 — Per-environment configuration via Spring profiles + `application-{env}.yml`; cross-service runtime policy values in the shared `configuration_values` table (read-only via direct SQL).
- AR27 — Azure API Management (APIM) at the edge for rate limits, header injection, deprecation/`Sunset` policies, and ops-restricting `/actuator/*` namespace.

### CI / CD pipeline (per service)

- AR28 — GitHub Actions workflows in `.github/workflows/`: `ci.yml` (build + test + lint + ArchUnit + Spectral + Helm lint), `deploy-dev.yml` (auto on PR merge to main), `deploy-staging.yml` (manual approval), `deploy-production.yml` (per-region per-wave gated, manual UAT sign-off as gate).
- AR29 — `PULL_REQUEST_TEMPLATE.md` includes patterns checklist; `CODEOWNERS` defines RAM Pathfinder team + service-specific reviewers.

### Observability (MVP per D7)

- AR30 — Logstash Logback Encoder (`net.logstash.logback:logstash-logback-encoder:9.0`) for structured JSON logs with async appender. Logback config in `src/main/resources/logback-spring.xml`.
- AR31 — OpenTelemetry (`spring-boot-starter-opentelemetry`) for traces; OTel Collector → Azure Application Insights as the export target. Instrumentation key configured via env var `APPINSIGHTS_INSTRUMENTATIONKEY`.
- AR32 — `CorrelationIdFilter` at request entry; correlation ID propagated in service-to-service HTTP client calls and threaded through MDC into log statements.
- AR33 — Spring Boot Actuator endpoints exposed: `/actuator/health`, `/actuator/info`, `/actuator/readiness`. `/actuator/metrics` and Prometheus endpoint **not exposed at MVP** per D7. `/actuator/*` namespace ops-restricted at the APIM layer.

### Security implementation

- AR34 — Custom `JWTFilter` in `config/JWTFilter.java` validates JWTs against the IdP's JWKS endpoint (mock-auth for Phase 0–8; HMCTS IdP from pre-Phase-9 cutover). On each request, calls `ram-authorisation` `POST /authz/check` to resolve principal → roles + Region/Area scope; populates request-scoped `AuthDetails` bean.
- AR35 — `ram-mock-auth` is the OIDC issuer for dev/CI/integration: issues human-user JWTs via `authorization_code` and service tokens via `client_credentials` for batch components. Refuses to start with `production` profile (per gaps.md G5.3). **Never deployed to production.**
- AR36 — Batch / scheduled component authentication: `ram-payment-batch` authenticates via OAuth 2.0 `client_credentials` to obtain a service-principal token; uses that token to call `ram-notification`. Production issuer for service tokens is a deferred decision per gaps.md G7.1 (default recommendation: Azure Workload Identity given AKS deployment).
- AR37 — Boilerplate `@ControllerAdvice` (`GlobalExceptionHandler.java`) emitting RFC 9457 problem-details with `ProblemDetailFactory`. Domain exceptions: `{Resource}NotFoundException`, `BusinessRuleViolation`, `DependencyException`.

### API surface / standards

- AR38 — Versioning via URI path prefix (e.g. `/v1/judges`, `/v2/judges`) for major versions; backwards-compatible additions don't require a new path. Versioning policy itself is a Phase 0 deliverable per D1.
- AR39 — Deprecation signalling: `Deprecation` (RFC 9745) and `Sunset` (RFC 8594) response headers; injected at APIM layer per AR27.
- AR40 — Versioned content-type for Payment: `application/vnd.hmcts.jfeps+json` (canonical) or `application/vnd.hmcts.jfeps+xlsx` (Excel for Liberata workflow). JFEPS shape evolves independently of Payment internals.
- AR41 — Postman collections per phase under `postman/` in each service repo, named `ram-{service}-phase{N}.postman_collection.json`. Each phase produces a collection that exercises the phase's endpoints (per NFR42); also serves as executable API documentation pre-UI demo.

### UI stack (architecture decisions on top of PRD D4)

- AR42 *(revised 2026-05-11)* — **Two UI repos**, same stack, separated by audience: `ram-ui` (business-user-facing SPA) and `ram-admin-ui` (admin-facing SPA). Stack for both: React + TypeScript + Vite + Vitest (unit) + Playwright (E2E). `ram-ui` carries per-domain operational modules under `src/modules/{domain}/` (Judge, Absence, Vacancy, Booking, Sitting, Payment, Itinerary, Reports). `ram-admin-ui` carries admin modules under `src/modules/` — `reference-data/` (FR6) and `users-roles/` (FR4) at MVP; future hooks for `activation/` (FR58 admin), `migration-reports/` (FR57 viewer), `audit/` (D7 post-MVP). TanStack Query for HTTP. GOV.UK Design System base styling with HMCTS / RAM Pathfinder extensions; `ram-admin-ui` uses a distinct accent in the header/nav so the admin surface is visually unambiguous.
- AR43 — Auto-generated TypeScript clients per service from per-service OpenAPI specs (regenerated in CI). Clients live under `src/modules/{domain}/api/` and `api-clients/{service}-client/`. Each UI repo regenerates its own clients independently — no shared client package between `ram-ui` and `ram-admin-ui`.
- AR44 — `HmctsIdpProvider.tsx` (OIDC client wrapper) + `ProtectedRoute.tsx` + `useAuth.ts` hook in `src/shared/auth/`. HTTP client (`src/shared/api/httpClient.ts`) attaches auth header; `errorHandling.ts` translates RFC 9457 problem-details into UI display. Same pattern duplicated (not shared) across both `ram-ui` and `ram-admin-ui`. `ram-admin-ui`'s `ProtectedRoute` gates by admin role resolved via `ram-authorisation`'s `POST /authz/check`.
- AR45 *(revised 2026-05-11)* — E2E test suites: `ram-ui` has one Playwright suite per backend phase under `tests/e2e/phase-{N}-{domain}.spec.ts`; `ram-admin-ui` has one Playwright suite per admin module under `tests/e2e/{module}.spec.ts` (e.g. `reference-data.spec.ts`, `users-roles.spec.ts`). axe-core accessibility checks in each repo's `ci.yml`.
- AR45b *(new 2026-05-11)* — **Independent deployment for the two UI repos**: separate Helm charts, separate Azure Static Web Apps (or CDN) deployments, distinct hostnames (e.g. `ram.hmcts.gov.uk` for business surface; `admin.ram.hmcts.gov.uk` for admin surface). Admin surface can deploy without touching the business surface and vice versa. Both share the same backend services, same SSO, same Authorisation service.

### Phase 0 Data Migration ETL (not a runtime service)

- AR46 — ETL lives at `ram-architecture/migration/` (not as a runtime service; not in Flyway). Reads APEX dumps, transforms to RAM Pathfinder shape, and **calls RAM Pathfinder APIs** (`ram-reference-data` and `ram-authorisation`) to load.
- AR47 — Two ETL streams: `migration/reference-data/` (Regions, Offices, calendar, 12 vocabularies; signed off by named owners per Risk #13) and `migration/users-roles/` (active users, role/scope mappings; reconciled to HMCTS IdP by email primary, employee number fallback per D9 / Risk #14).
- AR48 — Per-run reconciliation reports under `migration/reports/` for named-owner sign-off. Unmatched user records flagged in `unmatched/` bucket with explicit handling decision (drop / hold / manual map).
- AR49 — ETL re-run per wave for incremental user activation. Re-runs are idempotent.

### Manual UAT (FR61 / NFR41 revised 2026-05-06)

- AR50 — Per-service manual UAT scripts live under `docs/uat/` in each domain service repo (markdown walkthroughs for APEX-experienced users to follow side-by-side against APEX). Not part of automated CI. Sign-off (per role per region) is the wave-cutover gate.

### Manual GitHub setup (new 2026-05-15 per D10)

- AR51 *(new 2026-05-15)* — The `gh` CLI is **not** available in the engineering environment. All GitHub admin operations (repo creation, branch protection, team / `CODEOWNERS` access, PR merges) happen **manually via the GitHub web UI** per the runbook at `ram-architecture/runbooks/github-setup.md`. The runbook is the canonical "before you scaffold a new RAM Pathfinder repo" checklist. The `ram-scaffold.sh` script (AR2) operates only locally and via plain `git` push to a remote the engineer has already created in the web UI. PRs are opened, reviewed, and merged via the web UI. This is a non-negotiable constraint of the engineering environment.

## UX Design Requirements

**(Not applicable — no UX design document was produced. UI requirements inherit directly from PRD FR55, FR56 and architecture decisions AR42–AR45. The 2026-05-06 readiness report documents this as an accepted gap.)**
