---
parent: ../architecture.md
title: Repository Strategy & List
last_updated: 2026-05-07
---

# Repository Strategy & List

> Sibling of [`../architecture.md`](../architecture.md). The parent links here from its *Project Structure & Boundaries* section.

## Repository Strategy: Polyrepo

**Decision:** 11 service repos + 1 mock-auth repo + 1 UI repo + 1 architecture/scaffolding repo. No monorepo, no Gradle root project.

A monorepo would either share `build.gradle` config (breaks no-shared-coupling), coordinate releases (breaks per-region phased rollout independence), or add Bazel-style hermetic build complexity that NJI's requirements don't need.

Polyrepo gives each service its own repo, pipeline, release cadence, CODEOWNERS, branch protection, and review policy. What stays cross-repo: API contracts (OpenAPI specs), the architecture documents and ADRs, the scaffolding script, the Phase 0 Data Migration ETL.

## Repository List

| Repo | Phase | Purpose | Key Functions |
|---|---|---|---|
| **`nji-architecture`** | 0 | Architecture index + siblings, ADRs, scaffolding script, **Phase 0 Data Migration ETL** under `migration/`. | Maintain architecture docs and ADRs; generate new service repos via `nji-scaffold.sh`; run the APEX → NJI ETL via NJI APIs; produce reconciliation reports. |
| **`nji-mock-auth`** | 0 | OIDC issuer for dev / CI / integration (human users **and** batch service principals). **Never deployed to production.** | Issue JWTs via OIDC `authorization_code` for human users; **issue service tokens via OAuth `client_credentials`** for batch components (initially `nji-payment-batch`); refuse to start with `production` profile (G5.3). |
| **`nji-reference-data`** | 0 | Owns the 15 Reference Data tables. | CRUD for `regions` / `offices` / `calendar_periods` and the 12 vocabulary tables; accept Phase 0 ETL writes; reads happen via direct SQL by other services. |
| **`nji-authorisation`** | 0 | Owns the 5 Authorisation tables; **the per-request authz authority**. | Manage `auth_users`, the 12 `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`; expose `POST /authz/check`; enforce per-region phased activation (FR58); reconcile principals to HMCTS IdP by email + employee number (D9). |
| **`nji-notification`** | 0 | Outbound transactional email dispatch. | Send booking ack (FR32) / absence ack / JFEPS-shaped payment-schedule emails (FR43); record dispatch log; retry on transient failure. |
| **`nji-judge`** | 1 | Judge profile + working patterns + tickets + jurisdictional split. | CRUD judge profiles (FR10, FR11); manage working patterns (FR12); generate forward sittings; manage tickets (FR15); jurisdictional splits with 100% sum constraint (FR16). |
| **`nji-absence`** | 2 | Absence records + approval workflow. | Create / approve / NTBF-flag / sickness-extend (FR19–FR22); on approval, call Vacancy to create cover-required vacancies (R4); send acknowledgements via Notification. |
| **`nji-vacancy`** | 3 | Cover-requirement records + per-day breakdown. | Create vacancies (FR23, FR24); manage `vacancy_days` (FR25); accept `filled` / `filled_at` UPDATEs from Booking. |
| **`nji-booking`** | 4 | Fee-paid bookings + verification. | Create / verify / cancel fee-paid bookings (FR29, FR31); within booking transaction take pessimistic row lock on the target vacancy and mark filled via direct DB UPDATE (R5, Principle 1); natural-key unique constraint + `@Version` provide retry safety. |
| **`nji-sitting`** | 5 | Salaried-judge sittings + verification. | Maintain sitting records (generated from working patterns); confirm and verify sittings (FR37); AM/PM session split (FR38); RFC unlock (FR40); work-type override on confirmation. |
| **`nji-payment`** | 6 | Payment processing + reconciliation. JFEPS-shaped Excel output. **Two parts: a synchronous API (RSU reconciliation) and a scheduled batch component (`nji-payment-batch`).** | **Batch component** (scheduled; runs as service principal `nji-payment-batch` per v2.6): SQL JOIN read across confirmed bookings + sittings without an existing payment record; generate JFEPS Excel (FR41–FR44); INSERT `payments` + `payment_schedules`; call Notification with bearer service token to dispatch the schedule (FR43). **Synchronous API**: RSU lists unreconciled payments and marks them reconciled (FR46). Natural-key unique on `(payment_cycle_id, run_date)` + `@Version` for FR45 retry safety; **never stores bank details** (NFR14). |
| **`nji-itinerary`** | 7 | Operational read model. **No own tables** — SQL JOINs across judges, absences, vacancies, bookings, sittings. | Court itinerary view; Judge itinerary view (scoped to own profile per R2); Forward Look (≤ 30 s p95 — NFR8). |
| **`nji-mi-feed`** | 8 | Aggregate MI read model. **No own tables**. | Standard reports (utilisation, sittings, payments) with same parameter shape as APEX; aggregate-only — **no case-level data** (NFR23); Excel/PDF export; DA&I consumer interface (post-MVP). |
| **`nji-ui`** | 0–8 | Single SPA repo, modules per domain. | Per-phase UI module replicating APEX functional surface; role-scoped Home with Outstanding-Actions tiles (FR55); SSO via HMCTS IdP / mock auth; GOV.UK Design System with WCAG 2.2 AA (NFR17). |

**14 repos total** (11 production services + UI + architecture + mock-auth). `nji-mock-auth` is dev/integration-only and never deploys to production.
