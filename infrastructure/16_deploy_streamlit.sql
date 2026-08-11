/*============================================================================
  Hospital 360 — Week 5: Streamlit-in-Snowflake Deployment
  
  This script:
    1. Creates an internal stage for Streamlit source files
    2. Creates the Streamlit app (warehouse runtime)
    3. Grants USAGE to all H360 roles
  
  Prerequisites:
    - Run as SYSADMIN (owns HOSPITAL360_APP.STREAMLIT schema)
    - H360_BI_WH warehouse must exist
    - Files must be staged via PUT before CREATE STREAMLIT
  
  File staging (run from SnowSQL or Snowflake CLI):
    PUT file://streamlit/environment.yml @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/streamlit_app.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/pages/1_readmission_los.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/pages/2_patient_leakage.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/pages/3_or_capacity.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/pages/4_denials_revcycle.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    PUT file://streamlit/pages/5_ml_insights.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;

-- -------------------------------------------------------------------------
-- 1. Internal stage for Streamlit files
-- -------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage for Hospital 360 Streamlit app source files';

-- -------------------------------------------------------------------------
-- 2. Create the Streamlit application (warehouse runtime)
--    Omitting RUNTIME_NAME and COMPUTE_POOL = warehouse runtime
-- -------------------------------------------------------------------------
CREATE OR REPLACE STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    FROM '@HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = H360_BI_WH
    TITLE = 'Hospital 360 Dashboard'
    COMMENT = 'Hospital 360 multi-page analytics dashboard — Executive Summary, Readmission & LOS, Patient Leakage, OR Capacity, Denials & RevCycle, ML Insights';

-- -------------------------------------------------------------------------
-- 3. Grant USAGE to all H360 analytical roles
-- -------------------------------------------------------------------------
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_ANALYST;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_CLINICIAN;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_EXEC;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_FINANCE;

-- -------------------------------------------------------------------------
-- 4. Validation queries (run after deployment)
-- -------------------------------------------------------------------------
-- SHOW STREAMLITS IN SCHEMA HOSPITAL360_APP.STREAMLIT;
-- DESCRIBE STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD;
-- LIST @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES;
