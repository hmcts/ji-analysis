---
parent: ../architecture.md
title: Authoritative Table Ownership Mapping
last_updated: 2026-05-06
extracted_in: architecture.md v1.8 — Strategy B refactor
---

# Authoritative Table Ownership Mapping

> Sibling of [`../architecture.md`](../architecture.md). The parent's *Data Architecture* section holds the strategy (shared schema, per-service DB roles, table-name convention, Flyway). This file holds the per-table inventory.

## RAM Pathfinder tables, not APEX

This is the inventory of RAM Pathfinder database tables, grouped by owning service. The table list, column shapes, FK relationships, and ownership boundaries are RAM Pathfinder's design.

APEX has its own (different) schema. APEX's schema is not in this inventory and is not owned by any RAM Pathfinder service. The Phase 0 ETL (see [`../architecture.md` → *Phase 0 Data Migration from APEX*](../architecture.md)) reads APEX dumps, transforms rows into RAM Pathfinder shape, and loads via RAM Pathfinder APIs.

> **Revalidation scope.** When the APEX SQL dump arrives in Phase 0, the migration tool's input-side mapping is revalidated against it: does the mapping cover every APEX field RAM Pathfinder needs, and does RAM Pathfinder have a slot for every APEX value? RAM Pathfinder's schema itself is not under revalidation — it is fixed by RAM Pathfinder design. New APEX vocabulary values are added as Reference Data rows via the API. Tracked as G4.6 in [`./gaps.md`](./gaps.md) and A33 in [`./assumptions.md`](./assumptions.md).

For naming convention rules (entity-plural for primary domain tables, service-prefix for service-internal or potentially-ambiguous tables), see [`./conventions.md` → "Naming Patterns"](./conventions.md).

## Reference Data service (`ram-reference-data`) — 15 tables

Cross-cutting controlled lists. Reads go directly via SQL JOIN with per-service SELECT grants. Writes go via the Reference Data API.

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
| `judge_fee_entitlements` | Vocabulary | Per-judge fee-entitlement list (yes / no / ask-when-booking). Answers "is this judge entitled to a fee for their sittings?" Set on the judge profile (FR11); consumed at booking time (FR33). | Judge (FR11), Booking (FR33) |
| `payment_lifecycle_statuses` | Vocabulary | Payment-record lifecycle (pending / requested / paid / reconciled / queried). State of an individual payment as it moves through the JFEPS / Liberata flow. | Payment (FR41, FR46), Booking (`payment_lifecycle_status_id` column UPDATE-granted to `ram_payment`) |
| `reconciliation_statuses` | Vocabulary | Reconciliation status list (matched / queried / unreconciled) | Payment (FR46) |

## Authorisation service (`ram-authorisation`) — 5 tables

RAM Pathfinder-owned tables, designed by RAM Pathfinder. Seeded in Phase 0 by the Phase 0 Data Migration ETL (per D9), which reads APEX user dumps, transforms them, and loads via the Authorisation API. Service prefix used because "users" / "roles" are domain-overloaded terms.

| Table | Type | Purpose |
|---|---|---|
| `auth_users` | Domain | RAM Pathfinder users (one row per active APEX user that the Phase 0 ETL was able to reconcile to an IdP principal by email + employee number) |
| `auth_roles` | Domain | RAM Pathfinder authorisation roles (the 12 documented roles from `functional-modules.md`) |
| `auth_user_roles` | Domain | User-role junction (many-to-many) |
| `auth_user_region_scopes` | Domain | Per-user Region/Area scope assignments |
| `auth_user_activation_flags` | Domain | Per-user "active in RAM Pathfinder" flag (FR58 — per-region phased activation) |

## Shared infrastructure tables (no owning service) — 1 table

Schema-managed by `ram-architecture`'s Flyway baseline migration; SELECT-granted to every RAM Pathfinder service DB role; writes are admin / Flyway-only (no API). *(Introduced in v2.2, 2026-05-07 — replaces the dedicated `ram-configuration` service.)*

| Table | Type | Purpose |
|---|---|---|
| `configuration_values` | Shared infra | Typed cross-service policy values (D1 — runtime policy keys that need to be visible to multiple services). Per-service configuration that is scoped to a single service uses Spring profiles + `application.yml` + Azure Key Vault, **not** this table. |

## Notification service (`ram-notification`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `notification_dispatches` | Domain | Outbound email dispatch log (recipient, content type, dispatched-at, status, retry count, FR9) |

## Judge service (`ram-judge`) — 5 tables

| Table | Type | Purpose |
|---|---|---|
| `judges` | Domain | Judge profile records (FR10, FR11) |
| `working_patterns` | Domain | Per-judge working-pattern definition (target sit %, active period, FR12) |
| `working_pattern_days` | Domain | Per-day breakdown within a working pattern (per-day work-type, FR12) |
| `judge_tickets` | Domain | Per-judge ticket assignments (start date, ticket type, FR15) |
| `jurisdictional_splits` | Domain | Per-judge jurisdictional split percentages (must total 100%, FR16) |

## Absence service (`ram-absence`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `absences` | Domain | Absence records (start/end, type, NTBF flag, status, FR19–FR22) |

## Vacancy service (`ram-vacancy`) — 2 tables

| Table | Type | Purpose |
|---|---|---|
| `vacancies` | Domain | Cover-requirement records (FR23, FR24); `filled` and `filled_at` columns are UPDATE-granted to `ram_booking` per Principle 1 |
| `vacancy_days` | Domain | Per-day breakdown for vacancies (FR25 — cancel individual days with reason) |

## Booking service (`ram-booking`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `bookings` | Domain | Fee-paid booking records (FR29, FR31); `payment_lifecycle_status_id` column is UPDATE-granted to `ram_payment` per Principle 1. Has `version integer NOT NULL DEFAULT 0` (`@Version` for optimistic locking) and a `uq_bookings_vacancy_judge_session_date_type` unique constraint enforcing natural-key dedup on retries. |

## Sitting service (`ram-sitting`) — 1 table

| Table | Type | Purpose |
|---|---|---|
| `sittings` | Domain | Salaried-judge sitting records (FR35, FR37, FR38, FR39, FR40 — including verification state) |

## Payment service (`ram-payment`) — 3 tables

| Table | Type | Purpose |
|---|---|---|
| `payments` | Domain | Payment request records (FR41, FR42). Has `version` (`@Version`) and a `uq_payments_cycle_run_date` unique constraint enforcing natural-key dedup on retries (FR45 — no double payment submission). |
| `payment_schedules` | Domain | JFEPS-shaped schedule snapshots (FR43, FR44). |
| `payment_reconciliations` | Domain | Reconciliation records (FR46). |

## Itinerary service (`ram-itinerary`) — 0 tables

Read-model service. No persistent state at MVP per Principle 2 — every read is a SQL JOIN over the shared schema across `judges`, `absences`, `vacancies`, `bookings`, `sittings`. Strategy C cache is post-MVP if measurement justifies.

## MI Feed service (`ram-mi-feed`) — 0 tables

Read-model service. Same pattern as Itinerary; SQL JOIN over the shared schema for aggregate reporting.

## Mock authentication service (`ram-mock-auth`) — 2 tables (dev/integration only)

Per `ram_mock_auth` DB role. **Never deployed to production**; production deployments reject mock-auth issuer URLs (per G5.3 in [`./gaps.md`](./gaps.md)).

| Table | Type | Purpose |
|---|---|---|
| `mock_oauth_clients` | Dev-only | OAuth client registrations (Spring Authorization Server backend). Holds **(a)** the SPA client for human `authorization_code` flow, and **(b)** service-principal client registrations for **batch / scheduled components** that need a service identity (initially: `ram-payment-batch`). User-initiated runtime calls between services use **JWT propagation** (no service principal needed); batch / scheduled components — which have no upstream user context — use OAuth `client_credentials` against this mock issuer. *(v2.5 narrowing reverted in v2.6 to support the payment batch.)* |
| `mock_user_roster` | Dev-only | Test user roster mirroring a representative subset of `auth_users` for realistic Authorisation testing (G5.2) |

## Inventory totals

- **Reference Data:** 15 tables (3 domain + 12 vocabulary)
- **Authorisation:** 5 tables
- **Notification:** 1 table
- **Judge:** 5 tables
- **Absence:** 1 table
- **Vacancy:** 2 tables
- **Booking:** 1 table
- **Sitting:** 1 table
- **Payment:** 3 tables
- **Itinerary, MI Feed:** 0 tables (read models)
- **Shared infrastructure:** 1 table (`configuration_values`; no owning service)
- **Mock auth:** 2 tables (dev/integration only)

**Total: 37 tables** across the shared schema (34 service-owned production + 1 shared infrastructure + 2 dev-only).

**Retry safety convention:** every RAM Pathfinder domain table that supports create has a `uq_{table}_{columns}` unique constraint on its natural key, and every entity that supports update has a `version` column for JPA `@Version` optimistic locking. There are *no* per-service `*_idempotency_keys` tables — those were dropped in v2.1 in favour of these PostgreSQL-native primitives. See [`./conventions.md` → "Retry safety and concurrency control"](./conventions.md) for the pattern.

**On APEX SQL dump validation:** when the dump arrives in Phase 0 (per A32 + A33 in [`./assumptions.md`](./assumptions.md); G4.6 in [`./gaps.md`](./gaps.md)), the validation focus is on the **Phase 0 Data Migration ETL's input/output mapping**, not on this RAM Pathfinder table inventory. RAM Pathfinder's shape is fixed by RAM Pathfinder design; the dump can surface (a) APEX fields the migration tool didn't anticipate (mapping gap → update the tool), or (b) APEX values not yet in RAM Pathfinder vocabularies (vocabulary row insertion via the Reference Data API; no schema change). If a fundamental mismatch surfaces — e.g. an APEX-side data structure RAM Pathfinder has no place for at all — that is an architectural decision (do we add a new RAM Pathfinder table?), and it lands via PR against the architecture document set, exactly as any other architectural change would.

**Fitness function** (Step 4 *ArchUnit-style fitness functions* in [`../architecture.md`](../architecture.md)) operates against this inventory: every table created by Flyway DDL must appear here with the matching owning service (or under "Shared infrastructure"); DB role grants must align. The Phase 0 ETL is *not* in scope for the fitness function — it's an external programme that calls RAM Pathfinder APIs.
