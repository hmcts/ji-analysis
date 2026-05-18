---
parent: 'epics/phase-0/index.md'
purpose: 'Phase 0 final validation report (Step 4 of bmad-create-epics-and-stories)'
date: '2026-05-15'
revisedAt: '2026-05-15'
revisionNote: 'Revised after the 2026-05-15 admin-UI-removed scope decision. Story count reduces from 18 → 11. FR4/FR6 UI surfaces deferred post-MVP.'
scope: 'Phase 0 (Epics 0.1–0.4, 11 stories total — revised from 18)'
verdict: 'VALIDATED - READY FOR IMPLEMENTATION'
---

# Phase 0 Step 4 — Final Validation Report (2026-05-15, revised)

**Date:** 2026-05-15
**Scope:** Phase 0 (Epics 0.1–0.4, 11 stories — revised down from 18 after the 2026-05-15 admin-UI-removed scope decision)

## What changed in this revision

The 2026-05-15 product-direction decision removes admin UI from MVP scope entirely. Phase 0 simplifies accordingly:

- **Story count:** 18 → **11**
- **Stories removed:**
  - Was 0.2.3 (Scaffold `ram-admin-ui`) — removed
  - Was 0.2.4 (Admin UI Reference Data module) — removed
  - Was 0.3.1 (`ram-authorisation` admin API extensions) — removed
  - Was 0.3.2 (Admin UI Users & Roles module) — removed
  - Was 0.3.4 (Admin UI Migration Reports module) — removed
  - Was 0.4.4 (Admin "Send Test Email" UI) — removed
- **Stories moved:**
  - Was 0.4.3 (OAuth `client_credentials` flow) — **moved to Phase 6** alongside `ram-payment-batch`
- **Stories renumbered:**
  - Was 0.2.5 → now 0.2.3 (Reference Data ETL — and changed to load via direct SQL rather than via the API)
  - Was 0.3.3 → now 0.3.1 (Users/Roles ETL — likewise)
- **Stories with content tweaks (no renumber):**
  - 0.1.3 — emphasises read-only API; auth tables still created here but populated by Epic 0.3's SQL ETL
  - 0.2.2 — read-only API only; no write endpoints; explicit `405 Method Not Allowed` on write attempts
  - Both renumbered ETL stories — now load via direct SQL `INSERT`, not via API

## FR Coverage (Phase 0 scope, post-revision)

Phase-0-applicable MVP FRs:

- **Fully covered (10):** FR1 ✅, FR2 ✅, FR3 ✅, FR7 ✅, FR8 ✅, FR9 ✅, FR55 ✅, FR57 ✅, FR59 ✅, FR60 ✅
- **Partially covered (4) — data layer in Phase 0, UI surface deferred post-MVP:**
  - **FR4** — auth tables populated by Epic 0.3's SQL ETL; DBAs can update via direct SQL; **admin UI surface for sysadmins to update role/scope assignments is post-MVP**
  - **FR6** — read API + SQL-loaded data in Phase 0; **RSU UI for maintenance is post-MVP**
  - **FR56** — `ram-ui` business stack covered; `ram-admin-ui` admin stack moves post-MVP
  - **FR58** — initial flag state set by ETL in Phase 0; cutover flips happen per region during Phase 9+ via direct SQL; **activation toggle UI is post-MVP**
- **Intentionally deferred (pre-existing, unchanged):** FR5 (post-MVP per PRD v2.5)

This is a **conscious scope reduction** approved at the 2026-05-15 product-direction decision. The deferred UI surfaces are documented in `epics/fr-coverage-map.md` under "Post-MVP roadmap".

## NFR Coverage (Phase 0 scope, post-revision)

All in-scope Phase 0 NFRs explicitly addressed via story ACs:

NFR10 ✅ (Story 0.1.1), NFR11 ✅ (Story 0.1.1), NFR12 ✅, NFR13 ✅, NFR14 ✅, NFR15 ✅ (audit now via git commits on `signoffs/` + delivery log table), NFR16 ✅, NFR17–NFR19 ✅ (business UI only; admin UI accessibility deferred with the admin UI), NFR20 ✅, NFR22 ✅, NFR25 ✅, NFR26 ✅ (Story 0.1.1 — 90 day non-prod / 365 day prod default subject to HMCTS sign-off), NFR27 ✅, NFR28 ✅, NFR31 ✅, NFR39 ✅, NFR40 ✅, NFR42 ✅

## Dependency Validation

- ✅ **Epic independence** — no epic requires a later epic to function. Backward dependencies only (Epic 0.2 → Epic 0.1; Epic 0.3 → Epic 0.1 + 0.2; Epic 0.4 → Epic 0.1).
- ✅ **Story sequencing within epics** — strictly sequential. The cross-epic dependency from Epic 0.4 onto `ram-admin-ui` is gone (admin UI removed).
- ✅ **File-churn check** — each epic targets its own slice. Cross-epic touches on `ram-authorisation` between Epic 0.1 (read API + JWT validation) and Epic 0.3 (ETL writes to the same auth tables) are additive (Epic 0.1 creates the schema; Epic 0.3 populates it).

## Architecture Compliance

- ✅ Starter template pattern (AR2–AR4) — Story 0.1.1 establishes; Stories 0.2.1, 0.4.1, and the mock-auth scaffold in 0.1.2 follow with canonical *"Scaffold RAM Pathfinder {service-name} from HMCTS starter"* commit.
- ✅ Database creation timing — every service's tables created in the service's own first or second story via service-owned Flyway; no upfront DB creation. The auth tables (Story 0.1.3) are created by Flyway; populated by ETL (Story 0.3.1).
- ✅ Shared baseline — `configuration_values` table managed exclusively by `ram-architecture` Flyway baseline (Story 0.1.1), consumed read-only by all services.
- ✅ Direct-SQL ETL pattern (AR46–AR49) — clarified in revision: ETLs **insert directly via SQL** rather than going through API admin endpoints (which are now removed). Idempotency via natural-key `INSERT ... ON CONFLICT` per AR21.

## Story Sizing Notes

- **Story 0.1.1 (XL)** — unchanged from prior validation. Canonical platform-pattern story.
- **Story 0.3.1 (L → consolidates the prior 4 stories down to 1)** — bigger than typical, but the user value is one coherent thing: "active APEX users are loaded into the auth tables with explicit handling of unmatched records and named-owner sign-off". Splitting would fragment the user outcome.
- All other stories sized for single dev-agent sessions.

## Gaps Fixed in the Original Validation (still applicable)

Three NFR gaps and one forward-dependency softness were identified in the original 2026-05-15 validation and fixed:

1. **NFR10 (TLS)** — explicit AC in Story 0.1.1: APIM terminates TLS at the latest supported version; HTTP-only rejected; verified by CI `testssl.sh` check.
2. **NFR11 (data-at-rest encryption)** — explicit AC in Story 0.1.1: Azure-managed PostgreSQL Flexible Server with encryption at rest; AKS persistent volumes encrypted; documented in ADR.
3. **NFR26 (log retention)** — explicit AC in Story 0.1.1: log retention policy set in Phase 0 (default 90/365 days, subject to HMCTS owner sign-off); documented in ADR; applied via IaC.
4. **Story 0.2.5 → Story 0.3.4 forward reference** — tightened in original; **moot in this revision** because Story 0.3.4 is removed. Sign-off via versioned git commits to `signoffs/` is the only mechanism in MVP. CODEOWNERS-enforced two-reviewer policy.

## New checks for the 2026-05-15 revision

| Check | Verdict |
|---|---|
| All admin-UI references purged from Phase 0 stories? | ✅ |
| Reference Data API confirmed read-only (`405` on write attempts)? | ✅ in Story 0.2.2 ACs |
| Authorisation API confirmed read-only (no admin endpoints)? | ✅ in Story 0.1.3 ACs |
| ETL loads documented as direct SQL `INSERT` (not via API)? | ✅ in Stories 0.2.3 and 0.3.1 |
| Sign-off workflow documented as git-only? | ✅ in Stories 0.2.3 and 0.3.1 |
| Unmatched-record decision mechanism documented (CSV in version control)? | ✅ in Story 0.3.1 |
| Activation flag cutover documented as direct SQL during Phase 9+? | ✅ in Story 0.3.1 and Phase 0 index |
| OAuth `client_credentials` flow moved to Phase 6 (not silently dropped)? | ✅ — noted in Epic 0.4 + Story 0.4.2 + post-MVP roadmap |
| Notification `client_credentials` callers explicitly rejected in Phase 0? | ✅ in Story 0.4.2 ACs (returns `403` with explanatory RFC 9457 body) |
| Post-MVP roadmap items inventoried? | ✅ in Phase 0 index + `epics/fr-coverage-map.md` |

## Verdict

🟢 **Phase 0 (revised, 11 stories) is validated and ready for implementation.**

Next steps:

1. Begin Phase 1 story design (run `bmad-create-epics-and-stories` step 2 + 3 again, scoped to Phase 1: Judge Records & Working Patterns).
2. Begin implementation of Story 0.1.1 (the canonical platform-pattern story) via `bmad-sprint-planning` → `bmad-create-story` → `bmad-dev-story`.
3. Open a separate workstream to track the post-MVP UI items (admin UI repo, modules, admin write endpoints) — this is now a programme deliverable to schedule, not a Phase 0 commitment.
4. **Recommend updating the PRD** via `bmad-correct-course` to reflect that the UI surfaces of FR4 / FR6 are post-MVP. The PRD currently lists them as MVP; this revision puts them post-MVP. Without a PRD update, FR4 / FR6 will continue to appear as MVP requirements and may cause readiness-check failures in later phases.
