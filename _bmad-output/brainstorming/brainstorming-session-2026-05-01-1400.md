---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: ['docs/architecture/asis/functional-modules.md']
session_topic: 'High-level API decomposition for Judicial Itineraries (JI) — moving from an Oracle APEX monolith to an API-driven architecture'
session_goals: 'Establish the right set of high-level APIs (service boundaries, candidate endpoints, ownership of data) for a new target system. UI is explicitly out of scope at this stage.'
selected_approach: 'progressive-flow'
techniques_used: ['First Principles Thinking', 'Cross-Pollination', 'Mind Mapping', 'Five Whys', 'Role Playing', 'SCAMPER', 'Constraint Mapping', 'Decision Tree Mapping']
ideas_generated: 30
session_active: false
workflow_completed: true
context_file: 'docs/architecture/asis/functional-modules.md'
---

# Brainstorming Session Results

**Facilitator:** Ramnish
**Date:** 2026-05-01

## Session Overview

**Topic:** High-level API decomposition for Judicial Itineraries (JI) — moving from an Oracle APEX monolith to an API-driven architecture.

**Goals:** Establish the right set of high-level APIs (service boundaries, candidate endpoints, ownership of data) for a new target system. UI is explicitly out of scope at this stage.

### Context Guidance

Source: `docs/architecture/asis/functional-modules.md` — the as-is JI catalogue of 12 functional modules: Home, Manage Judges, Court Itinerary, Judge Itinerary, Absences, Vacancies, Fee-paid and Other Bookings, Payments, Payment Reconciliation, Sittings, Admin, Reports.

Critical end-to-end flow to keep in mind during decomposition:
**Manage Judges → Absences → Vacancies → Fee-paid Bookings → Sittings → Payments → Payment Reconciliation**

Read-only / aggregate surfaces: Court Itinerary, Judge Itinerary, Home dashboard, Reports.
Cross-cutting concerns: AuthN/AuthZ (12 roles), audit logging, accessibility, performance budgets.
External integrations (today indirect / human-mediated): eLinks (judge identity), HR systems (working arrangements), JFEPS / L!BERATA (finance), HMCTS Email, DA&I MI, OPT/APEX runtime.

### Session Setup

Facilitator approach: divergent ideation first (lots of API candidates, multiple decomposition lenses), then convergent organisation later. UI / front-end concerns deferred. No premature commitment to REST vs GraphQL vs events — capability boundaries first, transport later.

### Early scope decisions (Phase 1, in-flight)

- **Itineraries are read models, not independent services.** Court Itinerary and Judge Itinerary (and Judges Forward Look) project state owned elsewhere — Sittings, Bookings, Absences, Vacancies. They become a query / materialised-view layer, not write APIs.
- **Reconciliation folds into Payment Request lifecycle.** Reconciliation status is a state on the payment, not a separate bounded context. The Payment context owns the full lifecycle: eligible → requested → schedule-emailed → paid → reconciled / queried.
- **Incoming integrations are out of scope for this exercise.** eLinks (judge identity), HR systems (working arrangements) feed JI today via manual / out-of-band means; we are not designing APIs to consume them at this stage.
- **Outgoing data must be exposed as APIs for consumers.** Wherever JI is the system of record for data that another system or human currently retrieves out-of-band (payment schedule for the Authoriser, MI for DA&I, sitting / utilisation feeds), the new architecture exposes a first-class API that consumers call.

### Phase 1 prune decisions (locked-in)

- **Identity is delegated to SSO.** JI owns *authorisation* (role + region/area scope + permission mapping), not authentication. User accounts and user-creation workflows live in the IdP / HR systems; JI's `Authorisation` service maps an authenticated user to what they can do in JI.
- **Reference Data is one service** (Organisation taxonomy + Judicial vocabularies + Calendar / financial-year rules), exposed as three resource families under one bounded context.
- **Working Pattern folds into Judge.** A pattern change is a domain event emitted by the Judge context; Sitting reacts to it.
- **Verification folds into Sitting and Booking.** Each owning context exposes a `verify` operation; the Verifier role gates who can invoke it (gated by `Authorisation`).
- **Reconciliation is a state on Payment.** No separate Reconciliation context.
- **Statistics fold into Reporting / MI Feed.** A simple read API exposes data for downstream reporting systems; JI does not own dashboards.
- **Document generation is out of scope.** APIs expose data; clients (UI, finance system, downstream MI) render Excel / PDF themselves.
- **Matching is deferred.** Today JI surfaces fee-paid candidates as a hint inside Vacancy; an active matching service is a post-MVP layer.
- **Conflict Enforcement is a principle, not a service.** Each owning context enforces its own constraints (no cross-context rules engine).
- **Search is solved by the Event Stream + indices**, not a separate Search service.
- **Snapshots / Replay fold into Event Stream + Audit.** Reconstructable state via replay; no separate snapshot store.
- **Bi-temporal history is out of scope** for this exercise.

### Standards every service adheres to (not separate services)

- **API-as-a-Product** — versioned contract, deprecation policy, `/capabilities`, SLA per endpoint, changelog.
- **Anti-fragility / degraded-mode contracts** — codified behaviour when dependencies are unavailable.

### Phase 2 architecture decisions (locked-in)

- **REST-first integration.** All cross-context coordination is synchronous REST (request/response). No domain event stream, no message bus, no webhooks/subscriptions in this design. Spine contexts call each other directly when they need to coordinate; read-model services pull from the spine.
- **No webhook / subscription surface** for now. Outgoing consumers (finance, MI, future tribunals) call JI's read APIs.
- **Audit is out of scope** for this exercise — re-introduce later if regulatory scope demands it.
- **Replay-via-event-stream is dropped as a standard** (no event stream exists).
- **Booking initiates the vacancy fill.** `POST /bookings` accepts an optional `vacancyId`; on creation, Booking calls `Vacancy.markFilled` synchronously. Vacancy is the *demand* record; Booking is the *supply commitment* and orchestrates the linkage.
- **Itinerary uses Strategy A — federate at request time.** Itinerary holds no data of its own; every read fans out to the spine in parallel and composes the answer. Strategy C (polled cache) is the fallback if Forward Look misses the ≤ 30 s NFR.
- **Reporting / MI Feed uses Strategy A — pull-based.** JI exposes the MI APIs; clients (DA&I, leadership tooling) consolidate, transmit, or transform the data themselves. JI does not push, batch, or pre-aggregate.

### Phase 3 refinements (locked-in)

- **Booking initiates fill of vacancies.** `POST /bookings` with optional `vacancyId` calls `Vacancy.markFilled` synchronously.
- **JFEPS Excel is a versioned content-type on Payment.** `GET /payments/{id}/schedule` accepts `application/vnd.hmcts.jfeps+json` (canonical) or `…+xlsx` (format-shifted) — schedule shape evolves independently of Payment internals.
- **Authorisation exposes `/users/{id}/effective-permissions`** in addition to `/authz/check` — UI clients and support tooling need it.
- **Itinerary and MI Feed are scope-gated** at the Authorisation layer — judges see their own; courts see their office; MI is aggregate-only with case-level data forbidden by contract.

---

## Technique execution narrative

Four techniques run in a progressive arc — divergent → analytical → convergent → action.

**Phase 1 — First Principles + Cross-Pollination.** Resisted the trap of "12 modules → 12 APIs." Generated 30 candidates spanning operational nouns, cross-cutting capabilities, reference data, capabilities-as-services, and pattern lenses. Pivoted domains every ~10 ideas (operational → cross-cutting → reference → capabilities → pattern lenses) to maintain divergence.

**Phase 2 — Mind Mapping + Five Whys.** Pruned 30 → 14 → 12 candidates. Folded Working Pattern into Judge, Verification into Sitting/Booking, Reconciliation into Payment, User Creation Request into Authorisation. Dropped Conflict Enforcement (principle, not service) and Search (solved at indexing layer). Five Whys tested the soft boundaries (Authorisation, Itinerary projection vs federation, Audit subscriber vs writer). Locked the architectural style: REST-first, no events, Strategy A read models.

**Phase 3 — Role Playing + SCAMPER.** Modelled seven consumer roles (UI, finance, MI, IdP, ops, ref-data admins, future tribunals) and derived API needs per service. Drafted resources + key operations + outbound dependencies + primary consumers across all 12 services. SCAMPER stress-test produced two refinements (JFEPS as versioned content-type; `/users/{id}/effective-permissions`) and validated all major boundaries.

**Phase 4 — Constraint Mapping + Decision Tree.** Separated real, inherited, and pseudo-constraints. Built a strict dependency DAG and mapped three viable extraction strategies (Foundations-first, Read-model-first, Vertical-slice). Recommended Read-model-first with Reference Data as Phase 0 root and MI Feed as the first user-visible API. Named five risks worth tracking.

---

## Final consolidated outputs

### The 12 services (locked)

| # | Service | Cluster | Owns data | Style |
|---|---|---|---|---|
| 1 | **Judge** | Spine | ✓ (incl. working pattern, tickets, jurisdictional split) | Write |
| 2 | **Absence** | Spine | ✓ | Write |
| 3 | **Vacancy** | Spine | ✓ | Write |
| 4 | **Booking** | Spine | ✓ (incl. verification) | Write — orchestrates vacancy fill |
| 5 | **Sitting** | Spine | ✓ (incl. verification, RFC unlock) | Write |
| 6 | **Payment** | Spine | ✓ (incl. reconciliation lifecycle) | Write — exposes JFEPS-shaped schedule |
| 7 | **Authorisation** | Cross-cutting | ✓ (role + scope mappings; not user accounts) | Gate — every spine call consults it |
| 8 | **Reference Data** | Cross-cutting | ✓ (org tree + vocabularies + calendar) | Read-mostly |
| 9 | **Notification** | Cross-cutting | ✓ (delivery log) | Side-effect |
| 10 | **Configuration** | Cross-cutting | ✓ (typed policy values) | Policy |
| 11 | **Itinerary** | Read model | ✗ (federated over spine) | Strategy A — fan-out at request |
| 12 | **Reporting / MI Feed** | Read model | ✗ (federated over spine) | Strategy A — pull-based |

### Architecture standards (apply to every service)

- **API-as-a-Product** — versioned contract, deprecation policy, `/capabilities`, SLA per endpoint, changelog
- **Anti-fragility / degraded-mode contracts** — codified behaviour when dependencies are unavailable

### Out-of-scope decisions (deferred or denied)

- Domain Event Stream (REST-first)
- Webhook / Subscription surface
- Audit (deferred — known gap to revisit before first write extraction)
- Document generation (clients render their own outputs)
- Active matching / allocation (deferred post-MVP)
- Bi-temporal history (deferred)
- Snapshots / replay store
- Search service (indices layered atop spine APIs)
- Conflict-rules engine (constraints stay inside owning services)
- Incoming integrations (eLinks, HR systems) — separate workstream

---

## Migration sequence (Phase 4 plan)

| Phase | Services | Outcome |
|---|---|---|
| **0 — Foundations** | Reference Data, Authorisation (with SSO), Configuration, Notification | Cross-cutting capabilities live; APEX increasingly defers to them |
| **1 — First user-visible API** | **MI Feed** (federated read over Oracle, strangler-style) | DA&I gets a real API; aggregate-only contract validated |
| **2 — Itinerary read API** | **Itinerary** (Strategy A; Strategy C cache as fallback if NFR misses) | Read-side primitives ready for any future UI client |
| **3 — First spine extraction** | **Judge** (smallest blast radius, tests pattern-regenerate REST coordination) | Write-side decomposition begins |
| **4 — Operational chain** | **Absence → Vacancy → Booking**, with **Sitting** in parallel | Most operationally critical chain extracted |
| **5 — Payment** | **Payment** (incl. Reconciliation) | Highest-stakes context, last because it benefits from prior validation |
| **6 — Decommission APEX** | — | Spine writes flow through new APIs; APEX retires |

### First API to extract: **Reference Data**
### First user-visible API: **MI Feed** (after Foundations)

---

## Session insights — surprises and inflection points

- **The 12 modules in the source doc are not 12 services.** The single most consequential reframe was treating Itineraries as read models, not write surfaces; folding sub-contexts (Working Pattern, Verification, Reconciliation, User Creation Request) into their parent contexts; and dropping speculative services (Conflict, Search, Document Generation, Matching).
- **Outgoing-data-as-API was the design forcing function.** Once you said "we expose APIs and let consumers decide what to do with the data," the read models locked into pull-based, federated, aggregate-only shapes. This single principle eliminated a lot of speculative push/event/webhook complexity.
- **REST-first removed an entire class of services.** Domain Event Stream, Webhook/Subscription, Replay store, and parts of the Audit story all collapsed once the integration style was decided. The system is meaningfully simpler — at the cost of synchronous coupling between spine writes and read-model freshness, which we accepted as a tradeoff.
- **Identity vs Authorisation is a clean separation worth naming.** SSO owns who-you-are; JI owns what-you-can-do-here. This eliminates user accounts, password lifecycles, and user-creation workflows from JI's responsibility surface — a substantial scope reduction.
- **Reference Data is the unsung hero.** Almost every other service depends on it. Extracting it first is the right call partly because it's safe, partly because it forces the API-as-a-Product standards to be defined before any business-critical surface adopts them.

---

## Captured ideas — IDEA FORMAT TEMPLATE

Selected high-leverage concepts that emerged during ideation:

**[Architecture #1]: REST-first synchronous spine**
*Concept:* Spine contexts coordinate via direct REST calls (Absence calls Vacancy on approve; Booking calls Payment on confirm). No event bus, no message queue, no webhook fabric.
*Novelty:* Inverts the usual microservices reflex toward eventual-consistency. Trades simplicity-of-coupling for simplicity-of-reasoning. Forces side-effect dependencies to be explicit and version-able.

**[Architecture #2]: Strategy-A federated read models**
*Concept:* Itinerary and MI Feed hold no data of their own. Every read fans out to the spine in parallel and assembles the answer. Cache (Strategy C) is a planned fallback, not a default.
*Novelty:* Rejects CQRS-by-default. Lower build cost, higher live-freshness, at the cost of stacked latency. Accepts the 30-s NFR risk with a documented escape hatch.

**[Architecture #3]: Booking-orchestrated vacancy fill**
*Concept:* `POST /bookings` with `vacancyId` is the single operation that creates the booking and marks the vacancy filled. Vacancy is demand-side; Booking is supply-side and orchestrates the linkage.
*Novelty:* Makes the booking the canonical write surface even when a vacancy exists. Bookings without vacancies (standalone) and vacancies without bookings (open / closed-NTBF) remain valid — the orchestration is the rare-case glue, not the dominant path.

**[Architecture #4]: SSO-delegated AuthN, JI-owned AuthZ**
*Concept:* Authorisation maps an authenticated principal (provided by SSO) to roles + region/area scope + permissions. No user account ownership, no passwords, no provisioning workflows in JI.
*Novelty:* Reduces JI's identity surface from the source-doc's "12 user roles + sessions + password lifecycle" to a thin policy layer. Provisioning becomes someone else's problem.

**[Architecture #5]: JFEPS-shape as a versioned content-type**
*Concept:* `GET /payments/{id}/schedule` accepts `application/vnd.hmcts.jfeps+json` or `+xlsx`. The JFEPS shape is a contract independent of Payment's internal model; future format updates touch only the renderer.
*Novelty:* Treats a downstream system's preferred shape as an API product surface in its own right. Decouples Payment evolution from L!BERATA evolution.

**[Architecture #6]: Reference Data as one service, three resource families**
*Concept:* Org taxonomy + judicial vocabularies + calendar collapse into a single Reference Data API. Same operational shape (read-mostly, audited writes, every consumer caches).
*Novelty:* Resists the urge to fragment reference data along source-doc lines. Easier to operate, easier to govern.

**[Process #1]: Strangler-fig with read-model-first sequencing**
*Concept:* Extract Reference Data as a foundation; then ship MI Feed (read-only over Oracle) as the first user-visible API; then layer in Itinerary and the spine in dependency order.
*Novelty:* Defers the riskiest decision (APEX/API write coexistence) until after the architecture has been proven on read paths. Gives an external consumer (DA&I) early evidence the migration is real.

---

## Risks to track post-session

| # | Risk | Trigger / mitigation |
|---|---|---|
| 1 | SSO migration timing slips | Treat as a separate parallel workstream that *must* land before Phase 1 |
| 2 | APEX/API write coexistence races (from Phase 3) | APEX writes routed through Judge API or strict per-record feature-flag locks |
| 3 | "Auditable" gap (Audit out of scope) | Revisit Audit before Phase 3; do not let the gap accumulate further |
| 4 | Forward Look ≤ 30 s NFR breach under Strategy A | Strategy C cache layer pre-designed in Phase 2; switch on if needed |
| 5 | Reference Data drift between APEX and the new API during transition | Reference Data API is the single writer from day-1; APEX reads from it |

---

## Next steps for the project

1. **Take this session into `/bmad-create-architecture`** to formalise the 12-service architecture as a decision document with implementation guidance for AI agents.
2. **Begin Phase 0 scoping** — Reference Data and Authorisation/SSO are the immediate workstreams. Identify owners, dependencies, and SSO target (HMCTS IdP).
3. **Open the Audit question explicitly** — decide whether the regulatory obligation can wait until Phase 3, or whether a minimal Audit subscriber needs to be planned in Phase 0.
4. **Validate the migration sequence with stakeholders** — particularly DA&I (consumers of MI Feed) and OPT support (operators of the existing system).
5. **Draft the API-as-a-Product standards** as a formal artefact — versioning policy, deprecation policy, SLA template, `/capabilities` shape — before any service implements them.

---

## Session metadata

- **Approach:** Progressive Technique Flow
- **Techniques used:** First Principles, Cross-Pollination, Mind Mapping, Five Whys, Role Playing, SCAMPER, Constraint Mapping, Decision Tree Mapping
- **Raw candidates generated:** 30
- **Final services after pruning:** 12
- **Total architectural decisions captured:** 30+ (across the in-flight decision blocks above)
- **Source documents consulted:** `docs/architecture/asis/functional-modules.md`

