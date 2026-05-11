---
parent: ../architecture.md
title: Repository Strategy & List
last_updated: 2026-05-07
---

# Repository Strategy & List

> Sibling of [`../architecture.md`](../architecture.md). The parent links here from its *Project Structure & Boundaries* section.

## Repository Strategy: Polyrepo

**Decision:** 11 service repos + 1 mock-auth repo + 2 UI repos (business + admin) + 1 architecture/scaffolding repo. No monorepo, no Gradle root project.

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
| **`nji-booking`** | 4 | Fee-paid bookings + verification. | Create / verify / cancel fee-paid bookings (FR29, FR31); within the booking transaction, mark the target vacancy as filled (R5, Principle 1); retry-safe via native DB primitives (see [`../architecture.md`](../architecture.md) → *Data Architecture*). |
| **`nji-sitting`** | 5 | Salaried-judge sittings + verification. | Maintain sitting records (generated from working patterns); confirm and verify sittings (FR37); AM/PM session split (FR38); post-verification re-open via RBAC (FR40 — RSU Admin only at MVP, with mandatory justification + audit; no external RFC process); work-type override on confirmation. |
| **`nji-payment`** | 6 | Payment processing + reconciliation. JFEPS-shaped Excel output. **Two parts: a synchronous API (RSU reconciliation) and a scheduled batch component (`nji-payment-batch`).** | **Batch component** (scheduled; runs as service principal `nji-payment-batch` per v2.6): SQL JOIN read across confirmed bookings + sittings without an existing payment record; generate JFEPS Excel (FR41–FR44); persist payments and schedules; call Notification with bearer service token to dispatch the schedule (FR43). **Synchronous API**: RSU lists unreconciled payments and marks them reconciled (FR46). FR45 retry safety via native DB primitives (see [`../architecture.md`](../architecture.md) → *Data Architecture*). **Never stores bank details** (NFR14). |
| **`nji-itinerary`** | 7 | Operational read model. **No own tables** — SQL JOINs across judges, absences, vacancies, bookings, sittings. | Court itinerary view; Judge itinerary view (scoped to own profile per R2); Forward Look (≤ 30 s p95 — NFR8). |
| **`nji-mi-feed`** | 8 | Aggregate MI read model. **No own tables**. | Standard reports (utilisation, sittings, payments) with same parameter shape as APEX; aggregate-only — **no case-level data** (NFR23); Excel/PDF export; DA&I consumer interface (post-MVP). |
| **`nji-ui`** | 0–8 | **Business-user-facing SPA**, modules per domain. Excludes admin workflows. | Per-phase UI module replicating APEX functional surface for business roles (RSU operational work, Court users, Judges, Judges' Clerks, Finance/Payment Authoriser, MI); role-scoped Home with Outstanding-Actions tiles (FR55); SSO via HMCTS IdP / mock auth; GOV.UK Design System with WCAG 2.2 AA (NFR17). |
| **`nji-admin-ui`** | 0 | **Admin-facing SPA**, separated from business workflows. Same stack as `nji-ui` but distinct repo, pipeline, and deployment. | Reference Data maintenance (FR6 — Regions, Offices, judicial vocabularies, calendar / financial-year boundaries with named-owner sign-off); User & Role admin (FR4 — system administrators update role and Region/Area assignments for migrated and new users). Future admin surfaces reserved: per-region activation flag dashboard (FR58), Phase 0 migration reconciliation report viewer (FR57), post-MVP user-action audit viewer (D7 roadmap). Same SSO + Authorisation pattern as `nji-ui`. |

**15 repos total** (11 production services + 2 UI + architecture + mock-auth). `nji-mock-auth` is dev/integration-only and never deploys to production.

**Why split admin and business UI:** business operational workflows (judges, absences, vacancies, bookings, sittings, payments, itineraries, reports) are continuously evolving with HMCTS judicial process. Admin work (managing the controlled vocabularies and user role assignments those workflows depend on) is lower-cadence, higher-stakes (a wrong Region rename or role flip cascades into operational chaos), and has a different audience (system administrators, not RSU/Court/Judges). Keeping them in separate repos gives independent CI/CD, independent rollout, distinct CODEOWNERS, and prevents accidental coupling — for example, admin-only screens cannot leak into a business user's nav by misconfiguration. Same as the backend's per-service polyrepo discipline: minimise shared code, accept duplication, gain independence.
