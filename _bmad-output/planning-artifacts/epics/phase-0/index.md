---
parent: 'epics/index.md'
phase: 0
phaseName: 'Foundations'
status: 'epics-and-stories-complete'
storiedAt: '2026-05-15'
validatedAt: '2026-05-15'
revisedAt: '2026-05-15'
revisionNote: 'Admin UI removed from MVP scope. User/role/scope/reference-data write operations move to direct SQL (DBA-operated). API surfaces are read-only. Phase 0 story count reduces from 18 → 11.'
---

# Phase 0 — Foundations

> Phase 0 is the platform smoke-test (per PRD Key Characteristic 4). All API-as-Product standards (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), `Deprecation`/`Sunset`) are exercised on Reference Data **reads** and Authorisation lookups before any domain service is built.
>
> The seven Phase 0 areas in [../framework.md](../framework.md) are an **architectural map**. The four concrete user-value epics below are the **implementation plan** — each delivers a demoable user outcome and consolidates the supporting technical work as stories within the epic.

## 2026-05-15 scope revision: admin UI removed from MVP

Per the 2026-05-15 product-direction decision:

- **Admin UI is not in scope for Phase 0 — and not in scope for MVP at all.** It moves to the post-MVP roadmap.
- **Reference Data and Users/Roles/Activation are managed via direct SQL** during MVP — by DBAs operationally — not via admin-gated API or admin UI.
- **API write endpoints are removed**: Reference Data API becomes read-only; Authorisation API stays read-only (it always was for runtime callers — the planned admin-write extensions are removed).
- **Named-owner sign-off** for migration data still happens, but via **versioned git commits** rather than a UI surface.

Phase 0 stories reduce from 18 → 11. Phase 0 epics still number 4.

## Epics

| Epic | Title | Stories | Status |
|---|---|---|---|
| [0.1](epic-0.1-user-authenticates.md) | User authenticates and lands on a role-scoped Home page | 5 | 🟢 |
| [0.2](epic-0.2-admin-manages-ref-data.md) | Reference data is SQL-loaded and served read-only | **3** *(was 5)* | 🟢 |
| [0.3](epic-0.3-admin-manages-users-roles.md) | Users, roles, and activation flags are SQL-loaded | **1** *(was 4)* | 🟢 |
| [0.4](epic-0.4-system-dispatches-emails.md) | Notification service is scaffolded and contractually ready | **2** *(was 4)* | 🟢 |
| **Total** | | **11 stories** *(was 18)* | |

## Epic summaries

### Epic 0.1: User authenticates and lands on a role-scoped Home page (5 stories, unchanged scope)

**User outcome:** A judicial user (RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, or MI/Reporting user) opens RAM Pathfinder, signs in via SSO, has their roles and Region/Area scope resolved by `ram-authorisation`'s **read-only** API, and lands on a Home page showing the navigation and tiles they're authorised to see.

**FRs covered:** FR1, FR2, FR3, FR55, FR56 (business stack portion)

**Key NFRs first exercised here:** NFR10, NFR11, NFR12, NFR13, NFR15, NFR16, NFR17–NFR19 (business UI WCAG), NFR20, NFR25–NFR28, NFR31, NFR40

**2026-05-15 change:** Story 0.1.3 reworded slightly to make explicit that `ram-authorisation` is read-only — its planned admin write endpoints (was Story 0.3.1 in the prior plan) are removed from MVP. The auth tables are still created here in Phase 0 — they're populated by Epic 0.3's SQL ETL.

→ [Full epic with stories](epic-0.1-user-authenticates.md)

### Epic 0.2: Reference data is SQL-loaded and served read-only (3 stories, was 5)

**User outcome:** Reference Data (Regions, Offices, judicial vocabularies, calendar / financial-year boundaries) is loaded into RAM Pathfinder via a direct-SQL ETL with named-owner sign-off, and is queryable read-only by downstream RAM Pathfinder services via a versioned REST API. Named owners approve via versioned git commits — **no admin UI** in MVP.

**FRs covered (Phase 0 surface):** FR7, FR57 (Reference Data portion via SQL), FR59, FR60

**FRs deferred post-MVP (UI surface):** FR6 (RSU UI for ref-data maintenance), FR4 (admin UI is the surface; data still loadable by DBAs via SQL)

**Key NFRs:** NFR14, NFR40, NFR42. *(NFR17–NFR19 do not apply here in Phase 0 — no UI for this domain until post-MVP.)*

**2026-05-15 change:** Stories 0.2.3 (Admin UI scaffolding) and 0.2.4 (Admin UI Reference Data module) removed. API becomes read-only (no admin CRUD writes). ETL loads via direct SQL `INSERT` rather than calling the API. What was Story 0.2.5 is renumbered to Story 0.2.3.

→ [Full epic with stories](epic-0.2-admin-manages-ref-data.md)

### Epic 0.3: Users, roles, and activation flags are SQL-loaded (1 story, was 4)

**User outcome:** Active APEX users and their role/Region/Area assignments are loaded into the RAM Pathfinder Authorisation tables via a direct-SQL ETL, with named-owner sign-off and explicit handling of unmatched records via versioned CSV decision files. Per-region activation flags are initialised all-FALSE and flipped per region during Phase 9+ cutover via direct SQL. **No admin UI.**

**FRs covered (Phase 0 surface):** FR57 (Users/Roles portion via SQL), FR58 (initial flag state via ETL)

**FRs deferred post-MVP (UI surface):** FR4 (admin UI for role/scope edits — data still editable by DBAs via SQL)

**2026-05-15 change:** Stories 0.3.1 (admin API extensions), 0.3.2 (admin UI users/roles), 0.3.4 (admin UI migration reports) all removed. Only what was Story 0.3.3 remains, renumbered to Story 0.3.1. Unmatched-record decisions move from a UI workflow to an **editable CSV** in version control.

**Why one story is OK as an epic:** the user value (users can sign in because their records exist) is distinct from Reference Data, the named-owner is different (identity/IT lead vs RSU/judicial-vocabulary owners), and the risk profile (Risk #14) differs from Reference Data's Risk #13.

→ [Full epic with stories](epic-0.3-admin-manages-users-roles.md)

### Epic 0.4: Notification service is scaffolded and contractually ready (2 stories, was 4)

**User outcome:** `ram-notification` is deployed with its API contract published, delivery log table created, SMTP integration configured, and `POST /v1/notifications/send` working. The contract is consumable from Phase 2+ via **user-JWT propagation**. Integration testing in MVP happens via Postman — **no admin UI**.

**FRs covered:** FR9

**Key NFRs:** NFR12 (JWT propagation), NFR15, NFR22, NFR25–NFR28, NFR39, NFR42

**2026-05-15 change:** Story 0.4.3 (OAuth `client_credentials` flow) **moved to Phase 6** — that's when `ram-payment-batch` arrives as the first non-user-initiated consumer that needs it. Story 0.4.4 (admin "Send Test Email" UI) **removed**, deferred post-MVP — Postman covers the integration-test gap.

→ [Full epic with stories](epic-0.4-system-dispatches-emails.md)

## Phase 0 Epic Stories Summary

| Epic | Stories | FRs covered | Phase 0 demo |
|---|---|---|---|
| 0.1 | 5 stories (0.1.1–0.1.5) | FR1, FR2, FR3, FR8, FR55, FR56, FR58 (activation flag surface), FR59, FR60 | User signs in → role-scoped Home renders |
| 0.2 | 3 stories (0.2.1–0.2.3) | FR7, FR57 (Ref Data via SQL), FR59, FR60 | Ref Data API serves controlled lists; ETL produces signed-off reconciliation report (via git) |
| 0.3 | 1 story (0.3.1) | FR57 (Users/Roles via SQL), FR58 (flag bootstrap) | Users + roles + scope live in auth tables; named-owner signoff in git; Epic 0.1 sign-in actually works against migrated users |
| 0.4 | 2 stories (0.4.1–0.4.2) | FR9 | `POST /v1/notifications/send` works end-to-end via Postman against Mailpit |
| **Total** | **11 stories** | | All four demos chain together for the Phase 0 stakeholder walkthrough |

**Cross-cutting NFRs verified across Phase 0 stories:** NFR10 (TLS), NFR11 (data-at-rest), NFR12 (JWT propagation), NFR13 (authz enforcement on reads), NFR14 (no forbidden data), NFR15 (audit via git commits + delivery log), NFR16 (Key Vault), NFR17–NFR19 (business UI WCAG — admin UI deferred), NFR20 (HMCTS IdP integration via mock), NFR22 (HMCTS email), NFR25–NFR28 (observability), NFR31 (Azure UK South), NFR39 (API-as-Product), NFR40 (per-service deployable), NFR42 (Postman collections).

## Post-MVP roadmap items spun out of Phase 0 (2026-05-15 revision)

The following surfaces were removed from Phase 0 / MVP and now sit on the post-MVP roadmap:

1. **`ram-admin-ui` repo** — scaffolding + auth wrapper + GOV.UK Design System admin theme
2. **Reference Data admin module** in `ram-admin-ui` — list/edit/create flows with named-owner sign-off workflow
3. **Users & Roles admin module** in `ram-admin-ui` — search, edit roles, edit Region/Area scope, toggle activation flag
4. **Migration Reports admin module** in `ram-admin-ui` — view reconciliation reports, apply decisions to unmatched records, sign off via UI
5. **Reference Data API write endpoints** — `POST/PUT/PATCH/DELETE`, admin-gated
6. **`ram-authorisation` admin write endpoints** — `PUT /v1/admin/users/{id}/roles`, `PUT /v1/admin/users/{id}/region-scopes`, `PUT /v1/admin/users/{id}/activation`
7. **Admin "Send Test Email" UI** in `ram-admin-ui`
8. **Delivery-log viewer UI**

What's NOT in this post-MVP list (because it migrated out of Phase 0 to a different MVP phase rather than post-MVP):

- **OAuth `client_credentials` flow** for batch / scheduled callers — moved to **Phase 6** alongside `ram-payment-batch`. Still MVP, just later.

## Validation

- [Phase 0 Validation Report (2026-05-15, revised)](validation-report-2026-05-15.md) — full coverage validation, dependency analysis, and gap remediations, **updated to reflect the 2026-05-15 admin-UI-removed scope**.
