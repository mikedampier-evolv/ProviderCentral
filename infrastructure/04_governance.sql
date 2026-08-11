-- =============================================================================
-- Hospital360 Demo: Governance — Tags, Masking Policies, Row-Access Policies
-- =============================================================================
-- Run as: SYSADMIN (after databases/schemas exist)
-- Prerequisite: 01_databases.sql, 03_roles.sql executed
-- =============================================================================

USE ROLE SYSADMIN;
USE DATABASE HOSPITAL360_CUR;
USE SCHEMA GOVERNANCE;

-- =============================================================================
-- SECTION 1: Governance Tags
-- =============================================================================

CREATE TAG IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.DATA_CLASSIFICATION
  ALLOWED_VALUES 'PHI', 'PII', 'FINANCIAL', 'RESTRICTED', 'INTERNAL', 'PUBLIC'
  COMMENT = 'HIPAA-aligned data classification level';

CREATE TAG IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.PII_TYPE
  ALLOWED_VALUES 'SSN', 'NAME', 'DOB', 'ADDRESS', 'PHONE', 'EMAIL', 'MRN'
  COMMENT = 'Granular PII type — drives masking policy selection';

CREATE TAG IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.DATA_DOMAIN
  ALLOWED_VALUES 'CLINICAL', 'CLAIMS', 'FINANCIAL', 'DEMOGRAPHIC', 'OPERATIONS', 'WORKFORCE', 'REFERENCE'
  COMMENT = 'Business data domain for lineage and ownership';

CREATE TAG IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.RETENTION_POLICY
  ALLOWED_VALUES '30_DAYS', '90_DAYS', '1_YEAR', '3_YEARS', '7_YEARS', 'INDEFINITE'
  COMMENT = 'Data retention policy aligned with HIPAA (6yr) and state requirements';

-- =============================================================================
-- SECTION 2: Masking Policies
-- =============================================================================

-- ---------------------------------------------------------------------------
-- MASK_SSN: Shows last 4 for clinical, fully masked for others
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_SSN
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')     THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')  THEN 'XXX-XX-' || RIGHT(val, 4)
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')   THEN 'XXX-XX-' || RIGHT(val, 4)
    ELSE '***-**-****'
  END
  COMMENT = 'SSN masking: full for admin, last-4 for clinical/engineer, hidden for others';

-- ---------------------------------------------------------------------------
-- MASK_DOB: Year-only for exec, full for clinical
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_DOB
  AS (val DATE) RETURNS DATE ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')      THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')   THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')    THEN val
    ELSE DATE_FROM_PARTS(YEAR(val), 1, 1)  -- year-only for exec/analyst/finance
  END
  COMMENT = 'DOB masking: full for clinical, year-only for non-clinical';

-- ---------------------------------------------------------------------------
-- MASK_PATIENT_NAME: Hash for exec, full for clinical
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_PATIENT_NAME
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')      THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')   THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')    THEN val
    ELSE 'PATIENT_' || LEFT(SHA2(val), 8)
  END
  COMMENT = 'Patient name masking: full for clinical, pseudonymized for others';

-- ---------------------------------------------------------------------------
-- MASK_MRN: Hidden for non-clinical roles
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_MRN
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')      THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')   THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')    THEN val
    ELSE '***MRN***'
  END
  COMMENT = 'MRN masking: visible for clinical roles, hidden for others';

-- ---------------------------------------------------------------------------
-- MASK_PHONE: Show last 4 for analyst, hidden for exec
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_PHONE
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')      THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')   THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')    THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ANALYST')     THEN '(***) ***-' || RIGHT(val, 4)
    ELSE '**********'
  END
  COMMENT = 'Phone masking: full for clinical, last-4 for analyst, hidden for exec';

-- ---------------------------------------------------------------------------
-- MASK_EMAIL: Domain-only for non-clinical
-- ---------------------------------------------------------------------------
CREATE MASKING POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.MASK_EMAIL
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')      THEN val
    WHEN IS_ROLE_IN_SESSION('H360_CLINICIAN')   THEN val
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER')    THEN val
    ELSE '****@' || SPLIT_PART(val, '@', 2)
  END
  COMMENT = 'Email masking: full for clinical, domain-only for others';

-- =============================================================================
-- SECTION 3: Row-Access Policy Mapping Tables
-- =============================================================================

-- Mapping table: which roles can see which departments
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.ROLE_DEPT_ACCESS (
  ROLE_NAME        STRING    NOT NULL,
  DEPT_ID          STRING    NOT NULL,
  COMMENT          STRING,
  CREATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Mapping table for department-level row-access policy';

-- Mapping table: which roles can see which facilities
CREATE TABLE IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.ROLE_FACILITY_ACCESS (
  ROLE_NAME        STRING    NOT NULL,
  FACILITY_ID      STRING    NOT NULL,
  COMMENT          STRING,
  CREATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Mapping table for facility-level row-access policy';

-- =============================================================================
-- SECTION 4: Row-Access Policies
-- =============================================================================

-- ---------------------------------------------------------------------------
-- RAP_DEPARTMENT: Filter rows by DEPT_ID based on role mapping
-- ---------------------------------------------------------------------------
CREATE ROW ACCESS POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.RAP_DEPARTMENT
  AS (dept_id STRING) RETURNS BOOLEAN ->
  CASE
    -- Admin and engineer see everything
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')    THEN TRUE
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER') THEN TRUE
    -- Other roles see only their mapped departments
    WHEN EXISTS (
      SELECT 1
      FROM HOSPITAL360_CUR.GOVERNANCE.ROLE_DEPT_ACCESS rda
      WHERE rda.DEPT_ID = dept_id
        AND IS_ROLE_IN_SESSION(rda.ROLE_NAME)
    ) THEN TRUE
    ELSE FALSE
  END
  COMMENT = 'Row-level security by department: maps roles to allowed departments';

-- ---------------------------------------------------------------------------
-- RAP_FACILITY: Filter rows by FACILITY_ID based on role mapping
-- ---------------------------------------------------------------------------
CREATE ROW ACCESS POLICY IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE.RAP_FACILITY
  AS (facility_id STRING) RETURNS BOOLEAN ->
  CASE
    -- Admin and engineer see everything
    WHEN IS_ROLE_IN_SESSION('H360_ADMIN')    THEN TRUE
    WHEN IS_ROLE_IN_SESSION('H360_ENGINEER') THEN TRUE
    -- Other roles see only their mapped facilities
    WHEN EXISTS (
      SELECT 1
      FROM HOSPITAL360_CUR.GOVERNANCE.ROLE_FACILITY_ACCESS rfa
      WHERE rfa.FACILITY_ID = facility_id
        AND IS_ROLE_IN_SESSION(rfa.ROLE_NAME)
    ) THEN TRUE
    ELSE FALSE
  END
  COMMENT = 'Row-level security by facility: maps roles to allowed facilities';
