---
parent: ../../architecture.md
title: End-to-end sequence — Absence → Vacancy → Booking → Sitting → Payment → Reconciliation
last_updated: 2026-05-07
---

# Absence → Vacancy → Booking → Sitting → Payment → Reconciliation

High-level sequence diagram of the canonical NJI operational cycle: a Court User logs an absence on behalf of a salaried judge, the absence triggers a vacancy, RSU fills the vacancy with a fee-paid booking, the Court User confirms the sitting, RSU processes the payment, the Payment Authoriser uploads the schedule to JFEPS / Liberata, and finally the payment is reconciled.

The flow is split into **seven phases** — each one driven by a different user (or external actor). Phases are colour-tinted in the diagram for visual separation. Within a phase the sequence is ordered top-to-bottom; phases follow each other in business-process order.

**Cross-cutting steps omitted for clarity** (they apply on every UI→service call but would clutter the diagram):

- All UI→service calls flow through Azure API Management.
- Each service's `JWTFilter` validates the inbound JWT signature against HMCTS IdP's JWKS endpoint **before** the controller runs.
- The same `JWTFilter` calls `POST /authz/check` against `nji-authorisation` to resolve role + Region/Area scope + per-region activation flag (FR58).
- Cross-service calls forward the user's JWT (token propagation; no service principals at MVP).

```mermaid
%%{init: {'sequence': {'actorFontSize': 18, 'actorFontWeight': 'bold', 'messageFontSize': 18, 'noteFontSize': 16}}}%%
sequenceDiagram
    autonumber

    actor Court as Court User
    actor RSU
    actor PA as Payment Authoriser

    participant UI as nji-ui
    participant Abs as nji-absence
    participant Vac as nji-vacancy
    participant Bk as nji-booking
    participant Pay as nji-payment
    participant Notif as nji-notification
    participant Email as HMCTS Email
    participant JFEPS as JFEPS / Liberata
    participant Judge as Judge

    Note over Court,Judge: All UI→service calls flow through Azure APIM. Each service's JWTFilter validates the JWT against HMCTS IdP JWKS, then calls nji-authorisation per request. These cross-cutting steps are omitted below for clarity. The "Judge" lifeline represents the salaried judge in Phase 1 (whose absence is being logged) and the fee-paid judge in Phase 3 (booked to provide cover) — different people in practice.

    rect rgb(232, 240, 250)
        Note over Court,Judge: Phase 1 — Absence logged on behalf of judge (Court User)
        Court->>UI: Log absence (with "Request fee-paid cover")
        UI->>Abs: POST /v1/absences (judgeId, dates, type, work-type, ticket-type)
        Abs->>Abs: validate (FR15-style: ticket-type + start date required)
        Abs-->>UI: 201 (status: pending)
        UI-->>Court: success
        Abs->>Notif: send absence acknowledgement
        Notif->>Email: SMTP / Graph
        Email->>Judge: ack email (salaried judge whose absence was logged)
    end

    rect rgb(232, 250, 232)
        Note over RSU,Vac: Phase 2 — Absence approved → vacancy auto-created (RSU)
        RSU->>UI: open absence from Outstanding Actions tile, click Approve
        UI->>Abs: POST /v1/absences/{id}/approve
        Abs->>Abs: state transition: pending → approved
        Note over Abs,Vac: R4 — absence approval triggers vacancy creation (the auto-creation business rule)
        Abs->>Vac: POST /v1/vacancies (judge_type, work_type, ticket_type, dates)
        Vac->>Vac: persist (status: needs-allocation)
        Vac-->>Abs: 201
        Abs-->>UI: 200 approved
        UI-->>RSU: vacancy created, ready for advertising
    end

    rect rgb(250, 240, 230)
        Note over RSU,Judge: Phase 3 — Vacancy filled by fee-paid booking (RSU)
        Note right of RSU: Advertising happens out-of-system via RSU's mailing list. A fee-paid judge replies confirming availability — the architectural sequence resumes when RSU records that booking.
        RSU->>UI: open vacancy → Create Booking (pick fee-paid judge)
        UI->>Bk: POST /v1/bookings (vacancyId, judgeId, session details)
        Note over Bk,Vac: R5 — pessimistic row lock + in-transaction UPDATE on the linked vacancy
        Bk->>Vac: SELECT … FOR UPDATE on vacancies.id
        Bk->>Bk: INSERT booking
        Bk->>Vac: UPDATE vacancies SET filled = true, filled_at = now()
        Bk->>Bk: COMMIT
        Bk-->>UI: 201 booking created
        UI-->>RSU: booking confirmed
        Bk->>Notif: send booking acknowledgement
        Notif->>Email: SMTP / Graph
        Email->>Judge: ack email (fee-paid judge — booked into the session)
    end

    rect rgb(250, 232, 240)
        Note over Court,Bk: Phase 4 — Sitting confirmed after the day (Court User)
        Court->>UI: open Sittings/Bookings awaiting confirmation tile
        Court->>UI: confirm yesterday's booking (one click)
        UI->>Bk: POST /v1/bookings/{id}/confirm
        Bk->>Bk: UPDATE bookings SET status = 'confirmed'
        Bk-->>UI: 200
        UI-->>Court: confirmed — eligible for payment
    end

    rect rgb(240, 232, 250)
        Note over RSU,PA: Phase 5 — Payment processed and JFEPS schedule emailed (RSU)
        RSU->>UI: navigate to Process Payments
        RSU->>UI: select payment authoriser, click Process
        UI->>Pay: POST /v1/payments/process (cycleId, runDate, authoriserId)
        Pay->>Pay: SQL JOIN over confirmed bookings + sittings (read-only across shared schema)
        Pay->>Pay: generate JFEPS-shaped Excel schedule
        Pay->>Pay: INSERT payments + payment_schedules
        Pay-->>UI: 201 cycle processed
        UI-->>RSU: schedule generated and emailed
        Pay->>Notif: send JFEPS schedule (Excel attachment) to authoriser
        Notif->>Email: SMTP / Graph
        Email->>PA: JFEPS Excel email
    end

    rect rgb(232, 250, 250)
        Note over PA,JFEPS: Phase 6 — Authoriser uploads to Liberata (out-of-band)
        Note right of PA: This step happens entirely outside NJI — the authoriser uses the existing JFEPS / Liberata workflow to upload and process. NJI is not in the loop until reconciliation.
        PA->>JFEPS: upload JFEPS Excel schedule
        JFEPS->>JFEPS: process payments
        JFEPS->>Judge: payment delivered (to fee-paid judge's payroll account)
    end

    rect rgb(250, 250, 232)
        Note over RSU,Pay: Phase 7 — Reconciliation by RSU (manual at MVP)
        Note right of RSU: At MVP reconciliation is a manual "mark as reconciled" action — there is no automated reconciliation feed from Liberata. Automated reconciliation is on the post-MVP roadmap.
        RSU->>UI: open Unreconciled Payments tile
        RSU->>UI: mark payment reconciled
        UI->>Pay: POST /v1/payments/{id}/reconcile
        Pay->>Pay: UPDATE payment_reconciliations SET status = 'matched'
        Pay-->>UI: 200
        UI-->>RSU: marked reconciled — cycle complete
    end
```

## Phase summary

| Phase | Driver | Architectural rule | Outcome |
|---|---|---|---|
| 1 — Absence logged | Court User | Validation (FR15-style) | Absence record created (pending); ack email to salaried judge |
| 2 — Absence approved | RSU | **R4** — approval triggers vacancy creation | Vacancy created (needs-allocation) |
| 3 — Booking created | RSU | **R5** — pessimistic row lock + in-transaction UPDATE on `vacancies.filled` | Booking persisted; vacancy filled; ack email to fee-paid judge |
| 4 — Sitting confirmed | Court User | State transition (eligible for payment) | Booking status = confirmed |
| 5 — Payment processed | RSU | SQL JOIN over confirmed bookings + sittings; JFEPS Excel content-type | Payment + payment_schedules persisted; JFEPS email to authoriser |
| 6 — Liberata upload | Payment Authoriser | Out-of-band; NJI is not in the loop | Judge paid via JFEPS / Liberata |
| 7 — Reconciliation | RSU | Manual at MVP (automated feed post-MVP) | `payment_reconciliations.status = matched` |

## Where to find more detail

| Detail | Location |
|---|---|
| Service responsibilities and key functions | [`../../architecture.md` → Repository List](../../architecture.md) |
| Data Architecture (shared schema, per-service DB roles, R5 pessimistic-lock pattern) | [`../../architecture.md` → Step 4 *Data Architecture*](../../architecture.md) |
| Integration Points — internal call patterns + external systems | [`../../architecture.md` → Step 6 *Integration Points*](../../architecture.md) |
| Authentication / authorisation cross-cutting steps (omitted from diagram) | [`../../architecture.md` → Step 4 *Authentication & Security*](../../architecture.md), [`../../architecture-summary.md` → *Authentication & Authorisation*](../../architecture-summary.md) |
| Per-table column-level detail (`bookings`, `vacancies`, `payments`, `payment_schedules`, `payment_reconciliations`, `notification_dispatches`, `auth_users`) | [`../data-tables.md`](../data-tables.md) |
| Reconciliation lifecycle (MVP manual; post-MVP roadmap) | [`../../architecture.md` → Step 4 *Data Flow — Canonical Operational Cycle*](../../architecture.md); PRD `FR46` |
| Retry-safety conventions (`@Version` optimistic locking, natural-key unique constraints, `SELECT … FOR UPDATE`) | [`../conventions.md` → *Retry safety and concurrency control*](../conventions.md) |
| JWT propagation pattern (the cross-cutting auth step omitted from the diagram) | [`../conventions.md` → *Communication Patterns / JWT propagation*](../conventions.md) |
