---
date: '2026-05-15'
mode: 'batch'
scope_classification: 'major'
triggers:
  - 'A: Admin UI removed from MVP — push to post-MVP roadmap'
  - 'B: gh CLI is not available in the engineering environment — all GitHub operations manual via web UI'
artefactsModified:
  - 'prd.md'
  - 'epics/requirements-inventory.md'
  - 'epics/fr-coverage-map.md'
  - 'epics/phase-0/index.md'
  - 'epics/phase-0/epic-0.1-user-authenticates.md'
  - 'epics/phase-0/epic-0.2-admin-manages-ref-data.md'
  - 'epics/phase-0/epic-0.3-admin-manages-users-roles.md'
  - 'epics/phase-0/epic-0.4-system-dispatches-emails.md'
  - 'epics/phase-0/validation-report-2026-05-15.md'
---

# Sprint Change Proposal — 2026-05-15

## 1. Issue Summary

Two product-direction decisions taken on **2026-05-15** require propagation into the PRD, the Phase 0 epics, and supporting reference documents:

### Trigger A — Admin UI removed from MVP

The product team has decided that **`nji-admin-ui`** — the entire admin-facing SPA, including its Reference Data maintenance, Users & Roles admin, Migration Reports, and Activation Toggle modules — is **not in scope for MVP** and moves to the post-MVP roadmap. Admin-write API endpoints on `nji-reference-data` and `nji-authorisation` likewise move post-MVP. The data layer remains in MVP: reference data and users are loaded via direct-SQL ETLs; ongoing operational maintenance is performed by DBAs via direct SQL per runbooks; named-owner sign-off happens via versioned git commits.

**Evidence:** product-direction decision recorded 2026-05-15 in a prior conversation turn; phase-0 epic stories were already restructured to remove admin UI stories (5 stories cut, 1 moved, count went 18 → 11). PRD and the Decisions Log had not yet been formally updated.

### Trigger B — `gh` CLI not available in the engineering environment

The engineering environment does not have the GitHub CLI (`gh`) available. All GitHub admin operations (private repo creation, branch protection on `main`, team / CODEOWNERS access, PR open / review / merge) must be performed **manually via the GitHub web UI**. Story 0.1.1 previously specified `gh CLI configured` as a precondition; that and the implicit "scaffold script creates the GitHub repo" assumption are no longer valid.

**Evidence:** direct user statement on 2026-05-15.

## 2. Impact Analysis

### Epic impact

| Epic | Impact |
|---|---|
| Phase 0 Epic 0.1 (user authenticates) | Story 0.1.1 first AC block rewritten (manual GitHub setup runbook + plain `git push`); Story 0.1.1 third AC block clarifies manual PR open via web UI; Story 0.1.2 scaffold-mock-auth precondition + Story 0.1.4 scaffold-`nji-ui` precondition updated. Story 0.1.3 already reflects read-only API surface from prior turn. |
| Phase 0 Epic 0.2 (Ref Data) | Story 0.2.1 scaffold precondition updated for manual GitHub web UI. Stories 0.2.2 (read-only API) and 0.2.3 (SQL ETL) already updated in prior turn. |
| Phase 0 Epic 0.3 (Users/Roles) | No further story changes — Story 0.3.1 (SQL ETL) was already updated in prior turn. |
| Phase 0 Epic 0.4 (Notification) | Story 0.4.1 scaffold precondition updated for manual GitHub web UI. Story 0.4.2 already reflects user-JWT-only (no `client_credentials`) from prior turn. |
| Future Phases 1–9+ | Inherit AR2 (revised) + AR51 automatically when storied. Stories generated after 2026-05-15 will pick up the manual-GitHub-setup pattern without per-story restatement. |

### Artefact conflicts (resolved in this proposal)

| Artefact | Conflict | Resolution |
|---|---|---|
| **PRD** | FR4 / FR6 / FR56 / FR58 wording implied admin UI in MVP. MVP scope section listed "Modern UI for all 11 user roles" without distinguishing business vs admin. Explicit MVP exclusions list did not mention admin UI. Decisions Log lacked the 2026-05-15 decision. | FR4, FR6, FR56, FR58 wording amended with "(scoped 2026-05-15 per D10)" clarifiers. MVP scope tweaked to distinguish business UI (in) vs admin UI (out). Admin UI items added to "Explicit exclusions from MVP". Growth Features section enriched with `nji-admin-ui` deliverables. **New D10 decision added to the Decisions Log** capturing both Trigger A and Trigger B. D9 wording amended to reference D10 (load via SQL, not via API). Phase 0 "platform smoke-test" characteristic updated. Document Map line updated D1–D9 → D1–D10. |
| **Architecture-derived requirements (AR list)** | AR2 wording implied scaffold script handles repo creation. | AR2 amended; **new AR51 added** documenting the manual-GitHub-setup constraint and runbook. |
| **Phase 0 epic stories** | Story 0.1.1, 0.1.2, 0.1.4, 0.2.1, 0.4.1 implicitly relied on `gh` CLI. | All five scaffold-precondition AC blocks updated with explicit manual web-UI setup steps + reference to `nji-architecture/runbooks/github-setup.md`. |
| **FR coverage map** | Already reflected MVP/post-MVP split from prior turn. | No further changes needed. |
| **Phase 0 index** | Already reflected the revised story count and FRs deferred post-MVP. | No further changes needed. |
| **Validation report (2026-05-15)** | Already reflected the revised scope from prior turn; the validation report's "Recommend updating the PRD" item is now satisfied by this proposal. | No further changes needed. |

### Technical impact

- **Branch protection setup** — manual via Settings → Branches on GitHub web UI (per repo)
- **CODEOWNERS, PULL_REQUEST_TEMPLATE.md** — still committed via git as usual; no special tooling needed (just files in the repo)
- **PR open / review / merge** — manual web UI; no `gh` CLI invocations
- **`nji-scaffold.sh`** — script implementation simplifies (no `gh repo create`, no `gh api` calls for branch protection); plain `git init` + `git remote add` + `git push` only
- **`nji-architecture/runbooks/github-setup.md`** — new artefact, owned by Story 0.1.1; documents the canonical "before you scaffold" checklist

## 3. Recommended Approach

**Direct Adjustment.** Both triggers can be addressed by amending existing PRD wording + adding a single new decision (D10) + a single new AR (AR51) + targeted scaffold-AC tweaks. No epic reordering, no rollback, no MVP redefinition beyond what was already storied.

- **Effort:** Low — wording-only changes plus the runbook deliverable (Story 0.1.1 picks it up)
- **Risk:** Low — these changes reflect already-made product decisions
- **Timeline:** No impact on Phase 0 sequencing or per-story sizing (the scaffold stories don't grow materially in complexity)

## 4. Detailed Change Proposals (applied in this turn)

### 4.1 PRD edits

**Document Map** — D1–D9 → D1–D10.

**Executive Summary § Key characteristic 4 (Phase 0 platform smoke-test)** — reword: "via the Reference Data and Authorisation APIs" → "via direct SQL INSERT per D10"; reword API-as-Product exercise from "Reference Data writes" to "Reference Data read endpoints".

**MVP — Minimum Viable Product** bullet 3 — "Modern UI for all 11 user roles replicating APEX layouts (D4)" → "Modern **business-user UI** for all 11 judicial/operational roles replicating APEX layouts (D4) … through `nji-ui`. Admin UI (`nji-admin-ui`) is NOT in MVP per D10 (2026-05-15 scope decision); admin tasks in MVP — reference-data maintenance, user/role/scope updates, activation toggles, migration-report review — happen via direct SQL by DBAs per operational runbooks."

**MVP § Explicit exclusions** — added admin UI + admin-write API endpoints to the exclusion list, with the four MVP-deferred admin-UI modules itemised.

**Growth Features (Post-MVP)** — added `nji-admin-ui` + admin-write API endpoints as the first bullet (with the four MVP-deferred modules itemised) to make the post-MVP commitment explicit.

**FR4 / FR6 / FR56 / FR58** — each amended with "(scoped 2026-05-15 per D10)" qualifier, stating: data layer in MVP, UI surface post-MVP, and pointing to Growth Features for the UI commitment.

**Decisions Log D9** — amended to note D10 supersedes its "load via the NJI Authorisation API" wording.

**Decisions Log D10 (new)** — captures both Trigger A (admin UI → post-MVP) and Trigger B (no `gh` CLI); references the revised Phase 0 epic plan.

### 4.2 Architecture-derived requirements edits

**AR2** — added 2026-05-15 revision note: `gh` CLI not available; scaffold script handles only local scaffolding + `git push`; GitHub admin operations are manual web-UI work per `nji-architecture/runbooks/github-setup.md`.

**AR51 (new)** — codifies the manual GitHub setup constraint as a non-negotiable environment constraint; declares the runbook location; explicitly notes that PRs are opened / reviewed / merged via the web UI.

### 4.3 Story edits (Phase 0)

**Story 0.1.1 (Scaffold `nji-authorisation`)** — first AC block rewritten:
- Removed `gh CLI configured` from "Given" environment
- Added a leading precondition AC about the engineer manually creating the empty GitHub repo + enabling branch protection + the runbook reference
- Rewrote the corresponding "Then" line — scaffold script scaffolds locally and pushes via plain `git`; the GitHub repo exists already
- Third AC block (PR + CI) updated to specify "opens a PR via the GitHub web UI"
- Fourth AC block (PR merged) updated to specify "merged via the GitHub web UI"
- Vertical-slice description updated to list the new `nji-architecture/runbooks/github-setup.md` runbook as a Phase 0 deliverable
- References line updated to include D10 + the runbook reference

**Story 0.1.2 (Scaffold `nji-mock-auth`)** — first AC block updated to require manual pre-creation of the GitHub repo per the runbook.

**Story 0.1.4 (Scaffold `nji-ui`)** — first AC block updated to require manual pre-creation of the GitHub repo per the runbook + plain `git push`.

**Story 0.2.1 (Scaffold `nji-reference-data`)** — first AC block updated to require manual pre-creation per the runbook.

**Story 0.4.1 (Scaffold `nji-notification`)** — first AC block updated to require manual pre-creation per the runbook.

## 5. Implementation Handoff

**Scope:** Moderate (PRD + architecture-derived requirements + 5 stories — all reflect existing product decisions, not new design work).

**Routed to:**

1. **Developer agent** (Story 0.1.1 first implementation) — picks up the now-explicit GitHub-setup runbook deliverable as part of Story 0.1.1 acceptance. The runbook is a small markdown file documenting the GitHub web-UI steps (~half-hour deliverable).
2. **Sprint planning** (`bmad-sprint-planning`) — can now run cleanly against the revised Phase 0 stories without ambiguity about admin UI scope or `gh` CLI availability.
3. **Future-phase story authors** (`bmad-create-epics-and-stories` for Phases 1–9+) — will inherit AR2 (revised) + AR51 automatically. No per-phase restatement of the manual-GitHub-setup pattern needed; just reference AR51.

**Success criteria:**

- Story 0.1.1's GitHub-setup runbook artefact exists at `nji-architecture/runbooks/github-setup.md`
- No Phase 0 story AC mentions `gh` CLI or assumes scripted GitHub repo creation
- PRD Decisions Log includes D10 and references it from FR4/FR6/FR56/FR58
- The `epics/fr-coverage-map.md` post-MVP roadmap matches the PRD's Growth Features section
- Re-running `bmad-check-implementation-readiness` no longer flags FR4 / FR6 / FR56 / FR58 as "MVP requirements not delivered" — they're now correctly scoped MVP-data-layer + post-MVP-UI

## 6. Workflow Completion

- **Issue addressed:** (A) Admin UI removed from MVP per 2026-05-15 product-direction decision; (B) `gh` CLI not available in engineering environment
- **Change scope:** Moderate (PRD + AR + 5 stories)
- **Artefacts modified (in this turn):** `prd.md`, `epics/requirements-inventory.md`, `epics/phase-0/epic-0.1-user-authenticates.md`, `epics/phase-0/epic-0.2-admin-manages-ref-data.md`, `epics/phase-0/epic-0.4-system-dispatches-emails.md`
- **Artefacts already updated in prior turn (re-validated by this proposal):** `epics/phase-0/index.md`, `epics/fr-coverage-map.md`, `epics/phase-0/epic-0.3-admin-manages-users-roles.md`, `epics/phase-0/validation-report-2026-05-15.md`
- **Sprint Change Proposal document:** this file (`sprint-change-proposal-2026-05-15.md`)
