/*==============================================================================
  HOSPITAL 360 — Week 8: Data Quality Checks Stored Procedure

  Creates SP_RUN_DATA_QUALITY_CHECKS() that validates:
    1. Row count minimums on all 4 marts
    2. NULL primary key checks on each mart
    3. Key metric reasonableness (readmission rate, leakage rate, etc.)
    4. Date range freshness

  Results are logged to HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS.
  Call manually or schedule via Task DAG.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;

CREATE OR REPLACE PROCEDURE HOSPITAL360_ML.MONITORING.SP_RUN_DATA_QUALITY_CHECKS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    LET pass_count NUMBER := 0;
    LET fail_count NUMBER := 0;
    LET warn_count NUMBER := 0;
    LET rc NUMBER := 0;

    -- =========================================================================
    -- CHECK 1: Row count minimums
    -- =========================================================================
    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_READMISSION_LOS', 'ROW_COUNT_MIN', 
            CASE WHEN :rc >= 100000 THEN 'PASS' ELSE 'FAIL' END,
            '>= 100000', :rc::STRING,
            'Readmission mart should have at least 100K IP/OBS encounters');
    pass_count := CASE WHEN :rc >= 100000 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc < 100000 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_PATIENT_LEAKAGE', 'ROW_COUNT_MIN',
            CASE WHEN :rc >= 40000 THEN 'PASS' ELSE 'FAIL' END,
            '>= 40000', :rc::STRING,
            'Leakage mart should have at least 40K referrals');
    pass_count := CASE WHEN :rc >= 40000 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc < 40000 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_OR_CAPACITY', 'ROW_COUNT_MIN',
            CASE WHEN :rc >= 25000 THEN 'PASS' ELSE 'FAIL' END,
            '>= 25000', :rc::STRING,
            'OR capacity mart should have at least 25K cases');
    pass_count := CASE WHEN :rc >= 25000 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc < 25000 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_DENIALS_REVCYCLE', 'ROW_COUNT_MIN',
            CASE WHEN :rc >= 100000 THEN 'PASS' ELSE 'FAIL' END,
            '>= 100000', :rc::STRING,
            'Denials mart should have at least 100K denied claim lines');
    pass_count := CASE WHEN :rc >= 100000 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc < 100000 THEN :fail_count + 1 ELSE :fail_count END;

    -- =========================================================================
    -- CHECK 2: NULL primary key checks
    -- =========================================================================
    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS WHERE ENCOUNTER_ID IS NULL;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_READMISSION_LOS', 'NULL_PK_CHECK',
            CASE WHEN :rc = 0 THEN 'PASS' ELSE 'FAIL' END,
            '0', :rc::STRING, 'ENCOUNTER_ID should never be NULL');
    pass_count := CASE WHEN :rc = 0 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc > 0 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE WHERE REFERRAL_ID IS NULL;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_PATIENT_LEAKAGE', 'NULL_PK_CHECK',
            CASE WHEN :rc = 0 THEN 'PASS' ELSE 'FAIL' END,
            '0', :rc::STRING, 'REFERRAL_ID should never be NULL');
    pass_count := CASE WHEN :rc = 0 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc > 0 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY WHERE CASE_ID IS NULL;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_OR_CAPACITY', 'NULL_PK_CHECK',
            CASE WHEN :rc = 0 THEN 'PASS' ELSE 'FAIL' END,
            '0', :rc::STRING, 'CASE_ID should never be NULL');
    pass_count := CASE WHEN :rc = 0 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc > 0 THEN :fail_count + 1 ELSE :fail_count END;

    SELECT COUNT(*) INTO :rc FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE WHERE CLAIM_LINE_SK IS NULL;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_DENIALS_REVCYCLE', 'NULL_PK_CHECK',
            CASE WHEN :rc = 0 THEN 'PASS' ELSE 'FAIL' END,
            '0', :rc::STRING, 'CLAIM_LINE_SK should never be NULL');
    pass_count := CASE WHEN :rc = 0 THEN :pass_count + 1 ELSE :pass_count END;
    fail_count := CASE WHEN :rc > 0 THEN :fail_count + 1 ELSE :fail_count END;

    -- =========================================================================
    -- CHECK 3: Metric reasonableness
    -- =========================================================================
    LET readmit_rate FLOAT := 0;
    SELECT AVG(CASE WHEN READMIT_30_FLAG THEN 1.0 ELSE 0.0 END) * 100 INTO :readmit_rate
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_READMISSION_LOS', 'METRIC_READMISSION_RATE',
            CASE WHEN :readmit_rate BETWEEN 5 AND 25 THEN 'PASS'
                 WHEN :readmit_rate BETWEEN 3 AND 30 THEN 'WARN'
                 ELSE 'FAIL' END,
            '5-25%', ROUND(:readmit_rate, 2)::STRING || '%',
            '30-day readmission rate should be 5-25% for typical hospital');
    pass_count := CASE WHEN :readmit_rate BETWEEN 5 AND 25 THEN :pass_count + 1 ELSE :pass_count END;
    warn_count := CASE WHEN :readmit_rate NOT BETWEEN 5 AND 25 AND :readmit_rate BETWEEN 3 AND 30 THEN :warn_count + 1 ELSE :warn_count END;
    fail_count := CASE WHEN :readmit_rate NOT BETWEEN 3 AND 30 THEN :fail_count + 1 ELSE :fail_count END;

    LET leakage_rate FLOAT := 0;
    SELECT AVG(CASE WHEN LEAKAGE_FLAG THEN 1.0 ELSE 0.0 END) * 100 INTO :leakage_rate
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_PATIENT_LEAKAGE', 'METRIC_LEAKAGE_RATE',
            CASE WHEN :leakage_rate BETWEEN 5 AND 30 THEN 'PASS'
                 WHEN :leakage_rate BETWEEN 2 AND 40 THEN 'WARN'
                 ELSE 'FAIL' END,
            '5-30%', ROUND(:leakage_rate, 2)::STRING || '%',
            'Patient leakage rate should be 5-30% for typical health system');
    pass_count := CASE WHEN :leakage_rate BETWEEN 5 AND 30 THEN :pass_count + 1 ELSE :pass_count END;
    warn_count := CASE WHEN :leakage_rate NOT BETWEEN 5 AND 30 AND :leakage_rate BETWEEN 2 AND 40 THEN :warn_count + 1 ELSE :warn_count END;
    fail_count := CASE WHEN :leakage_rate NOT BETWEEN 2 AND 40 THEN :fail_count + 1 ELSE :fail_count END;

    LET avg_util FLOAT := 0;
    SELECT AVG(UTILIZATION_PCT) * 100 INTO :avg_util
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE UTILIZATION_PCT IS NOT NULL;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_OR_CAPACITY', 'METRIC_OR_UTILIZATION',
            CASE WHEN :avg_util BETWEEN 60 AND 95 THEN 'PASS'
                 WHEN :avg_util BETWEEN 40 AND 100 THEN 'WARN'
                 ELSE 'FAIL' END,
            '60-95%', ROUND(:avg_util, 2)::STRING || '%',
            'Average OR utilization should be 60-95%');
    pass_count := CASE WHEN :avg_util BETWEEN 60 AND 95 THEN :pass_count + 1 ELSE :pass_count END;
    warn_count := CASE WHEN :avg_util NOT BETWEEN 60 AND 95 AND :avg_util BETWEEN 40 AND 100 THEN :warn_count + 1 ELSE :warn_count END;
    fail_count := CASE WHEN :avg_util NOT BETWEEN 40 AND 100 THEN :fail_count + 1 ELSE :fail_count END;

    -- =========================================================================
    -- CHECK 4: Date freshness — most recent data should be within expected range
    -- =========================================================================
    LET max_admit STRING := '';
    SELECT MAX(ADMIT_DATE)::STRING INTO :max_admit FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_READMISSION_LOS', 'DATE_FRESHNESS',
            CASE WHEN :max_admit >= '2024-12-01' THEN 'PASS' ELSE 'WARN' END,
            '>= 2024-12-01', :max_admit,
            'Most recent admit date should be in Dec 2024 range for demo data');
    pass_count := CASE WHEN :max_admit >= '2024-12-01' THEN :pass_count + 1 ELSE :pass_count END;
    warn_count := CASE WHEN :max_admit < '2024-12-01' THEN :warn_count + 1 ELSE :warn_count END;

    LET max_ref STRING := '';
    SELECT MAX(REFERRAL_DATE)::STRING INTO :max_ref FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE;
    INSERT INTO HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
        (TABLE_NAME, CHECK_NAME, RESULT, EXPECTED_VALUE, ACTUAL_VALUE, DETAILS)
    VALUES ('MART_PATIENT_LEAKAGE', 'DATE_FRESHNESS',
            CASE WHEN :max_ref >= '2024-12-01' THEN 'PASS' ELSE 'WARN' END,
            '>= 2024-12-01', :max_ref,
            'Most recent referral date should be in Dec 2024 range');
    pass_count := CASE WHEN :max_ref >= '2024-12-01' THEN :pass_count + 1 ELSE :pass_count END;
    warn_count := CASE WHEN :max_ref < '2024-12-01' THEN :warn_count + 1 ELSE :warn_count END;

    -- =========================================================================
    -- Summary
    -- =========================================================================
    INSERT INTO HOSPITAL360_ML.MONITORING.PIPELINE_RUN_LOG (TASK_NAME, STATUS, METADATA)
    VALUES ('DATA_QUALITY_CHECKS', 'SUCCESS',
            OBJECT_CONSTRUCT('pass', :pass_count, 'fail', :fail_count, 'warn', :warn_count));

    RETURN 'DQ checks complete. PASS: ' || :pass_count::STRING || 
           ', FAIL: ' || :fail_count::STRING || 
           ', WARN: ' || :warn_count::STRING;
END;
$$;

-- Grant execute to analyst/admin roles
GRANT USAGE ON PROCEDURE HOSPITAL360_ML.MONITORING.SP_RUN_DATA_QUALITY_CHECKS()
    TO ROLE H360_ANALYST;
GRANT USAGE ON PROCEDURE HOSPITAL360_ML.MONITORING.SP_RUN_DATA_QUALITY_CHECKS()
    TO ROLE H360_EXEC;
