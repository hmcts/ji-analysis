---
parent: ../architecture.md
title: Functional Requirements Coverage (FR1–FR61)
last_updated: 2026-05-07
---

# Functional Requirements Coverage (FR1–FR61)

> Sibling of [`../architecture.md`](../architecture.md). The parent links here from its *Architecture Validation Results / Requirements Coverage Validation* section.

The 61 Functional Requirements are organised into 9 capability areas. Each subsection below lists the FRs in that area (verbatim from PRD) and the architectural support that satisfies them.

**All 61 FRs have explicit architectural support.** None unaddressed.

## Identity & Authorisation (FR1–FR5)

- **FR1** — Authenticated users access NJI via HMCTS IdP single sign-on; password, session, and account lifecycle are owned by the IdP and not duplicated in NJI.
- **FR2** — NJI's Authorisation service maps each authenticated principal to one or more roles and a Region/Area scope, and authorises every system call against that mapping.
- **FR3** — Authorised users can retrieve their effective permissions for their authenticated session.
- **FR4** — System administrators can update role and Region/Area assignments for migrated and new users.
- **FR5** *(reframed v2.5 as post-MVP)* — External machine-to-machine consumers require an authentication mechanism. At MVP, no machine-to-machine consumers are in scope. The mechanism for genuine service-principal authentication is a post-MVP open question (see [`./gaps.md` G7](./gaps.md)).

**Architectural support:** Authorisation service + per-service custom `JWTFilter` (HMCTS template pattern) + OIDC for human users (mock auth Phase 0–8; HMCTS IdP from pre-Phase-9) + JWT propagation interceptor (Pattern 1) + OAuth `client_credentials` for the payment-batch service principal (Pattern 2). FR5 (full programmatic service-account directory) remains post-MVP.

## Foundational Data Management (FR6–FR9)

- **FR6** — RSU users can view and maintain Reference Data lists — Regions, Offices, judicial vocabularies, calendar/financial-year boundaries — with named-owner sign-off on changes.
- **FR7** — Every NJI service can read Reference Data via a versioned API; Reference Data is the single writer (no duplicates anywhere).
- **FR8** *(revised v2.2)* — Cross-service runtime policy values are stored in a shared `configuration_values` infrastructure table, schema-managed by `nji-architecture`'s Flyway baseline migration and SELECT-granted to every NJI service DB role. Updates via Flyway migrations or admin SQL — no API service. Per-service config that's scoped to one service uses Spring profiles + `application.yml` + Azure Key Vault.
- **FR9** — NJI dispatches transactional emails (booking acks, absence acks, payment schedules) via HMCTS email infrastructure, with a delivery log retained.

**Architectural support:** Reference Data + Notification services; direct SQL access to the 15 Reference Data tables (no caching at MVP per Principle 2); shared `configuration_values` table for cross-service policy values.

## Judge Records & Working Patterns (FR10–FR18)

- **FR10** — RSU users can search and filter judges by name, base location, location type, and judge type.
- **FR11** — RSU users can maintain judge profiles, including personal details, judge type, base office, active/inactive status, and role-specific data (payroll number, retirement date, fee-payment status, London weighting, name-for-itinerary, heading).
- **FR12** — Authorised users can define and update Working Patterns (None / Daily / Weekly) with target sit %, jurisdictional split, and per-day work-type pattern.
- **FR13** — NJI auto-populates judge itineraries up to the next 31st March from the working pattern, preserving any prior absences.
- **FR14** — RSU users can convert salaried judges between full-time and part-time, adjusting mandatory sitting days.
- **FR15** — RSU users can maintain ticket information per judge role, requiring start date and ticket type.
- **FR16** — NJI validates that jurisdictional split percentages total 100% before saving.
- **FR17** — RSU users can switch a judge's base location to another office within the same Region; cross-Region changes require OPT Advice Point and are out-of-system.
- **FR18** — Authorised users can link to judges managed by other offices (off-circuit / cross-Region) for booking purposes.

**Architectural support:** `nji-judge` repo (Phase 1); working-pattern engine owned by Judge.

## Absence Workflow (FR19–FR22)

- **FR19** — Authorised users can record absence requests with start/end date, partial-day option (full / AM / PM), type from a controlled list, and an NTBF flag.
- **FR20** — NJI distinguishes auto-confirmed absences (from judicial teams) from those requiring confirmation (from Courts or judges); confirmation can trigger an acknowledgement email.
- **FR21** — Sickness absences can be extended without creating a new record; non-sickness extensions require a new absence record.
- **FR22** — Authorised users can mark absences as *Not To Be Filled* (NTBF) or as *needs fee-paid cover*.

**Architectural support:** `nji-absence` repo (Phase 2); approval workflow with auto-vacancy creation per R4.

## Vacancy & Cover (FR23–FR28)

- **FR23** — NJI auto-creates a vacancy when an approved absence requires fee-paid cover, pre-populated with judge type, work type, ticket, and dates.
- **FR24** — Authorised users can create standalone vacancies independent of any absence.
- **FR25** — Authorised users can edit a vacancy's daily breakdown — cancel individual days with a captured reason; extend or shorten the period.
- **FR26** — NJI marks a vacancy as filled when a booking is created against it; vacancy days cannot be cancelled once a booking is recorded.
- **FR27** — NJI surfaces fee-paid judges matching a vacancy's filter as a hint for advertising; advertising itself is performed out-of-system by judicial teams.
- **FR28** — Authorised users can cancel or close vacancies (e.g. when a parent absence becomes NTBF).

**Architectural support:** `nji-vacancy` repo (Phase 3); Booking marks `vacancies.filled = true` (and `filled_at`) via direct in-transaction DB UPDATE per Principle 1 (no `markFilled` API endpoint at MVP — Booking has UPDATE grant on those columns).

## Booking Management (FR29–FR34)

- **FR29** — Authorised users can create fee-paid bookings (linked to a vacancy or standalone), capturing judge, court, date, session type (full / AM / PM / evening / reserved-matter), booking type, and work type.
- **FR30** — Booking creation marks the linked vacancy as filled within the same transaction when a `vacancyId` is supplied. *(In-process direct DB UPDATE on the `vacancies` row using a per-service DB role grant; see Principle 1.)*
- **FR31** — NJI tracks booking status (planned, provisional, confirmed, cancelled, rejected) with reason capture for cancellation.
- **FR32** — NJI sends booking acknowledgement emails to fee-paid judges, batched overnight or sent immediately via *Create and Email Now*.
- **FR33** — NJI requires a Y/N fee-payment answer at booking time when a judge's fee-payment status is *Ask when booking*.
- **FR34** — NJI prevents double-booking of fee-paid judges for overlapping sessions.

**Architectural support:** `nji-booking` repo (Phase 4); natural-key unique constraint (`uq_bookings_*`) + JPA `@Version` + pessimistic row lock (`SELECT … FOR UPDATE`) on the target vacancy provide retry safety natively (no custom idempotency table).

## Sitting Management (FR35–FR40)

- **FR35** — NJI generates planned sittings for salaried judges from their working patterns, court, date, and work type.
- **FR36** — Authorised users can filter sitting records by Region/Office, judge type, judge, and date range.
- **FR37** — Authorised users can confirm that a sitting actually took place, updating outcome (confirmed, cancelled, rejected) and actual work type.
- **FR38** — Authorised users can split a sitting into AM/PM with different work types within a single day.
- **FR39** — Authorised users can create ad-hoc sittings for salaried judges, including DJ(MC)s and Legal Advisers in County Courts.
- **FR40** — Verifiers can verify confirmed sittings; once verified, the data is read-only and amendments require an RFC.

**Architectural support:** `nji-sitting` repo (Phase 5); generated from Judge working patterns; verification gates downstream edits.

## Payment & Reconciliation (FR41–FR47)

- **FR41** *(revised v2.6)* — Authorised users can list confirmed bookings and salaried sittings, filterable by Region/Office, judge, date range, and payment status (pending, requested, paid, reconciled). The **payment-eligible** subset is the read-only union of confirmed bookings + sittings whose payment record does not yet exist; this is the input the scheduled batch consumes.
- **FR42** *(revised v2.6)* — NJI's **payment-processing batch** (`nji-payment-batch`, scheduled on a configurable cron) automatically marks eligible bookings as *payment requested* and creates the corresponding `payments` + `payment_schedules` records. **No user click is required.** Authorised users can also list and review the generated schedule before/after dispatch.
- **FR43** *(revised v2.6)* — The **payment batch** generates JFEPS-compatible payment schedules and dispatches them as Excel attachments to a configured Payment Authoriser via email (using its service-principal identity to call the Notification API); the Payment Authoriser forwards to Liberata out-of-system. Schedule generation and dispatch are batch-driven, not user-initiated.
- **FR44** — NJI exposes the payment schedule via API with content-type negotiation (`application/vnd.hmcts.jfeps+json` or `+xlsx`); the JFEPS shape evolves independently of Payment internals.
- **FR45** — NJI prevents double submission of the same booking for payment. The batch's natural-key unique constraint on `(payment_cycle_id, booking_id)` rejects duplicate creates; re-runs of the same cycle are idempotent.
- **FR46** — Authorised users (Finance, RSU) can flag payments as reconciled, capturing notes for mismatches; once fully reconciled, a payment cannot be re-requested for the same booking.
- **FR47** — NJI does not store or expose bank details for any judge — those remain in the finance system.

**Architectural support:** `nji-payment` repo (Phase 6) — scheduled batch (`nji-payment-batch`) authenticates as a service principal, picks up confirmed-but-unpaid bookings/sittings, generates the JFEPS-shaped Excel, dispatches via Notification → HMCTS Email; reconciliation marked manually by RSU at MVP. See [`./sequence-diagrams/payment-batch-flow.md`](./sequence-diagrams/payment-batch-flow.md).

## Itineraries & Reporting (FR48–FR54)

- **FR48** — Authorised users can render the Court Itinerary (monthly or annual) for a given Office, Financial Year, and Month, showing sittings, bookings, vacancies, and NTBF absences for each day.
- **FR49** — Authorised users can render the Judge Itinerary for one or more judges over a date range, scoped by Authorisation (judges see only their own; courts see their office; RSU sees their region).
- **FR50** — Authorised users can use the Forward Look view across a Region with paged or filtered access for performance.
- **FR51** — Itinerary cells are clickable and drill into the underlying record (Sitting, Absence, Vacancy, or Booking).
- **FR52** — Authorised users can copy/export Itinerary and Report contents to Excel and PDF.
- **FR53** — NJI provides a fixed catalogue of standard Reports (weekly sitting projections, weekly vacancies, absence analysis, vacancy by court, confirmed sittings/bookings by judge or judge type, judge utilisation, jurisdictional split, summary by court / work type) with parameter filters per report.
- **FR54** — NJI exposes aggregated MI Feed APIs for external consumers (DA&I, future programmes); MI Feed responses contain no case-level data and are aggregate-only by contract.

**Architectural support:** `nji-itinerary` and `nji-mi-feed` repos (Phases 7–8); SQL-based read models via JOINs over the shared schema in the global database — no parallel API fan-out, no Strategy A latency stacking.

## Platform Operations & Migration (FR55–FR61)

- **FR55** — Authenticated users land on a Home page showing role-scoped navigation, Region/Area selector, summary tiles for the selected scope (judges, absences, vacancies, pending payments, payments made, unreconciled), and contextual help.
- **FR56** — NJI's UI replicates the functional surface of the as-is APEX UI on a modern UI stack and meets WCAG 2.2 Level AA accessibility standards.
- **FR57** — A Phase 0 Data Migration ETL takes Reference Data and active user records (with role and Region/Area mappings) from APEX, transforms them into NJI's own (independently-designed) shape, and loads them via the NJI Reference Data API and Authorisation API. Migrated user records are keyed to HMCTS IdP principals (email primary, employee number fallback). Phase 0 deliverable; unmatched records flagged for explicit handling. The ETL is *not* a Flyway DB-seeding migration — it lives in `nji-architecture/migration/` and runs against running NJI services.
- **FR58** — NJI supports per-region phased activation — a region's user accounts can be activated for NJI use only when that region's feature-parity gate is passed; activation is a flag flip, not a data migration.
- **FR59** — Every NJI service exposes a versioned API contract, a `/capabilities` endpoint, RFC 7807 problem-details for errors, and a published OpenAPI specification.
- **FR60** — Every NJI service emits structured logs with correlation IDs and consistent error categorisation, retained for pilot incident triage.
- **FR61** *(revised 2026-05-06)* — Every NJI domain service has a **manual UAT script** that captures the workflows and edge cases an APEX-experienced user is expected to verify against the existing APEX application before that service's region rollout. The UAT is performed by users from the in-region applicable roles (RSU, Court, Judge, Judges' Clerks, Finance/Payment Authoriser, MI) and recorded with explicit per-role sign-off. There is no automated APEX-comparison test harness; APEX-comparison parity is a manual UAT activity, not a CI gate.

**Architectural support:** Per-service implementations bootstrapped from the HMCTS Crime SpringBoot template scaffolding; Phase 0 Data Migration ETL at `nji-architecture/migration/`; per-service `docs/uat/` for manual UAT scripts.
