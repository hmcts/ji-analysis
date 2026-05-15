---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
workflowCompleted: true
assessor: Claude (bmad-check-implementation-readiness, revision 2)
overallVerdict: READY
filesIncluded:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md (whole, source of truth)
  - _bmad-output/planning-artifacts/architecture/ (folder, part of source of truth per user direction)
  - _bmad-output/planning-artifacts/architecture-summary.md
  - _bmad-output/planning-artifacts/epics.md (top-level pointer)
  - _bmad-output/planning-artifacts/epics/index.md
  - _bmad-output/planning-artifacts/epics/framework.md
  - _bmad-output/planning-artifacts/epics/requirements-inventory.md
  - _bmad-output/planning-artifacts/epics/fr-coverage-map.md
  - _bmad-output/planning-artifacts/epics/phase-0/index.md
  - _bmad-output/planning-artifacts/epics/phase-0/epic-0.1-user-authenticates.md
  - _bmad-output/planning-artifacts/epics/phase-0/epic-0.2-admin-manages-ref-data.md
  - _bmad-output/planning-artifacts/epics/phase-0/epic-0.3-admin-manages-users-roles.md
  - _bmad-output/planning-artifacts/epics/phase-0/epic-0.4-system-dispatches-emails.md
  - _bmad-output/planning-artifacts/epics/phase-0/validation-report-2026-05-15.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-05-15.md
uxIncluded: false
uxDeferralReason: 'Project currently scoped to domains and APIs only; UI deferred. Admin UI explicitly post-MVP per D10 (2026-05-15). Business UI accessibility constraints (WCAG 2.2 AA) carried in nji-ui scaffold stories.'
priorReports:
  - implementation-readiness-report-2026-05-05.md (historical)
  - implementation-readiness-report-2026-05-06.md (historical)
  - implementation-readiness-report-2026-05-15.md (superseded by this revision after D10 was added to the PRD)
---

# Implementation Readiness Assessment Report — 2026-05-15 (revision 2, post-D10)

**Date:** 2026-05-15
**Project:** ji-analysis (NJI rebuild)
**Trigger for this re-run:** Formal PRD update via `bmad-correct-course` added D10 (admin UI removed from MVP; `gh` CLI not available) and added AR51 (manual GitHub setup). All four Phase 0 epics + the PRD + the requirements inventory were modified earlier today. This report validates that the changes are internally consistent across PRD, architecture-derived requirements, and Phase 0 stories.

## 1. Document Inventory

| Artefact | State |
|---|---|
| `prd.md` (72 KB → **78 KB**) | Modified today: added D10 + amended FR4 / FR6 / FR56 / FR58 + grew the MVP-exclusions list + grew Growth Features section + D9 amended to reference D10 |
| `architecture.md` + `architecture/` folder | Unchanged (architecture's two-UI-repo split + per-service DB roles + manual UAT pattern already documented; no architectural changes triggered by D10) |
| `architecture-summary.md` | Unchanged |
| `epics.md` (pointer) | Unchanged |
| `epics/index.md`, `framework.md`, `requirements-inventory.md`, `fr-coverage-map.md` | `requirements-inventory.md` modified (added AR51, revised AR2); other files updated in prior turn; all current |
| `epics/phase-0/index.md` | Updated in prior turn (story counts 18→11, scope reduction notes) |
| `epics/phase-0/epic-0.1-user-authenticates.md` | Modified today (Story 0.1.1 first + third + fourth AC blocks rewritten for manual GitHub; Stories 0.1.2 + 0.1.4 first AC blocks updated) |
| `epics/phase-0/epic-0.2-admin-manages-ref-data.md` | Modified today (Story 0.2.1 first AC block updated) |
| `epics/phase-0/epic-0.3-admin-manages-users-roles.md` | Updated in prior turn (single SQL-ETL story) |
| `epics/phase-0/epic-0.4-system-dispatches-emails.md` | Modified today (Story 0.4.1 first AC block updated) |
| `epics/phase-0/validation-report-2026-05-15.md` | Updated in prior turn (revised scope verdict) |
| `sprint-change-proposal-2026-05-15.md` | New today — audit trail of the `bmad-correct-course` run |

UX still absent — accepted gap, now formally captured under D10 (admin UI post-MVP).

## 2. PRD Analysis (post-D10 deltas)

All 61 FRs and 42 NFRs unchanged in count. The post-D10 amendments are all wording / qualifier additions:

- **D10 added** to the Decisions Log as the 10th locked decision.
- **D9 amended** to defer to D10 on the "via SQL not via API" framing.
- **MVP scope bullet 3** distinguishes business UI (in MVP via `nji-ui`) vs admin UI (post-MVP per D10).
- **MVP exclusions list** added: admin UI (with the four modules itemised) + admin-write API endpoints.
- **Growth Features list** added: admin UI as a first-class post-MVP deliverable.
- **FR4 / FR6 / FR56 / FR58** each marked "(scoped 2026-05-15 per D10)" with explicit MVP-data-layer + post-MVP-UI-surface split.
- **Executive Summary Key characteristic 4** rephrased: Phase 0 ETL loads via direct SQL INSERT (not via API); API-as-Product is exercised on Reference Data reads.

Cross-references verified: D10 ↔ FR4/FR6/FR56/FR58, D10 ↔ MVP exclusions, D10 ↔ Growth Features. Self-consistent.

## 3. Epic Coverage Validation

**Phase 0 stories (post-revision):** 11 stories across 4 epics.

```
Epic 0.1 (5): 0.1.1 0.1.2 0.1.3 0.1.4 0.1.5
Epic 0.2 (3): 0.2.1 0.2.2 0.2.3
Epic 0.3 (1): 0.3.1
Epic 0.4 (2): 0.4.1 0.4.2
```

### Phase-0-scope FR coverage matrix (post-D10)

| FR | Phase 0 stories covering it | MVP coverage | Post-MVP residual | Verdict |
|---|---|---|---|---|
| FR1 | 0.1.2, 0.1.5 | ✅ full | — | ✅ |
| FR2 | 0.1.3, 0.1.5 | ✅ full | — | ✅ |
| FR3 | 0.1.3, 0.1.5 | ✅ full | — | ✅ |
| **FR4** | 0.3.1 (data layer via SQL ETL into `auth_users`/`auth_user_roles`/`auth_user_region_scopes`) | ✅ data layer (DBAs edit via SQL) | UI surface for sysadmins (`nji-admin-ui` Users & Roles module) | ✅ correctly scoped per D10 — NOT a coverage gap |
| FR5 | — | n/a (post-MVP per PRD v2.5) | — | ✅ intentional deferral |
| **FR6** | 0.2.2 (read API), 0.2.3 (SQL ETL load + git sign-off) | ✅ read API + data layer + git-based sign-off | RSU UI for view/edit/create + UI sign-off workflow | ✅ correctly scoped per D10 — NOT a coverage gap |
| FR7 | 0.2.1, 0.2.2 | ✅ full | — | ✅ |
| FR8 | 0.1.1 | ✅ full | — | ✅ |
| FR9 | 0.4.1, 0.4.2 | ✅ user-JWT propagation surface | `client_credentials` flow ships in Phase 6 (still MVP, just later) | ✅ |
| FR55 | 0.1.5 | ✅ full | — | ✅ |
| **FR56** | 0.1.4 (`nji-ui` scaffold), 0.1.5 (Home shell), 0.2.2 (consumes API) | ✅ business stack | `nji-admin-ui` admin stack post-MVP per D10 | ✅ correctly scoped — NOT a coverage gap |
| FR57 | 0.2.3 (Ref Data ETL via SQL), 0.3.1 (Users/Roles ETL via SQL) | ✅ full (both ETL streams) | — | ✅ |
| **FR58** | 0.3.1 (initial flag state via ETL — all FALSE) | ✅ initial state set; cutover flips via DBA SQL per Phase 9+ runbook | Activation toggle UI post-MVP per D10 | ✅ correctly scoped — NOT a coverage gap |
| FR59 | 0.1.3, 0.2.2, 0.4.2 | ✅ full (read-side API-as-Product) | — | ✅ |
| FR60 | 0.1.1 (Logback baseline), 0.2.1 (consumes pattern) | ✅ full | — | ✅ |

**Phase-0-scope FR coverage: 14 / 14 in-scope FRs ✅** (FR5 intentionally deferred pre-2026-05-15; FR4 / FR6 / FR56 / FR58 each delivered to the boundary correctly defined in D10).

### Non-Phase-0 FRs (out of this readiness check)

FR10–FR54 + FR61 belong to Phases 1–9+ and are framework-only (no concrete stories yet). They'll be storied phase-by-phase as Phase 0 implementation progresses. Not a Phase 0 readiness concern.

### Coverage statistics

- Total PRD FRs: **61**
- In scope for Phase 0 (post-D10): **14** (was 14; the count didn't change — only the depth at FR4/FR6/FR56/FR58 changed, and that depth correctly matches D10)
- Phase 0 stories covering the in-scope FRs: **11 / 11** (no orphan stories — every story maps to at least one FR)
- Coverage of in-scope FRs: **100%** within the D10-defined MVP boundary
- Post-MVP residuals: **4 FRs** (FR4 UI / FR6 UI / FR56 admin stack / FR58 toggle UI) — explicitly tracked in `epics/fr-coverage-map.md` post-MVP table and PRD Growth Features

**No gaps within the D10-defined MVP boundary.** The four FRs that previously appeared as "partial coverage with admin UI deferred" no longer appear as gaps because the PRD itself now scopes them to data-layer-MVP + UI-surface-post-MVP. The PRD and epics are aligned.

## 4. UX Alignment Assessment

UX document still absent. Now formally **PRD-blessed**:

- **Business UI** (`nji-ui`) — in MVP via D4 (modern stack replicates APEX), GOV.UK Design System, WCAG 2.2 AA per NFR17–NFR19. No UX doc; APEX is the behavioural reference.
- **Admin UI** (`nji-admin-ui`) — post-MVP per D10. A UX design will be needed when the admin UI is scheduled. Out of MVP scope, no gap.

Internal consistency PRD ↔ architecture ↔ epics on UI matters: ✅.

Carry-forward note from the prior validation: the *deferral-model ambiguity* (Phase 0 UI Foundations vs UX deferred) is now **resolved by D10**. The business UI ships in MVP via FR55/FR56 with APEX-replica framing; admin UI is fully deferred. No remaining ambiguity.

## 5. Epic Quality Review

### Story sizing + dependency check (all 11 stories)

| Story | Size | Forward dependencies? | Gherkin ACs | FRs/NFRs/ARs/Decisions referenced |
|---|---|---|---|---|
| 0.1.1 | XL — canonical platform pattern | None | ✅ 8 AC blocks (added 2 for manual-GitHub steps) | ✅ + D10 + AR51 |
| 0.1.2 | M | None | ✅ | ✅ |
| 0.1.3 | L | None | ✅ | ✅ |
| 0.1.4 | L | None | ✅ | ✅ |
| 0.1.5 | M (demo synthesis) | None | ✅ | ✅ |
| 0.2.1 | M | None | ✅ | ✅ |
| 0.2.2 | L (read-only enforcement via `405`) | None | ✅ | ✅ |
| 0.2.3 | L (direct SQL ETL + git sign-off) | None | ✅ | ✅ |
| 0.3.1 | L (consolidates ETL + decisions CSV + sign-off) | None | ✅ | ✅ |
| 0.4.1 | M | None | ✅ | ✅ |
| 0.4.2 | L (rejects `client_credentials` with `403`) | None | ✅ | ✅ |

### Architecture compliance

- ✅ AR2 (revised 2026-05-15) — scaffold script handles only local + `git push`; consistent across all 5 scaffold stories
- ✅ AR51 (new 2026-05-15) — manual GitHub setup constraint codified; runbook location specified; referenced by every scaffold story
- ✅ Per-service Flyway pattern — unchanged
- ✅ Direct-SQL ETL pattern (AR46–AR49) — Stories 0.2.3 and 0.3.1 follow the SQL `INSERT` framing per D10

### Findings by severity

**🔴 Critical Violations:** None.

**🟠 Major Issues:** None.

**🟡 Minor Concerns:**

1. **AR46 / AR47 wording could be tightened** — they still describe ETLs as "calls NJI APIs to load". D10 supersedes (load via direct SQL). The story ACs and AR2 already reflect D10; AR46/AR47 themselves are merely less-precise. **Recommendation:** add a `(amended by D10, 2026-05-15)` qualifier to AR46 and AR47 in `epics/requirements-inventory.md` for full internal consistency.

2. **`nji-architecture/runbooks/github-setup.md` doesn't exist yet** — referenced from 5 stories + AR51. Story 0.1.1 owns it as a deliverable. As long as Story 0.1.1 is implemented first (and it should be — it's the canonical platform pattern), the runbook will exist before any other scaffold work. **No action needed; just preserve story ordering.**

## 6. Summary and Recommendations

### Overall Readiness Status

# 🟢 READY

The 2026-05-15 PRD update (D10) successfully closes the gap that the previous readiness check flagged. PRD ↔ Phase 0 epics ↔ requirements inventory are now internally consistent. The four previously "partial coverage" FRs (FR4 / FR6 / FR56 / FR58) are now correctly scoped at the PRD level — data layer in MVP, UI surface post-MVP — and the Phase 0 stories cover the MVP portion completely.

### What's still pending (not blockers, just sequencing)

1. **Phase 1–9+ stories** — to be produced in follow-up `bmad-create-epics-and-stories` runs. Phase 0 stories are ready; subsequent phases will inherit the patterns established here (manual GitHub setup, direct-SQL ETLs, read-only APIs in MVP).
2. **Minor wording tweaks to AR46 / AR47** — non-blocking, but worth fixing in the next maintenance pass for full internal consistency. Should not delay Phase 0 implementation.

### Recommended Next Steps

1. **Run `bmad-sprint-planning`** to produce the Phase 0 sprint plan. The 11 stories are ready; the sprint plan will sequence them and assign owners.
2. **Implement Story 0.1.1 first** — produces the canonical platform pattern AND the `nji-architecture/runbooks/github-setup.md` deliverable that the other scaffold stories depend on.
3. **In parallel:** the platform engineering team should provision the dev/staging/production Azure infrastructure (AKS, PostgreSQL Flexible Server, APIM, Application Insights, Key Vault, Static Web Apps) so Story 0.1.1's deploy ACs can pass.
4. **After Phase 0 stories implementation begins:** continue producing Phase 1+ stories via `bmad-create-epics-and-stories`.

### Comparison with prior readiness report

| Concern from prior readiness check (2026-05-15 rev 1) | Status now |
|---|---|
| Epics framework only, no stories yet | ✅ Resolved (Phase 0 storied; 11 stories with Gherkin ACs) |
| UX deferral model not declared in epics.md | ✅ Resolved (D10 + Phase 0 index explicit) |
| 3 technical proto-epics need re-framing at story-design time | ✅ Resolved (vertical-slice stories with user-value framing in current epics) |
| Cross-cutting NFRs lack explicit per-phase ACs | ✅ Resolved (NFR10/11/12/13/14/15/16/17–19/20/22/25–28/31/39/40/42 explicit in Story 0.1.1 + per-story ACs) |
| **NEW: FR4 / FR6 / FR56 / FR58 PRD wording implied admin UI in MVP** | ✅ Resolved by D10 (PRD update via correct-course) |
| **NEW: `gh` CLI assumed in scaffold stories** | ✅ Resolved (manual web-UI setup documented in Story 0.1.1 + AR51 + runbook deliverable) |

### Final note

The PRD update via `bmad-correct-course` was the right intervention. Without it, FR4 / FR6 / FR56 / FR58 would have continued to read as "MVP requirements" while the epics deferred their UI surfaces — that mismatch is now closed. The implementation can proceed with confidence that PRD expectations match Phase 0 epic deliverables.

---

**Report generated:** 2026-05-15 (revision 2, post-D10)
**Assessor:** Claude (bmad-check-implementation-readiness)
**Output file:** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-15-rev2.md`
**Supersedes:** `implementation-readiness-report-2026-05-15.md` (rev 1, pre-D10)


