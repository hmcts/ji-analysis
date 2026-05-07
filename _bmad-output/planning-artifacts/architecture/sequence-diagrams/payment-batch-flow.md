---
parent: ../../architecture.md
title: Payment-batch sequence — Scheduler → Batch → JFEPS Excel → Authoriser → Liberata
last_updated: 2026-05-07
---

# Payment-batch flow

High-level sequence diagram of the **scheduled, non-user-initiated** half of the operational cycle: a scheduler triggers the payment-processing batch, which authenticates as a service principal, picks up the bookings/sittings that are confirmed but not yet paid, generates the JFEPS-compatible Excel schedule, and dispatches it via Notification → HMCTS Email to the Payment Authoriser. The authoriser then uploads to Liberata out-of-band, and Liberata pays the judge.

This is the companion to [`./absence-to-reconciliation.md`](./absence-to-reconciliation.md), which covers the user-initiated activities. Together they describe the end-to-end operational cycle: the user-initiated flow ends with a booking marked as confirmed and ready for payment; the batch flow below picks up that record on its next scheduled run.

The flow is split into **four phases** — phase 1 is in-process automation (scheduler + batch authentication); phases 2–3 are the batch's actual work; phase 4 is out-of-band external processing (Liberata). Phases are colour-tinted in the diagram for visual separation.

## What is and isn't in this diagram

**Included** (the batch's runtime activity):

- Scheduler trigger (Kubernetes CronJob, or Spring `@Scheduled` annotation — implementation choice deferred).
- Batch acquiring its service-principal token via OAuth `client_credentials` against `nji-mock-auth` (non-prod) — production issuer per [`../gaps.md` G7.1](../gaps.md), default recommendation Azure Workload Identity.
- Batch SQL-JOIN read across the shared schema for eligible records.
- Batch persisting `payments` + `payment_schedules` and marking the related bookings as *payment requested*.
- Batch calling the Notification API (with bearer service token) to dispatch the JFEPS Excel email.
- Authoriser → Liberata upload as the bridge between NJI and the external payment system (out-of-band but architecturally relevant).
- Liberata processing the payment.

**Not included** (explicitly out of scope of this diagram):

- User-initiated activities (logging absences, approving them, creating bookings, confirming sittings, marking payments reconciled) — those are in [`./absence-to-reconciliation.md`](./absence-to-reconciliation.md).
- Reconciliation feedback from Liberata back into NJI — at MVP this is a manual RSU action (see the user-initiated diagram, Phase 5). Automated reconciliation feed from Liberata is post-MVP.
- The mock-auth's internal token-issuing logic (signing, JWKS, etc.) — covered by the architecture's Authentication & Security section and the auth/JWKS sequences in `architecture.md`.

## Cross-cutting steps omitted for clarity

- The Notification API call from the batch to `nji-notification` flows through Azure API Management (same path as user-initiated calls).
- Notification's `JWTFilter` validates the batch's service-principal JWT against the issuer's JWKS — same mechanism as for human user JWTs.
- Notification calls `nji-authorisation` `POST /authz/check` to resolve the service principal's permissions (service principals have records in `auth_users` with a kind flag distinguishing them from humans).

```mermaid
%%{init: {'sequence': {'actorFontSize': 16, 'actorFontWeight': 'bold', 'messageFontSize': 15, 'noteFontSize': 13, 'mirrorActors': false, 'actorMargin': 30, 'boxMargin': 6, 'messageMargin': 30}}}%%
sequenceDiagram
    autonumber

    participant Sched as Scheduler
    participant Batch as nji-payment-batch
    participant Auth as nji-mock-auth
    participant Notif as nji-notification
    actor PA as Payment Authoriser
    participant JFEPS as JFEPS / Liberata

    rect rgb(232, 240, 250)
        Note over Sched,JFEPS: Phase 1 — Scheduler triggers batch, batch acquires service token
        Sched->>Batch: cron tick (e.g. weekly Friday 17:00)
        Batch->>Auth: POST /oauth2/token (client_credentials)
        Auth-->>Batch: service JWT (short-lived)
    end

    rect rgb(232, 250, 232)
        Note over Sched,JFEPS: Phase 2 — Batch collects eligible records and persists schedule
        Note right of Batch: Eligible = confirmed bookings + sittings without an existing payment row.
        Batch->>Batch: SQL JOIN over bookings + sittings + (LEFT JOIN payments WHERE NULL)
        Batch->>Batch: generate JFEPS-shaped Excel
        Batch->>Batch: INSERT payments + payment_schedules
        Batch->>Batch: UPDATE bookings status = payment_requested (FR42)
    end

    rect rgb(250, 240, 230)
        Note over Sched,JFEPS: Phase 3 — Batch dispatches schedule via Notification
        Batch->>Notif: POST /v1/notifications/send (bearer = service JWT)
        Notif->>Notif: dispatch JFEPS Excel email to authoriser via HMCTS Email
        Notif-->>Batch: 202 accepted
        Notif-->>PA: JFEPS Excel email
    end

    rect rgb(250, 232, 240)
        Note over Sched,JFEPS: Phase 4 — Authoriser uploads to Liberata (out-of-band)
        Note right of PA: Authoriser reviews schedule and uploads to Liberata via the existing JFEPS workflow. NJI is not in the loop.
        PA->>JFEPS: review and upload Excel
        JFEPS->>JFEPS: process payments and pay judge
    end

    Note over Sched,JFEPS: Reconciliation feedback from Liberata back to NJI is manual at MVP — RSU clicks "mark reconciled" in the user-initiated flow (see absence-to-reconciliation diagram, Phase 5). Automated reconciliation is post-MVP.
```

## Phase summary

| Phase | Driver | Architectural rule | Outcome |
|---|---|---|---|
| 1 — Scheduler triggers batch + token acquisition | Scheduler (cron) | Batch authenticates as service principal via OAuth `client_credentials` | Batch holds a short-lived service JWT for its run |
| 2 — Eligible records collected + schedule persisted | Batch (no user) | SQL JOIN over confirmed bookings + sittings without payments; FR41–FR45 retry safety via natural-key unique constraints + `@Version` | `payments` + `payment_schedules` rows created; bookings flagged `payment_requested` |
| 3 — Schedule dispatched | Batch (no user) | Service-token bearer on Notification API call; Notification `JWTFilter` validates same as user JWTs (via JWKS) | JFEPS Excel email delivered to Payment Authoriser |
| 4 — Liberata processing | Payment Authoriser → JFEPS | Out-of-band; NJI is not in the loop | Judge paid; awaiting reconciliation (which is user-initiated — see other diagram) |

## Where to find more detail

| Detail | Location |
|---|---|
| User-initiated activities — absence to reconciliation | [`./absence-to-reconciliation.md`](./absence-to-reconciliation.md) |
| Service-principal auth model + production issuer options | [`../../architecture.md` → Step 4 *Authentication & Security*](../../architecture.md); [`../gaps.md` G1.2 + G7.1](../gaps.md); [`../assumptions.md` A2 + A26 + A35](../assumptions.md) |
| `nji-payment` Repository List entry — synchronous API + batch component | [`../../architecture.md` → Repository List](../../architecture.md) |
| Per-table column-level detail (`payments`, `payment_schedules`, `payment_reconciliations`, `notification_dispatches`, `mock_oauth_clients`) | [`../data-tables.md`](../data-tables.md) |
| FR41–FR45 (Payment) and NFR12 (Authentication) | PRD `FR41`, `FR42`, `FR43`, `FR44`, `FR45`, `NFR12` |
| JWT propagation (the user-initiated counterpart pattern) | [`../conventions.md` → *Communication Patterns / JWT propagation*](../conventions.md) |
