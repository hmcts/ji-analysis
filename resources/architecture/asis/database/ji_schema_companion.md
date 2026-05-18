# JI as-is database — diagram companion reference

This document accompanies the PNG schema diagrams in this folder. It contains:

- Trigger reference (every trigger, its table, timing, event, and body)
- External-reference inventory (columns pointing to tables NOT in this PDF)
- FK inference confidence notes

## Trigger reference

All 24 triggers extracted from the source DDL. Triggers are predominantly mechanical: `BI_*` (before-insert) assign the PK from a sequence; `BU_*` (before-update) maintain `LAST_MODIFIED_BY` / `LAST_MODIFIED_DATE` audit columns.

| Table | Trigger | Timing | Event | Purpose (summary) |
|---|---|---|---|---|
| `TBL_JI_ABS_OB` | `BI_TBL_JI_ABS_OB` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_ABS_OB_DETAIL` | `BI_TBL_JI_ABS_OB_DETAIL` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_ABS_OB_VAC_OPTS` | `BI_TBL_JI_ABS_OB_VAC_OPTS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_CHANGES` | `BI_TBL_JI_CHANGES` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_FP_BOOKINGS` | `BI_TBL_JI_FP_BOOKINGS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_FP_BOOKING_DETAIL` | `BU_TBL_JI_FP_BOOKING_DETAIL` | Before | update | — |
| `TBL_JI_FP_BOOKING_DETAIL` | `BI_TBL_JI_FP_BOOKING_DETAIL` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_PLANNED_SITTINGS` | `BU_TBL_JI_PLANNED_SITTINGS` | Before | update | — |
| `TBL_JI_PLANNED_SITTINGS` | `BI_TBL_JI_PLANNED_SITTINGS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_VACANCIES` | `BI_TBL_JI_VACANCIES` | Before | insert | Auto-assign PK from sequence |
| `TBL_JI_VACANCIES` | `BU_TBL_JI_VACANCIES` | Before | update | — |
| `TBL_JI_VACANCY_GROUPS` | `BI_TBL_JI_VACANCY_GROUPS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES` | `BI_TBL_JUDGES` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES` | `BU_TBL_JUDGES` | Before | update | Maintain LAST_MODIFIED_BY/DATE audit |
| `TBL_JUDGES_JURIS_SPLIT` | `BI_TBL_JUDGES_JURIS_SPLIT` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES_MASTER` | `BU_TBL_JUDGES_MASTER` | Before | update | Maintain LAST_MODIFIED_BY/DATE audit |
| `TBL_JUDGES_MASTER` | `BI_TBL_JUDGES_MASTER` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES_TICKETS` | `BI_TBL_JUDGES_TICKETS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES_USER_LINKS` | `BU_TBL_JUDGES_USER_LINKS` | Before | update | Maintain LAST_MODIFIED_BY/DATE audit |
| `TBL_JUDGES_USER_LINKS` | `BI_TBL_JUDGES_USER_LINKS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES_WORK_PATTERNS` | `BI_TBL_JUDGES_WORK_PATTERNS` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGES_WP_DETAIL` | `BI_TBL_JUDGES_WP_DETAIL` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGE_COURTS_LINK` | `BI_TBL_JUDGE_COURTS_LINK` | Before | insert | Auto-assign PK from sequence |
| `TBL_JUDGE_COURTS_LINK` | `BU_TBL_JUDGE_COURTS_LINK` | Before | update | Maintain LAST_MODIFIED_BY/DATE audit |

### Trigger bodies (full)

#### `TBL_JI_ABS_OB`

**`BI_TBL_JI_ABS_OB`** — before insert

```sql
for each row
begin
  if :NEW."JI_ABS_OB_ID" is null then
     select "TBL_JI_ABS_OB_SEQ".nextval into :NEW."JI_ABS_OB_ID" from dual;
  end if;
end;
```

#### `TBL_JI_ABS_OB_DETAIL`

**`BI_TBL_JI_ABS_OB_DETAIL`** — before insert

```sql
for each row
begin
  if :NEW."JI_ABS_OB_DETAIL_ID" is null then
     select "TBL_JI_ABS_OB_DETAIL_SEQ".nextval into
:NEW."JI_ABS_OB_DETAIL_ID" from dual;
  end if;
end;
```

#### `TBL_JI_ABS_OB_VAC_OPTS`

**`BI_TBL_JI_ABS_OB_VAC_OPTS`** — before insert

```sql
for each row
begin
  if :NEW."JI_ABS_OB_VAC_OPTS_ID" is null then
     select "TBL_JI_ABS_OB_VAC_OPTS_SEQ".nextval into
:NEW."JI_ABS_OB_VAC_OPTS_ID" from dual;
  end if;
end;
```

#### `TBL_JI_CHANGES`

**`BI_TBL_JI_CHANGES`** — before insert

```sql
for each row
begin
  if :NEW."JI_CHANGE_ID" is null then
     select "TBL_JI_CHANGES_SEQ".nextval into :NEW."JI_CHANGE_ID" from dual;
  end if;
end;
```

#### `TBL_JI_FP_BOOKINGS`

**`BI_TBL_JI_FP_BOOKINGS`** — before insert

```sql
for each row
begin
  if :NEW."JI_FP_BOOKING_ID" is null then
     select "TBL_JI_FP_BOOKINGS_SEQ".nextval into :NEW."JI_FP_BOOKING_ID"
from dual;
  end if;
end;
/
ALTER TRIGGER "BI_TBL_JI_FP_BOOKINGS" ENABLE;


  GRANT SELECT ON "TBL_JI_FP_BOOKINGS" TO "OPTLIVE_RO";
  CREATE TABLE "TBL_JI_FP_CANCELLERS"
   ( "JI_FP_CANCELLER_ID" NUMBER(2,0) NOT NULL ENABLE,
       "JI_FP_CANCELLER_NAME" VARCHAR2(100) NOT NULL ENABLE,
       "IN_USE" CHAR(1) NOT NULL ENABLE,
        CONSTRAINT "TBL_JI_FP_CANCELLERS_PK" PRIMARY KEY
("JI_FP_CANCELLER_ID")
  USING INDEX ENABLE
   ) ;


  GRANT SELECT ON "TBL_JI_FP_CANCELLERS" TO "OPTLIVE_RO";
  CREATE TABLE "TBL_JI_LOC_JT_AWD_LINKS"
   ( "LOC_TYPE_ID" NUMBER(6,0) NOT NULL ENABLE,
       "JUDGE_TYPE_ID" NUMBER(2,0) NOT NULL ENABLE,
       "JI_ACTUAL_WORK_TYPE_ID" NUMBER(3,0) NOT NULL ENABLE,
       "ROLE_SPECIFIC" CHAR(1) DEFAULT 'N' NOT NULL ENABLE,
        CONSTRAINT "TBL_JI_LOC_JT_AWD_LINKS_PK" PRIMARY KEY ("LOC_TYPE_ID",
"JUDGE_TYPE_ID", "JI_ACTUAL_WORK_TYPE_ID")
  USING INDEX ENABLE
   ) ;


  GRANT SELECT ON "TBL_JI_LOC_JT_AWD_LINKS" TO "OPTLIVE_RO";
  CREATE TABLE "TBL_JI_LOC_JT_PWD_LINKS"
   ( "LOC_TYPE_ID" NUMBER(6,0) NOT NULL ENABLE,
       "JUDGE_TYPE_ID" NUMBER(2,0) NOT NULL ENABLE,
       "JI_PLANNED_WORK_TYPE_ID" NUMBER(3,0) NOT NULL ENABLE,
       "ROLE_SPECIFIC" CHAR(1) DEFAULT 'N' NOT NULL ENABLE,
        CONSTRAINT "TBL_JI_LOC_JT_PWD_LINKS_PK" PRIMARY KEY ("LOC_TYPE_ID",
"JUDGE_TYPE_ID", "JI_PLANNED_WORK_TYPE_ID")
  USING INDEX ENABLE
   ) ;


  GRANT SELECT ON "TBL_JI_LOC_JT_PWD_LINKS" TO "OPTLIVE_RO";
  CREATE TABLE "TBL_JI_LOC_JT_SD_LINKS"
   ( "LOC_TYPE_ID" NUMBER(6,0) NOT NULL ENABLE,
       "JUDGE_TYPE_ID" NUMBER(2,0) NOT NULL ENABLE,
       "JI_SITTING_DUR_ID" NUMBER(2,0) NOT NULL ENABLE,
        CONSTRAINT "TBL_JI_LOC_JT_SD_LINKS_PK" PRIMARY KEY ("LOC_TYPE_ID",
"JUDGE_TYPE_ID", "JI_SITTING_DUR_ID")
  USING INDEX ENABLE
   ) ;


  GRANT SELECT ON "TBL_JI_LOC_JT_SD_LINKS" TO "OPTLIVE_RO";
  CREATE TABLE "TBL_JI_PLANNED_SITTINGS"
   ( "JI_PLANNED_SITTING_ID" NUMBER NOT NULL ENABLE,
       "JI_PLANNED_WORK_TYPE_ID" NUMBER(3,0) NOT NULL ENABLE,
       "LOC_TYPE_ID" NUMBER(2,0) NOT NULL ENABLE,
       "LOC_ID" NUMBER(6,0) NOT NULL ENABLE,
       "CUT_COURTROOM_ID" NUMBER,
       "JUDGE_CODE" NUMBER(6,0) NOT NULL ENABLE,
       "SITTING_DATE" DATE NOT NULL ENABLE,
       "SITTING_DUR_ID" NUMBER(2,0) NOT NULL ENABLE,
       "COMMENTS" VARCHAR2(4000),
       "CREATED_BY" VARCHAR2(255) NOT NULL ENABLE,
       "CREATED_DATE" DATE NOT NULL ENABLE,
       "LAST_MODIFIED_BY" VARCHAR2(255),
       "LAST_MODIFIED_DATE" DATE,
       "CANCELLED" CHAR(1) NOT NULL ENABLE,
       "ACKNOWLEDGED_BY" VARCHAR2(255),
       "ACKNOWLEDGED_DATE" DATE,
       "CANCELLED_BY" VARCHAR2(255),
       "CANCELLED_DATE" DATE,
       "CANCELLED_OTHER_REASON" VARCHAR2(4000),
       "JI_CHANGE_FROM_ID" NUMBER,
       "JI_CHANGE_TO_ID" NUMBER,
       "CUT_OWNER_ID" NUMBER,
       "YEARMONTH" NUMBER(6,0) NOT NULL ENABLE,
       "JI_ACTUAL_WORK_TYPE_ID" NUMBER(3,0),
       "CONFIRMED_BY" VARCHAR2(255),
       "CONFIRMED_DATE" DATE,
       "SEND_AMEND_EMAIL" CHAR(1) DEFAULT 'N' NOT NULL ENABLE,
       "AMEND_ACKN_SENT" DATE,
       "SITTING_TYPE_ID" NUMBER(2,0) DEFAULT 1 NOT NULL ENABLE,
       "VERIFIED_BY" VARCHAR2(255),
       "VERIFIED_DATE" DATE,
       "VERIFIED_FLAG" NUMBER(1,0) DEFAULT 0 NOT NULL ENABLE,
       "HEARING_LOC_TYPE_ID" NUMBER(2,0),
       "HEARING_LOC_ID" NUMBER(6,0),
       "EXTRA_ITIN_TEXT" VARCHAR2(4000),
       "LEGAL_ADV_WITH_MAGS" CHAR(1),
       "LEGAL_ADV_SIT_TYPE" NUMBER(1,0),
        CONSTRAINT "TBL_JI_PLANNED_SITTINGS_PK" PRIMARY KEY
("JI_PLANNED_SITTING_ID")
  USING INDEX ENABLE
   ) ;

  CREATE INDEX "TBL_JI_PLANNED_SITTINGS_IDX1" ON "TBL_JI_PLANNED_SITTINGS"
("SITTING_DATE", "YEARMONTH", "LOC_ID", "LOC_TYPE_ID", "CUT_OWNER_ID",
"JI_PLANNED_WORK_TYPE_ID", "SITTING_DUR_ID")
  ;

  CREATE INDEX "TBL_JI_PLANNED_SITTINGS_IDX2" ON "TBL_JI_PLANNED_SITTINGS"
("JUDGE_CODE", "LOC_ID", "LOC_TYPE_ID")
  ;

  CREATE INDEX "TBL_JI_PLANNED_SITTINGS_IDX3" ON "TBL_JI_PLANNED_SITTINGS"
("YEARMONTH", "LOC_ID", "JUDGE_CODE")
  ;

  CREATE OR REPLACE EDITIONABLE TRIGGER "BU_TBL_JI_PLANNED_SITTINGS"
  before UPDATE on "TBL_JI_PLANNED_SITTINGS"
  for each row
begin
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.sitting_date, 'YYYYMM'));
  IF :NEW.verified_by IS NOT NULL AND :NEW.verified_date IS NOT NULL THEN
     :NEW.verified_flag := 1;
  ELSE
     :NEW.verified_flag := 0;
  END IF;
end;
```

#### `TBL_JI_FP_BOOKING_DETAIL`

**`BU_TBL_JI_FP_BOOKING_DETAIL`** — before update

```sql
for each row
begin
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.fp_booking_date, 'YYYYMM'));
  IF :NEW.verified_by IS NOT NULL AND :NEW.verified_date IS NOT NULL THEN
     :NEW.verified_flag := 1;
  ELSE
     :NEW.verified_flag := 0;
  END IF;
end;
```

**`BI_TBL_JI_FP_BOOKING_DETAIL`** — before insert

```sql
for each row
begin
  if :NEW."JI_FP_BOOKING_DETAIL_ID" is null then
     select "TBL_JI_FP_BOOKING_DETAIL_SEQ".nextval into
:NEW."JI_FP_BOOKING_DETAIL_ID" from dual;
  end if;
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.fp_booking_date, 'YYYYMM'));
  IF :NEW.verified_by IS NOT NULL AND :NEW.verified_date IS NOT NULL THEN
     :NEW.verified_flag := 1;
  ELSE
     :NEW.verified_flag := 0;
  END IF;
end;
```

#### `TBL_JI_PLANNED_SITTINGS`

**`BU_TBL_JI_PLANNED_SITTINGS`** — before update

```sql
for each row
begin
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.sitting_date, 'YYYYMM'));
  IF :NEW.verified_by IS NOT NULL AND :NEW.verified_date IS NOT NULL THEN
     :NEW.verified_flag := 1;
  ELSE
     :NEW.verified_flag := 0;
  END IF;
end;
```

**`BI_TBL_JI_PLANNED_SITTINGS`** — before insert

```sql
for each row
begin
  if :NEW."JI_PLANNED_SITTING_ID" is null then
     select "TBL_JI_PLANNED_SITTINGS_SEQ".nextval into
:NEW."JI_PLANNED_SITTING_ID" from dual;
  end if;
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.sitting_date, 'YYYYMM'));
  IF :NEW.verified_by IS NOT NULL AND :NEW.verified_date IS NOT NULL THEN
     :NEW.verified_flag := 1;
  ELSE
     :NEW.verified_flag := 0;
  END IF;
end;
```

#### `TBL_JI_VACANCIES`

**`BI_TBL_JI_VACANCIES`** — before insert

```sql
for each row
begin
  if :NEW."JI_VACANCY_ID" is null then
     select "TBL_JI_VACANCIES_SEQ".nextval into :NEW."JI_VACANCY_ID" from
dual;
  end if;
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.vacancy_date, 'YYYYMM'));
end;
```

**`BU_TBL_JI_VACANCIES`** — before update

```sql
for each row
begin
  :NEW.yearmonth := TO_NUMBER(TO_CHAR(:NEW.vacancy_date, 'YYYYMM'));
end;
```

#### `TBL_JI_VACANCY_GROUPS`

**`BI_TBL_JI_VACANCY_GROUPS`** — before insert

```sql
for each row
begin
  if :NEW."JI_VACANCY_GROUP_ID" is null then
     select "TBL_JI_VACANCY_GROUPS_SEQ".nextval into
:NEW."JI_VACANCY_GROUP_ID" from dual;
  end if;
end;
```

#### `TBL_JUDGES`

**`BI_TBL_JUDGES`** — before insert

```sql
for each row
begin
  :NEW.last_modified_by := NVL(wwv_flow.g_user,USER);
  :NEW.last_modified_date := TRUNC(SYSDATE);
  :NEW.search := SUBSTR(TO_CHAR(:NEW.judge_code,
pkg_const.JUDGE_CODE_CHAR_FORMAT)
    || LOWER(:NEW.itin_name)
    || LOWER(:NEW.payroll_no)
    || LOWER(:NEW.itin_sort_name)
    || LOWER(:NEW.role_title_prefix)
    || LOWER(:NEW.role_title_suffix)
    || LOWER(:NEW.judge_name), 1, 4000);
end;
```

**`BU_TBL_JUDGES`** — before update

```sql
for each row
begin
  :NEW.last_modified_by := NVL(wwv_flow.g_user,USER);
  :NEW.last_modified_date := TRUNC(SYSDATE);
  :NEW.search := SUBSTR(TO_CHAR(:NEW.judge_code,
pkg_const.JUDGE_CODE_CHAR_FORMAT)
     || LOWER(:NEW.itin_name)
     || LOWER(:NEW.payroll_no)
     || LOWER(:NEW.itin_sort_name)
     || LOWER(:NEW.role_title_prefix)
     || LOWER(:NEW.role_title_suffix)
     || LOWER(:NEW.judge_name), 1, 4000);
end;
```

#### `TBL_JUDGES_JURIS_SPLIT`

**`BI_TBL_JUDGES_JURIS_SPLIT`** — before insert

```sql
for each row
begin
  if :NEW."JUDGES_JURIS_SPLIT_ID" is null then
     select "TBL_JUDGES_JURIS_SPLIT_SEQ".nextval into
:NEW."JUDGES_JURIS_SPLIT_ID" from dual;
  end if;
end;
```

#### `TBL_JUDGES_MASTER`

**`BU_TBL_JUDGES_MASTER`** — before update

```sql
for each row
begin
  IF :NEW.last_modified_by IS NULL THEN
    :NEW.last_modified_by := NVL(wwv_flow.g_user,USER);
  END IF;
  IF :NEW.last_modified_date IS NULL THEN
    :NEW.last_modified_date := TRUNC(SYSDATE);
  END IF;
  :NEW.master_judge_name := TRIM(:NEW.title_prefix || ' ' || :NEW.surname
|| ' ' || :NEW.initials || ' ' || :NEW.title_suffix);
  :NEW.search := SUBSTR(TO_CHAR(:NEW.current_main_judge_code,
pkg_const.JUDGE_CODE_CHAR_FORMAT)
    || LOWER(:NEW.title_prefix)
    || LOWER(:NEW.forename)
    || LOWER(:NEW.surname)
    || LOWER(:NEW.title_suffix)
    || LOWER(:NEW.email)
    || LOWER(:NEW.phone1)
    || LOWER(:NEW.other_contact_name)
       || LOWER(:NEW.other_contact_email)
       || LOWER(:NEW.other_contact_phone1)
       || LOWER(:NEW.comments)
       , 1, 4000);
end;
```

**`BI_TBL_JUDGES_MASTER`** — before insert

```sql
for each row
begin
  IF :NEW.created_by IS NULL THEN
     :NEW.created_by := NVL(wwv_flow.g_user,USER);
  END IF;
  IF :NEW.created_date IS NULL THEN
     :NEW.created_date := TRUNC(SYSDATE);
  END IF;
  IF :NEW.master_judge_name IS NULL THEN
     :NEW.master_judge_name := TRIM(:NEW.title_prefix || ' ' || :NEW.surname
|| ' ' || :NEW.initials || ' ' || :NEW.title_suffix);
  END IF;
  :NEW.search := SUBSTR(TO_CHAR(:NEW.current_main_judge_code,
pkg_const.JUDGE_CODE_CHAR_FORMAT)
     || LOWER(:NEW.title_prefix)
     || LOWER(:NEW.forename)
     || LOWER(:NEW.surname)
     || LOWER(:NEW.title_suffix)
     || LOWER(:NEW.email)
     || LOWER(:NEW.phone1)
     || LOWER(:NEW.other_contact_name)
     || LOWER(:NEW.other_contact_email)
     || LOWER(:NEW.other_contact_phone1)
     || LOWER(:NEW.comments)
     , 1, 4000);
end;
```

#### `TBL_JUDGES_TICKETS`

**`BI_TBL_JUDGES_TICKETS`** — before insert

```sql
for each row
begin
  if :NEW."JUDGES_TICKET_ID" is null then
     select "TBL_JUDGES_TICKETS_SEQ".nextval into :NEW."JUDGES_TICKET_ID"
from dual;
  end if;
end;
```

#### `TBL_JUDGES_USER_LINKS`

**`BU_TBL_JUDGES_USER_LINKS`** — before update

```sql
for each row
begin
  :new.last_modified_BY := nvl(wwv_flow.g_user,user);
  :new.last_modified_DATE := trunc(sysdate);
end;
```

**`BI_TBL_JUDGES_USER_LINKS`** — before insert

```sql
for each row
begin
  select "TBL_JUDGES_USER_LINKS_SEQ".nextval into
:NEW."JUDGES_USER_LINKS_ID" from dual;
  :new.CREATED_BY := nvl(wwv_flow.g_user,user);
  :new.CREATED_DATE := trunc(sysdate);
end;
```

#### `TBL_JUDGES_WORK_PATTERNS`

**`BI_TBL_JUDGES_WORK_PATTERNS`** — before insert

```sql
for each row
begin
  if :NEW."JUDGES_WORK_PATTERN_ID" is null then
     select "TBL_JUDGES_WORK_PATTERNS_SEQ".nextval into
:NEW."JUDGES_WORK_PATTERN_ID" from dual;
  end if;
end;
```

#### `TBL_JUDGES_WP_DETAIL`

**`BI_TBL_JUDGES_WP_DETAIL`** — before insert

```sql
for each row
begin
  if :NEW."JUDGES_WP_DETAIL_ID" is null then
     select "TBL_JUDGES_WP_DETAIL_SEQ".nextval into
:NEW."JUDGES_WP_DETAIL_ID" from dual;
  end if;
end;
```

#### `TBL_JUDGE_COURTS_LINK`

**`BI_TBL_JUDGE_COURTS_LINK`** — before insert

```sql
for each row
begin
  select "TBL_JUDGE_COURTS_LINK_SEQ".nextval into
:NEW."JUDGE_COURTS_LINK_ID" from dual;
  :new.CREATED_BY := nvl(wwv_flow.g_user,user);
  :new.CREATED_DATE := trunc(sysdate);
end;
```

**`BU_TBL_JUDGE_COURTS_LINK`** — before update

```sql
for each row
begin
  :new.last_modified_BY := nvl(wwv_flow.g_user,user);
  :new.last_modified_DATE := trunc(sysdate);
end;
```

## External-reference inventory

These columns reference tables that are **NOT present in the source PDF**. Likely live in a separate reference-data dump (locations, regions, courtrooms, OPT user accounts, status lookups). Confirm with the data-dictionary owner before treating them as authoritative.

| Column | Inferred target | Tables using it |
|---|---|---|
| `ABS_OB_LENGTH_TYPE_ID` | External: Absence Length Type lookup (not in this PDF) | `TBL_JI_ABS_OB` |
| `BASE_LOC_ID` | External: LOCATIONS (not in this PDF) | `TBL_JUDGES`, `TBL_JUDGES_MONTHLY_STATS`, `TBL_JUDGES_WORK_PATTERNS` |
| `BASE_LOC_TYPE_ID` | External: LOCATION TYPES (not in this PDF) | `TBL_JUDGES`, `TBL_JUDGES_MONTHLY_STATS`, `TBL_JUDGES_WORK_PATTERNS` |
| `COURT_ID` | External: COURTS (not in this PDF) | `TBL_JUDGE_COURTS_LINK` |
| `CUT_COURTROOM_ID` | External: COURTROOMS / CUT_* (not in this PDF) | `TBL_JI_PLANNED_SITTINGS` |
| `CUT_OWNER_ID` | External: COURTROOMS / CUT_* (not in this PDF) | `TBL_JI_ABS_OB_DETAIL`, `TBL_JI_ABS_OB_VAC_OPTS`, `TBL_JI_FP_BOOKINGS`, `TBL_JI_FP_BOOKING_DETAIL`, `TBL_JI_PLANNED_SITTINGS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS`, `TBL_JUDGES_WP_DETAIL` |
| `FILL_ACTION_ID` | External: Fill Action lookup (not in this PDF) | `TBL_JI_ABS_OB` |
| `FP_STATUS_ID` | External: FP Status lookup (not in this PDF) | `TBL_JUDGES` |
| `HEARING_LOC_ID` | External: LOCATIONS (not in this PDF) | `TBL_JI_FP_BOOKINGS`, `TBL_JI_FP_BOOKING_DETAIL`, `TBL_JI_PLANNED_SITTINGS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS` |
| `HEARING_LOC_TYPE_ID` | External: LOCATION TYPES (not in this PDF) | `TBL_JI_FP_BOOKINGS`, `TBL_JI_FP_BOOKING_DETAIL`, `TBL_JI_PLANNED_SITTINGS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS` |
| `HMCS_LEGAL_TIER_CODE` | External: HMCS Legal Tier codes (not in this PDF) | `TBL_JUDGES` |
| `LOC_ID` | External: LOCATIONS / OFFICES (not in this PDF) | `TBL_JI_ABS_OB_DETAIL`, `TBL_JI_ABS_OB_VAC_OPTS`, `TBL_JI_FP_BOOKINGS`, `TBL_JI_FP_BOOKING_DETAIL`, `TBL_JI_PLANNED_SITTINGS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS`, `TBL_JUDGES_WP_DETAIL` |
| `LOC_TYPE_ID` | External: LOCATION TYPES (not in this PDF) | `TBL_JI_ABS_OB_DETAIL`, `TBL_JI_ABS_OB_VAC_OPTS`, `TBL_JI_FP_BOOKINGS`, `TBL_JI_FP_BOOKING_DETAIL`, `TBL_JI_LOC_JT_AWD_LINKS`, `TBL_JI_LOC_JT_PWD_LINKS`, `TBL_JI_LOC_JT_SD_LINKS`, `TBL_JI_PLANNED_SITTINGS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS`, `TBL_JUDGES_WP_DETAIL` |
| `LONDON_WT_STATUS_ID` | External: London Weighting Status lookup (not in this PDF) | `TBL_JUDGES` |
| `REGION_ID` | External: REGIONS (not in this PDF) | `TBL_JI_AREAS`, `TBL_JI_RESTR_ITIN_USERS`, `TBL_JUDGES`, `TBL_JUDGE_COURTS_LINK` |
| `SITTING_TYPE_ID` | External: Sitting Type lookup (not in this PDF) | `TBL_JI_PLANNED_SITTINGS` |
| `VACANCY_STATUS_ID` | External: Vacancy Status lookup (not in this PDF) | `TBL_JI_ABS_OB_VAC_OPTS`, `TBL_JI_VACANCIES`, `TBL_JI_VACANCY_GROUPS` |

## FK inference notes

The source DDL contains **zero explicit `FOREIGN KEY` constraints**. Every relationship in the diagrams is inferred from column-naming conventions. Confidence buckets:

- **HIGH (solid line, blue)** — column name exactly matches another table's primary-key column. Example: `JI_ABS_OB_ID` in `TBL_JI_VACANCIES` matches `TBL_JI_ABS_OB.JI_ABS_OB_ID`.
- **MEDIUM (dashed line, grey)** — column is a *prefixed* version of another table's PK column (≥ 5-char suffix). Example: `START_SITTING_DUR_ID` and `END_SITTING_DUR_ID` both end with `SITTING_DUR_ID`, the PK of `TBL_JI_SITTING_DURS`.
- **EXTERNAL (dotted line, light grey)** — column references a table outside this PDF.

Columns ending in `_ID` or `_CODE` that match neither rule are flagged in the diagram body but no edge is drawn. They may be valid FK references to tables not yet identified.

### Counts

- HIGH confidence FKs: **68**
- MEDIUM confidence FKs: **11**
- EXTERNAL references: **58**

### All inferred FKs

| Source table | Source column | → | Target table | Target column | Confidence |
|---|---|---|---|---|---|
| `TBL_JI_ABS_OB` | `ABS_OB_LENGTH_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB` | `FILL_ACTION_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB` | `JI_ABS_OB_TYPE_ID` | → | `TBL_JI_ABS_OB_TYPES` | `JI_ABS_OB_TYPE_ID` | high |
| `TBL_JI_ABS_OB` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_ABS_OB` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JI_ABS_OB` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_ABS_OB` | `VAC_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
| `TBL_JI_ABS_OB_DETAIL` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_DETAIL` | `JI_ABS_OB_ID` | → | `TBL_JI_ABS_OB` | `JI_ABS_OB_ID` | high |
| `TBL_JI_ABS_OB_DETAIL` | `JI_ACTUAL_WORK_TYPE_ID` | → | `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | high |
| `TBL_JI_ABS_OB_DETAIL` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_ABS_OB_DETAIL` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_DETAIL` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_VAC_OPTS` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_VAC_OPTS` | `JI_ABS_OB_DETAIL_ID` | → | `TBL_JI_ABS_OB_DETAIL` | `JI_ABS_OB_DETAIL_ID` | high |
| `TBL_JI_ABS_OB_VAC_OPTS` | `JI_ABS_OB_ID` | → | `TBL_JI_ABS_OB` | `JI_ABS_OB_ID` | high |
| `TBL_JI_ABS_OB_VAC_OPTS` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_ABS_OB_VAC_OPTS` | `JI_VACANCY_GROUP_ID` | → | `TBL_JI_VACANCY_GROUPS` | `JI_VACANCY_GROUP_ID` | high |
| `TBL_JI_ABS_OB_VAC_OPTS` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_ABS_OB_VAC_OPTS` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_VAC_OPTS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_VAC_OPTS` | `VACANCY_STATUS_ID` | → | _(external)_ | — | external |
| `TBL_JI_ABS_OB_VAC_OPTS` | `VAC_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
| `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_CAT_ID` | → | `TBL_JI_ACTUAL_WORK_CATS` | `JI_ACTUAL_WORK_CAT_ID` | high |
| `TBL_JI_ACTUAL_WORK_TYPES` | `JI_PLANNED_WORK_CAT_ID` | → | `TBL_JI_PLANNED_WORK_CATS` | `JI_PLANNED_WORK_CAT_ID` | high |
| `TBL_JI_AREAS` | `REGION_ID` | → | _(external)_ | — | external |
| `TBL_JI_CHANGES` | `JI_CHANGE_TYPE_ID` | → | `TBL_JI_CHANGE_TYPES` | `JI_CHANGE_TYPE_ID` | high |
| `TBL_JI_EXTRA_NWDS` | `JUDGE_CIRCUIT_CODE` | → | `TBL_JUDGE_CIRCUITS` | `JUDGE_CIRCUIT_CODE` | high |
| `TBL_JI_EXTRA_NWDS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKINGS` | `HEARING_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKINGS` | `HEARING_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKINGS` | `JI_ABS_OB_ID` | → | `TBL_JI_ABS_OB` | `JI_ABS_OB_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `JI_FP_BOOKING_TYPE_ID` | → | `TBL_JI_FP_BOOKING_TYPES` | `JI_FP_BOOKING_TYPE_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `JI_FP_CANCELLER_ID` | → | `TBL_JI_FP_CANCELLERS` | `JI_FP_CANCELLER_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JI_FP_BOOKINGS` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_FP_BOOKINGS` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKINGS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKING_DETAIL` | `ABS_OB_JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | medium |
| `TBL_JI_FP_BOOKING_DETAIL` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKING_DETAIL` | `HEARING_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKING_DETAIL` | `HEARING_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKING_DETAIL` | `JI_ACTUAL_WORK_TYPE_ID` | → | `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `JI_FP_BOOKING_ID` | → | `TBL_JI_FP_BOOKINGS` | `JI_FP_BOOKING_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `JI_FP_CANCELLER_ID` | → | `TBL_JI_FP_CANCELLERS` | `JI_FP_CANCELLER_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `JI_VACANCY_ID` | → | `TBL_JI_VACANCIES` | `JI_VACANCY_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_FP_BOOKING_DETAIL` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_FP_BOOKING_DETAIL` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_LOC_JT_AWD_LINKS` | `JI_ACTUAL_WORK_TYPE_ID` | → | `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | high |
| `TBL_JI_LOC_JT_AWD_LINKS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JI_LOC_JT_AWD_LINKS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_LOC_JT_PWD_LINKS` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_LOC_JT_PWD_LINKS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JI_LOC_JT_PWD_LINKS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_LOC_JT_SD_LINKS` | `JI_SITTING_DUR_ID` | → | `TBL_JI_SITTING_DURS` | `JI_SITTING_DUR_ID` | high |
| `TBL_JI_LOC_JT_SD_LINKS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JI_LOC_JT_SD_LINKS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `CUT_COURTROOM_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `HEARING_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `HEARING_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `JI_ACTUAL_WORK_TYPE_ID` | → | `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | high |
| `TBL_JI_PLANNED_SITTINGS` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_PLANNED_SITTINGS` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JI_PLANNED_SITTINGS` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_SITTINGS` | `SITTING_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_PLANNED_WORK_TYPES` | `JI_ACTUAL_WORK_CAT_ID` | → | `TBL_JI_ACTUAL_WORK_CATS` | `JI_ACTUAL_WORK_CAT_ID` | high |
| `TBL_JI_PLANNED_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | → | `TBL_JI_ACTUAL_WORK_TYPES` | `JI_ACTUAL_WORK_TYPE_ID` | high |
| `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_CAT_ID` | → | `TBL_JI_PLANNED_WORK_CATS` | `JI_PLANNED_WORK_CAT_ID` | high |
| `TBL_JI_RESTR_ITIN_USERS` | `REGION_ID` | → | _(external)_ | — | external |
| `TBL_JI_UA_JT_LINKS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JI_VACANCIES` | `ABS_OB_JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | medium |
| `TBL_JI_VACANCIES` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCIES` | `HEARING_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCIES` | `HEARING_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCIES` | `JI_ABS_OB_DETAIL_ID` | → | `TBL_JI_ABS_OB_DETAIL` | `JI_ABS_OB_DETAIL_ID` | high |
| `TBL_JI_VACANCIES` | `JI_ABS_OB_ID` | → | `TBL_JI_ABS_OB` | `JI_ABS_OB_ID` | high |
| `TBL_JI_VACANCIES` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_VACANCIES` | `JI_VACANCY_GROUP_ID` | → | `TBL_JI_VACANCY_GROUPS` | `JI_VACANCY_GROUP_ID` | high |
| `TBL_JI_VACANCIES` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_VACANCIES` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCIES` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCIES` | `VACANCY_STATUS_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `ABS_OB_JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | medium |
| `TBL_JI_VACANCY_GROUPS` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `HEARING_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `HEARING_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `JI_ABS_OB_ID` | → | `TBL_JI_ABS_OB` | `JI_ABS_OB_ID` | high |
| `TBL_JI_VACANCY_GROUPS` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JI_VACANCY_GROUPS` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JI_VACANCY_GROUPS` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `VACANCY_STATUS_ID` | → | _(external)_ | — | external |
| `TBL_JI_VACANCY_GROUPS` | `VAC_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
| `TBL_JUDGES` | `BASE_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES` | `BASE_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES` | `FP_STATUS_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES` | `HMCS_LEGAL_TIER_CODE` | → | _(external)_ | — | external |
| `TBL_JUDGES` | `JUDGES_MASTER_ID` | → | `TBL_JUDGES_MASTER` | `JUDGES_MASTER_ID` | high |
| `TBL_JUDGES` | `JUDGE_CIRCUIT_CODE` | → | `TBL_JUDGE_CIRCUITS` | `JUDGE_CIRCUIT_CODE` | high |
| `TBL_JUDGES` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JUDGES` | `LONDON_WT_STATUS_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES` | `REGION_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_ANNUAL_LEAVE` | `JUDGES_MASTER_ID` | → | `TBL_JUDGES_MASTER` | `JUDGES_MASTER_ID` | high |
| `TBL_JUDGES_BOOKING_STATS` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JUDGES_JURIS_SPLIT` | `JUDGES_WORK_PATTERN_ID` | → | `TBL_JUDGES_WORK_PATTERNS` | `JUDGES_WORK_PATTERN_ID` | high |
| `TBL_JUDGES_JURIS_SPLIT` | `JUDGE_JURIS_ID` | → | `TBL_JUDGE_JURIS` | `JUDGE_JURIS_ID` | high |
| `TBL_JUDGES_MASTER` | `CURRENT_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
| `TBL_JUDGES_MASTER` | `CURRENT_MAIN_JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | medium |
| `TBL_JUDGES_MONTHLY_STATS` | `BASE_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_MONTHLY_STATS` | `BASE_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_MONTHLY_STATS` | `CURRENT_MAIN_JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | medium |
| `TBL_JUDGES_MONTHLY_STATS` | `JUDGES_MASTER_ID` | → | `TBL_JUDGES_MASTER` | `JUDGES_MASTER_ID` | high |
| `TBL_JUDGES_MONTHLY_STATS` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JUDGES_TICKETS` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JUDGES_TICKETS` | `JUDGE_TICKET_TYPE_ID` | → | `TBL_JUDGE_TICKET_TYPES` | `JUDGE_TICKET_TYPE_ID` | high |
| `TBL_JUDGES_USER_LINKS` | `JUDGES_MASTER_ID` | → | `TBL_JUDGES_MASTER` | `JUDGES_MASTER_ID` | high |
| `TBL_JUDGES_WORK_PATTERNS` | `BASE_LOC_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_WORK_PATTERNS` | `BASE_LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_WORK_PATTERNS` | `JUDGES_MASTER_ID` | → | `TBL_JUDGES_MASTER` | `JUDGES_MASTER_ID` | high |
| `TBL_JUDGES_WORK_PATTERNS` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JUDGES_WP_DETAIL` | `CUT_OWNER_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_WP_DETAIL` | `JI_PLANNED_WORK_TYPE_ID` | → | `TBL_JI_PLANNED_WORK_TYPES` | `JI_PLANNED_WORK_TYPE_ID` | high |
| `TBL_JUDGES_WP_DETAIL` | `JUDGES_WORK_PATTERN_ID` | → | `TBL_JUDGES_WORK_PATTERNS` | `JUDGES_WORK_PATTERN_ID` | high |
| `TBL_JUDGES_WP_DETAIL` | `LOC_ID` | → | _(external)_ | — | external |
| `TBL_JUDGES_WP_DETAIL` | `LOC_TYPE_ID` | → | _(external)_ | — | external |
| `TBL_JUDGE_COURTS_LINK` | `COURT_ID` | → | _(external)_ | — | external |
| `TBL_JUDGE_COURTS_LINK` | `JUDGE_CODE` | → | `TBL_JUDGES` | `JUDGE_CODE` | high |
| `TBL_JUDGE_COURTS_LINK` | `REGION_ID` | → | _(external)_ | — | external |
| `TBL_JUDGE_FEE_RATES` | `JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | high |
| `TBL_JUDGE_TYPE_PROMOTION` | `CURRENT_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
| `TBL_JUDGE_TYPE_PROMOTION` | `PROMOTED_JUDGE_TYPE_ID` | → | `TBL_JUDGE_TYPES` | `JUDGE_TYPE_ID` | medium |
