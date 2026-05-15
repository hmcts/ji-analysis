---
parent: 'epics/index.md'
phase: 0
phaseName: 'Foundations'
status: 'epics-and-stories-complete'
storiedAt: '2026-05-15'
validatedAt: '2026-05-15'
---

# Phase 0 — Foundations

> Phase 0 is the platform smoke-test (per PRD Key Characteristic 4). All API-as-Product standards (versioning, OpenAPI, [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), `Deprecation`/`Sunset`) are exercised on Reference Data writes and Authorisation lookups before any domain service is built.

The seven Phase 0 areas in [../framework.md](../framework.md) are an **architectural map**. The four concrete user-value epics below are the **implementation plan** — each delivers a demoable user outcome and consolidates the supporting technical work as stories within the epic rather than as separate technical-milestone epics.

## Epics

| Epic | Title | Stories | Status |
|---|---|---|---|
| [0.1](epic-0.1-user-authenticates.md) | User authenticates and lands on a role-scoped Home page | 5 | 🟢 |
| [0.2](epic-0.2-admin-manages-ref-data.md) | Admin manages reference data with named-owner migration sign-off | 5 | 🟢 |
| [0.3](epic-0.3-admin-manages-users-roles.md) | Admin manages users, roles, and per-region activation with migration sign-off | 4 | 🟢 |
| [0.4](epic-0.4-system-dispatches-emails.md) | System dispatches transactional emails and admin can verify delivery | 4 | 🟢 |
| **Total** | | **18 stories** | |

## Epic summaries

### Epic 0.1: User authenticates and lands on a role-scoped Home page

**User outcome:** A judicial user (RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, or MI/Reporting user) opens NJI, signs in via SSO, has their roles and Region/Area scope resolved, and lands on a Home page showing the navigation and tiles they're authorised to see.

**FRs covered:** FR1, FR2, FR3, FR55, FR56 (business stack portion)

**Key NFRs first exercised here:** NFR10 (TLS), NFR11 (data-at-rest), NFR12 (JWT propagation), NFR13 (authz enforcement), NFR15 (GovS 7), NFR16 (Key Vault), NFR17–NFR19 (WCAG 2.2 AA + assistive tech + Accessibility Regs 2018), NFR20 (HMCTS IdP integration via mock), NFR25–NFR28 (structured logs + Application Insights ingestion + liveness/readiness probes), NFR31 (Azure UK South data residency), NFR40 (per-service deployable on Kubernetes)

**Out of scope (explicitly):** FR5 machine-to-machine consumer auth (post-MVP per PRD v2.5). Real HMCTS IdP integration (mock-only at Phase 0; cuts over pre-Phase-9 per AR34).

→ [Full epic with stories](epic-0.1-user-authenticates.md)

### Epic 0.2: Admin manages reference data with named-owner migration sign-off

**User outcome:** An admin user signs into `nji-admin-ui`, opens Reference Data maintenance, can view and edit Regions, Offices, judicial vocabularies (12 controlled lists), and calendar / financial-year boundaries. Phase 0 ETL has loaded initial data from APEX; named owners review the migration reconciliation report and sign off before downstream phases consume the data.

**FRs covered:** FR4 (admin-foundation portion), FR6, FR7, FR57 (Reference Data portion), FR59, FR60

**Key NFRs:** NFR14 (no forbidden data), NFR17–NFR19 (admin UI WCAG), NFR40 (admin UI independently deployable from business UI), NFR42 (Postman collection)

→ [Full epic with stories](epic-0.2-admin-manages-ref-data.md)

### Epic 0.3: Admin manages users, roles, and per-region activation with migration sign-off

**User outcome:** An admin user signs into `nji-admin-ui`, opens the User & Role admin module, can search users (migrated from APEX + new), edit role and Region/Area scope assignments, view per-user effective permissions, and flip per-user activation flags. Phase 0 ETL has loaded the active APEX users and produced a reconciliation report keyed to HMCTS IdP principals (email primary, employee number fallback); named owners review and sign off, with explicit handling decisions (drop / hold / manual map) for unmatched records.

**FRs covered:** FR4 (full role/scope edits), FR57 (Users/Roles portion), FR58 (flag wire-up surface)

**Key NFRs:** NFR12–NFR13 (auth enforcement on admin endpoints), NFR17–NFR19 (admin UI WCAG)

**Why separate from Epic 0.2:** Different ETL stream, different domain owners (judicial-team owners for Reference Data vs identity / IT owners for Users/Roles), different reconciliation methodology (controlled-list vs identity-reconciliation), different risk profile (Risk #13 vs Risk #14). Bundling would dilute the user value and the sign-off accountability.

→ [Full epic with stories](epic-0.3-admin-manages-users-roles.md)

### Epic 0.4: System dispatches transactional emails and admin can verify delivery

**User outcome:** An admin can trigger a test email through a system-admin utility in `nji-admin-ui`; NJI dispatches via HMCTS email infrastructure; the delivery log records attempt and outcome. This establishes the pattern that downstream domain phases (Phase 2 Absence acknowledgement, Phase 4 Booking acknowledgement, Phase 6 Payment Batch dispatch) consume.

**FRs covered:** FR9

**Key NFRs:** NFR22 (HMCTS email infrastructure)

**Why Phase 0 rather than deferring to Phase 2 as a consumer:** Three downstream phases depend on Notification's API contract, retry semantics, and delivery-log schema (FR20 ack, FR32 ack, FR43 schedule dispatch). Locking those in Phase 0 with an admin-triggered demoable path avoids re-work and unblocks parallel development of the downstream consumers.

→ [Full epic with stories](epic-0.4-system-dispatches-emails.md)

## Phase 0 Epic Stories Summary

| Epic | Stories | FRs covered | Phase 0 demo |
|---|---|---|---|
| 0.1 | 5 stories (0.1.1–0.1.5) | FR1, FR2, FR3, FR8, FR55, FR56, FR58 (activation surface), FR59, FR60 | User signs in → role-scoped Home renders |
| 0.2 | 5 stories (0.2.1–0.2.5) | FR4 (foundation), FR6, FR7, FR57 (Ref Data), FR59, FR60 | Admin edits Ref Data with sign-off; ETL produces signed-off reconciliation report |
| 0.3 | 4 stories (0.3.1–0.3.4) | FR4 (full edits), FR57 (Users/Roles), FR58 (flag wire-up) | Admin manages users/roles + activation; signs off on Users/Roles migration |
| 0.4 | 4 stories (0.4.1–0.4.4) | FR9 | Admin sends test email; sees `sent` status; downstream phases can consume Notification |

**Cross-cutting NFRs verified across Phase 0 stories:** NFR10 (TLS), NFR11 (data-at-rest), NFR12 (JWT propagation + `client_credentials`), NFR13 (authz enforcement), NFR14 (no forbidden data), NFR15 (audit), NFR16 (Key Vault), NFR17–NFR19 (WCAG 2.2 AA), NFR20 (HMCTS IdP integration via mock), NFR22 (HMCTS email), NFR25–NFR28 (observability), NFR31 (Azure UK South), NFR39 (API-as-Product), NFR40 (per-service deployable), NFR42 (Postman collections).

## Validation

- [Phase 0 Validation Report (2026-05-15)](validation-report-2026-05-15.md) — full coverage validation, dependency analysis, and gap remediations
