---
parent: 'epics/index.md'
purpose: 'Single source of truth for FR → Epic mapping across all phases'
---

# FR Coverage Map

This is the canonical FR-to-Epic mapping. It is updated each time a phase advances from framework to concrete epics + stories. The Phase × Area framework in [framework.md](framework.md) is the architectural spine; this map is the implementation index.

## Phase 0 (concrete epics 0.1–0.4 — complete)

| FR | Epic | Notes |
|---|---|---|
| FR1 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | SSO via `nji-mock-auth` in non-prod |
| FR2 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | Authorisation principal → roles + scope mapping |
| FR3 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | `GET /users/{id}/effective-permissions` |
| FR4 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) (foundation) + [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (full edits) | Admin role/scope edits |
| FR5 | — | Post-MVP per PRD v2.5 (intentional deferral) |
| FR6 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | Ref Data maintenance with named-owner sign-off |
| FR7 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | Direct SQL via SELECT grants — pattern established |
| FR8 | distributed (lands in [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) first) | Shared `configuration_values` Flyway baseline |
| FR9 | [Epic 0.4](phase-0/epic-0.4-system-dispatches-emails.md) | Notification dispatch + delivery log |
| FR55 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | Home shell with role-scoped navigation |
| FR56 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) (business stack) + [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md)/[Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (admin stack) | Modern UI stack |
| FR57 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) (Ref Data ETL) + [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (Users/Roles ETL) | Phase 0 migration with named-owner sign-off |
| FR58 | [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (flag wire-up) — orchestration in Phase 9+ | Per-user activation flags |
| FR59 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | API-as-Product first exercise (Reference Data API) |
| FR60 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | Structured logs first exercise |

## Phases 1–9+ (FR10–FR54, FR61) — pending

To be populated by subsequent runs of `bmad-create-epics-and-stories` step 2 against the corresponding Phase × Area entries in [framework.md](framework.md). Phase 0 sets the pattern; later phases follow the same vertical-slice user-value framing.

| FR | Phase | Area | Status |
|---|---|---|---|
| FR10–FR18 | 1 | Judge Records & Working Patterns | ⚪ |
| FR19–FR22 | 2 | Absence Workflow | ⚪ |
| FR23–FR28 | 3 | Vacancy & Cover | ⚪ |
| FR29–FR34 | 4 | Booking Management | ⚪ |
| FR35–FR40 | 5 | Sitting Management | ⚪ |
| FR41 | 6 | Payment Processing | ⚪ |
| FR42, FR43, FR45 | 6 | Payment Batch | ⚪ |
| FR44, FR46, FR47 | 6 | Payment Processing | ⚪ |
| FR48–FR52 | 7 | Itineraries | ⚪ |
| FR53, FR54 | 8 | MI Feed & Reporting | ⚪ |
| FR61 | 9+ | Pilot Rollout | ⚪ |
