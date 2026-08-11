/*==============================================================================
  HOSPITAL 360 — Week 8: Monitoring & Observability Tables
  
  Creates tables in HOSPITAL360_ML.MONITORING for pipeline run logs,
  model performance tracking, and data quality check results.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;
USE SCHEMA HOSPITAL360_ML.MONITORING;

-- ---------------------------------------------------------------------------
-- Pipeline execution log — one row per task execution
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS HOSPITAL360_ML.MONITORING.PIPELINE_RUN_LOG (
    RUN_ID          STRING      DEFAULT UUID_STRING(),
    RUN_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TASK_NAME       STRING      NOT NULL,
    STATUS          STRING      NOT NULL,   -- SUCCESS, FAILURE, SKIPPED
    ROWS_AFFECTED   NUMBER,
    DURATION_SECONDS NUMBER(10,2),
    ERROR_MESSAGE   STRING,
    METADATA        VARIANT                 -- extra context (JSON)
)
COMMENT = 'Logs each task execution in the Hospital 360 pipeline DAG';

-- ---------------------------------------------------------------------------
-- Model performance log — tracks ML model metrics over time
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS HOSPITAL360_ML.MONITORING.MODEL_PERFORMANCE_LOG (
    LOG_ID          STRING      DEFAULT UUID_STRING(),
    LOG_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    MODEL_NAME      STRING      NOT NULL,
    METRIC_NAME     STRING      NOT NULL,   -- e.g. MAPE, RMSE, ANOMALY_COUNT
    METRIC_VALUE    FLOAT,
    DETAILS         VARIANT                 -- extra context
)
COMMENT = 'Tracks ML model performance metrics over time';

-- ---------------------------------------------------------------------------
-- Data quality check results — one row per check execution
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS (
    CHECK_ID        STRING      DEFAULT UUID_STRING(),
    CHECK_TS        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TABLE_NAME      STRING      NOT NULL,
    CHECK_NAME      STRING      NOT NULL,
    RESULT          STRING      NOT NULL,   -- PASS, FAIL, WARN
    EXPECTED_VALUE  STRING,
    ACTUAL_VALUE    STRING,
    DETAILS         STRING
)
COMMENT = 'Stores data quality check results for all Hospital 360 tables';

-- ---------------------------------------------------------------------------
-- Grant monitoring tables to analyst/exec roles (read-only)
-- ---------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_EXEC;
GRANT SELECT ON ALL TABLES IN SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_CLINICIAN;
GRANT SELECT ON ALL TABLES IN SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_FINANCE;

-- Grant schema usage
GRANT USAGE ON SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_ANALYST;
GRANT USAGE ON SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_EXEC;
GRANT USAGE ON SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_CLINICIAN;
GRANT USAGE ON SCHEMA HOSPITAL360_ML.MONITORING TO ROLE H360_FINANCE;
