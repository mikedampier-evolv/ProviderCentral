-- =============================================================================
-- Hospital360 Demo: Cortex ML Model Creation (Week 4)
-- =============================================================================
-- Run as: SYSADMIN on H360_ML_WH
-- Prerequisite: 13_ml_feature_views.sql executed
-- Note: Forecast and Anomaly Detection training takes 1-3 minutes each.
--       Top Insights models are stateless (instant creation).
-- Important: Use SYSTEM$REFERENCE for input data, and TS (not DATE) for
--            timestamp columns to avoid reserved-word issues with Cortex ML.
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_ML_WH;

-- =============================================================================
-- Model 1: FORECAST_ENCOUNTER_VOLUME
-- Type: SNOWFLAKE.ML.FORECAST (multi-series)
-- Purpose: Forecast daily encounter volumes by type for 90 days
-- Input: VW_DAILY_ENCOUNTER_VOLUME (548 days × 4 series)
-- =============================================================================
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST HOSPITAL360_ML.MODELS.FORECAST_ENCOUNTER_VOLUME(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'HOSPITAL360_ML.FEATURES.VW_DAILY_ENCOUNTER_VOLUME'),
    SERIES_COLNAME => 'ENCOUNTER_TYPE',
    TIMESTAMP_COLNAME => 'TS',
    TARGET_COLNAME => 'ENCOUNTER_COUNT'
);

-- =============================================================================
-- Model 2: ANOMALY_DENIAL_VOLUME
-- Type: SNOWFLAKE.ML.ANOMALY_DETECTION (multi-series, unsupervised)
-- Purpose: Detect anomalous daily denial volumes by category
-- Input: FIRST 12 months of denial data (train set)
-- Note: DETECT_ANOMALIES requires evaluation timestamps AFTER training data.
--       We train on months 1-12 and detect anomalies on months 13-18.
--       The training data must be materialized — views cause empty-input errors.
-- Label: '' (no labeled anomalies — unsupervised)
-- =============================================================================

-- Materialize training data (first 12 months)
CREATE OR REPLACE TEMPORARY TABLE HOSPITAL360_ML.FEATURES.TMP_DENIAL_TRAIN AS
SELECT TS, DENIAL_CATEGORY, DENIAL_COUNT
FROM HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME
WHERE TS < DATEADD(MONTH, -6, (SELECT MAX(TS) FROM HOSPITAL360_ML.FEATURES.VW_DAILY_DENIAL_VOLUME));

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION HOSPITAL360_ML.MODELS.ANOMALY_DENIAL_VOLUME(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'HOSPITAL360_ML.FEATURES.TMP_DENIAL_TRAIN'),
    SERIES_COLNAME => 'DENIAL_CATEGORY',
    TIMESTAMP_COLNAME => 'TS',
    TARGET_COLNAME => 'DENIAL_COUNT',
    LABEL_COLNAME => ''
);

-- =============================================================================
-- Model 3: INSIGHTS_READMISSION
-- Type: SNOWFLAKE.ML.TOP_INSIGHTS (stateless — no training data)
-- Purpose: Identify key drivers of readmission rate changes
-- =============================================================================
CREATE OR REPLACE SNOWFLAKE.ML.TOP_INSIGHTS HOSPITAL360_ML.MODELS.INSIGHTS_READMISSION();

-- =============================================================================
-- Model 4: INSIGHTS_LEAKAGE
-- Type: SNOWFLAKE.ML.TOP_INSIGHTS (stateless — no training data)
-- Purpose: Identify key drivers of referral leakage changes
-- =============================================================================
CREATE OR REPLACE SNOWFLAKE.ML.TOP_INSIGHTS HOSPITAL360_ML.MODELS.INSIGHTS_LEAKAGE();
