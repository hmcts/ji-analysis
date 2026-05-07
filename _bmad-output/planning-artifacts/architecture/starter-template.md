---
parent: ../architecture.md
title: HMCTS Crime SpringBoot starter — initialisation, build tool, dependency inventory, NJI conventions
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Starter Template — Initialisation Flow, Build Tool, Dependency Inventory, NJI Conventions

> Sibling of [`../architecture.md`](../architecture.md). The parent file's *Starter Template Evaluation* section keeps the high-level rationale ("HMCTS internal Java/Spring Boot starter — selected"); this file keeps the implementation-detail content that backs that decision.

The starter selection rationale and the comparison table of options considered live in [`../architecture.md`](../architecture.md). The content below is the per-service initialisation flow, the dependency inventory the starter brings, and the NJI-specific conventions overlaid by the scaffolding script.

## Initialisation Flow (per service)

Each new NJI service is scaffolded from the HMCTS starter, then customised for its specific domain. The exact CLI form depends on what HMCTS publishes; the conceptual flow is:

```bash
# Conceptual — actual command per HMCTS published documentation
git clone https://github.com/hmcts/spring-boot-template.git nji-{service-name}
cd nji-{service-name}
git remote remove origin
git remote add origin <new-repo-url>

# Rename package, artifact, application name to match the service
# (specific tooling / scripts per HMCTS starter conventions)
./scripts/rename uk.gov.hmcts.nji.{service-name}

# Verify build
./gradlew build

# Initial commit on new repo
git add . && git commit -m "Scaffold NJI {service-name} from HMCTS starter"
git push -u origin main
```

The team should produce a small **NJI scaffolding script** (a thin wrapper over the HMCTS starter clone-and-rename steps, plus NJI-specific defaults like Azure UK region selection, default Application Insights workspace, and naming conventions) so that creating service N+1 takes minutes, not hours. The scaffolding script is *not* a runtime dependency; it is a one-shot tool used at service-creation time.

## Build Tool: Gradle

**Selected: Gradle** for all 11 services and the scaffolding script itself.

Rationale:

- More flexible for the per-service repo + occasional cross-repo conventions pattern.
- Faster incremental builds; better for the per-service Postman collection generation and OpenAPI artefact publication.
- Aligns with the HMCTS starter's typical default (HMCTS Java templates have used Gradle).
- Settled once for all 11 services for consistency.

## Architectural Decisions Provided by Starter

The HMCTS Crime SpringBoot template provides (verified by review on 2026-05-06):

**Language & Runtime:**

- Java 25 (current LTS).
- Spring Boot 4.0.x (released Q4 2025).
- Gradle build with Gradle Wrapper (`gradlew`) committed.

**Build Tooling (per HMCTS Crime SpringBoot template):**

- **Gradle Groovy DSL** with Gradle Wrapper.
- **Spring Boot Gradle plugin 4.0.6** for fat-jar packaging.
- **`io.spring.dependency-management:1.1.7`** for BOM-based dependency management.
- **JaCoCo** plugin for code coverage reports.
- **`org.cyclonedx.bom:3.2.4`** for SBOM (Software Bill of Materials) generation — supply-chain security.
- **`com.gorylenko.gradle-git-properties:2.5.7`** to embed Git metadata in `/actuator/info` (and inspires `/capabilities`).
- **`com.github.ben-manes.versions:0.54.0`** for dependency-update reports.
- **`com.avast.gradle.docker-compose:0.17.21`** for local development with docker-compose-managed dependencies.
- Gradle multi-task layout: `build`, `test`, `bootRun`, `bootJar`, `dockerBuild`, `helmLint`.

**Testing Framework (per HMCTS Crime SpringBoot template):**

- **Spring Boot Test** (JUnit 5 via `junit-bom:6.0.3`).
- **`spring-boot-testcontainers:4.0.6`** + **`testcontainers-postgresql:1.21.4`** + **`testcontainers-junit-jupiter:1.21.4`** for integration tests with real PostgreSQL.
- **AssertJ** for assertions (transitively via Spring Boot Test).
- **`spring-boot-starter-webmvc-test`** for controller-layer testing.
- Pact or similar for consumer-driven contract tests — added per service (not in HMCTS Crime template).

**Observability (per HMCTS Crime SpringBoot template):**

- **Logstash Logback Encoder** (`net.logstash.logback:logstash-logback-encoder:9.0`) for structured JSON logs; async appender.
- **OpenTelemetry** (`spring-boot-starter-opentelemetry`) for traces; OTel Collector → Azure Application Insights as the export target.
- Correlation ID filter at request entry; correlation ID propagation in service-to-service calls.
- Spring Boot Actuator endpoints (`/actuator/health`, `/actuator/info`, `/actuator/readiness`); `/actuator/metrics` and Prometheus endpoint not exposed at MVP per D7.
- Application Insights instrumentation key configured via env vars (`APPINSIGHTS_INSTRUMENTATIONKEY`).

**Security defaults (per HMCTS Crime SpringBoot template):**

- TLS-only configuration (no HTTP).
- Secure header defaults.
- **Custom `JWTFilter`** (using `io.jsonwebtoken:jjwt:0.13.0`) for JWT validation; integrates with NJI Authorisation service per Step 4 of [`../architecture.md`](../architecture.md).
- **`org.owasp.encoder:encoder:1.4.0`** for XSS-safe output encoding.
- Azure Key Vault integration for secret retrieval (added per service via Spring Cloud Azure — not in template baseline).

**Deployment:**

- Dockerfile (multi-stage build, JDK image) — provided by HMCTS template.
- Standard health probe configuration via Spring Actuator — provided by HMCTS template.
- **Helm chart for AKS deployment is NOT in the template baseline** (G1.4a in [`./gaps.md`](./gaps.md)) — NJI scaffolding script adds it.

**Code Organisation:**

- Standard Gradle directory layout: `src/main/java`, `src/main/resources`, `src/test/java`.
- Per-service top-level package: `uk.gov.hmcts.nji.{service-name}` (e.g. `uk.gov.hmcts.nji.judge`, `uk.gov.hmcts.nji.booking`).
- Standard Spring Boot application class with `@SpringBootApplication`.
- Service internals follow a layered approach (controller / service / repository) — the precise pattern is settled in [`./conventions.md`](./conventions.md).

**Productivity libraries (per HMCTS Crime SpringBoot template):**

- **Lombok 1.18.46** for boilerplate reduction (`@Data`, `@Builder`, `@RequiredArgsConstructor`, `@Slf4j`, etc.).
- **MapStruct 1.6.3** for compile-time bean mapping (DTO ↔ entity); pairs naturally with the per-service `dto/` and `domain/` package layout.

## Per-service NJI Conventions (encoded in scaffolding script, not in shared library)

The scaffolding script applies NJI-specific defaults on top of the HMCTS starter:

- Group ID: `uk.gov.hmcts.nji`.
- Naming: artefact `nji-{service-name}`, package `uk.gov.hmcts.nji.{service-name}`.
- Default Azure UK region: UK South (UK West for DR if needed — programme decision).
- Default Application Insights workspace: NJI shared workspace (HMCTS-provided).
- Default Reference Data and Authorisation service URL placeholders.
- Boilerplate `@ControllerAdvice` for RFC 7807 error envelopes.
- Boilerplate `CapabilitiesController` (`@RestController` at root path `/capabilities`) — consumer-facing API-as-Product contract endpoint, distinct from Spring Actuator (ops). Build metadata from `gradle-git-properties`; per-service version/deprecation/feature fields from `application.yml`. Response shape per Step 4 *API Documentation* in [`../architecture.md`](../architecture.md).
- Boilerplate `JWTFilter` + `AuthDetails` bean (per HMCTS template pattern); modified to call NJI Authorisation service per request (NJI variance from template's claims-only approach — required by FR58).
- Boilerplate Reference Data direct-SQL access (JPA entities mapped to whitelisted Reference Data tables — 15 tables, see [`./data-tables.md`](./data-tables.md): `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables); no client class.
- *(removed 2026-05-06)* Boilerplate APEX-comparison test base class — retracted. Behavioural parity is verified via **manual UAT performed by APEX-experienced users** (FR61 / NFR41 revised). Per-service UAT scripts live under `docs/uat/` in the service repo, not as test code.
- Default port `8082` (per HMCTS template).

These are **scaffolded once per service**; subsequent edits live in the service's own repo. There is no upstream library that can force a redeployment.

**Note:** Project initialisation using these commands and the scaffolding script should be the first implementation story per service.
