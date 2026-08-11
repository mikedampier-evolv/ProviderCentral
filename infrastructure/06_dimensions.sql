-- =============================================================================
-- Hospital360 Demo: Dimension Table DDLs
-- =============================================================================
-- Run as: SYSADMIN (after databases/schemas exist)
-- Prerequisite: 01_databases.sql executed
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_LOAD_WH;

-- =============================================================================
-- DIM_DATE — Universal date spine (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_DATE (
    DATE_KEY          INTEGER       NOT NULL,  -- YYYYMMDD
    FULL_DATE         DATE          NOT NULL,
    YEAR              INTEGER       NOT NULL,
    QUARTER           INTEGER       NOT NULL,
    MONTH             INTEGER       NOT NULL,
    MONTH_NAME        STRING(10)    NOT NULL,
    DAY_OF_MONTH      INTEGER       NOT NULL,
    DAY_OF_WEEK       INTEGER       NOT NULL,  -- 0=Sun, 6=Sat
    DAY_NAME          STRING(10)    NOT NULL,
    WEEK_OF_YEAR      INTEGER       NOT NULL,
    FISCAL_YEAR       INTEGER       NOT NULL,  -- July fiscal year start
    FISCAL_QUARTER    INTEGER       NOT NULL,
    IS_WEEKEND        BOOLEAN       NOT NULL,
    IS_HOLIDAY        BOOLEAN       NOT NULL DEFAULT FALSE,
    HOLIDAY_NAME      STRING(50),
    PRIMARY KEY (DATE_KEY)
)
COMMENT = 'Conformed date dimension: 2023-01-01 to 2025-12-31';

-- =============================================================================
-- DIM_FACILITY — Hospital facilities (HOSPITAL360_CUR.OPERATIONS)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.DIM_FACILITY (
    FACILITY_SK       INTEGER       NOT NULL AUTOINCREMENT,
    FACILITY_ID       STRING(20)    NOT NULL,
    FACILITY_NAME     STRING(100)   NOT NULL,
    FACILITY_TYPE     STRING(50)    NOT NULL,  -- HOSPITAL, COMMUNITY, REHAB, ASC, CLINIC
    ADDRESS           STRING(200),
    CITY              STRING(50),
    STATE             STRING(2),
    ZIP               STRING(10),
    LATITUDE          FLOAT,
    LONGITUDE         FLOAT,
    BED_COUNT         INTEGER,
    OR_ROOM_COUNT     INTEGER,
    IS_OWNED          BOOLEAN       NOT NULL DEFAULT TRUE,
    OPENED_DATE       DATE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (FACILITY_SK),
    UNIQUE (FACILITY_ID)
)
COMMENT = 'Conformed facility dimension: hospitals, clinics, ASCs';

-- =============================================================================
-- DIM_DEPARTMENT — Hospital departments (HOSPITAL360_CUR.OPERATIONS)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS.DIM_DEPARTMENT (
    DEPT_SK           INTEGER       NOT NULL AUTOINCREMENT,
    DEPT_ID           STRING(20)    NOT NULL,
    DEPT_NAME         STRING(100)   NOT NULL,
    DEPT_TYPE         STRING(50)    NOT NULL,  -- INPATIENT, OUTPATIENT, ED, OR, ICU, ANCILLARY
    FACILITY_ID       STRING(20)    NOT NULL,
    COST_CENTER       STRING(20),
    BED_COUNT         INTEGER,
    TARGET_OCCUPANCY  FLOAT,        -- e.g. 0.85
    MANAGER_NAME      STRING(100),
    IS_ACTIVE         BOOLEAN       NOT NULL DEFAULT TRUE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DEPT_SK),
    UNIQUE (DEPT_ID)
)
COMMENT = 'Conformed department dimension: ED, ICU, Med-Surg, OR, etc.';

-- =============================================================================
-- DIM_PAYER — Insurance payers (HOSPITAL360_CUR.FINANCIAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.DIM_PAYER (
    PAYER_SK          INTEGER       NOT NULL AUTOINCREMENT,
    PAYER_ID          STRING(20)    NOT NULL,
    PAYER_NAME        STRING(100)   NOT NULL,
    PAYER_TYPE        STRING(30)    NOT NULL,  -- MEDICARE, MEDICAID, COMMERCIAL, SELF_PAY, WORKERS_COMP
    PLAN_NAME         STRING(100),
    IS_IN_NETWORK     BOOLEAN       NOT NULL DEFAULT TRUE,
    CONTRACT_RATE_PCT FLOAT,        -- % of charges, e.g. 0.45
    TIMELY_FILING_DAYS INTEGER,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PAYER_SK),
    UNIQUE (PAYER_ID)
)
COMMENT = 'Conformed payer dimension: Medicare, Medicaid, commercial, self-pay';

-- =============================================================================
-- DIM_PATIENT — Patient master (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PATIENT (
    PATIENT_SK        INTEGER       NOT NULL AUTOINCREMENT,
    MRN               STRING(20)    NOT NULL,
    FIRST_NAME        STRING(50)    NOT NULL,
    LAST_NAME         STRING(50)    NOT NULL,
    DOB               DATE          NOT NULL,
    GENDER            STRING(10)    NOT NULL,
    RACE              STRING(30),
    ETHNICITY         STRING(30),
    LANGUAGE          STRING(20)    DEFAULT 'English',
    MARITAL_STATUS    STRING(20),
    SSN               STRING(11),
    PHONE             STRING(15),
    EMAIL             STRING(100),
    ADDRESS           STRING(200),
    CITY              STRING(50),
    STATE             STRING(2),
    ZIP               STRING(10),
    COUNTY            STRING(50),
    PRIMARY_PAYER_ID  STRING(20),
    HCC_SCORE         FLOAT,        -- CMS-HCC risk score
    SDOH_RISK_INDEX   FLOAT,        -- Social determinants composite (0-1)
    IS_ACTIVE         BOOLEAN       NOT NULL DEFAULT TRUE,
    DEATH_DATE        DATE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PATIENT_SK),
    UNIQUE (MRN)
)
COMMENT = 'Conformed patient dimension: 25K synthetic patients with demographics';

-- =============================================================================
-- DIM_PROVIDER — Provider master (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PROVIDER (
    PROVIDER_SK       INTEGER       NOT NULL AUTOINCREMENT,
    NPI               STRING(10)    NOT NULL,
    FIRST_NAME        STRING(50)    NOT NULL,
    LAST_NAME         STRING(50)    NOT NULL,
    CREDENTIAL        STRING(20),   -- MD, DO, NP, PA
    SPECIALTY         STRING(50)    NOT NULL,
    DEPT_ID           STRING(20),
    FACILITY_ID       STRING(20),
    IS_EMPLOYED       BOOLEAN       NOT NULL DEFAULT TRUE,
    IS_ACTIVE         BOOLEAN       NOT NULL DEFAULT TRUE,
    HIRE_DATE         DATE,
    FTE               FLOAT         DEFAULT 1.0,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PROVIDER_SK),
    UNIQUE (NPI)
)
COMMENT = 'Conformed provider dimension: 200 synthetic providers with specialties';

-- =============================================================================
-- DIM_DIAGNOSIS_ICD10 — ICD-10 codes (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_DIAGNOSIS_ICD10 (
    DX_SK             INTEGER       NOT NULL AUTOINCREMENT,
    ICD10_CODE        STRING(10)    NOT NULL,
    DESCRIPTION       STRING(255)   NOT NULL,
    CHAPTER           STRING(5),
    CHAPTER_DESC      STRING(100),
    CATEGORY          STRING(10),
    IS_CHRONIC        BOOLEAN       NOT NULL DEFAULT FALSE,
    HCC_FLAG          BOOLEAN       NOT NULL DEFAULT FALSE,
    HCC_CATEGORY      STRING(10),
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DX_SK),
    UNIQUE (ICD10_CODE)
)
COMMENT = 'ICD-10 diagnosis dimension: ~200 common codes';

-- =============================================================================
-- DIM_PROCEDURE_CPT — CPT codes (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PROCEDURE_CPT (
    PROC_SK           INTEGER       NOT NULL AUTOINCREMENT,
    CPT_CODE          STRING(10)    NOT NULL,
    DESCRIPTION       STRING(255)   NOT NULL,
    CATEGORY          STRING(50),   -- E&M, Surgery, Radiology, Lab, Medicine
    SUBCATEGORY       STRING(50),
    RVU_WORK          FLOAT,
    RVU_PE            FLOAT,        -- practice expense
    RVU_MALPRACTICE   FLOAT,
    RVU_TOTAL         FLOAT,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PROC_SK),
    UNIQUE (CPT_CODE)
)
COMMENT = 'CPT procedure dimension: ~150 common codes with RVU values';

-- =============================================================================
-- DIM_DRG — MS-DRG codes (HOSPITAL360_CUR.FINANCIAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL.DIM_DRG (
    DRG_SK            INTEGER       NOT NULL AUTOINCREMENT,
    DRG_CODE          STRING(5)     NOT NULL,
    DESCRIPTION       STRING(255)   NOT NULL,
    MDC               STRING(5),    -- Major Diagnostic Category
    MDC_DESCRIPTION   STRING(100),
    TYPE              STRING(10),   -- MEDICAL, SURGICAL
    WEIGHT            FLOAT         NOT NULL,
    GEOMETRIC_LOS     FLOAT,        -- expected LOS
    ARITHMETIC_LOS    FLOAT,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DRG_SK),
    UNIQUE (DRG_CODE)
)
COMMENT = 'MS-DRG dimension: ~80 common DRGs with weights and LOS benchmarks';

-- =============================================================================
-- DIM_MEDICATION_RXNORM — Medication master (HOSPITAL360_CUR.CLINICAL)
-- =============================================================================
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.CLINICAL.DIM_MEDICATION_RXNORM (
    MED_SK            INTEGER       NOT NULL AUTOINCREMENT,
    RXNORM_CODE       STRING(20)    NOT NULL,
    GENERIC_NAME      STRING(100)   NOT NULL,
    BRAND_NAME        STRING(100),
    DRUG_CLASS        STRING(50),
    THERAPEUTIC_AREA  STRING(50),
    ROUTE             STRING(30),   -- ORAL, IV, IM, TOPICAL, INH
    IS_CONTROLLED     BOOLEAN       NOT NULL DEFAULT FALSE,
    DEA_SCHEDULE      STRING(5),
    UNIT_COST         FLOAT,
    IS_ON_SHORTAGE    BOOLEAN       NOT NULL DEFAULT FALSE,
    _LOADED_AT        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (MED_SK),
    UNIQUE (RXNORM_CODE)
)
COMMENT = 'RxNorm medication dimension: ~100 common medications with drug class and cost';
