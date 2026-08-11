-- =============================================================================
-- Hospital360 Demo: Stages & File Formats
-- =============================================================================
-- Run as: SYSADMIN (after databases/schemas exist)
-- Prerequisite: 01_databases.sql executed
-- =============================================================================

USE ROLE SYSADMIN;

-- =============================================================================
-- SECTION 1: File Formats
-- =============================================================================

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.EPIC.FF_PARQUET
  TYPE = PARQUET
  COMPRESSION = SNAPPY
  COMMENT = 'Parquet format for Epic data loads';

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.EPIC.FF_CSV
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  COMMENT = 'CSV format with header row for Epic data loads';

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.CLAIMS.FF_JSON
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE
  COMMENT = 'JSON format for 835/837 EDI parsed claims data';

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.IOT.FF_JSON_STREAMING
  TYPE = JSON
  STRIP_OUTER_ARRAY = FALSE
  COMMENT = 'JSON format for IoT/RTLS streaming events (single objects)';

-- Also create formats in a shared location for cross-schema use
CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.PUBLIC.FF_PARQUET
  TYPE = PARQUET
  COMPRESSION = SNAPPY
  COMMENT = 'Shared Parquet format';

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.PUBLIC.FF_CSV
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  COMMENT = 'Shared CSV format with header row';

CREATE FILE FORMAT IF NOT EXISTS HOSPITAL360_RAW.PUBLIC.FF_JSON
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE
  COMMENT = 'Shared JSON format';

-- =============================================================================
-- SECTION 2: Internal Stages (for demo data loading)
-- =============================================================================

-- Epic data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.EPIC.STG_EPIC
  FILE_FORMAT = HOSPITAL360_RAW.EPIC.FF_CSV
  COMMENT = 'Internal stage for Epic Clarity/Caboodle data files';

-- ERP/GL data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.ERP.STG_ERP
  FILE_FORMAT = HOSPITAL360_RAW.PUBLIC.FF_CSV
  COMMENT = 'Internal stage for Workday-shaped ERP/GL data files';

-- HR/Time data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.HR.STG_HR
  FILE_FORMAT = HOSPITAL360_RAW.PUBLIC.FF_CSV
  COMMENT = 'Internal stage for Kronos-shaped HR/timekeeping data files';

-- Claims data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.CLAIMS.STG_CLAIMS
  FILE_FORMAT = HOSPITAL360_RAW.CLAIMS.FF_JSON
  COMMENT = 'Internal stage for 835/837 EDI claims data files';

-- Supply chain data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.SUPPLY_CHAIN.STG_SUPPLY
  FILE_FORMAT = HOSPITAL360_RAW.PUBLIC.FF_CSV
  COMMENT = 'Internal stage for supply chain data files';

-- AD logs staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.AD_LOGS.STG_AD_LOGS
  FILE_FORMAT = HOSPITAL360_RAW.PUBLIC.FF_JSON
  COMMENT = 'Internal stage for Active Directory log files';

-- IoT data staging
CREATE STAGE IF NOT EXISTS HOSPITAL360_RAW.IOT.STG_IOT
  FILE_FORMAT = HOSPITAL360_RAW.IOT.FF_JSON_STREAMING
  COMMENT = 'Internal stage for RTLS/IoT bed-status data files';
