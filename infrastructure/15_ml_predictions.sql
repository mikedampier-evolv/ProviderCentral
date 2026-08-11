-- =============================================================================
-- Hospital360 Demo: ML Prediction Generation & Materialization (Week 4)
-- =============================================================================
-- Run as: SYSADMIN on H360_ML_WH
-- Prerequisite: 14_ml_models.sql executed (models trained/created)
--
-- IMPORTANT Cortex ML patterns used here:
--   1. FORECAST: Just call !FORECAST(FORECASTING_PERIODS => N) — no input data needed
--   2. ANOMALY_DETECTION: Must retrain on first portion of data, then
--      call !DETECT_ANOMALIES on the latter portion (timestamps must be AFTER
--      the last training timestamp). We use a train/test split approach.
--   3. TOP_INSIGHTS: Call !GET_DRIVERS with SYSTEM$REFERENCE for view inputs.
--      Returns contributor segments with control/test metrics and growth rates.
--
-- Temp tables:
--   The anomaly detection workflow requires materializing train/test splits
--   into temp tables. These are dropped after prediction generation.
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_ML_WH;

-- =============================================================================
-- Prediction 1: PRED_ENCOUNTER_VOLUME
-- 90-day forecast of daily encounter volumes by type (Jan-Mar 2025)
-- =============================================================================
CREATE OR REPLACE TABLE HOSPITAL360_ML.PREDICTIONS.PRED_ENCOUNTER_VOLUME AS
SELECT
    SERIES::VARCHAR          AS ENCOUNTER_TYPE,
    TS::TIMESTAMP_NTZ        AS FORECAST_DATE,
    ROUND(FORECAST, 0)       AS FORECAST_COUNT,
    ROUND(LOWER_BOUND, 0)    AS LOWER_BOUND,
    ROUND(UPPER_BOUND, 0)    AS UPPER_BOUND,
    CURRENT_TIMESTAMP()      AS MODEL_RUN_TS
FROM TABLE(HOSPITAL360_ML.MODELS.FORECAST_ENCOUNTER_VOLUME!FORECAST(
    FORECASTING_PERIODS => 90
));

-- =============================================================================
-- Prediction 2: PRED_DENIAL_ANOMALIES
-- Anomaly detection on last 6 months of daily denial volumes
-- Note: The anomaly detection model in 14_ml_models.sql is trained on the
--       FIRST 12 months. We detect anomalies on the LAST 6 months here.
--       DETECT_ANOMALIES requires all evaluation timestamps to be strictly
--       AFTER the last timestamp in the training data.
-- =============================================================================

-- Step 2a: Materialize recent 6 months for anomaly detection input
CREATE OR REPLACE TEMPORARY TABLE HOSPITAL360_ML.FEATURES.TMP_RECENT_DENIALS AS
SELECT TS, DENIAL_CATEGORY, DENIAL_COUNT
FROM HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME
WHERE TS >= DATEADD(MONTH, -6, (SELECT MAX(TS) FROM HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME));

-- Step 2b: Run anomaly detection and join back actuals
CREATE OR REPLACE TABLE HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES AS
SELECT
    r.SERIES::VARCHAR           AS DENIAL_CATEGORY,
    r.TS::TIMESTAMP_NTZ         AS TS,
    ROUND(r.FORECAST, 0)        AS EXPECTED_COUNT,
    ROUND(r.LOWER_BOUND, 0)     AS LOWER_BOUND,
    ROUND(r.UPPER_BOUND, 0)     AS UPPER_BOUND,
    r.IS_ANOMALY::BOOLEAN       AS IS_ANOMALY,
    ROUND(r.PERCENTILE, 4)      AS PERCENTILE,
    d.DENIAL_COUNT              AS ACTUAL_COUNT,
    d.DENIED_CHARGES            AS ACTUAL_CHARGES,
    CURRENT_TIMESTAMP()         AS MODEL_RUN_TS
FROM TABLE(HOSPITAL360_ML.MODELS.ANOMALY_DENIAL_VOLUME!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'HOSPITAL360_ML.FEATURES.TMP_RECENT_DENIALS'),
    SERIES_COLNAME => 'DENIAL_CATEGORY',
    TIMESTAMP_COLNAME => 'TS',
    TARGET_COLNAME => 'DENIAL_COUNT'
)) r
LEFT JOIN HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME d
    ON r.SERIES = d.DENIAL_CATEGORY
    AND r.TS = d.TS;

-- =============================================================================
-- Prediction 3: PRED_READMISSION_DRIVERS
-- Top Insights: key drivers of readmission rate changes (recent vs prior)
-- =============================================================================
CREATE OR REPLACE TABLE HOSPITAL360_ML.PREDICTIONS.PRED_READMISSION_DRIVERS AS
SELECT
    res.*,
    CURRENT_TIMESTAMP() AS MODEL_RUN_TS
FROM TABLE(HOSPITAL360_ML.MODELS.INSIGHTS_READMISSION!GET_DRIVERS(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'HOSPITAL360_ML.FEATURES.VW_READMISSION_DRIVERS'),
    LABEL_COLNAME => 'LABEL',
    METRIC_COLNAME => 'READMIT_METRIC'
)) res;

-- =============================================================================
-- Prediction 4: PRED_LEAKAGE_DRIVERS
-- Top Insights: key drivers of referral leakage changes (recent vs prior)
-- =============================================================================
CREATE OR REPLACE TABLE HOSPITAL360_ML.PREDICTIONS.PRED_LEAKAGE_DRIVERS AS
SELECT
    res.*,
    CURRENT_TIMESTAMP() AS MODEL_RUN_TS
FROM TABLE(HOSPITAL360_ML.MODELS.INSIGHTS_LEAKAGE!GET_DRIVERS(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'HOSPITAL360_ML.FEATURES.VW_LEAKAGE_DRIVERS'),
    LABEL_COLNAME => 'LABEL',
    METRIC_COLNAME => 'LEAKAGE_METRIC'
)) res;
