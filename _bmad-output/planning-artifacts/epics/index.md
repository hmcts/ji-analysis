---
projectName: 'ji-analysis'
productCodename: 'RAM Pathfinder'
sharded: true
shardedAt: '2026-05-15'
shardedFrom: 'epics.md (1566-line monolith — superseded by this folder)'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/architecture/starter-template.md'
  - '_bmad-output/planning-artifacts/architecture/repo-structure.md'
  - '_bmad-output/planning-artifacts/architecture/repository-strategy.md'
uxDocument: 'not-present-accepted-gap'
stepsCompleted:
  - 'step-01-validate-prerequisites'
  - 'step-02-design-epics-phase-0'
  - 'step-03-create-stories-phase-0'
  - 'step-04-final-validation-phase-0'
phase0Status: 'validated-ready-for-implementation'
---

# ji-analysis (RAM Pathfinder) — Epic Breakdown

This is the **sharded entry point** for the RAM Pathfinder epic and story breakdown. Each section below lives in its own file for maintainability — the prior single-file `epics.md` reached ~1,500 lines covering Phase 0 alone, and Phases 1–9+ would push it past 4,000 lines.

## Overview

RAM Pathfinder is the greenfield rebuild of HMCTS's Judicial Itineraries system. This document decomposes the requirements from the PRD (61 FRs, 42 NFRs, D1–D9) and the Architecture (HMCTS Crime SpringBoot starter, polyrepo, shared-DB + per-service DB roles, Kubernetes on Azure AKS) into implementable stories.

UX Design document is not present; downstream epics inherit UI requirements directly from PRD FRs (FR55, FR56) and architecture conventions (GOV.UK Design System base, WCAG 2.2 AA per NFR17). This gap is documented in the 2026-05-06 readiness report.

## Document Map

### Foundations (project-wide context)

| File | Contents |
|---|---|
| [requirements-inventory.md](requirements-inventory.md) | All FRs (FR1–FR61), NFRs (NFR1–NFR42), Architecture-derived ARs (AR1–AR50), and UX Design Requirements (none — accepted gap) |
| [framework.md](framework.md) | Phase × Area architectural framework — the spine that organises concrete epics across 10 sequential phases |
| [fr-coverage-map.md](fr-coverage-map.md) | Single source of truth for FR → Epic mapping across the whole programme |

### Phase-level breakdowns (one folder per phase)

| Phase | Folder | Status |
|---|---|---|
| **0** — Foundations | [phase-0/](phase-0/index.md) | 🟢 Epics + stories + validation complete (2026-05-15) |
| **1** — Judge | _to be storied_ | ⚪ Framework only |
| **2** — Absence | _to be storied_ | ⚪ Framework only |
| **3** — Vacancy | _to be storied_ | ⚪ Framework only |
| **4** — Booking | _to be storied_ | ⚪ Framework only |
| **5** — Sitting | _to be storied_ | ⚪ Framework only |
| **6** — Payment | _to be storied_ | ⚪ Framework only |
| **7** — Itineraries | _to be storied_ | ⚪ Framework only |
| **8** — MI Feed & Reporting | _to be storied_ | ⚪ Framework only |
| **9+** — Pilot Rollout | _to be storied_ | ⚪ Framework only |

## How this document is produced

Each phase advances through four steps of the `bmad-create-epics-and-stories` workflow:

1. **Validate prerequisites** — confirm PRD + Architecture available, extract requirements
2. **Design epics** — group requirements into user-value epics (not technical milestones)
3. **Create stories** — produce Gherkin-AC user stories sized for a single dev-agent session
4. **Final validation** — verify FR/NFR coverage, dependency soundness, architecture compliance

Phase 0 has completed all four steps. Phases 1–9+ are at the framework stage only (Step 1 inputs ready; Steps 2–4 not yet run).

## How to find your way

- **Looking for what to build next?** Start at the phase index (e.g. [phase-0/index.md](phase-0/index.md)) and pick an epic.
- **Looking for a specific story?** Stories are named `Story {phase}.{epic}.{n}` (e.g. Story 0.1.5). They live under `phase-{n}/epic-{n}.{m}-{slug}.md`.
- **Looking for an FR?** Use [fr-coverage-map.md](fr-coverage-map.md).
- **Looking for an architecture rule?** Use [requirements-inventory.md](requirements-inventory.md) — ARs are in the Additional Requirements section.
- **Verifying readiness?** Run `bmad-check-implementation-readiness` from the repo root; it understands this sharded shape.
