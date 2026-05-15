---
parent: 'epics/phase-0/index.md'
purpose: 'Phase 0 final validation report (Step 4 of bmad-create-epics-and-stories)'
date: '2026-05-15'
scope: 'Phase 0 (Epics 0.1–0.4, Stories 0.1.1–0.4.4)'
verdict: 'VALIDATED - READY FOR IMPLEMENTATION'
---

# Phase 0 Step 4 — Final Validation Report

**Date:** 2026-05-15
**Scope:** Phase 0 (Epics 0.1–0.4, Stories 0.1.1–0.4.4)

## FR Coverage (Phase 0 scope)

All 14 Phase-0-applicable MVP FRs covered with explicit story references:

FR1 ✅, FR2 ✅, FR3 ✅, FR4 ✅, FR5 (intentionally deferred post-MVP), FR6 ✅, FR7 ✅, FR8 ✅, FR9 ✅, FR55 ✅, FR56 ✅, FR57 ✅, FR58 ✅ (surface only — orchestration is Phase 9+), FR59 ✅, FR60 ✅

## NFR Coverage (Phase 0 scope)

All in-scope Phase 0 NFRs explicitly addressed via story ACs:

NFR10 ✅ (Story 0.1.1), NFR11 ✅ (Story 0.1.1), NFR12 ✅, NFR13 ✅, NFR14 ✅, NFR15 ✅, NFR16 ✅, NFR17–NFR19 ✅, NFR20 ✅, NFR22 ✅, NFR25 ✅, NFR26 ✅ (Story 0.1.1 — 90 day non-prod / 365 day prod default subject to HMCTS sign-off), NFR27 ✅, NFR28 ✅, NFR31 ✅, NFR39 ✅, NFR40 ✅, NFR42 ✅

## Dependency Validation

- ✅ **Epic independence** — no epic requires a later epic to function. Backward dependencies only (Epic 0.2 → Epic 0.1; Epic 0.3 → Epic 0.1 + 0.2; Epic 0.4 → Epic 0.1 + 0.2).
- ✅ **Story sequencing within epics** — strictly sequential; no forward references after fix to Story 0.2.5 (sign-off via versioned commits to `signoffs/` directory, independent of Story 0.3.4 UI promotion).
- ✅ **File-churn check** — each epic targets its own slice; cross-epic touches on `nji-authorisation` and `nji-admin-ui` are additive (new endpoints / new module surfaces), not editing of existing code paths.

## Architecture Compliance

- ✅ Starter template pattern (AR2–AR4) — Story 0.1.1 establishes; Stories 0.2.1, 0.4.1, and mock-auth scaffold in 0.1.2 follow with canonical *"Scaffold NJI {service-name} from HMCTS starter"* commit.
- ✅ Database creation timing — every service's tables created in the service's own first or second story via service-owned Flyway; no upfront DB creation.
- ✅ Shared baseline — `configuration_values` table managed exclusively by `nji-architecture` Flyway baseline (Story 0.1.1), consumed read-only by all services.

## Story Sizing Notes

- **Story 0.1.1 (XL)** — canonical platform-pattern story; intentionally large because it establishes scaffolding + CI/CD + first deployment + Flyway baseline + TLS / encryption / log-retention ACs. Dev agent picking this up should plan a multi-day session OR split into 0.1.1a (scaffold + local build), 0.1.1b (CI/CD + first deploy), 0.1.1c (Flyway baseline + cross-cutting NFR setup) at implementation time. Decision deferred to dev agent.
- All other stories sized for single dev-agent sessions.

## Gaps Fixed in Validation

Three NFR gaps and one forward-dependency softness were identified and remediated:

1. **NFR10 (TLS)** — added explicit AC to Story 0.1.1: APIM terminates TLS at the latest supported version; HTTP-only rejected; verified by CI `testssl.sh` check.
2. **NFR11 (data-at-rest encryption)** — added explicit AC to Story 0.1.1: Azure-managed PostgreSQL Flexible Server with encryption at rest; AKS persistent volumes encrypted; documented in ADR.
3. **NFR26 (log retention)** — added explicit AC to Story 0.1.1: log retention policy set in Phase 0 (default 90/365 days, subject to HMCTS owner sign-off); documented in ADR; applied via IaC.
4. **Story 0.2.5 → Story 0.3.4 forward reference** — tightened: sign-off via versioned commit to `signoffs/` directory with `CODEOWNERS`-enforced two-reviewer policy; Story 0.2.5 no longer depends on Story 0.3.4 being delivered first.

## Verdict

🟢 **Phase 0 epics + stories are validated and ready for implementation.**

Next steps:
1. Re-run `bmad-check-implementation-readiness` to confirm overall status moves to 🟢 READY for Phase 0.
2. Begin Phase 1 story design (run `bmad-create-epics-and-stories` step 2 + 3 again, scoped to Phase 1: Judge Records & Working Patterns).
3. Begin implementation of Story 0.1.1 (the canonical platform-pattern story) via `bmad-sprint-planning` → `bmad-create-story` → `bmad-dev-story`.
