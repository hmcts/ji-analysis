---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - '_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md'
  - '_bmad-output/brainstorming/brainstorming-session-2026-05-05-1500.md'
  - 'docs/architecture/asis/functional-modules.md'
session_topic: 'Phase sequencing for the JI greenfield rebuild — order of functional implementation for incremental development'
session_goals: 'Determine the correct order of functional implementation for incremental greenfield development of the new API-driven JI application. Build is in isolation from Oracle APEX (no strangler, no parallel run); cutover happens after full functional port. MI Feed comes last. Produce a recommended phase sequencing, a constraint map, sequencing variants with tradeoffs, risks, and an updated migration table.'
selected_approach: 'Targeted convergent / analytical session — re-run with greenfield reframe'
techniques_used: ['Five Whys', 'Constraint Mapping', 'Decision Tree Mapping']
ideas_generated: 0
session_active: false
workflow_completed: true
context_file: '_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md'
supersedes:
  - 'Lines 139–149 of brainstorming-session-2026-05-01-1400.md (Migration sequence)'
  - 'brainstorming-session-2026-05-05-1500.md in its entirety (built on a strangler-fig assumption that has been retracted)'
---

# Brainstorming Session Results — Phase Sequencing for Greenfield Rebuild

**Facilitator:** Ramnish
**Date:** 2026-05-05

## Session Overview

**Topic:** The order of functional implementation for the JI greenfield rebuild.

**Critical reframe (dropped from prior sessions):**

- **No parallel run with Oracle APEX.** The new API-driven application is built in isolation. Cutover happens after all functionality has been ported.
- **No strangler-fig pattern.** The Oracle APEX legacy platform is not amenable to strangler decomposition; treating this as a greenfield project is the agreed approach.
- **Functional learnings come from APEX**, but APEX is a *reference*, not a host for the migrating system.
- **MI Feed comes last** — it federates over data set up earlier, and there are no external consumers waiting on a Phase-1 deliverable from it.
- **The dominant lens is incremental-development feasibility** — at each phase, can the team build, test, and demo the new functionality with minimum stub work and maximum prior context?
- **MVP-style delivery with progressive user move-over.** Demonstrate to users as we develop; move users over (in batches) once all functions have been implemented and tested. There is no "live partial system" — users either remain on APEX or move to the fully-built new system.
- **Phased rollout per region or user subset** is the cutover strategy. Migrated users do not use APEX; non-migrated users do not use the new system. No contention between the two.
- **UI is in scope per phase**, replicating the as-is APEX UI using a modern UI stack. Each domain phase delivers its corresponding UI surface end-to-end so users can see the system as it develops.

**Cluster terminology (carried from updated 2026-05-01 artefact):** Domain services / Cross-cutting services / Read-model services. *The term "Spine" is not reintroduced.*

**Out of scope for re-sequencing:** Phase 0 Foundations stay first. The 12-service decomposition itself is locked from the prior session. *(Note: revised to **11-service decomposition** in architecture v2.2, 2026-05-07 — `ram-configuration` was dropped in favour of per-service Spring profiles + Key Vault and a shared `configuration_values` infrastructure table. Sequencing logic below is unaffected.)*

### Why this session re-runs the analysis

The 2026-05-01 session and the 2026-05-05-1500 draft both treated APEX/API write coexistence (Risk #2 in the prior session) as the dominant risk to manage in sequencing. That risk depended on a strangler-fig migration. **Under greenfield isolation, that risk does not exist** — there is no dual-write, no coexistence window, no APEX-as-host pattern to validate against. Most of the prior session's inherited preferences and pseudo-constraints (read-model-first, smallest blast radius, MI Feed as first user-visible API, DA&I early-evidence) collapse with that risk.

What replaces it is a different optimisation function: at each phase, what is the smallest set of services that can be built end-to-end (CRUD + business rules + tests + demo) with all upstream dependencies already in place, and that leaves downstream services with maximum context when their turn comes?

That optimisation function points almost entirely at the dependency DAG, which mirrors the business workflow chain.

---

## Decisions taken (2026-05-05 follow-up)

These decisions were taken in conversation immediately after the analytical sections below were drafted. They resolve the open programme questions that the analysis had named as the new high-leverage decisions. They are recorded here, ahead of the analytical sections, so a reader sees the operating constraints first.

### D1 — Phase 0 Foundations scope (locked)

**In scope:** Reference Data, Authorisation (with SSO), Notification, **shared `configuration_values` infrastructure table** (no dedicated configuration service per architecture v2.2, 2026-05-07; per-service config uses Spring profiles + Key Vault), **API contracts** (versioned contracts for every domain service plus paper contracts for Itinerary and MI Feed to constrain downstream design), **deployment platform** (continuous deploy from Phase 1 onwards).

**Reference Data migration from APEX is part of Phase 0** — the only data migration the programme will undertake.

**Out of scope (explicitly post-MVP):** Audit, Observability. Accepted as known gaps for the MVP build and pilot rollout; must be revisited before broad GA.

### D2 — Cutover strategy (locked): phased rollout

A region or subset of users moves to the new platform first; the rest remain on APEX. **Migrated users do not use APEX; non-migrated users do not use the new system.** No contention, no dual-write, no synchronisation.

Implication: each rollout wave is a discrete cutover for a defined user/region scope, gated on full feature parity for that scope.

### D3 — Data migration (locked, mechanism clarified 2026-05-06): Reference Data only *(extended by D9)*

Reference Data migrates in Phase 0. **No transactional data migration.** Each user/region migrates onto a clean transactional state in the new system; their historical transactional data remains in APEX (read-only, queried out-of-band if needed).

Implication: the cutover gate is functional ("can the user transact going forward?"), not data-completeness ("can the user see their last 5 years of bookings?"). Historical data access strategy is a separate, smaller decision.

**Mechanism (clarified 2026-05-06):** the migration is an **ETL** that reads APEX dumps, transforms each row into the new system's own (independently-designed) shape, and **loads via the new system's APIs** (Reference Data API for vocabularies and lists; Authorisation API per D9). The new system's tables are designed by the new system; APEX's schema is the data source, not the target shape. The ETL is *not* a database-migration tool (Flyway etc.) seeding APEX rows directly into the new schema — it is a separate Phase 0 programme deliverable.

*Extended by D9: in addition to Reference Data, user records and their role/scope mappings are also ETL'd from APEX in Phase 0 and loaded into the Authorisation service via its API.*

### D4 — Feature parity gate (locked): functional, not screen-by-screen

Feature parity is the cutover gate. **No UI redesign**: the working assumption is that the new UI replicates the as-is APEX UI using a modern UI stack. The functional surface mirrors APEX; the visual / interaction layer is modernised.

Implication: each domain phase includes the modern-UI replication of its corresponding APEX module(s), demoable to users at the end of the phase.

### D5 — APEX as behavioural reference (locked, revised)

APEX is the *behavioural reference*, including edge cases not in `functional-modules.md`. Behavioural parity is verified by **manual user acceptance testing (UAT)** performed by users who have hands-on experience with the existing Oracle APEX JI application — RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, and MI users. These users compare RAM Pathfinder's behaviour against APEX behaviour as they reproduce it interactively in APEX, and sign off on parity per service phase before that wave's cutover.

There is **no automated APEX-comparison test harness**, no programmatic comparison against a running APEX instance, and no automated APEX-comparison test base class. Automated testing inside RAM Pathfinder is the standard pyramid (unit, integration with Testcontainers, contract); APEX-comparison parity is exclusively a manual UAT activity owned by the user community.

*Revised on 2026-05-06: an earlier version of D5 proposed automated parity tests with real APEX as an automated comparison reference. That mechanism was retracted because (a) APEX runs in a separate environment with no programmatic test hook, (b) maintaining an automated comparison harness against a system the project does not co-manage (D6) is fragile, and (c) the users who know APEX behaviour are the right source of truth, not a synthetic harness. See changelog entry for the corresponding architecture revision.*

### D6 — APEX maintenance posture (locked): out of scope for this project

APEX continues as-is, maintained separately from this project. Project plans, capacity, and risk register treat APEX as a stable external system, not a co-managed asset.

### D7 — Audit / Observability MVP minimum (locked): log-based only

The MVP and pilot waves use **log-based auditing** — application logs (request, error) are the audit and observability surface. There is no metrics platform, no trace platform, no structured before/after audit trail in the MVP.

**Scope of log-based:** errors logged from every domain service; failed requests captured; logs retained long enough to support pilot incident triage.

**Roadmap:** further iterations after MVP introduce **user-action auditing** (who did what, when, with before/after values for write operations). This is explicitly on the roadmap, not deferred indefinitely.

Implication: Risks #7 and #8 collapse from "accepted gap" to "mitigated to a defined minimum"; the gap that remains is structured user-action audit, which has a roadmap commitment.

### D8 — Rollout boundary (locked): by region, full user-role coverage

Each rollout wave is **a whole region with all applicable user roles** — RSU, Court (all access tiers), Judges, Judges' Clerks, Finance/Payment Authoriser, MI users — for that region. A region only moves once **all functionality required by every role in that region** is implemented and tested.

Implication: per-wave feature parity (Risk #3) is defined as "every workflow used by any in-region role on the new platform." The wave gate is high (full functional coverage for the region), but the boundary is clean (no half-migrated regions, no role-by-role partial rollout).

Cross-region workflows (Risk #1) remain a transitional concern between waves — any workflow that crosses a migrated region and a non-migrated region needs an explicit handling decision per wave.

### D9 — Users + roles ETL'd from APEX into Authorisation (locked; mechanism clarified 2026-05-06)

**In addition to Reference Data (D3),** APEX user records and their role / Region / Area scope mappings are extracted from APEX, transformed into the new system's shape, and **loaded into the new Authorisation service's tables via its API** in Phase 0. The Authorisation layer is built on real APEX-derived data from day 1, not seeded by hand or by stub.

The new system owns the Authorisation tables and their shape (`auth_users`, `auth_roles`, `auth_user_roles`, `auth_user_region_scopes`, `auth_user_activation_flags`); APEX's user-record shape is whatever it is; the ETL is the mapping between them.

**Scope of the migration:** for every active APEX user — identifier (email / username / employee ID), assigned role(s) from the 12 documented roles in `functional-modules.md` line 497, Region / Office scope, active/inactive flag.

**Identity boundary with SSO (per prior Authorisation locked-in decisions):** SSO (HMCTS IdP) owns AuthN; JI's Authorisation service owns AuthZ. Migrated user records are keyed to the IdP principal (most likely by email or employee ID) so that when a user authenticates via SSO, the Authorisation service resolves their role + scope from the migrated record. **The identity-key mapping between APEX and the IdP must be established as part of D9** — see Risk #14.

Implication for sequencing: Phase 0 Authorisation now exercises the full role + scope model with realistic data. The "Authorisation maps an authenticated principal to roles + region/area scope + permissions" decision from the 2026-05-01 session becomes testable end-to-end in Phase 0, before any domain service is built.

Implication for rollout (D8): when a region migrates, the in-region users already exist in the Authorisation service from Phase 0; no per-wave user-onboarding step is required. Activation per wave is a flag flip (or equivalent), not a data migration.

---

## Technique 1 — Five Whys

**Adjusted question for greenfield:** Why might we deviate from pure dependency-DAG / business-chain order under greenfield?

**Why 1 — Why not just follow the DAG?**
You might want to start with a "thin vertical slice" through the chain (Judge + minimal Sitting + minimal Payment for one happy-path use case) to demonstrate end-to-end shape early, ahead of building each domain service deeply.

**Why 2 — Why is a thin slice tempting?**
Because incremental development thrives on a working skeleton: you get cross-cutting concerns (auth, observability, error handling, contract patterns) exercised end-to-end early, and you can iterate on architecture before commitment hardens.

**Why 3 — Why doesn't a thin slice override the DAG?**
A thin slice is a *packaging* choice within phases, not a re-ordering across phases. Dependency direction still holds: Sitting still needs Judge; Payment still needs Booking and Sitting. A "thin slice" version of Phase 1 is "Judge with working-pattern-driven sitting generation, but no Sitting service yet" — which is exactly what Phase 1 produces under DAG order anyway. The slice idea decorates the order; it does not change it.

**Why 4 — Why don't the prior session's strangler-era reasons survive?**
Because they were arguments about *risk reduction during APEX coexistence* (read-model-first to defer write coexistence; MI Feed first to validate the pattern on a low-stakes surface; smallest blast radius first to minimise production impact). Under greenfield, there is no APEX coexistence, no production blast radius for the new app until cutover, and no surface that is "lower stakes" than another in a build-in-isolation sense — every service is at the same stake (shippable at cutover or not).

**Why 5 — Why does "MI last" still hold under greenfield?**
For the same reason it always held in the dependency DAG: MI Feed federates over every domain service, including Payment. It is downstream of everything. Under strangler it was conflated with "first user-visible API" because external consumers (DA&I) needed evidence; under greenfield no one sees MI Feed until cutover, so its placement is purely DAG-driven, and the DAG puts it last.

### Crystallised conclusion

**Under greenfield, there is no surviving reason to deviate from dependency-DAG / business-chain order.** The prior session's risk-graded order was a response to a strangler-specific risk class that is not present here. The recommendation collapses to "build in dependency order, with parallelism where the DAG permits it."

The remaining open questions are:

- How thick is each phase? (Packaging — separate from sequencing.)
- Is Sitting built sequentially or in parallel with Booking/Vacancy/Absence? (Team-capacity question.)
- Where does Itinerary land — alongside Payment (parallel) or after Payment (sequential)?

---

## Technique 2 — Constraint Mapping

### Real constraints (binding under greenfield)

| # | Constraint | Source |
|---|---|---|
| R1 | **Reference Data → every domain service.** | Prior session line 50; functional-modules.md cross-cutting NFRs. |
| R2 | **Authorisation → every user-facing or write API.** | Prior session locked-in decision: SSO-delegated AuthN, JI-owned AuthZ. |
| R3 | **Notification → most domain services** (booking ack, payment authoriser email, absence ack); **shared `configuration_values` table** (read-only direct SQL) for cross-service policy values. | functional-modules.md §4.5–4.8. |
| R4 | **Absence → Vacancy.** Approved absences requiring cover auto-create vacancies. | functional-modules.md line 244. |
| R5 | **Vacancy → Booking.** `POST /bookings` orchestrates `Vacancy.markFilled` synchronously. | Prior session Architecture #3. |
| R6 | **Judge → Sitting / Vacancy / Booking.** Working patterns, jurisdictional split, tickets, fee-payment status all originate in Judge. | functional-modules.md §4.2. |
| R7 | **Booking + Sitting → Payment.** Payment derives from confirmed bookings AND confirmed sittings (where salaried staff sit as Recorders). | functional-modules.md §4.8 inputs; line 410. |
| R8 | **Payment → Reconciliation** (folded into Payment lifecycle). | Prior session, line 43. |
| **R9** *(new)* | **Itinerary → Judge + Absence + Vacancy + Booking + Sitting.** Itinerary federates over those domains; cannot be meaningfully built without them. | Prior session Architecture #2 (Strategy A federation). |
| **R10** *(new)* | **MI Feed → all domain services including Payment.** MI aggregates utilisation, sittings, payments. | Prior session line 117; functional-modules.md §4.12. |

### Inherited preferences from prior sessions (re-examined under greenfield)

| # | Preference | Status under greenfield |
|---|---|---|
| I1 | **Read-model-first ordering** of MI Feed (Phase 1) and Itinerary (Phase 2) before any domain extraction. | **DROPPED.** Greenfield has no Oracle to federate over; read models can only federate over greenfield domain services that don't exist yet. The original rationale (defer APEX/API write coexistence by validating pattern on read paths) is moot. |
| I2 | **"Smallest blast radius first"** applied to Judge as Phase 3. | **DROPPED.** No production blast radius under build-in-isolation. Every service is shippable-at-cutover; "blast radius" is a strangler-era concept. |
| I3 | **Sitting in parallel** with Absence/Vacancy/Booking. | **STAYS, conditional on team capacity.** The DAG permits it (Sitting depends only on Judge, R6); whether to exercise parallelism is a team-sizing decision. |
| I4 | **MI Feed as first user-visible API** for DA&I early evidence. | **DROPPED.** No external consumers see anything before cutover. DA&I continue receiving MI from Oracle reports until cutover; the migration plan has no obligation to surface a partial MI Feed mid-build. |
| I5 | **Strategy C cache for Itinerary** as fallback if Forward Look ≤ 30 s NFR is breached. | **STAYS.** This is an architectural choice (within-Itinerary), not a sequencing constraint. |

### Pseudo-constraints under greenfield

| # | Pseudo-constraint | Why it isn't binding |
|---|---|---|
| P1 | "DA&I must see something within X months." | Greenfield: DA&I are on Oracle until cutover. No mid-build deliverable to DA&I exists or is expected. |
| P2 | "Pattern must be validated on a read-only surface before any write extraction." | Greenfield: there is no "extraction." Reference Data in Phase 0 is a write surface and is the platform smoke-test (pagination, versioning, deprecation policy, audited writes). MI Feed adds nothing not already exercised by Reference Data. |
| P3 | "Business-chain order is more legible to stakeholders." | Under greenfield, business-chain order is the **natural** dependency order. Legibility is a free side-benefit, not a tradeoff to weigh. |
| P4 | "Itinerary must be extracted early so its ≤ 30 s NFR risk is discovered before cutover." | UI is greenfield and designed-to-NFR; no mid-build Itinerary consumer pressure. NFR validation happens during Itinerary construction, not via sequencing. |
| P5 | "Read models must precede domain services." | Inverted dependency under any model; under greenfield, doubly so — there is nothing for read models to federate over until the domain services are built. |
| **P6** *(new)* | "We should build a thin vertical slice through every domain service first to demo end-to-end." | Tempting but it's a *packaging* choice within Phase 1, not a re-ordering. DAG order already produces an incremental thin slice via Phase 1 Judge with working-pattern-driven sitting generation. Forcing a cross-domain thin slice would mean building stub Sitting, stub Payment, etc., earlier than their data is available — net work increase. |
| **P7** *(new)* | "Build Itinerary early so testers can see schedules during dev." | Stub Itinerary or test fixtures address dev-visibility. Real Itinerary needs all domains; building it before its data sources exist is rework waiting to happen. |

### Implications under greenfield

- **The dependency DAG fully determines the order**, with one degree of freedom (Sitting parallelism) and one minor packaging choice (Itinerary alongside or after Payment).
- **Most prior risk-management arguments evaporate** because they were strangler-specific.
- **The constraint map is now boringly tight.** That is the right answer — under greenfield, sequencing is largely a non-issue; the architecture, data model, and cutover plan are where the interesting decisions live.

### Post-decision additions (after D1–D6 were taken)

- **R11 (new real constraint): UI-per-phase.** Per D4, each domain phase delivers the modern-UI replication of its corresponding APEX module(s) end-to-end, demoable to users at phase end. This is now a sequencing constraint, not a separate workstream — every phase row in the migration table includes UI scope.
- **R12 (new real constraint): API contracts in Phase 0.** Per D1, versioned contracts for every domain service plus paper contracts for Itinerary + MI Feed are Phase 0 deliverables. This is the formalisation of captured idea #1.
- **R13 (new real constraint): Deployment platform in Phase 0.** Per D1. Continuous deploy from Phase 1 onwards is non-negotiable for the demo cadence required by D4.
- **Several risks are now explicit accepted gaps**, not constraints to design around: Audit (Risk #7) and Observability (Risk #8) are deferred to post-MVP per D1. They re-enter as constraints before broad GA.
- **Cutover is no longer a single decision but a sequence of waves** (Phase 9, 10, …). The constraint mapping is unchanged at the build phases (0–8); the wave-by-wave rollout is governed by per-wave feature parity (captured idea #5) and rollout-boundary choice (captured idea #6).

---

## Technique 3 — Decision Tree Mapping

Two viable variants under greenfield (both respecting Phase 0 Foundations and the real constraints R1–R10). A third "vertical-slice" styling is noted as a packaging variation, not a separate variant.

### Variant α — Strict Sequential Business-Chain (single team)

| Phase | Cluster | Services | Notes |
|---|---|---|---|
| 0 | Cross-cutting | Reference Data, Authorisation (with SSO), Notification (shared `configuration_values` table is part of Phase 0 schema baseline; no separate service per arch v2.2) | Foundations |
| 1 | Domain | **Judge** (incl. working pattern, tickets, jurisdictional split) | Chain head; working patterns generate forward sittings (the Sitting *records* exist as domain data even before the Sitting service does) |
| 2 | Domain | **Absence** | Sequential after Judge |
| 3 | Domain | **Vacancy** | Sequential after Absence (R4) |
| 4 | Domain | **Booking** | Sequential after Vacancy (R5) |
| 5 | Domain | **Sitting** | Sequential — confirms / verifies the sittings already generated by Judge working patterns; adds ad-hoc, AM/PM split, RFC unlock |
| 6 | Domain | **Payment** (incl. Reconciliation) | After Booking + Sitting (R7, R8) |
| 7 | Read model | **Itinerary** | Federates over Judge + Absence + Vacancy + Booking + Sitting (R9) |
| 8 | Read model | **MI Feed** | Federates over all domain services (R10); the user's stated "last" position |
| 9 | — | Cutover from APEX | Big-bang or phased — separate decision |

**Pros:** Simplest plan; each phase has a clean demoable increment; minimum coordination overhead; suits a single squad.
**Cons:** Sitting parallelism opportunity unused — calendar time is longer than necessary if multi-team capacity exists.

### Variant β — Business-Chain with Sitting Parallelism (multi-team)

| Phase | Cluster | Services | Notes |
|---|---|---|---|
| 0 | Cross-cutting | Reference Data, Authorisation (with SSO), Notification (shared `configuration_values` table is part of Phase 0 schema baseline; no separate service per arch v2.2) | Foundations |
| 1 | Domain | **Judge** | Chain head |
| 2 | Domain | **Absence** | Track 1 |
| 3 | Domain | **Vacancy** | Track 1 (after R4) |
| 4 | Domain | **Booking** + **Sitting** | Track 1: Booking (after R5). **Track 2: Sitting** in parallel (depends only on Judge, R6) |
| 5 | Domain | **Payment** (incl. Reconciliation) | Joins Tracks 1 + 2 (R7) |
| 6 | Read model | **Itinerary** | Optionally parallel with Phase 5 if a third track exists (R9 satisfied by end of Phase 4) |
| 7 | Read model | **MI Feed** | Last (R10) |
| 8 | — | Cutover from APEX | — |

**Pros:** Compresses calendar time; preserves the parallelism opportunity recognised in the 2026-05-01 session; matches well to a two- or three-squad team structure.
**Cons:** Coordination overhead between tracks; Sitting and Booking both consume Judge so Judge API contract churn during Phase 1 ripples into both tracks; reconciling Sitting and Booking with Payment is a Phase-5 integration milestone with risk.

### Packaging variation — Vertical-slice MVP first (notable but not a separate variant)

A "build a thin happy path through every service" approach is sometimes proposed for incremental greenfield work. It would mean: in Phase 1, build minimal Judge + minimal Sitting + minimal Booking + minimal Payment, all demoable end-to-end for one use case, then thicken each phase by phase.

**Why this is a variation, not a variant:** The dependency direction is unchanged (you'd still build Judge before Sitting before Payment). What changes is whether each "phase" delivers a *complete* service or a *thin slice*. Under thin-slice, every phase becomes a horizontal pass through all services. The total work is the same; the demo cadence changes.

**When to consider it:** if early architectural validation requires exercising every cross-cutting concern (auth, observability, contract testing) end-to-end before committing to a service-deep build pattern. If those concerns are settled in Phase 0 Foundations (which is the prior session's intent), this variation adds coordination cost without proportional benefit.

### Tradeoff matrix

| Dimension | α: Strict Sequential | β: Sitting Parallel |
|---|---|---|
| Calendar time | Longer | Shorter |
| Coordination overhead | Low | Medium |
| Team-size requirement | 1 squad | 2–3 squads |
| Demo cadence | One service per phase | One or two services per phase |
| Risk of API churn cascading | Low (one consumer ahead at a time) | Higher (Sitting and Booking both consume Judge concurrently) |
| Suitability under uncertain budget / staffing | High | Lower (parallel tracks need stable funding) |

---

## Recommendation

**Variant α — Strict Sequential Business-Chain** as the default plan, with **Variant β as a contingency upgrade if and when team capacity supports it.**

Rationale:

- **Under greenfield, the dependency DAG fully determines sequencing.** The business workflow chain mirrors the DAG; following it is the natural incremental order.
- **MI Feed last** is consistent with both the user's explicit direction and R10 (it federates over every other service including Payment).
- **Itinerary just before MI Feed** is consistent with R9 (federates over the operational chain but not Payment) and keeps read-model construction clustered.
- **Strict sequential (α) is the lower-coordination starting point.** Every phase has a clean demoable increment with all upstream dependencies in place.
- **β is an upgrade, not a different plan.** The phase order doesn't change; only whether Sitting is co-developed with Booking rather than after it. This decision can be deferred until staffing is known.

**The decision is largely uncontroversial under greenfield.** This is the right outcome — sequencing was over-weighted as a decision under the strangler model because risk-management considerations were doing real work. Removing strangler removes most of the difficulty; what's left is a near-mechanical reading of the DAG.

The interesting decisions for the programme have now been taken (see [Decisions taken (2026-05-05 follow-up)](#decisions-taken-2026-05-05-follow-up)):

- **Phase 0 Foundations scope:** Reference Data, Authorisation (SSO), Notification, shared `configuration_values` infrastructure table (no separate configuration service per arch v2.2), API contracts, deployment platform, Reference Data migration. Audit + Observability deferred post-MVP. *(D1)*
- **Cutover strategy:** Phased rollout per region / user subset; no contention because migrated users abandon APEX. *(D2)*
- **Data migration:** Reference Data only, in Phase 0. No transactional data migration. *(D3)*
- **Feature parity gate:** Functional parity per workflow; UI replicates APEX layout using a modern UI stack; no UI redesign. *(D4)*
- **APEX role:** Behavioural reference verified by **manual UAT** performed by APEX-experienced users; not a co-managed system, not an automated comparison reference. *(D5 revised, D6)*

These decisions reshape the migration table (UI work is now in-scope per phase; cutover becomes a sequence of rollout waves rather than a single event) and the risk register (cutover risk drops; feature parity per rollout wave rises).

---

## Updated migration table — supersedes lines 139–149 of `brainstorming-session-2026-05-01-1400.md` and the entire `brainstorming-session-2026-05-05-1500.md`

Each domain phase below bundles **API + UI** for its corresponding APEX module(s), demoable end-to-end at phase end (per D4). The UI is a modern-stack replication of the APEX layout — no redesign.

| Phase | Cluster | Scope | Outcome |
|---|---|---|---|
| **0 — Foundations** | Cross-cutting | Reference Data (incl. one-shot migration from APEX), Authorisation (with SSO; **users + roles + Region/Area scope migrated from APEX per D9**), Notification, **shared `configuration_values` infrastructure table** (Flyway baseline managed by `ram-architecture`; no dedicated configuration service per arch v2.2), **API contracts** (versioned contracts for every domain service + paper contracts for Itinerary & MI Feed), **deployment platform** (CI/CD; continuous deploy from Phase 1 onwards), **stub Home / navigation shell** so each subsequent phase plugs in a working module, **structured logging conventions** (consistent fields, correlation IDs, request/error categorisation) per D7 so logs are usable as the only operational signal during MVP. *Formal Audit & metrics/trace observability are post-MVP per D1; user-action auditing on the post-MVP roadmap per D7.* | Cross-cutting capabilities live with realistic data; Authorisation testable end-to-end with migrated APEX users from day 1; API-as-Product standards battle-tested on Reference Data writes; pipeline ready to deploy every subsequent phase as it lands; logging conventions in place for every service from Phase 1 |
| **1 — Judge** | Domain | **Judge** API (incl. working pattern, tickets, jurisdictional split) **+ Manage Judges UI** (search, filter, profile, working-pattern editor, ticket maintenance). Home dashboard tile for *judges* lights up. | Chain head; working-pattern engine generates forward sittings (records exist; service surface comes in Phase 5). First end-to-end demoable module |
| **2 — Absence** | Domain | **Absence** API + **Absences UI** (list, create, approve/NTBF flag, sickness extension). Home tile for *absences*. | Cover-creation upstream; approval workflow; auto-creates vacancies (R4 wired in Phase 3) |
| **3 — Vacancy** | Domain | **Vacancy** API + **Vacancies UI** (list, edit daily breakdown, mark filled, weekly-by-court quick links). Home tile for *vacancies*. | Demand-side modelled; standalone + absence-derived; cover requirements visible to RSU |
| **4 — Booking** | Domain | **Booking** API (incl. verification, `Vacancy.markFilled` orchestration) **+ Fee-paid and Other Bookings UI**. Home tile for *fee-paid bookings*. | Supply commitment; the high-coupling mid-chain |
| **5 — Sitting** | Domain | **Sitting** API (incl. verification, RFC unlock, AM/PM split) **+ Sittings UI**. **Parallel-eligible from Phase 2 if a second track exists (Variant β).** | Salaried sittings confirmed/verified; the Phase-1 working-pattern-generated records gain a real service surface |
| **6 — Payment** | Domain | **Payment** API (incl. Reconciliation; JFEPS-shaped schedule as versioned content-type) **+ Payments UI + Payment Reconciliation UI**. Home tiles for *pending payments / payments made / unreconciled*. | Highest-stakes context; benefits from prior validation. End of operational chain |
| **7 — Itinerary** | Read model | **Itinerary** API (Strategy A; Strategy C cache as fallback if Forward Look ≤ 30 s NFR misses) **+ Court Itinerary UI + Judge Itinerary UI + Forward Look UI**. | Operational read view; federates over Judge + Absence + Vacancy + Booking + Sitting (R9). Itinerary-eligible for parallel execution with Phase 6 (multi-track) |
| **8 — MI Feed** | Read model | **Reporting / MI Feed** API (Strategy A pull-based) **+ Reports UI**. | Aggregate management information; federates over all domain services including Payment (R10). **Last per user direction.** End of build |
| **9 — Pilot rollout (wave 1)** | — | First pilot **region** migrates with **all applicable user roles** (RSU, Court, Judges, Judges' Clerks, Finance, MI) per D8. Migrated users abandon APEX; remaining regions stay on APEX. Cross-region workflows (e.g. cross-region judge bookings) handled per Risk #1. | First production usage; validates the cutover playbook on a contained but functionally-complete scope |
| **10..N — Subsequent rollout waves** | — | Additional regions migrate, wave by wave (per D8: whole region, all roles). Each wave is gated on full functional coverage for the region's roles. | Programme proceeds until all regions are on the new platform; APEX retires when its last region has migrated |

### Notes on the table

- **First service to extract: Reference Data** (Phase 0 root — unchanged from prior session).
- **First domain service: Judge** (Phase 1, chain head — converges with all prior analyses).
- **Last service before rollout: MI Feed** (Phase 8 — per user direction; consistent with R10).
- **Sitting parallelism:** Phase 5 can begin in parallel with Phase 2 if team capacity supports it (Variant β). Default plan (Variant α) keeps it sequential after Booking.
- **Itinerary parallelism:** Phase 7 can begin in parallel with Phase 6 since Itinerary doesn't depend on Payment (R9 satisfied by end of Phase 5). Default plan keeps it sequential after Payment.
- **UI per phase:** each domain phase delivers its corresponding APEX module's modern-UI replica. The Home dashboard accumulates tiles incrementally as each phase lands.
- **Admin module attrition:** the APEX Admin module (password change + new-user request) is largely absorbed by SSO/IdP under D1. Whatever residual is needed (e.g. a "request access" link to the IdP) lands as part of Phase 0's stub Home / navigation shell, not as a separate module.
- **Cutover (Phase 9+) replaces what was previously a single big-bang event** with a sequence of rollout waves. Each wave is its own go/no-go decision with feature-parity gating for the scope of that wave.

---

## Risks to track post-session (greenfield + phased-rollout risk register)

The risk register reflects D1–D6. Big-bang cutover risk drops out (rollout is phased, D2). Transactional data-migration risk drops out (no transactional migration, D3). Audit and Observability gaps are explicit accepted risks (D1). New risks emerge around per-wave feature parity, cross-region workflow during partial rollout, and historical-data access for migrated users.

| # | Risk | Trigger / mitigation |
|---|---|---|
| 1 | **Cross-region workflow during partial rollout** | Per D8, each wave is a whole region with all roles — so the boundary is "between regions," never "within a region." Cross-region workflows (off-circuit judges sat in another region; cross-region judge management; reports that aggregate across regions) are the transitional concern. Per-wave decision: which cross-region workflows are operable in mixed mode, which are gated until both ends migrate, which fall back to manual coordination during the transition. Document explicitly per wave |
| 2 | **Historical-data access for migrated users** | Per D3, transactional history stays in APEX. Decide: read-only APEX access for migrated users (operational), or a one-page export at migration time, or no access. Document the choice and communicate to users at migration |
| 3 | **Feature-parity gating per rollout wave** | Each rollout wave needs an explicit feature-parity checklist for the scope of that wave (which user roles, which workflows, which Region/Office). Gate the wave on the checklist; do not generalise readiness from one wave to the next without verification |
| 4 | **API contract churn cascading downstream** | Versioned contracts from Phase 0 (D1); contract tests between consecutive phases; a frozen contract for any service before its consumer's phase begins. More acute under Variant β parallelism |
| 5 | **Scope creep during build** | Lock the 11-service decomposition (revised v2.2, 2026-05-07 — `ram-configuration` dropped); new requirements get triaged against post-MVP backlog by default; only changes to existing in-flight services are entertained mid-phase |
| 6 | **SSO availability** | SSO must be live in Phase 0 — every UI demo from Phase 1 onwards depends on it. Treat SSO as a Phase 0 hard dependency, with a contingency plan (mock SSO for internal demo) if HMCTS IdP integration slips |
| 7 | **Audit minimum: log-based only for MVP (D7)** | Per D7, MVP audit is application logs (request, error). No structured before/after audit trail. **Roadmap commitment:** user-action auditing in a post-MVP iteration. The remaining accepted gap is structured user-action audit during the pilot — regulatory or compliance questions about "who changed what when" during a pilot incident will rely on log triage, not a structured audit trail. Acceptable if pilot incidents are rare and contained; reassess before broad GA |
| 8 | **Observability minimum: log-based only for MVP (D7)** | Per D7, MVP observability is application logs. No metrics platform, no traces, no dashboards. Mean-time-to-diagnose for pilot incidents is bounded by log-grep effectiveness. Mitigation: structured logging (consistent fields, correlation IDs, request/error categorisation) so logs are usable as the only signal source. Define logging conventions in Phase 0 |
| 9 | **Forward Look ≤ 30 s NFR breach under Strategy A** | Strategy C cache pre-designed; switch on if needed during Itinerary construction (Phase 7) |
| 10 | **Read-model API gap discovered late** | Phase 0 paper contracts for Itinerary + MI Feed (D1) constrain domain API design across Phases 1–6, so Phase 7–8 federation has no surprises |
| 11 | **Behavioural divergence from APEX** | Per D5 (revised), treat APEX as the behavioural reference verified by **manual UAT performed by APEX-experienced users**. For each domain service, the per-phase UAT script names the workflows / edge cases users are expected to compare in APEX vs RAM Pathfinder, with sign-off captured per role per region before the wave gate. There is no automated APEX-comparison harness |
| 12 | **UI replication scope** | Per D4, modern-UI replication of as-is APEX layouts. Risk: subtle APEX UX behaviours (validation messages, in-line errors, keyboard shortcuts, the *Select Report* copy-paste pattern) are easy to under-spec. Mitigation: include UX behavioural cases in the per-phase **manual UAT scripts** users walk through (alongside data-flow cases), with APEX-experienced users running the side-by-side comparison |
| 13 | **Phase 0 migration correctness — Reference Data + Users/Roles** | Reference Data (D3) and Users + Roles (D9) are migrated from APEX in Phase 0. Errors cascade into every domain service (for Reference Data) and into every authorisation decision (for Users/Roles). Treat as two discrete sign-off deliverables: (a) RSU / judicial-team owners verify controlled lists; (b) named owners (likely RSU + OPT Support) verify role + Region/Area assignments per migrated user against APEX |
| 14 | **APEX-to-IdP identity mapping (D9)** | D9 migrates APEX user records keyed to an IdP-resolvable identifier (email / employee ID). Risk: APEX records that don't cleanly map to an IdP principal — leavers, shared accounts, accounts with mismatched email between APEX and the IdP. Mitigation: pre-migration reconciliation report (APEX user list ⇄ IdP principal list) with explicit handling rules for unmatched records (drop / hold / manual map). Run reconciliation in Phase 0 before going live; rerun before each rollout wave for the in-scope region's users |

### Risks that retire under D1–D6

- **Big-bang cutover risk** — retired by phased rollout (D2).
- **Transactional data migration at cutover** — retired by D3 (no transactional migration).
- **APEX maintenance posture / team velocity split** — retired by D6 (APEX is out of project scope).
- **APEX/API write coexistence races** *(Risk #2 in 2026-05-01 session)* — already retired by greenfield reframe; reaffirmed here.
- **Reference Data drift between APEX and the new API during transition** *(Risk #5 in 2026-05-01 session)* — retired by D3 + D2 (one-shot Reference Data migration in Phase 0; no parallel-run period in which drift could occur).

---

## Session insights — surprises and inflection points

- **Removing the strangler assumption simplifies the sequencing question to near-triviality.** Under strangler, sequencing was a high-stakes design choice because risk-management considerations cut against the dependency DAG. Under greenfield, the DAG dominates and the answer is "follow it." Most of the prior intellectual work was load-bearing only because of the strangler premise.
- **The prior session's "read-model-first" recommendation was strangler-specific.** It traded some calendar time for risk reduction during APEX coexistence. With no APEX coexistence, there is nothing to trade for — read-model-first becomes pure cost (read models federate over domain services that don't exist yet).
- **"Smallest blast radius first," "MI Feed as first user-visible API," and "DA&I early evidence"** are all strangler-era artefacts. None survive greenfield analysis. This is not a criticism of the prior session — those concerns were real under the prior premise; they just don't apply now.
- **The interesting decisions move out of sequencing and into Phase 0 Foundations and Cutover.** Sequencing is largely mechanical under greenfield. Phase 0 scope (Audit, observability, contract-testing, deployment platform) and Cutover strategy (big-bang vs phased) are now the high-leverage decisions.
- **APEX as a behavioural reference** is more important than its role as a system to migrate from. The new system needs to *match the behaviour* APEX exhibits today — including edge cases not in `functional-modules.md`. That implies **manual UAT scripts written against APEX behaviour** (executed by APEX-experienced users), not just functional verification against the spec. *Note: an earlier insight bullet here proposed automated parity tests; that has been replaced by manual UAT under the revised D5.*

---

## Captured ideas — IDEA FORMAT TEMPLATE

**[Sequencing #1]: Phase 0 paper contracts for Itinerary and MI Feed**
*Concept:* Before any domain service is built, write the contracts (resource shape, query parameters, federation pattern) for Itinerary and MI Feed. Use those contracts to constrain the field-shape of Judge, Absence, Vacancy, Booking, Sitting, and Payment APIs as they're built. Phases 7–8 then become construction-only, with no contract surprises.
*Novelty:* Inverts the dependency. Read models depend on domain services for *data*; domain services depend on read models for *shape constraints*. Capturing constraints early prevents Phase 7–8 gap-discovery and rework.

**[Sequencing #2]: Sitting as parallel-eligible, not parallel-mandatory**
*Concept:* Recognise Sitting depends only on Judge (R6), not on the Absence/Vacancy/Booking chain. Permit Sitting extraction to begin in parallel with Phase 2 *if capacity exists*; default plan keeps it sequential after Booking. Variant β is a delta on Variant α, not a separate plan.
*Novelty:* Treats parallelism as a capacity-conditional upgrade rather than a phase boundary. Removes the need to pick parallelism vs sequential at sequencing time — defer until staffing is known.

**[Sequencing #3]: ~~Audit as a Phase 0 capability~~ — retracted by D1**
*Concept (retracted):* Originally proposed Audit as a Phase 0 capability so writes are auditable from Phase 1 onwards.
*Status:* Per D1, Audit is explicitly post-MVP. The accepted-risk equivalents (Risk #7, Risk #8) replace this idea. Decision-makers should revisit Audit + Observability before broad GA, but the MVP and pilot waves proceed without them.

**[Sequencing #4]: APEX as behavioural reference, not migration host (locked as D5; revised 2026-05-06)**
*Concept:* Treat APEX as the source-of-truth for *behaviour* (including edge cases not in the functional spec) but not as a host for any part of the migrating system. Behavioural parity is verified by **manual UAT performed by users who use the existing APEX application** — RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI users — comparing RAM Pathfinder's behaviour against APEX behaviour they reproduce interactively in APEX. UAT scripts include UX behaviours under D4 (validation messages, keyboard patterns, *Select Report* copy-paste) alongside functional and data-flow cases.
*Novelty:* Reframes APEX from a system being decomposed into a system being *replicated*. Captures undocumented behaviour without depending on whether the documentation is complete or whether an automated harness can reach a system the project does not co-manage (D6). The users themselves are the source of truth for behavioural parity.
*What was retracted:* Earlier framing proposed automated "APEX-comparison" tests in CI with the new app as the system under test. That was retracted on 2026-05-06 — APEX has no programmatic test hook, the project does not co-manage APEX (D6), and an automated harness against an external system is fragile. Manual UAT by APEX-experienced users replaces it.

**[Sequencing #5]: Per-wave feature-parity gating (refined under D2 + D4 + D8)**
*Concept:* Each rollout wave (Phase 9, 10, …) is its own go/no-go decision with a feature-parity checklist scoped to **the region and all its applicable user roles** (per D8). The checklist is derived from `functional-modules.md` user actions, mapped to the new APIs and modern-UI replicas, **and from the manual UAT scripts walked through by APEX-experienced users (per D5 revised)**. UI fidelity is part of the gate (per D4 — replicate APEX layouts), but cosmetic divergence is permitted; functional and behavioural parity (the latter signed off by users via manual UAT) are the binding criteria. Cross-region workflows that touch the in-scope region are checked separately (Risk #1).
*Novelty:* Replaces the prior idea of a single big-bang cutover gate with an incremental gate that adapts to each wave's scope. The first wave can be deliberately a small region so the gate is contained and the first cutover is rehearsed before scope expands to larger regions.

**[Sequencing #6]: Phased rollout boundary — by region with full role coverage (locked as D8)**
*Concept:* Each rollout wave is a whole region with **all applicable user roles** for that region — RSU, Court, Judges, Judges' Clerks, Finance, MI. A region only moves once all functionality required by every in-region role is implemented and tested. Wave gate is high (full functional coverage for the region) but the boundary is clean (no half-migrated regions, no role-by-role partial rollout).
*Novelty:* Picks the boundary at programme-design time. Eliminates within-region role contention; keeps cross-region workflow as the only transitional concern (Risk #1). Trades a higher per-wave readiness bar for a simpler operational picture during rollout.

---

## Next steps for the project

### Decisions taken (recorded above as D1–D9)

- ✅ **Phase 0 scope locked** — Reference Data + Authorisation/SSO + Notification + shared `configuration_values` infrastructure table (no separate configuration service per arch v2.2) + API contracts + deployment platform + Reference Data migration + Users/Roles migration + structured logging conventions. Formal Audit & metrics/trace observability post-MVP. *(D1, extended by D9)*
- ✅ **Cutover strategy: phased rollout.** *(D2)*
- ✅ **Data migration: Reference Data + Users/Roles** (Phase 0). No transactional data migration. *(D3 + D9)*
- ✅ **Feature parity gate is functional + UI-replicates-APEX** (modern UI stack, no redesign). *(D4)*
- ✅ **APEX is behavioural reference**, verified via **manual UAT by APEX-experienced users**; not migration host, not an automated comparison reference. *(D5 revised)*
- ✅ **APEX maintenance is out of project scope.** *(D6)*
- ✅ **Audit / Observability MVP minimum: log-based** (request, error). User-action auditing on the post-MVP roadmap. *(D7)*
- ✅ **Rollout boundary: by region, all applicable user roles.** A region migrates only once every in-region role's functionality is complete. *(D8)*
- ✅ **Users + roles migrated from APEX** in Phase 0 to seed Authorisation. SSO (HMCTS IdP) owns AuthN; migrated records keyed to IdP principal. *(D9)*

### Still open (for follow-up)

1. **Team capacity decision** — Variant α (single squad, sequential) or Variant β (multi-squad, Sitting in parallel from Phase 2). Defer until staffing is known; default to α.
2. **Pilot region selection** — which region migrates first under D8? Smaller / less workflow-complex regions reduce wave-1 risk. Decision affects Risk #1 sizing.
3. **Cross-region workflow handling per wave** — for each cross-region workflow type (off-circuit judges, cross-region reports, cross-region judge management), a per-wave decision: operable in mixed mode, gated until both ends migrate, or fall back to manual coordination. (Risk #1.) Worth a programme-level template.
4. **Historical-data access policy for migrated users** (Risk #2) — read-only APEX access, one-shot export, or no access.
5. **Phase 0 migration owners** — name owners for (a) Reference Data sign-off (RSU / judicial-team owners of each controlled list, Risk #13a) and (b) Users/Roles sign-off (likely RSU + OPT Support; Risk #13b).
6. **APEX ⇄ IdP identity mapping** (Risk #14) — define the identity-key scheme (email vs employee ID vs other), produce a pre-migration reconciliation report, and decide handling for unmatched records (drop / hold / manual map). Owner needed.
7. **Phase 0 paper contracts for Itinerary + MI Feed** — drafted as part of D1; needs an owner.
8. **Logging conventions detail** — under D7, structured logging is the operational signal. Define the schema (correlation ID format, error categorisation taxonomy, retention policy) in Phase 0; it cannot be retrofitted to earlier phases.
9. **Per-wave user activation mechanism** — under D9 the in-region users already exist in Authorisation from Phase 0; activation per wave is a flag flip. Define the flag and the activation procedure as a Phase 0 deliverable.
10. **Take this artefact into `/bmad-create-architecture`** alongside the 2026-05-01 12-service decomposition. The architecture document supersedes lines 139–149 of the 2026-05-01 session and the entire 2026-05-05-1500 draft.

---

## Session metadata

- **Approach:** Targeted convergent / analytical session — re-run with greenfield reframe; iterated in conversation to lock D1–D6
- **Techniques used:** Five Whys, Constraint Mapping, Decision Tree Mapping
- **Variants generated:** 2 (Strict Sequential α, Sitting-Parallel β); plus a vertical-slice packaging variation noted but not endorsed
- **Recommendation:** Variant α as default; β as capacity-conditional upgrade
- **Decisions locked in conversation (D1–D9):** Phase 0 scope (D1); phased rollout (D2); ref-data-only migration *(extended by D9)* (D3); functional + APEX-replica UI parity gate (D4); APEX as behavioural reference verified via **manual UAT by APEX-experienced users** (D5 revised 2026-05-06); APEX maintenance out of scope (D6); log-based audit/observability minimum with user-action audit on post-MVP roadmap (D7); rollout boundary by region with full role coverage (D8); users + roles migrated from APEX to seed Authorisation, keyed to SSO IdP principal (D9)
- **Source documents consulted:**
  - `_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md` (12-service decomposition; lines 139–149 superseded)
  - `_bmad-output/brainstorming/brainstorming-session-2026-05-05-1500.md` (entirely superseded — built on retracted strangler assumption)
  - `docs/architecture/asis/functional-modules.md`
- **Supersedes:** Lines 139–149 of 2026-05-01-1400; all of 2026-05-05-1500
