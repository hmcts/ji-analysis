---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - '_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md'
  - 'docs/architecture/asis/functional-modules.md'
session_topic: 'Aligning the JI migration phase sequencing to the actual business workflow chain (Manage Judges → Absences → Vacancies → Fee-paid Bookings → Sittings → Payments → Payment Reconciliation)'
session_goals: 'Decide whether, after Phase 0 Foundations, the migration should extract domain services in business-workflow order rather than the prior session''s risk-graded order with read-model services front-loaded. Produce a recommended phase sequencing, a constraint map, 2–3 variants with tradeoffs, risks, and an updated migration table to supersede lines 139–149 of the prior session.'
selected_approach: 'Targeted convergent / analytical session (divergent work already done in 2026-05-01 session)'
techniques_used: ['Five Whys', 'Constraint Mapping', 'Decision Tree Mapping']
ideas_generated: 0
session_active: false
workflow_completed: true
context_file: '_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md'
supersedes: 'Lines 139–149 of brainstorming-session-2026-05-01-1400.md (Migration sequence, Phase 4 plan)'
---

# Brainstorming Session Results — Phase Sequencing Re-evaluation

**Facilitator:** Ramnish
**Date:** 2026-05-05

## Session Overview

**Topic:** Aligning the JI migration phase sequencing to the actual business workflow chain.

**Business workflow chain (from `docs/architecture/asis/functional-modules.md`):**
**Manage Judges → Absences → Vacancies → Fee-paid Bookings → Sittings → Payments → Payment Reconciliation**

**Goals:** Decide whether, after Phase 0 Foundations (Reference Data, Authorisation, Configuration, Notification — non-negotiable, stay first), the migration should extract domain services in business-workflow order **(Judge → Absence → Vacancy → Booking → Sitting → Payment → Reconciliation)** instead of the prior session's risk-graded order (Judge as smallest blast radius first, Payment last, with MI Feed and Itinerary front-loaded as Phases 1–2).

**Cluster terminology (carried from updated prior artefact):** Domain services / Cross-cutting services / Read-model services. *The term "Spine" is not reintroduced.*

**Out of scope for re-sequencing:** Phase 0 Foundations stay first. The 12-service decomposition itself is locked from the prior session — only the *order* of extraction is open.

### Tensions to pressure-test (provided in the brief)

1. Read-model-first vs write-first
2. "Smallest blast radius" vs "first in the chain"
3. MI Feed as first user-visible API vs deferred read models
4. Business legibility vs technical staging
5. Where do read models go (front-loaded, end-loaded, interleaved)
6. Parallelism (parallel domain extraction vs strict sequence purity)

---

## Technique 1 — Five Whys

**Purpose:** Surface the *real* reason the existing sequence chose risk-graded order with read-models front-loaded. Methodology dogma, or binding constraint?

**Why 1 — Why does Phase 1 ship MI Feed first instead of Judge?**
Because MI Feed is read-only over the existing Oracle DB (strangler-style). It validates the API-as-Product / REST-first pattern without touching the write side. APEX/API write coexistence is deferred.

**Why 2 — Why is validating the pattern on read-only worth deferring write-side?**
Because if the architectural pattern is wrong (versioned content-types, `/capabilities`, Strategy A federation, degraded-mode contracts, SLA templates, deprecation policy), you want to learn it on a low-stakes surface — not while extracting Judge from Oracle and dual-writing.

**Why 3 — Why is dual-writing risky enough to want pattern-validated first?**
Because Oracle APEX is the system of record today. Any write extraction means coexistence: APEX still writes to its own tables, the new service writes to its own store, and the two must stay in sync. This is named explicitly in the prior session as Risk #2 (APEX/API write coexistence races).

**Why 4 — Why is APEX/API write coexistence the dominant risk?**
Because there is no event bus (REST-first decision), no audit (deferred), no domain event stream — consistency is enforced by direct synchronous calls. APEX writes can't be observed by the new service without CDC or audit. Mitigation reduces to (a) APEX calls the new service (forces APEX changes), (b) per-record feature-flag locks (operationally complex), or (c) hard cutover (risk concentrated, not avoided).

**Why 5 — Why does "MI Feed validates the pattern" actually hold up as a risk-reduction argument?**
*Partially.* MI Feed exercises Strategy A federation, `/capabilities`, versioning, JSON shape negotiation. It does **not** exercise the Booking-orchestrates-`Vacancy.markFilled` write coordination, dual-write coexistence with APEX, per-record feature flags, or synchronous-call latency budgets under write contention. **MI Feed reduces some pattern risk but not the dominant risk surface.**

### Crystallised reason

The existing sequence has **two distinct rationales** that the prior artefact treats as one:

- **Rationale A — Pattern validation on a low-stakes surface.** Real value, partially obtainable from Reference Data (Phase 0) which is *already* a write surface but has no APEX coexistence (JI is the single writer; Risk #5 mitigation already names this).
- **Rationale B — Early external evidence for DA&I.** This is a *stakeholder-management* benefit, not an architectural one. DA&I get MI from Oracle reports today; their expectation that they receive MI Feed at Phase 1 was created by the prior plan, not by an external SLA.

**Conclusion:** The risk-graded order is **partially** a binding constraint and **partially** inherited preference. The pattern-validation argument is half-met by Reference Data extraction in Phase 0. The remaining benefit is stakeholder-management, which is a real but soft constraint.

---

## Technique 2 — Constraint Mapping

**Purpose:** Separate real dependencies, inherited preferences, and pseudo-constraints.

### Real constraints (binding — must respect in any variant)

| # | Constraint | Source |
|---|---|---|
| R1 | **Reference Data → every domain service.** Every domain service depends on org tree, vocabularies, calendar. | Prior session line 50 (Reference Data Phase 0 root); functional-modules.md cross-cutting NFRs. |
| R2 | **Authorisation → every user-facing or write API.** Every domain call consults it. | Prior session locked-in decision: SSO-delegated AuthN, JI-owned AuthZ. |
| R3 | **Notification & Configuration → most domain services.** Booking acknowledgement emails (FPB-FR), Payment authoriser email (PAY-FR), absence acknowledgement (ABS-FR) all rely on Notification. | functional-modules.md §4.5–4.8. |
| R4 | **Absence → Vacancy.** Approved absences requiring cover auto-create vacancies. | functional-modules.md line 244 (ABS key user action #2). |
| R5 | **Vacancy → Booking.** `POST /bookings` orchestrates `Vacancy.markFilled` synchronously. | Prior session Architecture #3, line 73. |
| R6 | **Judge → Sitting / Vacancy / Booking.** Working patterns, jurisdictional split, tickets, fee-payment status all originate in Judge. | functional-modules.md §4.2 cross-module dependencies. |
| R7 | **Booking + Sitting → Payment.** Payment derives from confirmed bookings AND confirmed sittings (where salaried staff sit as Recorders). | functional-modules.md §4.8 inputs; line 410 (SIT outputs). |
| R8 | **Payment → Reconciliation (folded into Payment lifecycle).** | Prior session early scope decision, line 43. |

### Inherited preferences (carried from prior session — re-examinable)

| # | Preference | Carried from |
|---|---|---|
| I1 | **Read-model-first ordering** of MI Feed (Phase 1) and Itinerary (Phase 2) before any domain write extraction. | Prior session Process #1, line 195. |
| I2 | **"Smallest blast radius first"** applied to Judge as Phase 3. | Prior session line 146. |
| I3 | **Sitting in parallel** with Absence/Vacancy/Booking. | Prior session Phase 4, line 147. |
| I4 | **MI Feed as first user-visible API** for DA&I early evidence. | Prior session line 152. |
| I5 | **Strategy C cache for Itinerary** as a fallback if the ≤ 30 s Forward Look NFR is breached. | Prior session Architecture #2, line 174. |

### Pseudo-constraints (look real but aren't)

| # | Pseudo-constraint | Why it isn't binding |
|---|---|---|
| P1 | "DA&I must see something within X months." | DA&I currently receive MI from Oracle reports; no external SLA defines a migration milestone. The expectation is created by the migration plan itself. |
| P2 | "Pattern must be validated on a read-only surface before any write extraction." | Half-real, half-pseudo. Reference Data extraction in Phase 0 already exercises versioned writes, `/capabilities`, audited reference writes, and deprecation policy. MI Feed adds Strategy A federation experience but does not exercise the dominant risk (APEX/API write coexistence). |
| P3 | "Business-chain order is more legible to stakeholders." | Conditional — only material if stakeholders are funding by milestone or if external comms rely on chain milestones. Verify before relying on this benefit. |
| P4 | "Itinerary must be extracted early so its ≤ 30 s NFR risk is discovered before any UI client lights up." | UI is out of scope of the API decomposition phase. Itinerary's consumers (future tribunals, downstream tooling) can adopt the API in Phase 6 with the contract clearly stating Strategy A's worst-case latency and Strategy C as fallback. |
| P5 | "Read models must precede domain services." | Inverted dependency. Read models *federate over* domain services (Strategy A); they technically need domain services to exist (or to fall back to Oracle). They can equally come *after* domain extraction with no functional loss — they simply federate over the new APIs instead of Oracle. |

### Implications of the constraint map

- **The dependency DAG between domain services already mirrors the business chain almost exactly.** Judge precedes everything (R6); Absence → Vacancy → Booking is a hard chain (R4, R5); Booking + Sitting feed Payment (R7). The disagreement between "business-chain" and "risk-graded" is **not** about domain-service order — it is about **where read models go**.
- **Reference Data, not MI Feed, is the actual pattern-validation surface.** It is in Phase 0 already (R1). MI Feed adds Strategy A federation experience — valuable, but not the dominant-risk validator.
- **The "front-loaded read-models" choice is mostly an inherited preference (I1, I4) reinforced by a partly-pseudo constraint (P2).** It survives challenge only if stakeholder-management benefits (P3) outweigh the cost of transitional double-mode federation (read models federating over Oracle initially, then re-federating over the new APIs as they extract).

---

## Technique 3 — Decision Tree Mapping

Three viable variants, all respecting Phase 0 Foundations and the real constraints (R1–R8).

### Variant A — Pure Business-Chain

| Phase | Cluster | Services | Notes |
|---|---|---|---|
| 0 | Cross-cutting | Reference Data, Authorisation (with SSO), Configuration, Notification | Foundations — locked |
| 1 | Domain | **Judge** | Chain head; smallest blast radius |
| 2 | Domain | **Absence** | Sequential after Judge |
| 3 | Domain | **Vacancy** | Sequential after Absence (R4) |
| 4 | Domain | **Booking** | Sequential after Vacancy (R5) |
| 5 | Domain | **Sitting** | Sequential — even though parallel-eligible after Phase 1 |
| 6 | Domain | **Payment** (incl. Reconciliation) | After Booking + Sitting (R7, R8) |
| 7 | Read model | **Itinerary**, **MI Feed** | Federate over the new domain APIs |
| 8 | — | Decommission APEX | — |

**Pros:** Maximum business legibility; clean read-model architecture (federate new APIs, no Oracle-transitional code); no "validation surface that doesn't validate the dominant risk."

**Cons:** Sitting parallelism lost (a real cost — Sitting depends only on Judge, not on the Absence/Vacancy/Booking chain); no external user-visible API until Phase 7; write-side risk hit at Phase 1 with no prior pattern smoke-test other than Reference Data.

### Variant B — Hybrid (recommended)

| Phase | Cluster | Services | Notes |
|---|---|---|---|
| 0 | Cross-cutting | Reference Data, Authorisation (with SSO), Configuration, Notification | Foundations — locked |
| 1 | Domain | **Judge** | First write-side extraction; chain head AND smallest blast radius. Optional 1a: read-only `GET /judges` federated over Oracle as a Phase-0 → Phase-1 bridge to smoke-test the pattern before dual-write |
| 2 | Domain | **Absence**, **Vacancy** | Sequential within phase (R4); two sub-services often co-deployed |
| 3 | Domain | **Booking** | Orchestrates `Vacancy.markFilled` (R5); the high-coupling mid-chain |
| 4 | Domain | **Sitting** | **Parallel-eligible from Phase 2** — depends only on Judge (R6), not on the Absence/Vacancy/Booking chain |
| 5 | Domain | **Payment** (incl. Reconciliation) | Highest-stakes; benefits from prior validation |
| 6 | Read model | **Itinerary**, **MI Feed** | Federate over the new domain APIs (clean — no Oracle transitional federation) |
| 7 | — | Decommission APEX | — |

**Pros:** Aligns with business chain in the order stakeholders recognise; write-side validation begins at Phase 1 (instead of Phase 3) — earlier learning on the dominant risk; read models federate cleanly over the new APIs in Phase 6; Sitting parallelism preserved; optional Phase 1a read-only bridge gives a partial pattern smoke-test on the actual write target.

**Cons:** No external user-visible API until Phase 6 (DA&I expectation reset required); the "validation on read-only first" benefit of Variant C is given up — pattern proves itself on Judge writes; Risk #2 (APEX/API write coexistence) trigger date moves earlier; Audit deferral (Risk #3) becomes more acute — Audit must be in place by Phase 1, not Phase 3.

### Variant C — Existing Risk-Graded (status quo from prior session)

| Phase | Cluster | Services | Notes |
|---|---|---|---|
| 0 | Cross-cutting | Reference Data, Authorisation, Configuration, Notification | Foundations |
| 1 | Read model | **MI Feed** (federated over Oracle) | DA&I early-evidence; Strategy A pattern validation |
| 2 | Read model | **Itinerary** (Strategy A; C as fallback) | Read primitives ready for any future client |
| 3 | Domain | **Judge** | Smallest blast radius; first write extraction |
| 4 | Domain | **Absence → Vacancy → Booking**, **Sitting** in parallel | Operational chain |
| 5 | Domain | **Payment** (incl. Reconciliation) | Highest stakes |
| 6 | — | Decommission APEX | — |

**Pros:** Pattern validation on lower-risk read surfaces first; DA&I gets early evidence; Risk #2 (write coexistence) deferred to Phase 3 with maximum prior context.

**Cons:** Read-side validation does not exercise the dominant-risk write surface (P2 unmasking); two phases (1–2) before any write-side learning; read models federate over Oracle initially, then re-federate over the new APIs as they extract — transitional double-mode logic; less business-legible to stakeholders unfamiliar with read-vs-write decomposition.

### Tradeoff matrix

| Dimension | A: Pure Business-Chain | B: Hybrid | C: Existing Risk-Graded |
|---|---|---|---|
| Business legibility | High | High | Medium |
| Pattern validation before write-side | Reference Data only | Reference Data + optional Phase 1a smoke-test | Two read-only phases |
| Earliest write-side learning | Phase 1 | Phase 1 | Phase 3 |
| Read-model architecture | Clean (federate new APIs) | Clean (federate new APIs) | Transitional (federate Oracle, then new) |
| External early-evidence consumer | None until Phase 7 | None until Phase 6 | DA&I via MI Feed at Phase 1 |
| Sitting parallelism | Lost | Preserved | Preserved |
| Audit trigger date (Risk #3) | Phase 1 | Phase 1 | Phase 3 |
| APEX/API write coexistence (Risk #2) trigger | Phase 1 | Phase 1 | Phase 3 |
| Total phases | 9 | 8 | 7 |

---

## Recommendation

**Variant B — Hybrid.**

Rationale:
- **The dependency DAG and the business chain agree on domain-service order.** Judge first, Payment last is true under both lenses (R6, R7). Variant B respects that without forcing strict serialisation where the DAG allows parallelism (Sitting).
- **Read models defer cleanly to Phase 6** because they federate over domain services. Front-loading them creates transitional double-mode federation logic that has to be removed later — wasted effort.
- **Reference Data in Phase 0 is the genuine pattern-validation surface.** MI Feed's role as a pattern-validator (Rationale A from Five Whys) is partially-redundant; its real differential value is DA&I early evidence (Rationale B), which is a stakeholder-management benefit, not an architectural one.
- **The optional Phase 1a read-only bridge** (`GET /judges` federated over Oracle, deployed before Phase 1b dual-write) gives a partial smoke-test of the actual write target without paying for two full read-only phases.
- **Sitting parallelism is preserved** by recognising Sitting depends only on Judge, not on the Absence/Vacancy/Booking chain. Variant A pays a real cost to abandon this; Variant B does not.

**Where this could split:** if stakeholders or funders need a user-visible *external* deliverable to fund or unblock the programme, Variant C's MI Feed at Phase 1 is the answer. This is a political/funding question, not a technical one. **Verify P3 (business legibility) and the DA&I expectation (P1) with the relevant stakeholders before locking Variant B.** If either turns binding, switch to Variant C.

---

## Updated migration table — supersedes lines 139–149 of `brainstorming-session-2026-05-01-1400.md`

| Phase | Cluster | Services | Outcome |
|---|---|---|---|
| **0 — Foundations** | Cross-cutting | Reference Data, Authorisation (with SSO), Configuration, Notification | Cross-cutting capabilities live; APEX increasingly defers to them; API-as-Product standards battle-tested on Reference Data writes |
| **1 — Judge (chain head)** | Domain | **Judge** (incl. working pattern, tickets, jurisdictional split). *Optional Phase 1a: read-only `GET /judges` federated over Oracle as a pattern smoke-test before Phase 1b dual-write* | First write-side extraction; smallest blast radius AND chain head; pattern validates itself on writes |
| **2 — Cover-creation flow** | Domain | **Absence**, **Vacancy** (sequential within phase — Absence approval auto-creates Vacancy) | Demand-side modelled; the upstream of Booking |
| **3 — Booking** | Domain | **Booking** (orchestrates `Vacancy.markFilled`; incl. verification) | Supply commitment extracted; the high-coupling mid-chain |
| **4 — Sitting** *(parallel-eligible from Phase 2)* | Domain | **Sitting** (incl. verification, RFC unlock) | Salaried sittings extracted; depends only on Judge so can begin in parallel with Phase 2 |
| **5 — Payment** | Domain | **Payment** (incl. Reconciliation lifecycle; JFEPS-shaped schedule as versioned content-type) | Highest-stakes context; benefits from prior validation |
| **6 — Read models** | Read model | **Itinerary** (Strategy A; Strategy C cache as fallback if NFR misses), **Reporting / MI Feed** (Strategy A pull-based) | Read surfaces federate over the new domain APIs — clean, no Oracle transitional federation |
| **7 — Decommission APEX** | — | — | Domain writes flow through new APIs; APEX retires |

### First API to extract: **Reference Data** (unchanged from prior session — Phase 0 root)
### First domain extraction: **Judge** (Phase 1, chain head and smallest blast radius — converges)
### First user-visible *external* API: **MI Feed** (now Phase 6, was Phase 1 — DA&I expectation must be reset)

---

## Risks to track post-session

Inherited risks remain in force; trigger dates shift under Variant B.

| # | Risk | Trigger / mitigation | Change vs prior session |
|---|---|---|---|
| 1 | SSO migration timing slips | Treat as a parallel workstream that *must* land before Phase 1 | Unchanged |
| 2 | APEX/API write coexistence races | APEX writes routed through Judge API or strict per-record feature-flag locks | **Trigger moves from Phase 3 to Phase 1.** Mitigation needs to be designed during Phase 0, not after Phase 2 read-model learnings |
| 3 | Audit out-of-scope gap | Audit must be in place before any write extraction. Decide: minimal Audit subscriber in Phase 0, or accept the risk for Phase 1 Judge writes | **Trigger moves from Phase 3 to Phase 1.** Stronger argument for adding minimal Audit to Phase 0 |
| 4 | Forward Look ≤ 30 s NFR breach under Strategy A | Strategy C cache pre-designed; switch on if needed | **Discovery deferred to Phase 6.** Lower urgency since UI is out of scope; consumers in Phase 6 can co-design fallback |
| 5 | Reference Data drift between APEX and the new API during transition | Reference Data API is the single writer from day-1; APEX reads from it | Unchanged |
| 6 | **NEW — Pattern invalidation on Judge extraction without read-only safety net** | Optional Phase 1a `GET /judges` federated read deployed before Phase 1b dual-write; rollback = stop pointing consumers at the new endpoint | New under Variant B |
| 7 | **NEW — Read-model API gaps discovered in Phase 6** | Itinerary or MI Feed may need a domain field that no one designed because Judge/Booking/Payment APIs were built without seeing the read-model contract. Mitigation: write paper Itinerary + MI Feed contracts in Phase 0 to constrain domain API design | New under Variant B |
| 8 | **NEW — DA&I expectation reset** | DA&I expectation that they receive MI Feed at Phase 1 (carried from prior plan) needs to be communicated and rebaselined to Phase 6. Provide bridging Oracle-report continuity until then | New under Variant B |
| 9 | **NEW — Sitting/Booking parallelism contention on Judge reads** | Running Sitting in parallel with Booking/Vacancy risks contention for Judge working-pattern reads. Mitigation: strict read-only on Judge from Sitting's side until Judge writes are stable; explicit cache-invalidation contract | New — surfaces from preserved parallelism |

---

## Session insights — surprises and inflection points

- **The headline disagreement between "business-chain order" and "risk-graded order" is *not* about domain-service order.** Both lenses agree Judge is first and Payment is last. The real disagreement is **where read models go** — front-loaded (Variant C) or end-loaded (Variants A, B). Recognising this collapses the question from a six-axis tradeoff to a single read-model placement decision.
- **Reference Data is the actual pattern-validator, not MI Feed.** Phase 0 already exercises versioned writes, `/capabilities`, audited reference writes, and deprecation policy. MI Feed's incremental pattern-validation contribution (Strategy A federation) does not validate the dominant risk surface (write coexistence).
- **"Read-model-first" is partially-pseudo.** It solves a problem (early-pattern-validation) that is partially-solved by Reference Data, and it carries a hidden cost (transitional double-mode federation over Oracle, then over the new APIs). Once that cost is named, the benefit-to-cost ratio shifts.
- **DA&I early-evidence is a stakeholder-management benefit dressed as an architectural one.** No external SLA forces Phase 1 MI Feed delivery. The prior plan created the expectation; the new plan can reset it. Whether that's politically viable is the determining question for Variant B vs C.
- **Sitting parallelism is the underrated cost of Variant A.** The DAG allows Sitting to begin in parallel with Phase 2 (it depends only on Judge). Pure-chain order pays a real serialisation cost to obtain narrative purity that the DAG does not require.

---

## Captured ideas — IDEA FORMAT TEMPLATE

**[Sequencing #1]: Phase 1a read-only Judge bridge as pattern smoke-test**
*Concept:* Before Phase 1b Judge dual-write, deploy `GET /judges` and `GET /judges/{id}` as a federated read over Oracle. Consumers (internal tools, integration tests) call the new endpoints; rollback is "stop pointing them there." This gives a partial smoke-test of the pattern on the actual write target without paying for two full read-only phases.
*Novelty:* Splits the read-model-first instinct into two parts — pattern validation (now done on Judge itself, low cost) and DA&I early evidence (deferred to Phase 6). Pays the smaller half of the read-first cost; defers the larger half.

**[Sequencing #2]: Read-model contracts as Phase 0 paper artefacts**
*Concept:* Write Itinerary and MI Feed contracts in Phase 0 — not the implementation, just the contract. Use those contracts to constrain Judge/Booking/Sitting/Payment API design across Phases 1–5, so the read models in Phase 6 federate cleanly without retroactive domain API changes.
*Novelty:* Inverts the dependency. Read models depend on domain services *for data*, but domain services depend on read models *for shape constraints*. Capturing shape constraints early prevents the Phase-6 gap-discovery risk.

**[Sequencing #3]: Sitting as parallel-eligible, not parallel-mandatory**
*Concept:* Recognise that Sitting depends only on Judge (R6), not on the Absence/Vacancy/Booking chain. Allow Sitting extraction to begin in parallel with Phase 2 Absence/Vacancy *if capacity exists*, but don't force it. This preserves the Variant C parallelism benefit without requiring it.
*Novelty:* Treats parallelism as an option rather than a phase boundary. Phase 4 Sitting in the table is the latest legal start; the earliest legal start is Phase 2.

**[Sequencing #4]: Audit folded into Phase 0 as a minimal subscriber, not a write service**
*Concept:* The prior session deferred Audit "until before Phase 3." Under Variant B, Phase 1 begins write extraction, so the deferred timeline collapses. Add a minimal Audit subscriber to Phase 0 — append-only log of write events from Reference Data and (later) Judge — without expanding it into a full Audit service.
*Novelty:* Closes the auditable-gap risk earlier by treating Audit as a Phase-0 cross-cutting capability rather than a separate context. Aligns with "auditable" being already in the Phase-0 cross-cutting NFRs from `functional-modules.md` line 496.

---

## Next steps for the project

1. **Validate the recommendation with stakeholders.** Specifically: confirm whether DA&I early-evidence at Phase 1 is a binding expectation (P1) and whether business-milestone legibility is a funding requirement (P3). If either is binding, switch to Variant C.
2. **Decide on Audit-in-Phase-0.** Risk #3 trigger date moves to Phase 1 under Variant B; deferring Audit further is harder to justify. Add a minimal Audit subscriber decision to the Phase 0 scope question.
3. **Draft Itinerary and MI Feed paper contracts now.** They become inputs to domain API design in Phases 1–5, mitigating the new Risk #7 (Phase 6 gap discovery).
4. **Decide on the optional Phase 1a Judge read-only bridge.** Useful pattern smoke-test, real engineering cost. Worth it if the team is uncertain about the API-as-Product standards or REST-first synchronous pattern; skippable if Reference Data extraction has already battle-tested them.
5. **Take this updated migration table into `/bmad-create-architecture`** alongside the prior session's 12-service catalogue. The architecture document supersedes lines 139–149 of the prior session with the table in this document.

---

## Session metadata

- **Approach:** Targeted convergent / analytical session (divergent work already complete in 2026-05-01 session)
- **Techniques used:** Five Whys, Constraint Mapping, Decision Tree Mapping
- **Variants generated:** 3 (Pure Business-Chain, Hybrid, Existing Risk-Graded)
- **Recommendation:** Variant B — Hybrid (with split-decision condition: switch to Variant C if DA&I early-evidence or business-milestone legibility prove binding)
- **Source documents consulted:** `_bmad-output/brainstorming/brainstorming-session-2026-05-01-1400.md`; `docs/architecture/asis/functional-modules.md`
- **Supersedes:** Lines 139–149 of the prior session (Migration sequence, Phase 4 plan)
