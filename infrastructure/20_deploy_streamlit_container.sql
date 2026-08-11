/*==============================================================================
  HOSPITAL 360 — Week 7: Deploy Streamlit with Container Runtime
  
  Converts the Streamlit app from warehouse runtime to container runtime
  to enable Cortex Agent API calls from within the app.
  
  Container runtime requires:
    - COMPUTE_POOL parameter
    - RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11'
    - requirements.txt instead of environment.yml
    - External Access Integration (EAI) for PyPI package installation
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE H360_BI_WH;

-- ---------------------------------------------------------------------------
-- 0. PyPI External Access (container runtime needs outbound to PyPI)
-- ---------------------------------------------------------------------------
-- Network rule: run as SYSADMIN (or role that owns HOSPITAL360_APP)
CREATE NETWORK RULE IF NOT EXISTS HOSPITAL360_APP.STREAMLIT.PYPI_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org', 'files.pythonhosted.org')
  COMMENT = 'Allow container runtime to install Python packages from PyPI';

-- EAI: requires ACCOUNTADMIN or a role with CREATE INTEGRATION privilege
USE ROLE ACCOUNTADMIN;
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS H360_PYPI_ACCESS
  ALLOWED_NETWORK_RULES = (HOSPITAL360_APP.STREAMLIT.PYPI_NETWORK_RULE)
  ENABLED = TRUE
  COMMENT = 'Hospital 360: PyPI access for container runtime Streamlit packages';
GRANT USAGE ON INTEGRATION H360_PYPI_ACCESS TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- 1. Upload new/updated files to stage
-- ---------------------------------------------------------------------------
-- Run from terminal:
--   cd streamlit
--   snow stage put requirements.txt @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/ --overwrite --connection SLALOM-SNOWFLAKE_ILABS_EMERGEPR
--   snow stage put pages/7_cortex_agent.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/pages/ --overwrite --connection SLALOM-SNOWFLAKE_ILABS_EMERGEPR
--   snow stage put streamlit_app.py @HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES/ --overwrite --connection SLALOM-SNOWFLAKE_ILABS_EMERGEPR

-- ---------------------------------------------------------------------------
-- 2. Recreate Streamlit with container runtime
-- ---------------------------------------------------------------------------
CREATE OR REPLACE STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    FROM '@HOSPITAL360_APP.STREAMLIT.STG_STREAMLIT_FILES'
    MAIN_FILE = 'streamlit_app.py'
    RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11'
    COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU
    QUERY_WAREHOUSE = H360_BI_WH
    EXTERNAL_ACCESS_INTEGRATIONS = (H360_PYPI_ACCESS)
    TITLE = 'Hospital 360 Dashboard'
    COMMENT = 'Hospital 360 multi-page analytics dashboard — Executive Summary, Readmission & LOS, Patient Leakage, OR Capacity, Denials & RevCycle, ML Insights, Cortex Analyst, Cortex Agent'
;

-- ---------------------------------------------------------------------------
-- 3. Push live version
-- ---------------------------------------------------------------------------
ALTER STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    ADD LIVE VERSION FROM LAST;

-- ---------------------------------------------------------------------------
-- 4. Re-grant access (CREATE OR REPLACE drops grants)
-- ---------------------------------------------------------------------------
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_ANALYST;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_CLINICIAN;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_EXEC;
GRANT USAGE ON STREAMLIT HOSPITAL360_APP.STREAMLIT.HOSPITAL360_DASHBOARD
    TO ROLE H360_FINANCE;
