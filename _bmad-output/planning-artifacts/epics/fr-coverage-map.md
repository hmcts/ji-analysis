---
parent: 'epics/index.md'
purpose: 'Single source of truth for FR → Epic mapping across all phases'
revisedAt: '2026-05-15'
revisionNote: 'Updated to reflect 2026-05-15 admin-UI-removed scope. FR4, FR6 (UI surfaces) and the admin-write portions of FR2 are deferred post-MVP. Data layers covered by SQL ETLs in Phase 0.'
---

# FR Coverage Map

This is the canonical FR-to-Epic mapping. It is updated each time a phase advances from framework to concrete epics + stories. The Phase × Area framework in [framework.md](framework.md) is the architectural spine; this map is the implementation index.

## Phase 0 (concrete epics 0.1–0.4 — complete, revised 2026-05-15)

| FR | Phase 0 epic / coverage | Post-MVP residual? | Notes |
|---|---|---|---|
| FR1 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | — | SSO via `ram-mock-auth` in non-prod |
| FR2 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | — | Authorisation principal → roles + scope (read-only API) |
| FR3 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | — | `GET /v1/users/{id}/effective-permissions` |
| **FR4** | **Data layer only** in [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (auth tables populated by SQL ETL; editable by DBAs via SQL) | **YES — UI surface** for sysadmins to update assignments **is post-MVP** | Was previously planned in Epic 0.2/0.3 admin UI stories — those stories were removed in the 2026-05-15 scope revision |
| FR5 | — | — | Post-MVP per PRD v2.5 (intentional deferral; pre-existing) |
| **FR6** | **Data layer + read API only** in [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) (read-only `GET` endpoints; data loaded by SQL ETL) | **YES — RSU UI for maintenance** is post-MVP | Read API works in Phase 0; the named-owner sign-off workflow for ongoing changes moves to the post-MVP admin UI roadmap |
| FR7 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | — | Direct SQL via SELECT grants — pattern established |
| FR8 | distributed (lands in [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) first) | — | Shared `configuration_values` Flyway baseline |
| FR9 | [Epic 0.4](phase-0/epic-0.4-system-dispatches-emails.md) | — | Notification dispatch + delivery log. User-JWT propagation only at Phase 0; `client_credentials` flow moved to Phase 6 |
| FR55 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) | — | Home shell with role-scoped navigation |
| FR56 | [Epic 0.1](phase-0/epic-0.1-user-authenticates.md) (business stack) | **Partial — admin stack** is post-MVP | The `ram-ui` business-user stack is delivered in Phase 0; the `ram-admin-ui` admin stack is post-MVP |
| FR57 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) (Ref Data ETL via SQL) + [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (Users/Roles ETL via SQL) | — | Both ETL streams now load via direct SQL rather than via API; named-owner sign-off via versioned git commits |
| FR58 | [Epic 0.3](phase-0/epic-0.3-admin-manages-users-roles.md) (initial flag state via ETL — all FALSE) — orchestration in Phase 9+ (per-region flip via direct SQL by DBA) | **Partial — activation toggle UI** is post-MVP | MVP cutover happens by DBA running `UPDATE auth_user_activation_flags SET activated = TRUE WHERE region = …` per the rollout runbook |
| FR59 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | — | API-as-Product first exercise on Reference Data read API |
| FR60 | [Epic 0.2](phase-0/epic-0.2-admin-manages-ref-data.md) | — | Structured logs first exercise |

### Phase 0 → post-MVP deferral summary (2026-05-15 revision)

| FR | What's in Phase 0 (MVP) | What's deferred to post-MVP |
|---|---|---|
| FR4 | Auth tables loaded via SQL ETL; data editable by DBAs via direct SQL | Admin UI surface for system administrators to update role + Region/Area scope assignments |
| FR6 | Read API + SQL-loaded data with git-based owner sign-off | RSU UI for view/edit/create on controlled lists; pending-change workflow with named-owner sign-off via UI |
| FR56 | Business-user `ram-ui` (modern stack, WCAG 2.2 AA) | Admin-user `ram-admin-ui` (same stack, distinct hostname) — was already partially admin-only; now fully post-MVP |
| FR58 | Activation flag table populated by ETL; cutover flips via DBA SQL | Activation toggle UI for system administrators |

## Phases 1–9+ (FR10–FR54, FR61) — pending

To be populated by subsequent runs of `bmad-create-epics-and-stories` step 2 against the corresponding Phase × Area entries in [framework.md](framework.md). Phase 0 sets the pattern; later phases follow the same vertical-slice user-value framing.

| FR | Phase | Area | Status |
|---|---|---|---|
| FR10–FR18 | 1 | Judge Records & Working Patterns | ⚪ |
| FR19–FR22 | 2 | Absence Workflow (first user-initiated Notification consumer via FR20 ack email) | ⚪ |
| FR23–FR28 | 3 | Vacancy & Cover | ⚪ |
| FR29–FR34 | 4 | Booking Management (second user-initiated Notification consumer via FR32 ack email) | ⚪ |
| FR35–FR40 | 5 | Sitting Management | ⚪ |
| FR41 | 6 | Payment Processing | ⚪ |
| FR42, FR43, FR45 | 6 | Payment Batch (**first non-user-initiated Notification consumer** — `client_credentials` flow established here, was previously planned in Phase 0) | ⚪ |
| FR44, FR46, FR47 | 6 | Payment Processing | ⚪ |
| FR48–FR52 | 7 | Itineraries | ⚪ |
| FR53, FR54 | 8 | MI Feed & Reporting | ⚪ |
| FR61 | 9+ | Pilot Rollout | ⚪ |

## Post-MVP roadmap (consolidated, 2026-05-15)

Items removed from MVP per the 2026-05-15 admin-UI-out-of-scope decision:

| Capability | Original Phase 0 owner (now removed) | Post-MVP owner |
|---|---|---|
| `ram-admin-ui` repo scaffold + auth wrapper | was Story 0.2.3 | Post-MVP UI programme |
| Reference Data admin module (list/edit/create + sign-off workflow) | was Story 0.2.4 | Post-MVP UI programme |
| Reference Data API write endpoints (`POST/PUT/PATCH/DELETE`) | was part of Story 0.2.2 | Post-MVP — paired with the admin UI |
| `ram-authorisation` admin write endpoints (`PUT /admin/users/{id}/...`) | was Story 0.3.1 | Post-MVP — paired with the admin UI |
| Users & Roles admin module | was Story 0.3.2 | Post-MVP UI programme |
| Migration Reports admin module | was Story 0.3.4 | Post-MVP UI programme |
| Admin "Send Test Email" UI | was Story 0.4.4 | Post-MVP UI programme |
| Delivery-log viewer UI | (no prior story; Postman covered) | Post-MVP UI programme |
| Activation-flag toggle UI | (no prior story; Phase 9+ direct SQL covers MVP) | Post-MVP UI programme |
