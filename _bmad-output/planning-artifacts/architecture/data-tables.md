---
parent: ../architecture.md
title: Authoritative Table Ownership Mapping
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Authoritative Table Ownership Mapping

> Sibling of [`../architecture.md`](../architecture.md). The parent file's *Data Architecture* (Step 4) section keeps the architectural strategy (single shared schema, per-service DB roles, table-name convention, Flyway migrations); this file keeps the per-table inventory.

## Framing — these are NJI's tables, not APEX's

This is the canonical inventory of **NJI** database entities, grouped by the owning NJI service. **Every table in this inventory is owned, named, and shaped by NJI** — the table list, column shapes, FK relationships, and ownership boundaries are NJI design choices.

APEX has its own (different) schema. APEX's schema is *not* in this inventory and is *not* owned by any NJI service. The Phase 0 ETL — described in [`../architecture.md` → *Phase 0 Data Migration from APEX*](../architecture.md) — reads APEX dumps, transforms each row into NJI shape, and loads via NJI service APIs. The APEX-side shape can differ arbitrarily; the transform absorbs the difference.

> ⚠️ **REVALIDATION SCOPE.** When the APEX SQL dump arrives in Phase 0, the migration tool's input-side mapping is revalidated against it. The validation checks: *does the migration tool's mapping cover every APEX field that NJI needs, and does NJI have a slot for every APEX value we expect to see?* It does **not** ask "is NJI's schema correct against APEX?" — NJI's schema is fixed by NJI design. If new APEX vocabulary values surface (e.g. an absence type the spec didn't mention), the appropriate NJI vocabulary table gains a row via the Reference Data API; the table itself does not change shape. Tracked as **G4.6** in [`./gaps.md`](./gaps.md) and **A33** in [`./assumptions.md`](./assumptions.md).

For naming convention rules (entity-plural for primary domain tables, service-prefix for service-internal or potentially-ambiguous tables), see [`./conventions.md` → "Naming Patterns"](./conventions.md).

## Reference Data service (`nji-reference-data`) — 15 tables

Cross-cutting controlled lists. **Reads** by other services go directly via SQL JOIN against per-service DB role SELECT grants; **writes** go via the Reference Data API (the seeding mechanism per Step 2 *Cross-Cutting Concerns* in [`../architecture.md`](../architecture.md)).

| Table | Type | Purpose | Key consumers |
|---|---|---|---|
| `regions` | Domain | Geographic regions | All services (Region/Area scoping) |
| `offices` | Domain | Offices within regions | Judge, Booking, Sitting, Itinerary |
| `calendar_periods` | Domain | Financial-year boundaries; term dates | Judge (working-pattern horizon to 31st March), Reports |
| `judge_types` | Vocabulary | Judge type controlled list (CJ, DJ, DDJ, Recorder, etc.) | Judge, Vacancy, Booking |
| `work_types` | Vocabulary | Work-type controlled list (Crime, Civil, Family, etc.) | Sitting, Booking, Vacancy, Itinerary |
| `court_types` | Vocabulary | Court / location-type controlled list | Office records, Itinerary |
| `ticket_types` | Vocabulary | Ticket-type controlled list | Judge tickets, Vacancy matching |
| `session_types` | Vocabulary | Session-type controlled list (full / AM / PM / evening / reserved-matter) | Booking, Sitting |
| `absence_types` | Vocabulary | Absence-type controlled list (leave, sickness, training, etc.) | Absence (FR19) |
| `working_pattern_types` | Vocabulary | Working-pattern-type list (None / Daily / Weekly) | Judge (FR12) |
| `booking_statuses` | Vocabulary | Booking status list (planned / provisional / confirmed / cancelled / rejected) | Booking (FR31) |
| `sitting_outcomes` | Vocabulary | Sitting outcome list (confirmed / cancelled / rejected) | Sitting (FR37) |
| `fee_payment_statuses` | Vocabulary | Fee-payment-status list (yes / no / ask-when-booking) | Judge (FR11), Booking (FR33) |
| `payment_statuses` | Vocabulary | Payment status list (pending / requested / paid / reconciled / queried) | Payment (FR41, FR46) |
| `reconciliation_statuses` | Vocabulary | Reconciliation status list (matched / queried / unreconciled) | Payment (FR46) |

## Authorisation service (`nji-authorisation`) — 5 tables

NJI-owned tables, designed by NJI. Seeded in Phase 0 by the Phase 0 Data Migration ETL (per D9), which reads APEX user dumps, transforms them, and loads via the Authorisation API. Service prefix used because "users" / "roles" are domain-overloaded terms.

| Table | Type | Purpose |
|---|---|---|
| `auth_users` | Domain | NJI users (one row per active APEX user that the Phase 0 ETL was able to reconcile to an IdP principal by email + employee number) |
| `auth_roles` | Domain | NJI authorisation roles (the 12 documented roles from `functional-modules.md`) |
| `auth_user_roles` | Domain | User-role junction (many-to-many) |
| `auth_user_region_scopes` | Domain | Per-user Region/Area scope assignments |
| `auth_user_activation_flags` | Domain | Per-user "active in NJI" flag (FR58 — per-region phased activation) |

## Configuration service (`nji-configuration`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `configuration_values` | Domain | Typed configuration key-value store (D1 — typed policy values) |

## Notification service (`nji-notification`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `notification_dispatches` | Domain | Outbound email dispatch log (recipient, content type, dispatched-at, status, retry count, FR9) |

## Judge service (`nji-judge`) — 5 tables

| Table | Type | Purpose |
|---|---|---|
| `judges` | Domain | Judge profile records (FR10, FR11) |
| `working_patterns` | Domain | Per-judge working-pattern definition (target sit %, active period, FR12) |
| `working_pattern_days` | Domain | Per-day breakdown within a working pattern (per-day work-type, FR12) |
| `judge_tickets` | Domain | Per-judge ticket assignments (start date, ticket type, FR15) |
| `jurisdictional_splits` | Domain | Per-judge jurisdictional split percentages (must total 100%, FR16) |

## Absence service (`nji-absence`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `absences` | Domain | Absence records (start/end, type, NTBF flag, status, FR19–FR22) |

## Vacancy service (`nji-vacancy`) — 2 tables

| Table | Type | Purpose |
|---|---|---|
| `vacancies` | Domain | Cover-requirement records (FR23, FR24); `filled` and `filled_at` columns are UPDATE-granted to `nji_booking` per Principle 1 |
| `vacancy_days` | Domain | Per-day breakdown for vacancies (FR25 — cancel individual days with reason) |

## Booking service (`nji-booking`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `bookings` | Domain | Fee-paid booking records (FR29, FR31); `payment_status` column is UPDATE-granted to `nji_payment` per Principle 1. Has `version integer NOT NULL DEFAULT 0` (`@Version` for optimistic locking) and a `uq_bookings_vacancy_judge_session_date_type` unique constraint enforcing natural-key dedup on retries. |

## Sitting service (`nji-sitting`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `sittings` | Domain | Salaried-judge sitting records (FR35, FR37, FR38, FR39, FR40 — including verification state) |

## Payment service (`nji-payment`) — 3 tables

| Table | Type | Purpose |
|---|---|---|
| `payments` | Domain | Payment request records (FR41, FR42). Has `version` (`@Version`) and a `uq_payments_cycle_run_date` unique constraint enforcing natural-key dedup on retries (FR45 — no double payment submission). |
| `payment_schedules` | Domain | JFEPS-shaped schedule snapshots (FR43, FR44). |
| `payment_reconciliations` | Domain | Reconciliation records (FR46). |

## Itinerary service (`nji-itinerary`) — 0 tables

Read-model service. No persistent state at MVP per Principle 2 — every read is a SQL JOIN over the shared schema across `judges`, `absences`, `vacancies`, `bookings`, `sittings`. Strategy C cache is post-MVP if measurement justifies.

## MI Feed service (`nji-mi-feed`) — 0 tables

Read-model service. Same pattern as Itinerary; SQL JOIN over the shared schema for aggregate reporting.

## Mock authentication service (`nji-mock-auth`) — 2 tables (dev/integration only)

Per `nji_mock_auth` DB role. **Never deployed to production**; production deployments reject mock-auth issuer URLs (per G5.3 in [`./gaps.md`](./gaps.md)).

| Table | Type | Purpose |
|---|---|---|
| `mock_oauth_clients` | Dev-only | OAuth client registrations for service principals (Spring Authorization Server backend) |
| `mock_user_roster` | Dev-only | Test user roster mirroring a representative subset of `auth_users` for realistic Authorisation testing (G5.2) |

## Inventory totals

- **Reference Data:** 15 tables (3 domain + 12 vocabulary)
- **Authorisation:** 5 tables
- **Configuration:** 1 table
- **Notification:** 1 table
- **Judge:** 5 tables
- **Absence:** 1 table
- **Vacancy:** 2 tables
- **Booking:** 1 table
- **Sitting:** 1 table
- **Payment:** 3 tables
- **Itinerary, MI Feed:** 0 tables (read models)
- **Mock auth:** 2 tables (dev/integration only)

**Total: 37 tables** across the shared schema (35 in production scope + 2 dev-only).

**Retry safety convention:** every NJI domain table that supports create has a `uq_{table}_{columns}` unique constraint on its natural key, and every entity that supports update has a `version` column for JPA `@Version` optimistic locking. There are *no* per-service `*_idempotency_keys` tables — those were dropped in v2.1 in favour of these PostgreSQL-native primitives. See [`./conventions.md` → "Retry safety and concurrency control"](./conventions.md) for the pattern.

**On APEX SQL dump validation:** when the dump arrives in Phase 0 (per A32 + A33 in [`./assumptions.md`](./assumptions.md); G4.6 in [`./gaps.md`](./gaps.md)), the validation focus is on the **Phase 0 Data Migration ETL's input/output mapping**, not on this NJI table inventory. NJI's shape is fixed by NJI design; the dump can surface (a) APEX fields the migration tool didn't anticipate (mapping gap → update the tool), or (b) APEX values not yet in NJI vocabularies (vocabulary row insertion via the Reference Data API; no schema change). If a fundamental mismatch surfaces — e.g. an APEX-side data structure NJI has no place for at all — that is an architectural decision (do we add a new NJI table?), and it lands via PR against the architecture document set, exactly as any other architectural change would.

**Fitness function** (Step 4 *ArchUnit-style fitness functions* in [`../architecture.md`](../architecture.md)) operates against this inventory: every table created by Flyway DDL must appear here with the matching owning service; DB role grants must align. The Phase 0 ETL is *not* in scope for the fitness function — it's an external programme that calls NJI APIs.
