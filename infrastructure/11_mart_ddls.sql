-- =============================================================================
-- Hospital360 Demo: Use-Case Mart DDLs (Week 3 — UCs 1-4)
-- =============================================================================
-- Run as: SYSADMIN
-- Prerequisite: 06_dimensions.sql, 07_facts.sql, 08/09 seed scripts executed
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_XFM_WH;

-- =============================================================================
-- UC1: MART_PATIENT_LEAKAGE — Referral leakage analysis
-- Grain: 1 row per referral
-- Schema: HOSPITAL360_CUR.CLINICAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE (
    REFERRAL_ID           STRING(20)    NOT NULL,
    MRN                   STRING(20)    NOT NULL,
    PATIENT_NAME          STRING(100),
    PATIENT_ZIP           STRING(10),
    PATIENT_PAYER_TYPE    STRING(30),
    REFERRING_PROVIDER_SK INTEGER       NOT NULL,
    REFERRING_PROVIDER    STRING(100),
    REFERRING_SPECIALTY   STRING(50),
    REFERRED_TO_NPI       STRING(10)    NOT NULL,
    REFERRED_TO_SPECIALTY STRING(50),
    FACILITY_ID           STRING(20),
    FACILITY_NAME         STRING(100),
    REFERRAL_DATE         DATE          NOT NULL,
    REFERRAL_MONTH        DATE,          -- truncated to month
    REFERRAL_QUARTER      STRING(7),     -- e.g. '2024-Q3'
    STATUS                STRING(20)    NOT NULL,
    LEAKAGE_FLAG          BOOLEAN       DEFAULT FALSE,
    EXPECTED_REVENUE      FLOAT,
    LOST_REVENUE          FLOAT,         -- EXPECTED_REVENUE when leaked, else 0
    DAYS_SINCE_REFERRAL   INTEGER,
    IS_HIGH_VALUE         BOOLEAN,       -- expected_revenue > 5000
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (REFERRAL_ID)
)
COMMENT = 'UC1 Patient Leakage mart: referral-level detail with revenue impact';

-- =============================================================================
-- UC2: MART_READMISSION_LOS — Readmission risk & LOS analysis
-- Grain: 1 row per inpatient/observation encounter
-- Schema: HOSPITAL360_CUR.CLINICAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS (
    ENCOUNTER_ID          STRING(20)    NOT NULL,
    MRN                   STRING(20)    NOT NULL,
    PATIENT_NAME          STRING(100),
    PATIENT_AGE           INTEGER,
    PATIENT_GENDER        STRING(10),
    HCC_SCORE             FLOAT,
    ADMIT_DATE            DATE          NOT NULL,
    ADMIT_MONTH           DATE,
    DISCHARGE_DATE        DATE,
    DISCHARGE_DISPOSITION STRING(50),
    ENCOUNTER_TYPE        STRING(20)    NOT NULL,
    LOS_DAYS              FLOAT,
    EXPECTED_LOS          FLOAT,         -- from DRG GEOMETRIC_LOS
    LOS_VARIANCE          FLOAT,         -- actual - expected
    LOS_INDEX             FLOAT,         -- actual / expected
    IS_LONG_STAY          BOOLEAN,       -- LOS_INDEX > 1.5
    DRG_CODE              STRING(5),
    DRG_DESCRIPTION       STRING(255),
    DRG_WEIGHT            FLOAT,
    MDC_DESCRIPTION       STRING(100),
    READMIT_30_FLAG       BOOLEAN       DEFAULT FALSE,
    PAYER_TYPE            STRING(30),
    PAYER_NAME            STRING(100),
    FACILITY_ID           STRING(20),
    FACILITY_NAME         STRING(100),
    DEPT_ID               STRING(20),
    DEPT_NAME             STRING(100),
    ATTENDING_PROVIDER    STRING(100),
    SPECIALTY             STRING(50),
    TOTAL_CHARGES         FLOAT,
    TOTAL_COST            FLOAT,
    TOTAL_PAYMENTS        FLOAT,
    COST_PER_DAY          FLOAT,         -- total_cost / LOS_DAYS
    NET_REVENUE           FLOAT,
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ENCOUNTER_ID)
)
COMMENT = 'UC2 Readmission & LOS mart: encounter-level with DRG benchmarks and risk indicators';

-- =============================================================================
-- UC3: MART_OR_CAPACITY — OR block utilization & efficiency
-- Grain: 1 row per OR case
-- Schema: HOSPITAL360_CUR.OPERATIONS
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY (
    CASE_ID               STRING(20)    NOT NULL,
    ENCOUNTER_ID          STRING(20),
    OR_ROOM_ID            STRING(10)    NOT NULL,
    FACILITY_ID           STRING(20)    NOT NULL,
    FACILITY_NAME         STRING(100),
    SURGEON_SK            INTEGER       NOT NULL,
    SURGEON_NAME          STRING(100),
    SPECIALTY             STRING(50),
    BLOCK_NAME            STRING(50),
    CASE_DATE             DATE          NOT NULL,
    CASE_MONTH            DATE,
    CASE_DAY_OF_WEEK      STRING(10),
    SCHEDULED_START       TIMESTAMP     NOT NULL,
    ACTUAL_START          TIMESTAMP,
    ACTUAL_END            TIMESTAMP,
    DELAY_MINUTES         FLOAT,         -- actual_start - scheduled_start
    CASE_MINUTES          FLOAT,
    TURNOVER_MINUTES      FLOAT,
    BLOCK_MINUTES         FLOAT,
    UTILIZATION_PCT       FLOAT,         -- case_minutes / block_minutes
    FIRST_CASE_ON_TIME    BOOLEAN,
    PRIME_TIME_FLAG       BOOLEAN,
    CASE_CLASS            STRING(20),    -- ELECTIVE, URGENT, EMERGENT, ADD_ON
    ASA_CLASS             STRING(5),
    CPT_CODE              STRING(10),
    CPT_DESCRIPTION       STRING(255),
    IS_UNDERUTILIZED      BOOLEAN,       -- utilization_pct < 0.60
    IS_OVERTIME           BOOLEAN,       -- actual_end after 17:00
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CASE_ID)
)
COMMENT = 'UC3 OR Capacity mart: case-level with utilization metrics and block analysis';

-- =============================================================================
-- UC4: MART_DENIALS_REVCYCLE — Denial management & revenue cycle
-- Grain: 1 row per denied claim line
-- Schema: HOSPITAL360_CUR.FINANCIAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE (
    CLAIM_LINE_SK         INTEGER       NOT NULL,
    CLAIM_ID              STRING(20)    NOT NULL,
    LINE_NUMBER           INTEGER       NOT NULL,
    ENCOUNTER_ID          STRING(20),
    MRN                   STRING(20),
    PATIENT_NAME          STRING(100),
    PAYER_SK              INTEGER       NOT NULL,
    PAYER_NAME            STRING(100),
    PAYER_TYPE            STRING(30),
    PROVIDER_NAME         STRING(100),
    SERVICE_DATE          DATE          NOT NULL,
    SERVICE_MONTH         DATE,
    CHARGE_AMT            FLOAT         NOT NULL,
    ALLOWED_AMT           FLOAT,
    DENIAL_REASON         STRING(50),
    DENIAL_CATEGORY       STRING(30),    -- mapped from DENIAL_REASON
    CLAIM_STATUS          STRING(20),
    IS_APPEALED           BOOLEAN,
    APPEAL_OUTCOME        STRING(20),    -- WON, LOST, PENDING
    CPT_CODE              STRING(10),
    CPT_DESCRIPTION       STRING(255),
    CPT_CATEGORY          STRING(50),
    ICD10_CODE            STRING(10),
    DX_DESCRIPTION        STRING(255),
    FILING_DATE           DATE,
    DAYS_TO_FILE          INTEGER,
    TIMELY_FILING_LIMIT   INTEGER,
    IS_TIMELY_FILED       BOOLEAN,
    ESTIMATED_RECOVERY    FLOAT,         -- charge_amt * recovery rate by denial category
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CLAIM_LINE_SK)
)
COMMENT = 'UC4 Denials & RevCycle mart: denied claim lines with recovery potential analysis';

-- =============================================================================
-- UC5: MART_STAFFING_QUALITY — Staffing levels correlated with clinical outcomes
-- Grain: 1 row per department per day
-- Schema: HOSPITAL360_CUR.WORKFORCE
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY (
    DEPT_ID               STRING(20)    NOT NULL,
    DEPT_NAME             STRING(100),
    DEPT_TYPE             STRING(50),
    FACILITY_ID           STRING(20)    NOT NULL,
    FACILITY_NAME         STRING(100),
    SHIFT_DATE            DATE          NOT NULL,
    SHIFT_MONTH           DATE,
    DAY_OF_WEEK           STRING(10),
    -- Labor metrics
    TOTAL_WORKED_HRS      FLOAT,
    TOTAL_OT_HRS          FLOAT,
    OT_PCT                FLOAT,         -- OT_HRS / WORKED_HRS
    TOTAL_LABOR_COST      FLOAT,
    STAFF_COUNT           INTEGER,
    AGENCY_STAFF_COUNT    INTEGER,
    AGENCY_PCT            FLOAT,         -- agency / total staff
    -- Patient metrics
    PATIENT_CENSUS        INTEGER,       -- encounters active that day in dept
    HRS_PER_PATIENT       FLOAT,         -- worked_hrs / patient_census
    ADMITS                INTEGER,
    DISCHARGES            INTEGER,
    -- Quality metrics
    READMIT_COUNT         INTEGER,
    READMIT_RATE          FLOAT,         -- readmit_count / discharges
    AVG_LOS_DAYS          FLOAT,
    AVG_LOS_INDEX         FLOAT,
    LONG_STAY_COUNT       INTEGER,
    -- Flags
    IS_UNDERSTAFFED       BOOLEAN,       -- HRS_PER_PATIENT below benchmark
    HIGH_OT_FLAG          BOOLEAN,       -- OT_PCT > 0.15
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DEPT_ID, SHIFT_DATE)
)
COMMENT = 'UC5 Staffing & Quality mart: department-day staffing levels correlated with clinical outcomes';

-- =============================================================================
-- UC6: MART_FINANCIAL_PERFORMANCE — Department-level financial performance
-- Grain: 1 row per department per fiscal period (month)
-- Schema: HOSPITAL360_CUR.FINANCIAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE (
    DEPT_ID               STRING(20)    NOT NULL,
    DEPT_NAME             STRING(100),
    DEPT_TYPE             STRING(50),
    FACILITY_ID           STRING(20)    NOT NULL,
    FACILITY_NAME         STRING(100),
    FISCAL_YEAR           INTEGER       NOT NULL,
    FISCAL_PERIOD         INTEGER       NOT NULL,
    PERIOD_DATE           DATE,           -- first of month
    -- Revenue
    TOTAL_REVENUE         FLOAT,
    -- Expenses by category
    LABOR_COST            FLOAT,
    SUPPLY_COST           FLOAT,
    OVERHEAD_COST         FLOAT,
    DEPRECIATION_COST     FLOAT,
    TOTAL_EXPENSE         FLOAT,
    -- Volume
    DISCHARGES            INTEGER,
    PATIENT_DAYS          FLOAT,
    CMI_ADJUSTED_DISCHARGES FLOAT,       -- discharges * avg DRG weight
    -- Derived metrics
    COST_PER_DISCHARGE    FLOAT,
    COST_PER_CMI_DISCHARGE FLOAT,
    LABOR_PCT             FLOAT,          -- labor / total expense
    SUPPLY_PCT            FLOAT,          -- supply / total expense
    OPERATING_MARGIN      FLOAT,          -- (revenue - expense) / revenue
    NET_REVENUE           FLOAT,          -- revenue - expense
    -- Flags
    IS_NEGATIVE_MARGIN    BOOLEAN,
    _LOADED_AT            TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DEPT_ID, FISCAL_YEAR, FISCAL_PERIOD)
)
COMMENT = 'UC6 Financial Performance mart: department-month GL financials with volume and margin metrics';
