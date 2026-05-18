-- =============================================================================
-- mock_judge_data.sql
-- =============================================================================
--
-- Mock data for the 5 tables owned by ram-judge.
-- Three judges threaded across every table so the rows tell a coherent story.
--
-- NOT production DDL. Production DDL lives in ram-judge's Flyway migrations.
-- This file exists for visualisation, local prototyping, and exploratory
-- queries against a throwaway PostgreSQL instance.
--
-- Depends on mock_ref_data.sql — load that first.
--
-- Run with:
--   psql -d ram_mock -f mock_ref_data.sql
--   psql -d ram_mock -f mock_judge_data.sql
--
-- The three judges:
--   j1 — HHJ Sarah Hawthorne, Circuit Judge, Manchester Crown Court (Northern), full-time
--   j2 — DJ  Emma Patel,      District Judge, Bristol Family Court (Western),   60% PT
--   j3 — HHJ Michael Chen,    Circuit Judge, Bristol Crown Court (Western),     full-time, mixed Crown/County
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- judges (FR10, FR11)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS judges CASCADE;
CREATE TABLE judges (
    id                          uuid        PRIMARY KEY,
    payroll_number              text        NOT NULL UNIQUE,
    first_name                  text        NOT NULL,
    last_name                   text        NOT NULL,
    name_for_itinerary          text        NOT NULL,
    heading                     text        NOT NULL,
    judge_type_id               uuid        NOT NULL REFERENCES judge_types(id),
    base_office_id              uuid        NOT NULL REFERENCES offices(id),
    judge_fee_entitlement_id    uuid        NOT NULL REFERENCES judge_fee_entitlements(id),
    is_active                   boolean     NOT NULL DEFAULT true,
    retirement_date             date,
    email                       text,
    employee_number             text,
    version                     integer     NOT NULL DEFAULT 0,
    created_at                  timestamptz NOT NULL,
    updated_at                  timestamptz NOT NULL
);

INSERT INTO judges (
    id, payroll_number, first_name, last_name, name_for_itinerary, heading,
    judge_type_id, base_office_id, judge_fee_entitlement_id,
    is_active, retirement_date, email, employee_number,
    version, created_at, updated_at
) VALUES
    (
        '30000001-0000-0000-0000-000000000001',
        'P00012345',
        'Sarah', 'Hawthorne', 'HHJ Hawthorne', 'His/Her Honour Judge',
        '20000001-0000-0000-0000-000000000001',  -- Circuit Judge
        '10000002-0000-0000-0000-000000000001',  -- Manchester Crown Court
        '2000000a-0000-0000-0000-000000000002',  -- fee entitlement: No (salaried, not separately fee-paid)
        true, '2032-06-15', 'sarah.hawthorne@judiciary.uk', 'E0012345',
        3, '2026-02-01T09:00:00Z', '2026-04-10T14:22:00Z'
    ),
    (
        '30000001-0000-0000-0000-000000000002',
        'P00023891',
        'Emma', 'Patel', 'DJ Patel', 'District Judge',
        '20000001-0000-0000-0000-000000000002',  -- District Judge
        '10000002-0000-0000-0000-000000000002',  -- Bristol Family Court
        '2000000a-0000-0000-0000-000000000002',  -- fee entitlement: No
        true, '2038-11-02', 'emma.patel@judiciary.uk', 'E0023891',
        1, '2026-02-12T10:15:00Z', '2026-03-22T11:40:00Z'
    ),
    (
        '30000001-0000-0000-0000-000000000003',
        'P00031007',
        'Michael', 'Chen', 'HHJ Chen', 'His/Her Honour Judge',
        '20000001-0000-0000-0000-000000000001',  -- Circuit Judge
        '10000002-0000-0000-0000-000000000003',  -- Bristol Crown Court
        '2000000a-0000-0000-0000-000000000002',  -- fee entitlement: No
        true, '2034-08-30', 'michael.chen@judiciary.uk', 'E0031007',
        0, '2026-02-15T08:50:00Z', '2026-02-15T08:50:00Z'
    );


-- -----------------------------------------------------------------------------
-- working_patterns (FR12)
-- -----------------------------------------------------------------------------
-- One row per active period per judge. When a pattern changes, the existing
-- row's valid_to is set and a new row is inserted with the new valid_from.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS working_patterns CASCADE;
CREATE TABLE working_patterns (
    id                          uuid        PRIMARY KEY,
    judge_id                    uuid        NOT NULL REFERENCES judges(id),
    working_pattern_type_id     uuid        NOT NULL REFERENCES working_pattern_types(id),
    target_sit_percentage       numeric(5,2) NOT NULL,
    valid_from                  date        NOT NULL,
    valid_to                    date,
    version                     integer     NOT NULL DEFAULT 0,
    created_at                  timestamptz NOT NULL,
    updated_at                  timestamptz NOT NULL
);

INSERT INTO working_patterns (
    id, judge_id, working_pattern_type_id, target_sit_percentage,
    valid_from, valid_to,
    version, created_at, updated_at
) VALUES
    (
        '30000002-0000-0000-0000-000000000001',
        '30000001-0000-0000-0000-000000000001',  -- Sarah
        '20000007-0000-0000-0000-000000000003',  -- Weekly
        100.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000002-0000-0000-0000-000000000002',
        '30000001-0000-0000-0000-000000000002',  -- Emma (60% part-time)
        '20000007-0000-0000-0000-000000000003',  -- Weekly
         60.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000002-0000-0000-0000-000000000003',
        '30000001-0000-0000-0000-000000000003',  -- Michael
        '20000007-0000-0000-0000-000000000003',  -- Weekly
        100.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    );


-- -----------------------------------------------------------------------------
-- working_pattern_days (FR12)
-- -----------------------------------------------------------------------------
-- Per-day breakdown for each working pattern. Three rows below cover the start
-- of Sarah's weekly pattern (Mon–Wed). A complete pattern would have 5 rows.
-- Days the judge does not sit have no row.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS working_pattern_days CASCADE;
CREATE TABLE working_pattern_days (
    id                          uuid        PRIMARY KEY,
    working_pattern_id          uuid        NOT NULL REFERENCES working_patterns(id),
    day_of_week                 text        NOT NULL,    -- MONDAY..SUNDAY
    work_type_id                uuid        NOT NULL REFERENCES work_types(id),
    session_type_id             uuid        NOT NULL REFERENCES session_types(id),
    created_at                  timestamptz NOT NULL,
    updated_at                  timestamptz NOT NULL
);

INSERT INTO working_pattern_days (
    id, working_pattern_id, day_of_week, work_type_id, session_type_id,
    created_at, updated_at
) VALUES
    (
        '30000003-0000-0000-0000-000000000001',
        '30000002-0000-0000-0000-000000000001',  -- Sarah's pattern
        'MONDAY',
        '20000002-0000-0000-0000-000000000001',  -- Crime
        '20000005-0000-0000-0000-000000000001',  -- Full Day
        '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000003-0000-0000-0000-000000000002',
        '30000002-0000-0000-0000-000000000001',
        'TUESDAY',
        '20000002-0000-0000-0000-000000000001',  -- Crime
        '20000005-0000-0000-0000-000000000001',  -- Full Day
        '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000003-0000-0000-0000-000000000003',
        '30000002-0000-0000-0000-000000000001',
        'WEDNESDAY',
        '20000002-0000-0000-0000-000000000002',  -- Civil
        '20000005-0000-0000-0000-000000000001',  -- Full Day
        '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    );


-- -----------------------------------------------------------------------------
-- judge_tickets (FR15)
-- -----------------------------------------------------------------------------
-- A judge's authorisations (e.g. SSO, Murder, Family Public Law).
-- end_date is NULL while the ticket is current.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS judge_tickets CASCADE;
CREATE TABLE judge_tickets (
    id                          uuid        PRIMARY KEY,
    judge_id                    uuid        NOT NULL REFERENCES judges(id),
    ticket_type_id              uuid        NOT NULL REFERENCES ticket_types(id),
    start_date                  date        NOT NULL,
    end_date                    date,
    version                     integer     NOT NULL DEFAULT 0,
    created_at                  timestamptz NOT NULL,
    updated_at                  timestamptz NOT NULL
);

INSERT INTO judge_tickets (
    id, judge_id, ticket_type_id, start_date, end_date,
    version, created_at, updated_at
) VALUES
    (
        '30000004-0000-0000-0000-000000000001',
        '30000001-0000-0000-0000-000000000001',  -- Sarah
        '20000004-0000-0000-0000-000000000001',  -- SSO
        '2019-01-15', NULL,
        0, '2026-02-01T09:05:00Z', '2026-02-01T09:05:00Z'
    ),
    (
        '30000004-0000-0000-0000-000000000002',
        '30000001-0000-0000-0000-000000000001',  -- Sarah
        '20000004-0000-0000-0000-000000000002',  -- Murder
        '2022-09-01', NULL,
        0, '2026-02-01T09:05:00Z', '2026-02-01T09:05:00Z'
    ),
    (
        '30000004-0000-0000-0000-000000000003',
        '30000001-0000-0000-0000-000000000002',  -- Emma
        '20000004-0000-0000-0000-000000000003',  -- Family Public Law
        '2021-03-20', NULL,
        0, '2026-02-12T10:20:00Z', '2026-02-12T10:20:00Z'
    );


-- -----------------------------------------------------------------------------
-- jurisdictional_splits (FR16)
-- -----------------------------------------------------------------------------
-- How a judge's time is allocated across jurisdictions. For each judge in a
-- given valid period, percentages must sum to 100 (application-layer rule).
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS jurisdictional_splits CASCADE;
CREATE TABLE jurisdictional_splits (
    id                          uuid        PRIMARY KEY,
    judge_id                    uuid        NOT NULL REFERENCES judges(id),
    court_type_id               uuid        NOT NULL REFERENCES court_types(id),
    percentage                  numeric(5,2) NOT NULL,
    valid_from                  date        NOT NULL,
    valid_to                    date,
    version                     integer     NOT NULL DEFAULT 0,
    created_at                  timestamptz NOT NULL,
    updated_at                  timestamptz NOT NULL
);

INSERT INTO jurisdictional_splits (
    id, judge_id, court_type_id, percentage, valid_from, valid_to,
    version, created_at, updated_at
) VALUES
    (
        '30000005-0000-0000-0000-000000000001',
        '30000001-0000-0000-0000-000000000001',  -- Sarah
        '20000003-0000-0000-0000-000000000001',  -- Crown Court
        100.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000005-0000-0000-0000-000000000002',
        '30000001-0000-0000-0000-000000000003',  -- Michael — 60% Crown
        '20000003-0000-0000-0000-000000000001',  -- Crown Court
         60.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    ),
    (
        '30000005-0000-0000-0000-000000000003',
        '30000001-0000-0000-0000-000000000003',  -- Michael — 40% County
        '20000003-0000-0000-0000-000000000002',  -- County Court
         40.00, '2026-04-01', NULL,
        0, '2026-04-01T08:00:00Z', '2026-04-01T08:00:00Z'
    );

COMMIT;
