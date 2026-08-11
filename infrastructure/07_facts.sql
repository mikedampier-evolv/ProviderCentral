-- =============================================================================
-- Hospital360 Demo: Fact Table DDLs
-- =============================================================================
-- Run as: SYSADMIN (after dimensions exist)
-- Prerequisite: 06_dimensions.sql executed
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_LOAD_WH;

-- =============================================================================
-- FCT_ENCOUNTER — 1 row per encounter (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.FCT_ENCOUNTER (
    ENCOUNTER_SK      INTEGER       NOT NULL AUTOINCREMENT,
    ENCOUNTER_ID      STRING(20)    NOT NULL,
    PATIENT_SK        INTEGER       NOT NULL,
    PROVIDER_SK       INTEGER,
    FACILITY_ID       STRING(20)    NOT NULL,
    DEPT_ID           STRING(20)    NOT NULL,
    PAYER_SK          INTEGER,
    DRG_SK            INTEGER,
    PRIMARY_DX_SK     INTEGER,
    ENCOUNTER_TYPE    STRING(20)    NOT NULL,  -- INPATIENT, OUTPATIENT, ED, OBSERVATION
    ADMIT_DATE        DATE          NOT NULL,
    ADMIT_DATE_KEY    INTEGER       NOT NULL,
    DISCHARGE_DATE    DATE,
    DISCHARGE_DATE_KEY INTEGER,
    DISCHARGE_DISPOSITION STRING(50),
    LOS_DAYS          FLOAT,
    EXPECTED_LOS      FLOAT,
    TOTAL_CHARGES     FLOAT,
    TOTAL_COST        FLOAT,
    TOTAL_PAYMENTS    FLOAT,
    NET_REVENUE       FLOAT,
    READMIT_30_FLAG   BOOLEAN       DEFAULT FALSE,
    ED_REVISIT_72H    BOOLEAN       DEFAULT FALSE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ENCOUNTER_SK),
    UNIQUE (ENCOUNTER_ID)
)
COMMENT = 'Conformed encounter fact: ~200K encounters over 18 months';

-- =============================================================================
-- FCT_ADT_EVENT — 1 row per ADT event (HOSPITAL360_CUR.OPERATIONS)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.FCT_ADT_EVENT (
    ADT_EVENT_SK      INTEGER       NOT NULL AUTOINCREMENT,
    ENCOUNTER_ID      STRING(20)    NOT NULL,
    PATIENT_SK        INTEGER       NOT NULL,
    FACILITY_ID       STRING(20)    NOT NULL,
    DEPT_ID           STRING(20)    NOT NULL,
    BED_ID            STRING(20),
    EVENT_TYPE        STRING(20)    NOT NULL,  -- ADMIT, TRANSFER, DISCHARGE
    EVENT_DATETIME    TIMESTAMP     NOT NULL,
    EVENT_DATE_KEY    INTEGER       NOT NULL,
    PRIOR_DEPT_ID     STRING(20),
    BED_HOURS         FLOAT,
    TRANSFER_FLAG     BOOLEAN       DEFAULT FALSE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ADT_EVENT_SK)
)
COMMENT = 'ADT event fact: admit/transfer/discharge events (~600K rows)';

-- =============================================================================
-- FCT_OR_CASE — 1 row per OR case (HOSPITAL360_CUR.OPERATIONS)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.FCT_OR_CASE (
    OR_CASE_SK        INTEGER       NOT NULL AUTOINCREMENT,
    CASE_ID           STRING(20)    NOT NULL,
    ENCOUNTER_ID      STRING(20),
    PATIENT_SK        INTEGER       NOT NULL,
    SURGEON_SK        INTEGER       NOT NULL,  -- FK to DIM_PROVIDER
    FACILITY_ID       STRING(20)    NOT NULL,
    OR_ROOM_ID        STRING(10)    NOT NULL,
    PRIMARY_CPT_SK    INTEGER,
    CASE_DATE         DATE          NOT NULL,
    CASE_DATE_KEY     INTEGER       NOT NULL,
    SCHEDULED_START   TIMESTAMP     NOT NULL,
    ACTUAL_START      TIMESTAMP,
    ACTUAL_END        TIMESTAMP,
    BLOCK_NAME        STRING(50),
    BLOCK_MINUTES     FLOAT,
    CASE_MINUTES      FLOAT,
    TURNOVER_MINUTES  FLOAT,
    FIRST_CASE_ON_TIME BOOLEAN      DEFAULT FALSE,
    PRIME_TIME_FLAG   BOOLEAN       DEFAULT TRUE,  -- 7am-5pm weekday
    CASE_CLASS        STRING(20),   -- ELECTIVE, URGENT, EMERGENT, ADD_ON
    ASA_CLASS         STRING(5),
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (OR_CASE_SK),
    UNIQUE (CASE_ID)
)
COMMENT = 'OR case fact: ~30K surgical cases with block utilization';

-- =============================================================================
-- FCT_CLAIM_LINE — 1 row per 837 claim line (HOSPITAL360_CUR.FINANCIAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.FCT_CLAIM_LINE (
    CLAIM_LINE_SK     INTEGER       NOT NULL AUTOINCREMENT,
    CLAIM_ID          STRING(20)    NOT NULL,
    LINE_NUMBER       INTEGER       NOT NULL,
    ENCOUNTER_ID      STRING(20),
    PATIENT_SK        INTEGER       NOT NULL,
    PAYER_SK          INTEGER       NOT NULL,
    PROVIDER_SK       INTEGER,
    DX_SK             INTEGER,
    PROC_SK           INTEGER,
    SERVICE_DATE      DATE          NOT NULL,
    SERVICE_DATE_KEY  INTEGER       NOT NULL,
    PLACE_OF_SERVICE  STRING(5),
    CHARGE_AMT        FLOAT         NOT NULL,
    ALLOWED_AMT       FLOAT,
    PAID_AMT          FLOAT,
    PATIENT_RESP_AMT  FLOAT,
    DENIED_FLAG       BOOLEAN       DEFAULT FALSE,
    DENIAL_REASON     STRING(50),
    CLAIM_STATUS      STRING(20),   -- SUBMITTED, ADJUDICATED, DENIED, APPEALED
    FILING_DATE       DATE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CLAIM_LINE_SK)
)
COMMENT = 'Claim line fact: ~1.2M lines with denial/payment detail';

-- =============================================================================
-- FCT_REMITTANCE — 1 row per 835 remittance line (HOSPITAL360_CUR.FINANCIAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.FCT_REMITTANCE (
    REMIT_LINE_SK     INTEGER       NOT NULL AUTOINCREMENT,
    REMIT_ID          STRING(20)    NOT NULL,
    CLAIM_ID          STRING(20)    NOT NULL,
    LINE_NUMBER       INTEGER       NOT NULL,
    PAYER_SK          INTEGER       NOT NULL,
    PATIENT_SK        INTEGER       NOT NULL,
    SERVICE_DATE      DATE          NOT NULL,
    SERVICE_DATE_KEY  INTEGER       NOT NULL,
    PAID_AMT          FLOAT         NOT NULL,
    ALLOWED_AMT       FLOAT,
    ADJUSTMENT_AMT    FLOAT,
    CARC_CODE         STRING(10),   -- Claim Adjustment Reason Code
    CARC_GROUP        STRING(30),   -- ELIGIBILITY, AUTH, CODING, MEDICAL_NECESSITY, OTHER
    RARC_CODE         STRING(10),
    REMIT_DATE        DATE,
    CHECK_NUMBER      STRING(20),
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (REMIT_LINE_SK)
)
COMMENT = 'Remittance fact: ~1.1M lines matched to claims with CARC/RARC codes';

-- =============================================================================
-- FCT_REFERRAL — 1 row per referral (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.FCT_REFERRAL (
    REFERRAL_SK       INTEGER       NOT NULL AUTOINCREMENT,
    REFERRAL_ID       STRING(20)    NOT NULL,
    PATIENT_SK        INTEGER       NOT NULL,
    REFERRING_PROVIDER_SK INTEGER   NOT NULL,
    REFERRED_TO_NPI   STRING(10)    NOT NULL,
    REFERRED_TO_SPECIALTY STRING(50),
    REFERRAL_DATE     DATE          NOT NULL,
    REFERRAL_DATE_KEY INTEGER       NOT NULL,
    STATUS            STRING(20)    NOT NULL,  -- OPEN, SCHEDULED, COMPLETED, CANCELLED
    LEAKAGE_FLAG      BOOLEAN       DEFAULT FALSE,
    EXPECTED_REVENUE  FLOAT,
    FACILITY_ID       STRING(20),
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (REFERRAL_SK),
    UNIQUE (REFERRAL_ID)
)
COMMENT = 'Referral fact: ~50K referrals with leakage flags';

-- =============================================================================
-- FCT_CARE_GAP — 1 row per measure-patient (HOSPITAL360_CUR.POPULATION_HEALTH)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.POPULATION_HEALTH.FCT_CARE_GAP (
    CARE_GAP_SK       INTEGER       NOT NULL AUTOINCREMENT,
    PATIENT_SK        INTEGER       NOT NULL,
    MEASURE_ID        STRING(10)    NOT NULL,  -- CBP, A1C, BCS, COL, SPC
    MEASURE_NAME      STRING(100)   NOT NULL,
    MEASURE_YEAR      INTEGER       NOT NULL,
    IS_ELIGIBLE       BOOLEAN       NOT NULL DEFAULT TRUE,
    IS_OPEN           BOOLEAN       NOT NULL DEFAULT TRUE,
    DUE_DATE          DATE,
    LAST_SERVICE_DATE DATE,
    LAST_RESULT       STRING(50),
    RISK_PRIORITY     STRING(10),   -- HIGH, MEDIUM, LOW
    OUTREACH_STATUS   STRING(20),   -- NONE, CALLED, SCHEDULED, REFUSED
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CARE_GAP_SK)
)
COMMENT = 'Care gap fact: HEDIS measures per patient (~75K rows)';

-- =============================================================================
-- FCT_EHR_USAGE — 1 row per provider-day (HOSPITAL360_CUR.WORKFORCE)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.WORKFORCE.FCT_EHR_USAGE (
    EHR_USAGE_SK      INTEGER       NOT NULL AUTOINCREMENT,
    PROVIDER_SK       INTEGER       NOT NULL,
    USAGE_DATE        DATE          NOT NULL,
    USAGE_DATE_KEY    INTEGER       NOT NULL,
    TOTAL_EHR_MIN     FLOAT,
    CHART_REVIEW_MIN  FLOAT,
    DOCUMENTATION_MIN FLOAT,
    INBOX_MIN         FLOAT,
    ORDER_ENTRY_MIN   FLOAT,
    PAJAMA_TIME_MIN   FLOAT,        -- after-hours EHR use
    AFTER_HOURS_FLAG  BOOLEAN       DEFAULT FALSE,
    WEEKEND_FLAG      BOOLEAN       DEFAULT FALSE,
    ENCOUNTERS_CLOSED INTEGER,
    TIME_TO_CLOSE_HRS FLOAT,       -- avg hours to close encounter note
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (EHR_USAGE_SK)
)
COMMENT = 'EHR usage fact (Epic Signal shape): per provider-day (~73K rows)';

-- =============================================================================
-- FCT_LABOR_HOUR — 1 row per employee-shift (HOSPITAL360_CUR.WORKFORCE)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.WORKFORCE.FCT_LABOR_HOUR (
    LABOR_HOUR_SK     INTEGER       NOT NULL AUTOINCREMENT,
    EMPLOYEE_ID       STRING(20)    NOT NULL,
    EMPLOYEE_NAME     STRING(100),
    JOB_TITLE         STRING(50),
    DEPT_ID           STRING(20)    NOT NULL,
    FACILITY_ID       STRING(20)    NOT NULL,
    SHIFT_DATE        DATE          NOT NULL,
    SHIFT_DATE_KEY    INTEGER       NOT NULL,
    SHIFT_TYPE        STRING(10)    NOT NULL,  -- DAY, EVENING, NIGHT
    SCHEDULED_HRS     FLOAT,
    WORKED_HRS        FLOAT         NOT NULL,
    OT_HRS            FLOAT         DEFAULT 0,
    AGENCY_FLAG       BOOLEAN       DEFAULT FALSE,
    HOURLY_RATE       FLOAT,
    TOTAL_LABOR_COST  FLOAT,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (LABOR_HOUR_SK)
)
COMMENT = 'Labor hour fact (Kronos shape): per employee-shift (~730K rows)';

-- =============================================================================
-- FCT_GL_TRANSACTION — 1 row per GL line (HOSPITAL360_CUR.FINANCIAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.FCT_GL_TRANSACTION (
    GL_TRANS_SK       INTEGER       NOT NULL AUTOINCREMENT,
    GL_ACCOUNT_CODE   STRING(20)    NOT NULL,
    GL_ACCOUNT_DESC   STRING(100),
    COST_CENTER       STRING(20)    NOT NULL,
    DEPT_ID           STRING(20),
    FACILITY_ID       STRING(20)    NOT NULL,
    FISCAL_YEAR       INTEGER       NOT NULL,
    FISCAL_PERIOD     INTEGER       NOT NULL,  -- 1-12
    POSTING_DATE      DATE          NOT NULL,
    POSTING_DATE_KEY  INTEGER       NOT NULL,
    AMOUNT            FLOAT         NOT NULL,
    DEBIT_CREDIT      STRING(1)     NOT NULL,  -- D or C
    CATEGORY          STRING(30),   -- LABOR, SUPPLIES, OVERHEAD, DEPRECIATION, REVENUE
    SOURCE_SYSTEM     STRING(20),
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (GL_TRANS_SK)
)
COMMENT = 'GL transaction fact (Workday shape): per GL line (~500K rows)';

-- =============================================================================
-- FCT_SUPPLY_USAGE — 1 row per item-encounter (HOSPITAL360_CUR.SUPPLY_CHAIN)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.SUPPLY_CHAIN.FCT_SUPPLY_USAGE (
    SUPPLY_USAGE_SK   INTEGER       NOT NULL AUTOINCREMENT,
    ENCOUNTER_ID      STRING(20),
    PATIENT_SK        INTEGER,
    ITEM_ID           STRING(20)    NOT NULL,
    ITEM_DESC         STRING(100),
    ITEM_CATEGORY     STRING(50),   -- MEDICAL_DEVICE, PHARMACEUTICAL, PPE, IMPLANT, GENERAL
    DEPT_ID           STRING(20)    NOT NULL,
    FACILITY_ID       STRING(20)    NOT NULL,
    USAGE_DATE        DATE          NOT NULL,
    USAGE_DATE_KEY    INTEGER       NOT NULL,
    QTY               FLOAT         NOT NULL,
    UNIT_COST         FLOAT,
    TOTAL_COST        FLOAT,
    PAR_LEVEL         FLOAT,
    REORDER_POINT     FLOAT,
    ON_HAND_QTY       FLOAT,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (SUPPLY_USAGE_SK)
)
COMMENT = 'Supply usage fact: per item-encounter (~400K rows)';

-- =============================================================================
-- FCT_BED_STATUS — 1 row per status change (HOSPITAL360_CUR.OPERATIONS)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.FCT_BED_STATUS (
    BED_STATUS_SK     INTEGER       NOT NULL AUTOINCREMENT,
    BED_ID            STRING(20)    NOT NULL,
    FACILITY_ID       STRING(20)    NOT NULL,
    DEPT_ID           STRING(20)    NOT NULL,
    STATUS            STRING(20)    NOT NULL,  -- OCCUPIED, VACANT_CLEAN, VACANT_DIRTY, MAINTENANCE, BLOCKED
    STATUS_START      TIMESTAMP     NOT NULL,
    STATUS_END        TIMESTAMP,
    DWELL_TIME_MIN    FLOAT,
    PATIENT_SK        INTEGER,
    EVENT_DATE_KEY    INTEGER       NOT NULL,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (BED_STATUS_SK)
)
COMMENT = 'Bed status fact (IoT/RTLS shape): per status change (~300K rows)';
