---
parent: 'epics/phase-0/index.md'
epic: 0.4
title: 'System dispatches transactional emails and admin can verify delivery'
storyCount: 4
status: 'validated'
---

# Epic 0.4: System dispatches transactional emails and admin can verify delivery

**User outcome:** An admin can trigger a test email through a system-admin utility in `nji-admin-ui`; NJI dispatches via HMCTS email infrastructure; the delivery log records attempt and outcome. This establishes the pattern that downstream domain phases (Phase 2 Absence acknowledgement, Phase 4 Booking acknowledgement, Phase 6 Payment Batch dispatch) consume.

**Vertical slice:**
- `nji-notification` backend service scaffolded (per AR2–AR4)
- Delivery log table with service-owned Flyway migration (per AR18)
- SMTP integration with HMCTS email infrastructure
- Retry-on-transient-failure pattern (DB row locking / optimistic locking per AR21 — no custom idempotency tables)
- API endpoint: `POST /notifications/send` with structured request (template + recipient + payload)
- Admin UI "Send Test Email" utility under a system-admin route in `nji-admin-ui` (guarded by Authorisation as system-admin role)
- First-exercise of OAuth `client_credentials` pattern for batch service-to-service auth (per NFR12 revised v2.6 + AR36) — even though `nji-payment-batch` is Phase 6, the `client_credentials` flow is established here for the Admin test send and re-used later
- Postman tests appended to the Phase 0 collection

**FRs covered:** FR9

**Key NFRs:** NFR22 (HMCTS email infrastructure)

**Why Phase 0 rather than deferring to Phase 2 as a consumer:** Three downstream phases depend on Notification's API contract, retry semantics, and delivery-log schema (FR20 ack, FR32 ack, FR43 schedule dispatch). Locking those in Phase 0 with an admin-triggered demoable path avoids re-work and unblocks parallel development of the downstream consumers. The Admin test-send utility gives Phase 0 a thin but real user outcome (the admin can verify the integration works) rather than shipping a service nobody can demo.

---

## Story 0.4.1: Scaffold `nji-notification` service + delivery log table + SMTP integration

As a **platform engineer**,
I want to scaffold `nji-notification` following the established pattern, create the delivery log table via Flyway, and configure SMTP integration with HMCTS email infrastructure,
So that **downstream phases** (Phase 2 absence ack, Phase 4 booking ack, Phase 6 payment schedule) **can dispatch transactional emails** via a consistent contract from day one of consuming them.

**Acceptance Criteria:**

**Given** the engineer runs `nji-scaffold.sh nji-notification`,
**When** the scaffold completes,
**Then** the new repo has the same baseline as Stories 0.1.1 / 0.2.1 (Spring Boot 4, Helm chart, GitHub Actions, Actuator, structured logs, OpenAPI tooling, Spectral, ArchUnit, Spotless, Checkstyle, Pact, Postman),
**And** Group ID is `uk.gov.hmcts.nji`, artefact is `nji-notification`, package is `uk.gov.hmcts.nji.notification`, default port is 8082,
**And** initial commit is *"Scaffold NJI notification from HMCTS starter"* (per AR4).

**Given** the engineer adds Flyway migration `V1__init_notification_schema.sql`,
**When** the migration runs,
**Then** a `notification_delivery_log` table exists with columns: `id` (UUID PK), `template_id`, `recipient`, `payload` (JSONB), `status` (queued / sending / sent / failed / dead-lettered), `attempt_count`, `last_attempt_at`, `last_error`, `created_at`, `sent_at`, `version` (for `@Version` optimistic locking per AR21),
**And** `nji_notification` DB role owns the table,
**And** the schema is documented in `architecture/data-tables.md`.

**Given** the engineer configures SMTP,
**When** the service starts in dev profile,
**Then** SMTP settings are loaded from Spring profiles + Azure Key Vault (per AR25, NFR16),
**And** in non-prod environments a SMTP mock (e.g. Mailpit container in docker-compose) intercepts outbound mail,
**And** in production the configuration points to HMCTS email infrastructure (per NFR22).

**Given** the service is deployed to dev AKS,
**When** `/actuator/health` is queried,
**Then** the response is `200 OK` with SMTP health-check status,
**And** the response includes a degraded status if SMTP is unreachable.

**References:** FR9, FR8 (consumes `configuration_values` for rate-limit policy), FR59, FR60; NFR16, NFR22, NFR25–NFR28, NFR40; AR2–AR22.

---

## Story 0.4.2: `POST /v1/notifications/send` endpoint with retry semantics, delivery logging, and RFC 9457 errors

As a **calling service** (Admin UI test send now; Absence/Booking/Payment Batch later),
I want a `POST /v1/notifications/send` endpoint that accepts a template + recipient + payload, persists a delivery log entry, dispatches via SMTP with retry on transient failure, and returns RFC 9457 errors on validation failure,
So that **transactional email dispatch is a single, observable, retry-safe contract** (per FR9, NFR22) that the rest of NJI consumes consistently.

**Acceptance Criteria:**

**Given** `nji-notification` is deployed per Story 0.4.1,
**When** the engineer implements the send endpoint,
**Then** `POST /v1/notifications/send` accepts a body with `{templateId, recipient, payload}` where `payload` is a JSON object,
**And** the endpoint is protected by `JWTFilter` (any authenticated principal with the `notification-sender` role can call; service principals from `client_credentials` flow are accepted per NFR12 + AR36),
**And** on a valid request, the endpoint inserts a row in `notification_delivery_log` with status `queued` and returns `202 Accepted` with `{deliveryId, status}`.

**Given** a worker (in-process scheduled task or message queue consumer — engineer to choose; recommendation at this scale: in-process Spring `@Scheduled` task picking `queued` rows with `FOR UPDATE SKIP LOCKED` per AR21 to avoid worker contention) processes queued rows,
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

**Given** a `GET /v1/notifications/delivery-log` endpoint is added,
**When** the caller is authenticated with a `system-admin` role,
**Then** the response returns paginated delivery log entries with filters (recipient, status, date range),
**And** non-admin callers get `403 Forbidden` with RFC 9457.

**Given** the OpenAPI spec is regenerated,
**When** `uk.gov.hmcts.nji:api-nji-notification:1.0.0` is published,
**Then** Spectral lint passes,
**And** the spec documents the send + delivery-log endpoints.

**Given** a Postman collection is published,
**When** `postman/nji-notification-phase0.postman_collection.json` runs,
**Then** it covers happy path + 400 + 401 + 403 + retry behaviour (via a fault-injection test endpoint, removable post-Phase-0).

**References:** FR9, FR59, FR60; NFR12, NFR13, NFR15, NFR22, NFR25, NFR28, NFR39, NFR42; AR17, AR21, AR34, AR36, AR37, AR38, AR41.

---

## Story 0.4.3: Establish OAuth `client_credentials` flow against `nji-mock-auth` for batch/scheduled callers

As a **scheduled or batch component** (the Admin UI test-send utility now; `nji-payment-batch` in Phase 6),
I want a documented and tested OAuth 2.0 `client_credentials` flow against `nji-mock-auth` issuing service-principal JWTs that NJI services accept,
So that **inter-service authentication for non-user-initiated calls** (per NFR12 revised v2.6, AR36) is in place from Phase 0 — locking in the pattern before downstream consumers depend on it.

**Acceptance Criteria:**

**Given** `nji-mock-auth` was scaffolded per Story 0.1.2 with `client_credentials` flow supported,
**When** the engineer adds a `service-client-config` seed under `nji-mock-auth`,
**Then** a service-token client `nji-notification-test-sender-client` is configured with client ID, client secret (in Key Vault per NFR16), and allowed scopes (e.g. `notification:send`),
**And** the client config is repeatable for future batch components by adding new entries (engineer documents the pattern in `nji-architecture/ADR-XXXX-service-token-flow.md`).

**Given** a batch caller (or test harness) requests a token,
**When** it calls `nji-mock-auth`'s token endpoint with `grant_type=client_credentials&client_id=...&client_secret=...&scope=notification:send`,
**Then** the response is `200 OK` with `{access_token, token_type: "Bearer", expires_in, scope}`,
**And** the JWT validates against `nji-mock-auth`'s JWKS endpoint,
**And** the JWT subject identifies the client.

**Given** the service-principal JWT is presented to `nji-notification`'s `POST /v1/notifications/send`,
**When** the JWTFilter validates the token,
**Then** the request is accepted,
**And** `nji-authorisation`'s `POST /authz/check` returns the service principal's allowed scopes,
**And** the send proceeds if the scope includes `notification:send`.

**Given** the production issuer for service tokens is documented as deferred per gaps.md G7.1 (default recommendation: Azure Workload Identity given AKS deployment per AR36),
**When** the engineer writes the ADR,
**Then** the ADR clearly states: (a) Phase 0 establishes `client_credentials` against `nji-mock-auth` for non-prod use only, (b) production issuer is a deferred decision, (c) default recommendation is Azure Workload Identity, (d) the JWT validation pattern in NJI services is issuer-agnostic so swap-in is mechanical at production cutover.

**References:** FR1 (service-principal authentication), FR59; NFR12, NFR16; AR35, AR36, gaps.md G7.1.

---

## Story 0.4.4: Admin can trigger a test email through `nji-admin-ui` and verify delivery in the log

As a **system administrator**,
I want a "Send Test Email" utility in `nji-admin-ui` that calls `nji-notification`'s send endpoint and shows the resulting delivery log entry,
So that **the Notification integration is end-to-end demoable at Phase 0** (the demoable user outcome for Epic 0.4) — and so admins have a sanity-check tool when downstream phases start consuming Notification.

**Acceptance Criteria:**

**Given** an admin signs into `nji-admin-ui` (Story 0.2.3) with a `system-admin` role,
**When** they open `/system/notification-test`,
**Then** they see a form with template-id selector (seeded templates: "test-email", "absence-ack", "booking-ack", "payment-schedule"), recipient email input, and payload JSON input (with sensible defaults per template),
**And** the form validates inputs client-side (valid email; JSON parseable),
**And** the auto-generated TypeScript client from `nji-notification` OpenAPI is used for the API call.

**Given** the admin submits the form,
**When** the UI calls `POST /v1/notifications/send`,
**Then** the response `202 Accepted` returns a `deliveryId`,
**And** the UI displays the delivery in a sidebar panel showing `queued` status,
**And** the panel polls (or subscribes to a WebSocket if added later — TanStack Query refetch interval is sufficient at Phase 0) for status changes,
**And** within ~30 seconds the panel shows `sent` or `failed` based on SMTP outcome.

**Given** the test recipient receives the email in non-prod (Mailpit catches outbound),
**When** the admin opens the Mailpit UI in dev,
**Then** the email is visible with rendered template + payload substitutions,
**And** the admin can verify the rendering matches expectation before downstream phases consume the template.

**Given** the send fails (e.g. SMTP rejected the recipient),
**When** the delivery log entry transitions to `dead-lettered`,
**Then** the UI panel shows the failure with the last error,
**And** the admin can drill into the delivery log via a link to `/system/notification-log`.

**Given** a `/system/notification-log` view exists,
**When** the admin opens it,
**Then** they see a paginated table of recent delivery log entries (fetched via `GET /v1/notifications/delivery-log`) with filters,
**And** axe-core scans the table view without WCAG 2.2 AA violations.

**Given** Playwright E2E coverage,
**When** `tests/e2e/notification-test.spec.ts` runs against dev,
**Then** it covers: open test-send page → fill form → submit → see `queued` → wait for `sent` → verify Mailpit captured the message,
**And** also covers the failure path (using an intentionally rejected recipient).

**References:** FR4 (admin gating), FR9, FR56 (admin stack); NFR12, NFR13, NFR17, NFR18, NFR19, NFR22; AR42–AR45.
