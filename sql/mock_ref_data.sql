-- =============================================================================
-- mock_ref_data.sql
-- =============================================================================
--
-- Mock data for the 15 tables owned by ram-reference-data.
--
-- Every row below is either:
--   * an enumerated value documented in the planning artefacts (most rows), or
--   * an illustrative placeholder where the docs reference the vocabulary but do
--     not enumerate values (offices, ticket_types) — clearly flagged in comments.
--
-- Source references (architecture/data-tables.md unless noted):
--   judge_types            line 31 (CJ, DJ, DDJ, Recorder, etc.) + PRD glossary
--                          (DJ, DJ(MC)) + FR39 (Legal Advisers)
--   work_types             line 32 (Crime, Civil, Family, etc.)
--   court_types            line 33 (Court / location-type controlled list)
--                          PRD §Executive Summary (Civil, Family, Crown Courts).
--                          Magistrates' / Tribunals out-of-MVP — see
--                          functional-modules.md "Discovery required".
--   ticket_types           line 34 (controlled list; values not enumerated)
--   session_types          line 35 (full / AM / PM / evening / reserved-matter)
--   absence_types          line 36 (leave, sickness, training, etc.) +
--                          functional-modules.md line 216 adds "official business"
--   working_pattern_types  line 37 (None / Daily / Weekly)
--   booking_statuses       line 38 (planned / provisional / confirmed /
--                          cancelled / rejected) + PRD FR31
--   sitting_outcomes       line 39 (confirmed / cancelled / rejected) + FR37
--   judge_fee_entitlements  line 40 (yes / no / ask-when-booking) + FR33.
--                          Renamed from fee_payment_statuses for clarity —
--                          this is a per-judge attribute answering "is the
--                          judge entitled to a fee for their sittings?"
--   payment_lifecycle_statuses line 41 (pending / requested / paid /
--                          reconciled / queried) + FR41. Renamed from
--                          payment_statuses for clarity — this is the
--                          lifecycle state of an individual payment record.
--   reconciliation_statuses line 42 (matched / queried / unreconciled)
--   regions                PRD NFR38 (Northern, Western — others not in docs)
--   offices                no specific offices enumerated in docs — illustrative
--   calendar_periods       FY 2026/27 derived from functional-modules.md (31st
--                          March horizon) and PRD timeline
--
-- NOT production DDL. Production DDL lives in ram-reference-data's Flyway
-- migrations. This file exists for visualisation, local prototyping, and
-- exploratory queries against a throwaway PostgreSQL instance.
--
-- Load order: this file first, then mock_judge_data.sql.
-- =============================================================================

BEGIN;

-- =============================================================================
-- VOCABULARY TABLES (no inter-FK dependencies)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- judge_types  —  CJ, DJ, DJ(MC), DDJ, Recorder, Legal Adviser
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS judge_types CASCADE;
CREATE TABLE judge_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO judge_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000001-0000-0000-0000-000000000001', 'CIRCUIT',         'Circuit Judge',                          10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000001-0000-0000-0000-000000000002', 'DISTRICT',        'District Judge',                         20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000001-0000-0000-0000-000000000003', 'DISTRICT_MC',     'District Judge (Magistrates'' Courts)',  30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000001-0000-0000-0000-000000000004', 'DEPUTY_DISTRICT', 'Deputy District Judge',                  40, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000001-0000-0000-0000-000000000005', 'RECORDER',        'Recorder',                               50, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000001-0000-0000-0000-000000000006', 'LEGAL_ADVISER',   'Legal Adviser',                          60, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- work_types  —  Crime, Civil, Family
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS work_types CASCADE;
CREATE TABLE work_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO work_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000002-0000-0000-0000-000000000001', 'CRIME',  'Crime',  10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000002-0000-0000-0000-000000000002', 'CIVIL',  'Civil',  20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000002-0000-0000-0000-000000000003', 'FAMILY', 'Family', 30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- court_types  —  Crown, County, Family (Magistrates / Tribunals are
-- "Discovery required" per functional-modules.md line 507 — not in MVP).
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS court_types CASCADE;
CREATE TABLE court_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO court_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000003-0000-0000-0000-000000000001', 'CROWN',  'Crown Court',  10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000003-0000-0000-0000-000000000002', 'COUNTY', 'County Court', 20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000003-0000-0000-0000-000000000003', 'FAMILY', 'Family Court', 30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- ticket_types  —  ILLUSTRATIVE placeholders.
-- The docs reference the vocabulary but do not enumerate specific tickets.
-- Three rows below exist so mock_judge_data.sql has FK targets for judge tickets.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS ticket_types CASCADE;
CREATE TABLE ticket_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO ticket_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000004-0000-0000-0000-000000000001', 'SSO',                  'Serious Sexual Offences',  10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000004-0000-0000-0000-000000000002', 'MURDER',               'Murder',                   20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000004-0000-0000-0000-000000000003', 'FAMILY_PUBLIC_LAW',    'Family Public Law',        30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- session_types  —  Full / AM / PM / Evening / Reserved Matter
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS session_types CASCADE;
CREATE TABLE session_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO session_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000005-0000-0000-0000-000000000001', 'FULL',             'Full Day',         10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000005-0000-0000-0000-000000000002', 'AM',               'AM',               20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000005-0000-0000-0000-000000000003', 'PM',               'PM',               30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000005-0000-0000-0000-000000000004', 'EVENING',          'Evening',          40, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000005-0000-0000-0000-000000000005', 'RESERVED_MATTER',  'Reserved Matter',  50, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- absence_types  —  Leave / Sickness / Training / Official Business
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS absence_types CASCADE;
CREATE TABLE absence_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO absence_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000006-0000-0000-0000-000000000001', 'LEAVE',              'Leave',              10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000006-0000-0000-0000-000000000002', 'SICK',               'Sickness',           20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000006-0000-0000-0000-000000000003', 'TRAINING',           'Training',           30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000006-0000-0000-0000-000000000004', 'OFFICIAL_BUSINESS',  'Official Business',  40, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- working_pattern_types  —  None / Daily / Weekly
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS working_pattern_types CASCADE;
CREATE TABLE working_pattern_types (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO working_pattern_types (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000007-0000-0000-0000-000000000001', 'NONE',   'None',   10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000007-0000-0000-0000-000000000002', 'DAILY',  'Daily',  20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000007-0000-0000-0000-000000000003', 'WEEKLY', 'Weekly', 30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- booking_statuses  —  Planned / Provisional / Confirmed / Cancelled / Rejected
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS booking_statuses CASCADE;
CREATE TABLE booking_statuses (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO booking_statuses (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000008-0000-0000-0000-000000000001', 'PLANNED',     'Planned',     10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000008-0000-0000-0000-000000000002', 'PROVISIONAL', 'Provisional', 20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000008-0000-0000-0000-000000000003', 'CONFIRMED',   'Confirmed',   30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000008-0000-0000-0000-000000000004', 'CANCELLED',   'Cancelled',   40, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000008-0000-0000-0000-000000000005', 'REJECTED',    'Rejected',    50, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- sitting_outcomes  —  Confirmed / Cancelled / Rejected
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS sitting_outcomes CASCADE;
CREATE TABLE sitting_outcomes (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO sitting_outcomes (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('20000009-0000-0000-0000-000000000001', 'CONFIRMED', 'Confirmed', 10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000009-0000-0000-0000-000000000002', 'CANCELLED', 'Cancelled', 20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('20000009-0000-0000-0000-000000000003', 'REJECTED',  'Rejected',  30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- judge_fee_entitlements  —  Yes / No / Ask when booking
-- A per-judge attribute: "is the judge entitled to a fee for their sittings?"
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS judge_fee_entitlements CASCADE;
CREATE TABLE judge_fee_entitlements (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO judge_fee_entitlements (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('2000000a-0000-0000-0000-000000000001', 'YES',              'Yes',              10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000a-0000-0000-0000-000000000002', 'NO',               'No',               20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000a-0000-0000-0000-000000000003', 'ASK_WHEN_BOOKING', 'Ask when booking', 30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- payment_lifecycle_statuses  —  Pending / Requested / Paid / Reconciled / Queried
-- Lifecycle state of an individual payment record as it moves through JFEPS /
-- Liberata and back to RAM Pathfinder for reconciliation.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS payment_lifecycle_statuses CASCADE;
CREATE TABLE payment_lifecycle_statuses (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO payment_lifecycle_statuses (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('2000000b-0000-0000-0000-000000000001', 'PENDING',    'Pending',    10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000b-0000-0000-0000-000000000002', 'REQUESTED',  'Requested',  20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000b-0000-0000-0000-000000000003', 'PAID',       'Paid',       30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000b-0000-0000-0000-000000000004', 'RECONCILED', 'Reconciled', 40, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000b-0000-0000-0000-000000000005', 'QUERIED',    'Queried',    50, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- -----------------------------------------------------------------------------
-- reconciliation_statuses  —  Matched / Queried / Unreconciled
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS reconciliation_statuses CASCADE;
CREATE TABLE reconciliation_statuses (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO reconciliation_statuses (id, code, display_name, sort_order, is_active, created_at, updated_at) VALUES
    ('2000000c-0000-0000-0000-000000000001', 'MATCHED',      'Matched',      10, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000c-0000-0000-0000-000000000002', 'QUERIED',      'Queried',      20, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z'),
    ('2000000c-0000-0000-0000-000000000003', 'UNRECONCILED', 'Unreconciled', 30, true, '2026-01-30T09:00:00Z', '2026-01-30T09:00:00Z');


-- =============================================================================
-- CONTROLLED LISTS (FKs into vocabulary tables)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- regions  —  Northern, Western
-- HMCTS judicial regions explicitly named in PRD NFR38. The full HMCTS regional
-- structure (Midlands, South-Eastern, etc.) is not enumerated in the RAM Pathfinder docs;
-- only these two are explicitly referenced.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS regions CASCADE;
CREATE TABLE regions (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    name            text NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO regions (id, code, name, is_active, created_at, updated_at) VALUES
    ('10000001-0000-0000-0000-000000000001', 'NORTHERN', 'Northern Region', true, '2026-01-15T09:00:00Z', '2026-01-15T09:00:00Z'),
    ('10000001-0000-0000-0000-000000000002', 'WESTERN',  'Western Region',  true, '2026-01-15T09:00:00Z', '2026-01-15T09:00:00Z');


-- -----------------------------------------------------------------------------
-- offices  —  ILLUSTRATIVE placeholders.
-- The RAM Pathfinder docs reference offices generically but do not enumerate specific
-- offices. The rows below exist so mock_judge_data.sql has FK targets for each
-- judge's base office. They pair the two documented regions with the three
-- documented court types.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS offices CASCADE;
CREATE TABLE offices (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    name            text NOT NULL,
    region_id       uuid NOT NULL REFERENCES regions(id),
    court_type_id   uuid NOT NULL REFERENCES court_types(id),
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO offices (id, code, name, region_id, court_type_id, is_active, created_at, updated_at) VALUES
    ('10000002-0000-0000-0000-000000000001', 'MAN-CC', 'Manchester Crown Court', '10000001-0000-0000-0000-000000000001', '20000003-0000-0000-0000-000000000001', true, '2026-01-20T09:00:00Z', '2026-01-20T09:00:00Z'),
    ('10000002-0000-0000-0000-000000000002', 'BRS-FC', 'Bristol Family Court',   '10000001-0000-0000-0000-000000000002', '20000003-0000-0000-0000-000000000003', true, '2026-01-20T09:00:00Z', '2026-01-20T09:00:00Z'),
    ('10000002-0000-0000-0000-000000000003', 'BRS-CC', 'Bristol Crown Court',    '10000001-0000-0000-0000-000000000002', '20000003-0000-0000-0000-000000000001', true, '2026-01-20T09:00:00Z', '2026-01-20T09:00:00Z');


-- -----------------------------------------------------------------------------
-- calendar_periods  —  Financial Year 2026/27 + its 12 monthly periods.
-- The 1 April / 31 March financial-year boundary is documented (PRD FR13
-- "next 31st March"; functional-modules.md). Monthly granularity is required
-- (Court / Judge Itinerary monthly view). Specific FY chosen to match the
-- programme timeline; subsequent FYs would be appended as the project rolls.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS calendar_periods CASCADE;
CREATE TABLE calendar_periods (
    id              uuid PRIMARY KEY,
    code            text NOT NULL UNIQUE,
    name            text NOT NULL,
    period_type     text NOT NULL,          -- FINANCIAL_YEAR, MONTH
    start_date      date NOT NULL,
    end_date        date NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL
);

INSERT INTO calendar_periods (id, code, name, period_type, start_date, end_date, is_active, created_at, updated_at) VALUES
    ('10000003-0000-0000-0000-000000000000', 'FY26-27',     'Financial Year 2026/27', 'FINANCIAL_YEAR', '2026-04-01', '2027-03-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000001', 'FY26-27-M01', 'April 2026',             'MONTH',          '2026-04-01', '2026-04-30', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000002', 'FY26-27-M02', 'May 2026',               'MONTH',          '2026-05-01', '2026-05-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000003', 'FY26-27-M03', 'June 2026',              'MONTH',          '2026-06-01', '2026-06-30', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000004', 'FY26-27-M04', 'July 2026',              'MONTH',          '2026-07-01', '2026-07-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000005', 'FY26-27-M05', 'August 2026',            'MONTH',          '2026-08-01', '2026-08-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000006', 'FY26-27-M06', 'September 2026',         'MONTH',          '2026-09-01', '2026-09-30', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000007', 'FY26-27-M07', 'October 2026',           'MONTH',          '2026-10-01', '2026-10-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000008', 'FY26-27-M08', 'November 2026',          'MONTH',          '2026-11-01', '2026-11-30', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-000000000009', 'FY26-27-M09', 'December 2026',          'MONTH',          '2026-12-01', '2026-12-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-00000000000a', 'FY26-27-M10', 'January 2027',           'MONTH',          '2027-01-01', '2027-01-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-00000000000b', 'FY26-27-M11', 'February 2027',          'MONTH',          '2027-02-01', '2027-02-28', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z'),
    ('10000003-0000-0000-0000-00000000000c', 'FY26-27-M12', 'March 2027',             'MONTH',          '2027-03-01', '2027-03-31', true, '2026-01-25T09:00:00Z', '2026-01-25T09:00:00Z');

COMMIT;
