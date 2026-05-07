---
parent: ../../architecture.md
title: End-to-end sequence — Absence → Vacancy → Booking → Sitting → Reconciliation
last_updated: 2026-05-07
---

# Absence → Vacancy → Booking → Sitting → Reconciliation

High-level sequence diagram of the **user-initiated** activities in the canonical NJI operational cycle: a Court User logs an absence on behalf of a salaried judge, the absence triggers a vacancy, RSU fills the vacancy with a fee-paid booking, the Court User confirms the sitting (marking it *ready for payment*), and finally RSU reconciles the payment after the downstream batch + external systems have completed.

The flow is split into **five phases** — each one driven by a user action. Phases are colour-tinted in the diagram for visual separation.

## What is deliberately NOT in this diagram

The MVP assumption (architecture v2.5 — A35) is that the diagrammed runtime flow contains only user-initiated activities. The following sit between Phase 4 and Phase 5 but are **not** drawn here because they are not user-initiated runtime calls:

- **Routine payment-processing batch** — picks up bookings whose `status = ready_for_payment`, SQL-JOINs across confirmed bookings + sittings, generates the JFEPS-shaped Excel schedule, persists `payments` + `payment_schedules`, and dispatches the schedule by email to the Payment Authoriser. Runs on a schedule (e.g. end-of-week), not in response to any user click.
- **Payment Authoriser → JFEPS / Liberata** — the authoriser reviews the emailed schedule and uploads it to Liberata using the existing JFEPS workflow. Out-of-band; NJI is not in the loop.
- **Liberata processing** — Liberata pays the fee-paid judge into their payroll account. External system; not part of NJI runtime.

The architectural rules and integration points for these batch / external steps are described in `architecture.md` (Step 4 *Data Architecture*, Step 6 *Integration Points — External*).

## Cross-cutting steps omitted for clarity

These apply on every Court / RSU → service call but would clutter the diagram:

- All UI→service calls flow through Azure API Management.
- Each service's `JWTFilter` validates the inbound JWT signature against HMCTS IdP's JWKS endpoint **before** the controller runs.
- The same `JWTFilter` calls `POST /authz/check` against `nji-authorisation` to resolve role + Region/Area scope + per-region activation flag (FR58).
- Cross-service calls forward the user's JWT (token propagation; no service principals at MVP).

```mermaid
%%{init: {'sequence': {'actorFontSize': 16, 'actorFontWeight': 'bold', 'messageFontSize': 15, 'noteFontSize': 13, 'mirrorActors': false, 'actorMargin': 30, 'boxMargin': 6, 'messageMargin': 30}}}%%
sequenceDiagram
    autonumber

    actor Court as Court User
    actor RSU

    participant Abs as nji-absence
    participant Vac as nji-vacancy
    participant Bk as nji-booking
    participant Pay as nji-payment
    participant Notif as nji-notification

    rect rgb(232, 240, 250)
        Note over Court,Notif: Phase 1 — Court User logs absence (with cover request)
        Court->>Abs: POST /v1/absences
        Abs->>Abs: validate (FR15)
        Abs-->>Court: 201 (pending)
        Abs->>Notif: send absence ack
        Notif->>Notif: dispatch to salaried judge via HMCTS Email
    end

    rect rgb(232, 250, 232)
        Note over Court,Notif: Phase 2 — RSU approves absence, vacancy auto-created (R4)
        RSU->>Abs: POST /v1/absences/{id}/approve
        Abs->>Abs: pending to approved
        Abs->>Vac: POST /v1/vacancies
        Vac-->>Abs: 201 (needs-allocation)
        Abs-->>RSU: 200
    end

    rect rgb(250, 240, 230)
        Note over Court,Notif: Phase 3 — RSU creates fee-paid booking, vacancy filled in-tx (R5)
        Note right of RSU: Advertising is out-of-system. RSU records the booking once a fee-paid judge replies.
        RSU->>Bk: POST /v1/bookings
        Bk->>Vac: SELECT FOR UPDATE
        Bk->>Bk: INSERT booking
        Bk->>Vac: UPDATE filled = true
        Bk->>Bk: COMMIT
        Bk-->>RSU: 201 booking
        Bk->>Notif: send booking ack
        Notif->>Notif: dispatch to fee-paid judge via HMCTS Email
    end

    rect rgb(250, 232, 240)
        Note over Court,Notif: Phase 4 — Court User confirms sitting, booking marked ready for payment
        Court->>Bk: POST /v1/bookings/{id}/confirm
        Bk->>Bk: status = ready_for_payment
        Bk-->>Court: 200
    end

    Note over Court,Notif: Between Phase 4 and Phase 5, the routine payment-processing batch runs and Liberata pays the judge — out of scope of this diagram (see "What is deliberately NOT in this diagram" above).

    rect rgb(250, 250, 232)
        Note over Court,Notif: Phase 5 — RSU marks payment reconciled (manual at MVP)
        RSU->>Pay: POST /v1/payments/{id}/reconcile
        Pay->>Pay: status = matched
        Pay-->>RSU: 200
    end
```

## Phase summary

| Phase | Driver | Architectural rule | Outcome |
|---|---|---|---|
| 1 — Absence logged | Court User | Validation (FR15-style: ticket-type + start date required) | Absence record created (status: pending); ack email to salaried judge |
| 2 — Absence approved | RSU | **R4** — approval triggers vacancy creation | Vacancy created (status: needs-allocation) |
| 3 — Booking created | RSU | **R5** — pessimistic row lock + in-transaction UPDATE on `vacancies.filled` | Booking persisted; vacancy filled; ack email to fee-paid judge |
| 4 — Sitting confirmed | Court User | State transition; record marked ready for the payment batch | Booking status = `ready_for_payment` (the batch picks this up later) |
| *(out of scope)* | *(none — batch / external)* | *Routine payment-processing batch + Liberata processing* | *JFEPS Excel generated, dispatched, uploaded; judge paid* |
| 5 — Reconciliation | RSU | Manual at MVP (automated reconciliation feed from Liberata is post-MVP) | `payment_reconciliations.status = matched` |

## Where to find more detail

| Detail | Location |
|---|---|
| Service responsibilities and key functions | [`../../architecture.md` → Repository List](../../architecture.md) |
| Data Architecture (shared schema, per-service DB roles, R5 pessimistic-lock pattern) | [`../../architecture.md` → Step 4 *Data Architecture*](../../architecture.md) |
| Integration Points — internal call patterns + external systems (HMCTS Email, JFEPS / Liberata) | [`../../architecture.md` → Step 6 *Integration Points*](../../architecture.md) |
| Authentication / authorisation cross-cutting steps (omitted from diagram) | [`../../architecture.md` → Step 4 *Authentication & Security*](../../architecture.md), [`../../architecture-summary.md` → *Authentication & Authorisation*](../../architecture-summary.md) |
| Per-table column-level detail (`bookings`, `vacancies`, `payments`, `payment_schedules`, `payment_reconciliations`, `notification_dispatches`, `auth_users`) | [`../data-tables.md`](../data-tables.md) |
| Reconciliation lifecycle (MVP manual; post-MVP roadmap) | [`../../architecture.md` → Step 4 *Data Flow — Canonical Operational Cycle*](../../architecture.md); PRD `FR46` |
| Retry-safety conventions (`@Version` optimistic locking, natural-key unique constraints, `SELECT … FOR UPDATE`) | [`../conventions.md` → *Retry safety and concurrency control*](../conventions.md) |
| JWT propagation pattern (the cross-cutting auth step omitted from the diagram) | [`../conventions.md` → *Communication Patterns / JWT propagation*](../conventions.md) |
| Service-identity question for non-user-initiated flows (which the payment batch is) | [`../gaps.md` → G7](../gaps.md) — explicitly post-MVP open item |
