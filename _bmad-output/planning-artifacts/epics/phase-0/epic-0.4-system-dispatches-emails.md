---
parent: 'epics/phase-0/index.md'
epic: 0.4
title: 'Notification service is scaffolded and contractually ready'
storyCount: 2
status: 'validated'
revisedAt: '2026-05-15'
revisionNote: 'Admin Send-Test-Email UI removed (was Story 0.4.4); OAuth client_credentials flow deferred to Phase 6 when nji-payment-batch needs it (was Story 0.4.3). Phase 0 delivers the backend contract; Phase 2+ exercises it via user-JWT-propagated calls.'
---

# Epic 0.4: Notification service is scaffolded and contractually ready

**User outcome:** The `nji-notification` service is deployed with its API contract published, delivery-log table created, SMTP integration to HMCTS email infrastructure configured, and `POST /v1/notifications/send` endpoint operational. The contract is consumable from Phase 2+ (Absence acknowledgement, Booking acknowledgement) via JWT propagation — the user-initiated flow. Service-token (`client_credentials`) auth for non-user-initiated callers is **deferred to Phase 6** when `nji-payment-batch` arrives as the first consumer. **No admin UI in MVP** — the test-send / verification flow happens via Postman during Phase 0 integration testing, not via a deployed UI.

**Vertical slice:**
- `nji-notification` backend service scaffolded (per AR2–AR4)
- `notification_delivery_log` table with service-owned Flyway migration (per AR18)
- SMTP integration with HMCTS email infrastructure (Mailpit in non-prod)
- Retry-on-transient-failure pattern (DB row locking / optimistic locking per AR21 — no custom idempotency tables)
- `POST /v1/notifications/send` endpoint accepting structured request (`{templateId, recipient, payload}`)
- JWT propagation for user-initiated calls (per NFR12 — Phase 2+ Absence and Phase 4 Booking acknowledgement flows are user-initiated)
- Delivery-log read endpoint (`GET /v1/notifications/delivery-log`, `system-admin` role required — accessed via Postman in MVP, no UI)
- OpenAPI spec published as Maven artefact + Postman collection
- Phase 0 integration testing via Postman: send → queued → sent → verify in Mailpit

**FRs covered:** FR9 (notification dispatch + delivery log)

**Key NFRs:** NFR12 (JWT propagation for user-initiated), NFR15 (delivery log = audit), NFR22 (HMCTS email infrastructure), NFR25–NFR28 (observability), NFR39 (API-as-Product), NFR42 (Postman)

**Out of scope for Phase 0 (deferred to other phases):**
- OAuth `client_credentials` flow for batch / scheduled callers — **deferred to Phase 6** (the flow is established alongside `nji-payment-batch`, the first non-user-initiated consumer; was Story 0.4.3 in the prior plan, now moved out of Phase 0)
- Admin "Send Test Email" UI utility — **deferred post-MVP** (no admin UI in MVP per the 2026-05-15 scope decision; was Story 0.4.4 in the prior plan, removed)
- Delivery-log viewer UI — **deferred post-MVP** (Postman queries cover the gap during integration testing in MVP)

---

## Story 0.4.1: Scaffold `nji-notification` service + delivery log table + SMTP integration

As a **platform engineer**,
I want to scaffold `nji-notification` following the established pattern, create the delivery log table via Flyway, and configure SMTP integration with HMCTS email infrastructure,
So that **downstream phases** (Phase 2 absence ack, Phase 4 booking ack, Phase 6 payment schedule) **can dispatch transactional emails** via a consistent contract from day one of consuming them.

**Acceptance Criteria:**

**Given** the engineer has manually pre-created the private GitHub repo `nji-notification` with branch protection on `main` via the GitHub web UI (per `nji-architecture/runbooks/github-setup.md`; the `gh` CLI is **not** available — see Story 0.1.1 for the canonical manual-setup pattern),
**And** runs `nji-scaffold.sh nji-notification`,
**When** the scaffold completes,
**Then** the new repo has the same baseline as Stories 0.1.1 / 0.2.1 (Spring Boot 4, Helm chart, GitHub Actions, Actuator, structured logs, OpenAPI tooling, Spectral, ArchUnit, Spotless, Checkstyle, Pact, Postman),
**And** Group ID is `uk.gov.hmcts.nji`, artefact is `nji-notification`, package is `uk.gov.hmcts.nji.notification`, default port is 8082,
**And** initial commit is *"Scaffold NJI notification from HMCTS starter"* (per AR4).

**Given** the engineer adds Flyway migration `V1__init_notification_schema.sql`,
**When** the migration runs,
**Then** a `notification_delivery_log` table exists with columns: `id` (UUID PK), `template_id`, `recipient`, `payload` (JSONB), `status` (queued / sending / sent / failed / dead-lettered), `attempt_count`, `last_attempt_at`, `last_error`, `created_at`, `sent_at`, `created_by_principal` (the IdP principal that initiated the send — for audit), `version` (for `@Version` optimistic locking per AR21),
**And** `nji_notification` DB role owns the table,
**And** the schema is documented in `architecture/data-tables.md`.

**Given** the engineer configures SMTP,
**When** the service starts in dev profile,
**Then** SMTP settings are loaded from Spring profiles + Azure Key Vault (per AR25, NFR16),
**And** in non-prod environments a SMTP mock (Mailpit container in docker-compose) intercepts outbound mail,
**And** in production the configuration points to HMCTS email infrastructure (per NFR22).

**Given** the service is deployed to dev AKS,
**When** `/actuator/health` is queried,
**Then** the response is `200 OK` with SMTP health-check status,
**And** the response includes a degraded status if SMTP is unreachable.

**References:** FR9, FR8 (consumes `configuration_values` for rate-limit policy), FR59, FR60; NFR16, NFR22, NFR25–NFR28, NFR40; AR2–AR22.

---

## Story 0.4.2: `POST /v1/notifications/send` endpoint with JWT propagation, retry semantics, delivery logging, RFC 9457 errors

As a **calling service** (Phase 2 Absence flow, Phase 4 Booking flow — both user-initiated),
I want a `POST /v1/notifications/send` endpoint that accepts a template + recipient + payload, validates the caller's user JWT, persists a delivery log entry, dispatches via SMTP with retry on transient failure, and returns RFC 9457 errors on validation failure,
So that **transactional email dispatch is a single, observable, retry-safe contract** (per FR9, NFR22) that the user-initiated downstream phases consume consistently. The OAuth `client_credentials` flow for non-user-initiated callers (batch / scheduled) is **out of scope for Phase 0** — it will be added in Phase 6 when `nji-payment-batch` arrives.

**Acceptance Criteria:**

**Given** `nji-notification` is deployed per Story 0.4.1,
**When** the engineer implements the send endpoint,
**Then** `POST /v1/notifications/send` accepts a body with `{templateId, recipient, payload}` where `payload` is a JSON object,
**And** the endpoint is protected by `JWTFilter` and accepts user JWTs from the SSO/IdP (per NFR12 — JWT propagation for user-initiated calls; the caller is a downstream NJI service that has propagated the user's token),
**And** the caller's role is checked against the template's permitted-callers list (e.g. only `RSU` and `system-admin` may send `absence-ack` template in MVP),
**And** on a valid request, the endpoint inserts a row in `notification_delivery_log` with status `queued` and the user's principal in `created_by_principal`, then returns `202 Accepted` with `{deliveryId, status}`.

**Given** a worker (in-process Spring `@Scheduled` task picking `queued` rows with `FOR UPDATE SKIP LOCKED` per AR21) processes queued rows,
**When** the worker picks a row,
**Then** it transitions to `sending`,
**And** invokes SMTP send,
**And** on success transitions to `sent` with `sent_at` populated,
**And** on transient failure increments `attempt_count`, populates `last_error`, and resets status to `queued` (retry budget: 5 attempts at exponential backoff),
**And** on exhausted retry budget transitions to `dead-lettered` with `last_error` retained for inspection.

**Given** an invalid request body reaches the send endpoint,
**When** validation fails (missing template, invalid recipient, payload schema mismatch),
**Then** the response is `400 Bad Request` with RFC 9457 problem-details including field-level errors (per AR37),
**And** no delivery log row is created.

**Given** an unauthenticated request reaches the send endpoint,
**When** the JWT is missing or invalid,
**Then** the response is `401 Unauthorized` with RFC 9457 problem-details,
**And** no delivery log row is created.

**Given** a request arrives with a service-principal JWT (from `client_credentials` flow),
**When** the JWTFilter validates the token,
**Then** the request is **rejected** at Phase 0 with `403 Forbidden` and an RFC 9457 body explaining "service-principal callers are not in scope until Phase 6 (`nji-payment-batch` arrives). Use user JWT propagation for Phase 2+ user-initiated flows.",
**And** the rejection is logged with the client identifier for visibility.

**Given** a `GET /v1/notifications/delivery-log` endpoint is added,
**When** the caller is authenticated with a `system-admin` role,
**Then** the response returns paginated delivery log entries with filters (recipient, status, date range, principal),
**And** non-admin callers get `403 Forbidden` with RFC 9457.

**Given** the OpenAPI spec is regenerated,
**When** `uk.gov.hmcts.nji:api-nji-notification:1.0.0` is published,
**Then** Spectral lint passes,
**And** the spec documents the send + delivery-log endpoints,
**And** the spec explicitly annotates "service-principal auth deferred to v2 (Phase 6) — Phase 0 / 1 only accept user-JWT".

**Given** a Postman collection is published,
**When** `postman/nji-notification-phase0.postman_collection.json` runs in CI,
**Then** it covers happy path + 400 + 401 + 403 (admin-only) + 403 (service-principal rejected pre-Phase-6) + retry behaviour (via a fault-injection test endpoint, removable post-Phase-0),
**And** Phase 0 manual integration test consists of: open Postman → authenticate as test user → POST send → poll delivery-log until `sent` → open Mailpit → verify rendered email. (No admin UI for this flow in MVP per the 2026-05-15 scope decision.)

**References:** FR9, FR59, FR60; NFR12, NFR13, NFR15, NFR22, NFR25, NFR28, NFR39, NFR42; AR17, AR21, AR34, AR37, AR38, AR41.

**Explicitly NOT in scope (deferred to other phases):**
- OAuth `client_credentials` flow for batch / scheduled callers — **moved to Phase 6** alongside `nji-payment-batch` (was Story 0.4.3 in the prior plan)
- Admin "Send Test Email" UI — **deferred post-MVP** (was Story 0.4.4)
- Delivery-log viewer UI — **deferred post-MVP** (Postman covers the gap)
