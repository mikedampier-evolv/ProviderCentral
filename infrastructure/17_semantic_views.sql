/*==============================================================================
  HOSPITAL 360 — Week 6: Semantic Views
  Unified Semantic View for Cortex Analyst
  
  Creates a single semantic view spanning 4 use-case marts + 2 ML prediction
  tables with relationships, facts, dimensions, metrics, custom instructions,
  and 12 verified queries.
  
  Target: HOSPITAL360_APP.SEMANTIC_VIEWS.HOSPITAL360_ANALYTICS
  
  IMPORTANT DDL SYNTAX NOTE:
    In CREATE SEMANTIC VIEW, fact/dimension declarations use:
      TABLE.SEMANTIC_NAME AS PHYSICAL_COLUMN_OR_EXPRESSION
    NOT the reverse. The part after the dot is the semantic alias exposed
    to Cortex Analyst; the AS part is the actual column name in the base table.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;
USE SCHEMA HOSPITAL360_APP.SEMANTIC_VIEWS;

CREATE OR REPLACE SEMANTIC VIEW HOSPITAL360_ANALYTICS
    tables (
        readmissions AS HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS unique (ENCOUNTER_ID),
        leakage AS HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE unique (REFERRAL_ID),
        or_cases AS HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY unique (CASE_ID),
        denials AS HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE unique (CLAIM_LINE_SK),
        encounter_forecast AS HOSPITAL360_ML.PREDICTIONS.PRED_ENCOUNTER_VOLUME,
        denial_anomalies AS HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES
    )
    relationships (
        denials (ENCOUNTER_ID) REFERENCES readmissions (ENCOUNTER_ID),
        or_cases (ENCOUNTER_ID) REFERENCES readmissions (ENCOUNTER_ID)
    )
    facts (
        -- Readmissions
        readmissions.LOS_DAYS AS LOS_DAYS comment = 'Actual length of stay in days',
        readmissions.EXPECTED_LOS AS EXPECTED_LOS comment = 'Expected LOS based on DRG benchmark',
        readmissions.LOS_VARIANCE AS LOS_VARIANCE comment = 'Actual minus expected LOS',
        readmissions.LOS_INDEX AS LOS_INDEX comment = 'Ratio of actual to expected LOS',
        readmissions.DRG_WEIGHT AS DRG_WEIGHT comment = 'DRG case-mix weight',
        readmissions.TOTAL_CHARGES AS TOTAL_CHARGES comment = 'Total charges for encounter',
        readmissions.TOTAL_COST AS TOTAL_COST comment = 'Total cost for encounter',
        readmissions.TOTAL_PAYMENTS AS TOTAL_PAYMENTS comment = 'Total payments received',
        readmissions.COST_PER_DAY AS COST_PER_DAY comment = 'Average cost per day',
        readmissions.NET_REVENUE AS NET_REVENUE comment = 'Payments minus cost',
        readmissions.PATIENT_AGE AS PATIENT_AGE comment = 'Patient age at admission',
        readmissions.HCC_SCORE AS HCC_SCORE comment = 'HCC risk score',
        -- Leakage
        leakage.EXPECTED_REVENUE AS EXPECTED_REVENUE comment = 'Expected revenue from referral',
        leakage.LOST_REVENUE AS LOST_REVENUE comment = 'Revenue lost to leakage',
        leakage.DAYS_SINCE_REFERRAL AS DAYS_SINCE_REFERRAL comment = 'Days since referral created',
        -- OR Capacity
        or_cases.DELAY_MINUTES AS DELAY_MINUTES comment = 'Delay from scheduled to actual start',
        or_cases.CASE_MINUTES AS CASE_MINUTES comment = 'Total surgical case duration',
        or_cases.TURNOVER_MINUTES AS TURNOVER_MINUTES comment = 'Room turnover time',
        or_cases.BLOCK_MINUTES AS BLOCK_MINUTES comment = 'Total allocated block time',
        or_cases.UTILIZATION_PCT AS UTILIZATION_PCT comment = 'OR block utilization 0-1 scale',
        -- Denials
        denials.CHARGE_AMT AS CHARGE_AMT comment = 'Denied charge amount USD',
        denials.ALLOWED_AMT AS ALLOWED_AMT comment = 'Payer allowed amount USD',
        denials.DAYS_TO_FILE AS DAYS_TO_FILE comment = 'Days from service to filing',
        denials.ESTIMATED_RECOVERY AS ESTIMATED_RECOVERY comment = 'Estimated recovery if appealed',
        -- Forecast (semantic names differ from physical to avoid collision)
        encounter_forecast.FORECAST_COUNT AS FORECAST_COUNT comment = 'Forecasted daily encounter count',
        encounter_forecast.FORECAST_LOWER AS LOWER_BOUND comment = 'Forecast lower confidence bound',
        encounter_forecast.FORECAST_UPPER AS UPPER_BOUND comment = 'Forecast upper confidence bound',
        -- Anomaly Detection
        denial_anomalies.ANOM_EXPECTED_COUNT AS EXPECTED_COUNT comment = 'Expected daily denial count',
        denial_anomalies.ANOM_ACTUAL_COUNT AS ACTUAL_COUNT comment = 'Actual daily denial count',
        denial_anomalies.ANOM_ACTUAL_CHARGES AS ACTUAL_CHARGES comment = 'Actual daily denied charges',
        denial_anomalies.ANOM_PERCENTILE AS PERCENTILE comment = 'Statistical percentile'
    )
    dimensions (
        -- Readmissions
        readmissions.ENCOUNTER_ID AS ENCOUNTER_ID comment = 'Unique encounter identifier',
        readmissions.READMIT_MRN AS MRN comment = 'Medical record number',
        readmissions.ENCOUNTER_TYPE AS ENCOUNTER_TYPE comment = 'INPATIENT or OBSERVATION',
        readmissions.READMIT_PAYER_TYPE AS PAYER_TYPE comment = 'Payer category',
        readmissions.READMIT_PAYER_NAME AS PAYER_NAME comment = 'Payer organization name',
        readmissions.READMIT_FACILITY AS FACILITY_NAME comment = 'Hospital facility name',
        readmissions.DEPT_NAME AS DEPT_NAME comment = 'Department name',
        readmissions.READMIT_SPECIALTY AS SPECIALTY comment = 'Attending specialty',
        readmissions.ATTENDING_PROVIDER AS ATTENDING_PROVIDER comment = 'Attending physician',
        readmissions.DRG_CODE AS DRG_CODE comment = 'DRG code',
        readmissions.DRG_DESCRIPTION AS DRG_DESCRIPTION comment = 'DRG text description',
        readmissions.MDC_DESCRIPTION AS MDC_DESCRIPTION comment = 'Major Diagnostic Category',
        readmissions.DISCHARGE_DISPOSITION AS DISCHARGE_DISPOSITION comment = 'Discharge destination',
        readmissions.PATIENT_GENDER AS PATIENT_GENDER comment = 'Patient gender',
        readmissions.IS_LONG_STAY AS IS_LONG_STAY comment = 'TRUE if LOS exceeds expected by 50 pct',
        readmissions.READMIT_30_FLAG AS READMIT_30_FLAG comment = 'TRUE if readmitted within 30 days',
        readmissions.ADMIT_DATE AS ADMIT_DATE comment = 'Admission date',
        readmissions.ADMIT_MONTH AS ADMIT_MONTH comment = 'First day of admission month',
        -- Leakage
        leakage.REFERRAL_ID AS REFERRAL_ID comment = 'Unique referral identifier',
        leakage.REFERRING_PROVIDER AS REFERRING_PROVIDER comment = 'Referring provider name',
        leakage.REFERRING_SPECIALTY AS REFERRING_SPECIALTY comment = 'Referring specialty',
        leakage.REFERRED_TO_SPECIALTY AS REFERRED_TO_SPECIALTY comment = 'Specialty referred to',
        leakage.LEAKAGE_FACILITY AS FACILITY_NAME comment = 'Referring facility',
        leakage.LEAKAGE_PAYER_TYPE AS PATIENT_PAYER_TYPE comment = 'Patient payer category',
        leakage.REFERRAL_STATUS AS STATUS comment = 'COMPLETED or PENDING',
        leakage.LEAKAGE_FLAG AS LEAKAGE_FLAG comment = 'TRUE if patient went external',
        leakage.IS_HIGH_VALUE AS IS_HIGH_VALUE comment = 'TRUE if high expected revenue',
        leakage.REFERRAL_DATE AS REFERRAL_DATE comment = 'Referral creation date',
        leakage.REFERRAL_MONTH AS REFERRAL_MONTH comment = 'First day of referral month',
        leakage.REFERRAL_QUARTER AS REFERRAL_QUARTER comment = 'Referral quarter',
        -- OR Capacity
        or_cases.CASE_ID AS CASE_ID comment = 'Unique surgical case ID',
        or_cases.OR_FACILITY AS FACILITY_NAME comment = 'Surgical facility name',
        or_cases.SURGEON_NAME AS SURGEON_NAME comment = 'Operating surgeon',
        or_cases.OR_SPECIALTY AS SPECIALTY comment = 'Surgical specialty',
        or_cases.BLOCK_NAME AS BLOCK_NAME comment = 'OR block name A-F',
        or_cases.CASE_DAY_OF_WEEK AS CASE_DAY_OF_WEEK comment = 'Day of week',
        or_cases.CASE_CLASS AS CASE_CLASS comment = 'ELECTIVE or URGENT',
        or_cases.ASA_CLASS AS ASA_CLASS comment = 'ASA physical status I-V',
        or_cases.FIRST_CASE_ON_TIME AS FIRST_CASE_ON_TIME comment = 'TRUE if first case on time',
        or_cases.IS_UNDERUTILIZED AS IS_UNDERUTILIZED comment = 'TRUE if utilization below 60 pct',
        or_cases.IS_OVERTIME AS IS_OVERTIME comment = 'TRUE if ran past block end',
        or_cases.PRIME_TIME_FLAG AS PRIME_TIME_FLAG comment = 'TRUE if prime-time hours',
        or_cases.CASE_DATE AS CASE_DATE comment = 'Surgical case date',
        or_cases.CASE_MONTH AS CASE_MONTH comment = 'First day of case month',
        -- Denials
        denials.CLAIM_LINE_SK AS CLAIM_LINE_SK comment = 'Claim line surrogate key',
        denials.CLAIM_ID AS CLAIM_ID comment = 'Claim identifier',
        denials.DENIAL_ENCOUNTER_ID AS ENCOUNTER_ID comment = 'Encounter for denied claim',
        denials.DENIAL_PAYER_NAME AS PAYER_NAME comment = 'Payer name for denial',
        denials.DENIAL_PAYER_TYPE AS PAYER_TYPE comment = 'Payer type for denial',
        denials.DENIAL_CATEGORY AS DENIAL_CATEGORY comment = 'Denial category',
        denials.DENIAL_REASON AS DENIAL_REASON comment = 'Specific denial reason',
        denials.CLAIM_STATUS AS CLAIM_STATUS comment = 'Claim processing status',
        denials.IS_APPEALED AS IS_APPEALED comment = 'TRUE if appealed',
        denials.APPEAL_OUTCOME AS APPEAL_OUTCOME comment = 'WON or LOST',
        denials.CPT_CATEGORY AS CPT_CATEGORY comment = 'CPT grouping',
        denials.IS_TIMELY_FILED AS IS_TIMELY_FILED comment = 'TRUE if filed timely',
        denials.SERVICE_DATE AS SERVICE_DATE comment = 'Service date',
        denials.SERVICE_MONTH AS SERVICE_MONTH comment = 'First day of service month',
        -- Forecast
        encounter_forecast.FORECAST_ENCOUNTER_TYPE AS ENCOUNTER_TYPE comment = 'Forecasted encounter type',
        encounter_forecast.FORECAST_DATE AS FORECAST_DATE comment = 'Forecasted date',
        -- Anomaly Detection
        denial_anomalies.ANOMALY_CATEGORY AS DENIAL_CATEGORY comment = 'Anomaly denial category',
        denial_anomalies.ANOMALY_DATE AS TS comment = 'Anomaly observation date',
        denial_anomalies.IS_ANOMALY AS IS_ANOMALY comment = 'TRUE if anomalous'
    )
    metrics (
        -- Readmissions
        readmissions.READMISSION_RATE AS AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100
            comment = '30-day readmission rate pct',
        readmissions.AVG_LOS_INDEX AS AVG(LOS_INDEX) comment = 'Average LOS index',
        readmissions.LONG_STAY_PCT AS AVG(CASE WHEN IS_LONG_STAY THEN 1 ELSE 0 END) * 100
            comment = 'Long stay percentage',
        readmissions.ENCOUNTER_COUNT AS COUNT(ENCOUNTER_ID) comment = 'Total encounters',
        readmissions.AVG_COST_PER_DAY AS AVG(COST_PER_DAY) comment = 'Average cost per day',
        readmissions.TOTAL_NET_REVENUE AS SUM(NET_REVENUE) comment = 'Total net revenue',
        -- Leakage
        leakage.LEAKAGE_RATE AS AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100
            comment = 'Leakage rate pct',
        leakage.TOTAL_LOST_REVENUE AS SUM(LOST_REVENUE) comment = 'Total lost revenue USD',
        leakage.REFERRAL_COUNT AS COUNT(REFERRAL_ID) comment = 'Total referrals',
        leakage.HIGH_VALUE_LEAK_COUNT AS SUM(CASE WHEN LEAKAGE_FLAG AND IS_HIGH_VALUE THEN 1 ELSE 0 END)
            comment = 'High-value leakage count',
        -- OR Capacity
        or_cases.AVG_UTILIZATION AS AVG(UTILIZATION_PCT) * 100 comment = 'Average OR utilization pct',
        or_cases.FIRST_CASE_ON_TIME_PCT AS AVG(CASE WHEN FIRST_CASE_ON_TIME THEN 1 ELSE 0 END) * 100
            comment = 'First case on time pct',
        or_cases.AVG_DELAY_MINUTES AS AVG(DELAY_MINUTES) comment = 'Average delay minutes',
        or_cases.CASE_COUNT AS COUNT(CASE_ID) comment = 'Total surgical cases',
        -- Denials
        denials.TOTAL_DENIED_CHARGES AS SUM(CHARGE_AMT) comment = 'Total denied charges USD',
        denials.APPEAL_RATE AS AVG(CASE WHEN IS_APPEALED THEN 1 ELSE 0 END) * 100
            comment = 'Appeal rate pct',
        denials.TIMELY_FILING_PCT AS AVG(CASE WHEN IS_TIMELY_FILED THEN 1 ELSE 0 END) * 100
            comment = 'Timely filing pct',
        denials.DENIED_CLAIM_COUNT AS COUNT(CLAIM_LINE_SK) comment = 'Total denied claim lines'
    )
    comment = 'Hospital 360 unified analytics covering readmission LOS analysis, patient leakage, OR capacity, claim denials, encounter forecasting, and denial anomaly detection across 5 facilities from July 2023 through December 2024.'
    ai_sql_generation 'Hospital 360 analytics across 4 clinical and financial domains plus ML predictions. TABLES: readmissions (106625 rows, PK ENCOUNTER_ID), leakage (48375, PK REFERRAL_ID), or_cases (30000, PK CASE_ID), denials (115905, PK CLAIM_LINE_SK), encounter_forecast (360 rows), denial_anomalies (736 rows). RELATIONSHIPS: denials joins readmissions on ENCOUNTER_ID (63788 overlap), or_cases joins readmissions on ENCOUNTER_ID. KEY VALUES: 5 Facilities, 6 Payer Types, 4 Denial Categories, 6 OR Blocks A-F, Appeal Outcomes WON/LOST. NOTES: UTILIZATION_PCT is 0-1 scale multiply by 100 for percentage. Boolean flags use CASE WHEN or COUNT_IF. Monthly trending columns truncated to first of month. Forecast range Dec 31 2024 to Mar 30 2025. Use fully qualified physical table names in generated SQL.'
    ai_verified_queries (
        READMISSION_RATE_BY_FACILITY AS (
            QUESTION 'What is the 30-day readmission rate by facility?'
            ONBOARDING_QUESTION true
            SQL 'SELECT FACILITY_NAME, COUNT(*) AS TOTAL_ENCOUNTERS, COUNT_IF(READMIT_30_FLAG) AS READMISSIONS, ROUND(COUNT_IF(READMIT_30_FLAG) / COUNT(*) * 100, 1) AS READMISSION_RATE_PCT FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS GROUP BY FACILITY_NAME ORDER BY READMISSION_RATE_PCT DESC'
        ),
        MONTHLY_READMISSION_TREND AS (
            QUESTION 'What is the monthly readmission rate trend?'
            ONBOARDING_QUESTION false
            SQL 'SELECT ADMIT_MONTH, COUNT(*) AS ENCOUNTERS, COUNT_IF(READMIT_30_FLAG) AS READMISSIONS, ROUND(COUNT_IF(READMIT_30_FLAG) / COUNT(*) * 100, 1) AS READMISSION_RATE_PCT FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS GROUP BY ADMIT_MONTH ORDER BY ADMIT_MONTH'
        ),
        TOP_DRGS_BY_READMISSION AS (
            QUESTION 'Which DRGs have the highest readmission rate?'
            ONBOARDING_QUESTION false
            SQL 'SELECT DRG_DESCRIPTION, COUNT(*) AS ENCOUNTERS, COUNT_IF(READMIT_30_FLAG) AS READMISSIONS, ROUND(COUNT_IF(READMIT_30_FLAG) / COUNT(*) * 100, 1) AS READMISSION_RATE_PCT FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS GROUP BY DRG_DESCRIPTION HAVING COUNT(*) >= 100 ORDER BY READMISSION_RATE_PCT DESC LIMIT 10'
        ),
        LEAKAGE_RATE_BY_SPECIALTY AS (
            QUESTION 'What is the patient leakage rate by referring specialty?'
            ONBOARDING_QUESTION true
            SQL 'SELECT REFERRING_SPECIALTY, COUNT(*) AS TOTAL_REFERRALS, COUNT_IF(LEAKAGE_FLAG) AS LEAKED, ROUND(COUNT_IF(LEAKAGE_FLAG) / COUNT(*) * 100, 1) AS LEAKAGE_RATE_PCT, ROUND(SUM(LOST_REVENUE), 0) AS TOTAL_LOST_REVENUE FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE GROUP BY REFERRING_SPECIALTY ORDER BY TOTAL_LOST_REVENUE DESC'
        ),
        TOTAL_LOST_REVENUE AS (
            QUESTION 'How much revenue was lost to patient leakage?'
            ONBOARDING_QUESTION false
            SQL 'SELECT ROUND(SUM(LOST_REVENUE), 0) AS TOTAL_LOST_REVENUE, COUNT_IF(LEAKAGE_FLAG) AS LEAKED_REFERRALS, COUNT(*) AS TOTAL_REFERRALS, ROUND(COUNT_IF(LEAKAGE_FLAG) / COUNT(*) * 100, 1) AS LEAKAGE_RATE_PCT FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE'
        ),
        OR_UTILIZATION_BY_BLOCK AS (
            QUESTION 'What is the OR utilization by block?'
            ONBOARDING_QUESTION true
            SQL 'SELECT BLOCK_NAME, COUNT(*) AS CASES, ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS AVG_UTILIZATION_PCT FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY GROUP BY BLOCK_NAME ORDER BY BLOCK_NAME'
        ),
        DENIALS_BY_CATEGORY AS (
            QUESTION 'What are the total denied charges by denial category?'
            ONBOARDING_QUESTION true
            SQL 'SELECT DENIAL_CATEGORY, COUNT(*) AS DENIED_CLAIMS, ROUND(SUM(CHARGE_AMT), 0) AS TOTAL_DENIED_CHARGES FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE GROUP BY DENIAL_CATEGORY ORDER BY TOTAL_DENIED_CHARGES DESC'
        ),
        APPEAL_SUCCESS_RATE AS (
            QUESTION 'What is the appeal success rate by denial category?'
            ONBOARDING_QUESTION false
            SQL 'SELECT DENIAL_CATEGORY, COUNT(*) AS APPEALS_FILED, COUNT_IF(APPEAL_OUTCOME = ''WON'') AS APPEALS_WON, ROUND(COUNT_IF(APPEAL_OUTCOME = ''WON'') / COUNT(*) * 100, 1) AS WIN_RATE_PCT FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE WHERE IS_APPEALED = TRUE GROUP BY DENIAL_CATEGORY ORDER BY WIN_RATE_PCT DESC'
        ),
        ENCOUNTER_FORECAST AS (
            QUESTION 'Show the encounter volume forecast for the next 90 days'
            ONBOARDING_QUESTION false
            SQL 'SELECT ENCOUNTER_TYPE, FORECAST_DATE::DATE AS FORECAST_DATE, ROUND(FORECAST_COUNT, 0) AS FORECAST_COUNT, ROUND(LOWER_BOUND, 0) AS LOWER_BOUND, ROUND(UPPER_BOUND, 0) AS UPPER_BOUND FROM HOSPITAL360_ML.PREDICTIONS.PRED_ENCOUNTER_VOLUME ORDER BY ENCOUNTER_TYPE, FORECAST_DATE'
        ),
        DENIAL_ANOMALIES AS (
            QUESTION 'Which denial categories have anomalies detected?'
            ONBOARDING_QUESTION false
            SQL 'SELECT DENIAL_CATEGORY, TS::DATE AS ANOMALY_DATE, ACTUAL_COUNT, ROUND(EXPECTED_COUNT, 0) AS EXPECTED_COUNT, IS_ANOMALY FROM HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES WHERE IS_ANOMALY = TRUE ORDER BY TS'
        ),
        FACILITY_PERFORMANCE AS (
            QUESTION 'Show me a facility performance summary'
            ONBOARDING_QUESTION false
            SQL 'SELECT FACILITY_NAME, COUNT(*) AS ENCOUNTERS, ROUND(COUNT_IF(READMIT_30_FLAG) / COUNT(*) * 100, 1) AS READMISSION_RATE_PCT, ROUND(AVG(LOS_INDEX), 2) AS AVG_LOS_INDEX FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS GROUP BY FACILITY_NAME ORDER BY ENCOUNTERS DESC'
        ),
        UNDERUTILIZED_BLOCKS AS (
            QUESTION 'Which OR blocks are underutilized?'
            ONBOARDING_QUESTION false
            SQL 'SELECT BLOCK_NAME, FACILITY_NAME, ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS AVG_UTILIZATION_PCT, COUNT_IF(IS_UNDERUTILIZED) AS UNDERUTILIZED_CASES FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY GROUP BY BLOCK_NAME, FACILITY_NAME HAVING AVG(UTILIZATION_PCT) < 0.7 ORDER BY AVG_UTILIZATION_PCT'
        )
    )
;

-- Verify creation
SHOW SEMANTIC VIEWS IN SCHEMA HOSPITAL360_APP.SEMANTIC_VIEWS;
DESCRIBE SEMANTIC VIEW HOSPITAL360_APP.SEMANTIC_VIEWS.HOSPITAL360_ANALYTICS;
