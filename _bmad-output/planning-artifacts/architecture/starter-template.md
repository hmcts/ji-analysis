---
parent: ../architecture.md
title: HMCTS Crime SpringBoot starter — initialisation, build tool, dependency inventory, RAM Pathfinder conventions
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Starter Template — Initialisation Flow, Build Tool, Dependency Inventory, RAM Pathfinder Conventions

> Sibling of [`../architecture.md`](../architecture.md). Selection rationale lives in the parent. This file holds the per-service initialisation flow, dependency inventory, and RAM Pathfinder conventions overlaid by the scaffolding script.

## Initialisation Flow (per service)

Each new RAM Pathfinder service is scaffolded from the HMCTS starter, then customised. The exact CLI depends on what HMCTS publishes; conceptual flow:

```bash
# Conceptual — actual command per HMCTS published documentation
git clone https://github.com/hmcts/spring-boot-template.git ram-{service-name}
cd ram-{service-name}
git remote remove origin
git remote add origin <new-repo-url>

# Rename package, artifact, application name to match the service
# (specific tooling / scripts per HMCTS starter conventions)
./scripts/rename uk.gov.hmcts.ram.{service-name}

# Verify build
./gradlew build

# Initial commit on new repo
git add . && git commit -m "Scaffold RAM Pathfinder {service-name} from HMCTS starter"
git push -u origin main
```

**RAM Pathfinder scaffolding script:** a thin wrapper over the HMCTS starter clone-and-rename steps, with RAM Pathfinder-specific defaults (Azure UK region, Application Insights workspace, naming conventions). Used at service-creation time only — not a runtime dependency.

## Build Tool: Gradle

Gradle for all 11 services and the scaffolding script.

Reasons:

- Flexible for per-service repos + occasional cross-repo conventions.
- Fast incremental builds; works well for per-service Postman collection generation and OpenAPI artefact publication.
- Matches the HMCTS starter's typical default.
- Consistent across all services.

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
- **`com.gorylenko.gradle-git-properties:2.5.7`** to embed Git metadata in `/actuator/info`.
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
- **Custom `JWTFilter`** (using `io.jsonwebtoken:jjwt:0.13.0`) for JWT validation; integrates with RAM Pathfinder Authorisation service per Step 4 of [`../architecture.md`](../architecture.md).
- **`org.owasp.encoder:encoder:1.4.0`** for XSS-safe output encoding.
- Azure Key Vault integration for secret retrieval (added per service via Spring Cloud Azure — not in template baseline).

**Deployment:**

- Dockerfile (multi-stage build, JDK image) — provided by HMCTS template.
- Standard health probe configuration via Spring Actuator — provided by HMCTS template.
- **Helm chart for AKS deployment is NOT in the template baseline** (G1.4a in [`./gaps.md`](./gaps.md)) — RAM Pathfinder scaffolding script adds it.

**Code Organisation:**

- Standard Gradle directory layout: `src/main/java`, `src/main/resources`, `src/test/java`.
- Per-service top-level package: `uk.gov.hmcts.ram.{service-name}` (e.g. `uk.gov.hmcts.ram.judge`, `uk.gov.hmcts.ram.booking`).
- Standard Spring Boot application class with `@SpringBootApplication`.
- Service internals follow a layered approach (controller / service / repository) — the precise pattern is settled in [`./conventions.md`](./conventions.md).

**Productivity libraries (per HMCTS Crime SpringBoot template):**

- **Lombok 1.18.46** for boilerplate reduction (`@Data`, `@Builder`, `@RequiredArgsConstructor`, `@Slf4j`, etc.).
- **MapStruct 1.6.3** for compile-time bean mapping (DTO ↔ entity); pairs naturally with the per-service `dto/` and `domain/` package layout.

## Per-service RAM Pathfinder Conventions (encoded in scaffolding script, not in shared library)

The scaffolding script applies RAM Pathfinder-specific defaults on top of the HMCTS starter:

- Group ID: `uk.gov.hmcts.ram`.
- Naming: artefact `ram-{service-name}`, package `uk.gov.hmcts.ram.{service-name}`.
- Default Azure UK region: UK South. (DR scope and target region are an open gap — see [`./gaps.md` G3.6](./gaps.md).)
- Default Application Insights workspace: RAM Pathfinder shared workspace (HMCTS-provided).
- Default Reference Data and Authorisation service URL placeholders.
- Boilerplate `@ControllerAdvice` for [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457) problem-details error envelopes (formerly RFC 7807; obsoleted July 2023 — content type and field shape unchanged).
- Boilerplate `JWTFilter` + `AuthDetails` bean (per HMCTS template pattern); modified to call RAM Pathfinder Authorisation service per request (RAM Pathfinder variance from template's claims-only approach — required by FR58).
- Boilerplate Reference Data direct-SQL access (JPA entities mapped to whitelisted Reference Data tables — 15 tables, see [`./data-tables.md`](./data-tables.md): `regions`, `offices`, `calendar_periods`, plus the 12 vocabulary tables); no client class.
- *(removed 2026-05-06)* Boilerplate APEX-comparison test base class — retracted. Behavioural parity is verified via **manual UAT performed by APEX-experienced users** (FR61 / NFR41 revised). Per-service UAT scripts live under `docs/uat/` in the service repo, not as test code.
- Default port `8082` (per HMCTS template).

These are **scaffolded once per service**; subsequent edits live in the service's own repo. There is no upstream library that can force a redeployment.

**Note:** Project initialisation using these commands and the scaffolding script should be the first implementation story per service.
