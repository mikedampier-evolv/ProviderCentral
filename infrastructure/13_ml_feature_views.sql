-- =============================================================================
-- Hospital360 Demo: ML Feature Engineering Views (Week 4)
-- =============================================================================
-- Run as: SYSADMIN on H360_ML_WH
-- Prerequisite: All dims, facts, and marts populated (Weeks 2-3)
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_ML_WH;

-- =============================================================================
-- VW_DAILY_ENCOUNTER_VOLUME
-- Purpose: Daily encounter counts by type for Cortex ML Forecast
-- Shape: ~2,200 rows (548 days × 4 encounter types)
-- Required columns: TS (TIMESTAMP_NTZ), ENCOUNTER_TYPE (series), ENCOUNTER_COUNT
-- Note: Use TS not DATE — DATE is a reserved word that causes Cortex ML issues
-- =============================================================================
-- Note: Only include TS, series, and target columns — extra columns become
--       exogenous features that require future values at forecast time.
CREATE OR REPLACE VIEW HOSPITAL360_ML.FEATURES.VW_DAILY_ENCOUNTER_VOLUME AS
SELECT
    ADMIT_DATE::TIMESTAMP_NTZ AS TS,
    ENCOUNTER_TYPE,
    COUNT(*)                  AS ENCOUNTER_COUNT
FROM HOSPITAL360_CUR.CLINICAL.FCT_ENCOUNTER
GROUP BY ADMIT_DATE, ENCOUNTER_TYPE;

-- =============================================================================
-- VW_DAILY_DENIAL_VOLUME
-- Purpose: Daily denial counts by category for Cortex ML Anomaly Detection
-- Shape: ~2,200 rows (548 days × 4 denial categories)
-- Required columns: TS (TIMESTAMP_NTZ), DENIAL_CATEGORY (series), DENIAL_COUNT
-- Note: Use TS not DATE — DATE is a reserved word that causes Cortex ML issues
-- =============================================================================
CREATE OR REPLACE VIEW HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME AS
SELECT
    SERVICE_DATE::TIMESTAMP_NTZ AS TS,
    DENIAL_CATEGORY,
    COUNT(*)                    AS DENIAL_COUNT
FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
GROUP BY SERVICE_DATE, DENIAL_CATEGORY;

-- =============================================================================
-- VW_READMISSION_DRIVERS
-- Purpose: Encounter-level features for Top Insights on readmission drivers
-- Shape: ~106K rows (all IP/OBS encounters)
-- Label: IS_RECENT = TRUE for last 3 months of data (test group)
-- Metric: READMIT_30_FLAG cast to numeric for Top Insights
-- =============================================================================
CREATE OR REPLACE VIEW HOSPITAL360_ML.FEATURES.VW_READMISSION_DRIVERS AS
SELECT
    CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END AS READMIT_METRIC,
    DRG_CODE,
    PAYER_TYPE,
    PATIENT_GENDER,
    CASE
        WHEN PATIENT_AGE < 18  THEN 'PEDIATRIC'
        WHEN PATIENT_AGE < 40  THEN 'YOUNG_ADULT'
        WHEN PATIENT_AGE < 65  THEN 'ADULT'
        WHEN PATIENT_AGE < 80  THEN 'SENIOR'
        ELSE 'ELDERLY'
    END AS AGE_BUCKET,
    CASE
        WHEN HCC_SCORE IS NULL      THEN 'UNKNOWN'
        WHEN HCC_SCORE < 0.5        THEN 'LOW'
        WHEN HCC_SCORE < 1.0        THEN 'MODERATE'
        WHEN HCC_SCORE < 2.0        THEN 'HIGH'
        ELSE 'VERY_HIGH'
    END AS HCC_BUCKET,
    DEPT_NAME,
    ENCOUNTER_TYPE,
    IS_LONG_STAY::VARCHAR AS IS_LONG_STAY,
    FACILITY_NAME,
    DISCHARGE_DISPOSITION,
    -- Label: last 3 months = test group, rest = control
    ADMIT_MONTH >= DATEADD(MONTH, -3, (SELECT MAX(ADMIT_MONTH) FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS))
        AS LABEL
FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS;

-- =============================================================================
-- VW_LEAKAGE_DRIVERS
-- Purpose: Referral-level features for Top Insights on leakage drivers
-- Shape: ~48K rows (all referrals)
-- Label: IS_RECENT = TRUE for last quarter of data (test group)
-- Metric: LEAKAGE_FLAG cast to numeric for Top Insights
-- =============================================================================
CREATE OR REPLACE VIEW HOSPITAL360_ML.FEATURES.VW_LEAKAGE_DRIVERS AS
SELECT
    CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END AS LEAKAGE_METRIC,
    REFERRED_TO_SPECIALTY,
    REFERRING_SPECIALTY,
    PATIENT_PAYER_TYPE,
    SUBSTRING(PATIENT_ZIP, 1, 3) AS ZIP_PREFIX,
    IS_HIGH_VALUE::VARCHAR AS IS_HIGH_VALUE,
    FACILITY_NAME,
    STATUS,
    -- Label: last quarter = test group, rest = control
    REFERRAL_DATE >= DATEADD(MONTH, -3, (SELECT MAX(REFERRAL_DATE) FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE))
        AS LABEL
FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE;
