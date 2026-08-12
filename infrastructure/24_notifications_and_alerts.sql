/*==============================================================================
  HOSPITAL 360 — Notifications & Alerts

  Creates the two objects the React app's /api/email and /api/alert endpoints
  depend on. These were originally created ad hoc during deployment and were
  not captured in this repo, so a fresh environment had working dashboards but
  broken email and alerting.

    1. H360_EMAIL_INT   — account-level EMAIL notification integration, used by
                          SYSTEM$SEND_EMAIL in react-app/server/app.py
    2. <db>.ALERTS      — schema that /api/alert writes CREATE ALERT into

  ----------------------------------------------------------------------------
  SCHEMA LAYOUT NOTE
  ----------------------------------------------------------------------------
  Scripts 01-23 target the original five-database layout (HOSPITAL360_CUR,
  HOSPITAL360_ML, HOSPITAL360_APP). This script targets the *deployed* layout —
  a single HOSPITAL_360 database — because that is where the React app creates
  its alerts. See the "Deployment Reality" section of README.md.

  For the five-database layout, substitute:
      HOSPITAL_360.ALERTS  ->  HOSPITAL360_APP.ALERTS
      DEMO_WH              ->  H360_BI_WH
      UNIFAI_USER          ->  H360_ADMIN (and grant to the other H360_* roles)

  ----------------------------------------------------------------------------
  PRIVILEGES REQUIRED
  ----------------------------------------------------------------------------
  Sections 1 and 2 need ACCOUNTADMIN:
    - CREATE INTEGRATION is a global privilege
    - EXECUTE ALERT ON ACCOUNT can only be granted by ACCOUNTADMIN
  Section 3 needs ownership of the target database.

  ----------------------------------------------------------------------------
  IMPORTANT — EMAIL RECIPIENTS MUST BE VERIFIED ACCOUNT USERS
  ----------------------------------------------------------------------------
  Snowflake email notifications can only be delivered to email addresses that
  belong to a user in THIS account and that have been verified (via Snowsight,
  or SYSTEM$START_USER_EMAIL_VERIFICATION). Sending to an arbitrary outside
  address will fail regardless of the grants below.

  This matters for the demo: the chat widget lets an operator type any address
  into the "email this" box, and /api/alert accepts any address for the alert
  notification. Only verified account-user addresses will actually receive mail.
  Verify the demo presenters' addresses before a demo.
==============================================================================*/


-- =============================================================================
-- CONFIGURATION — edit these to match the target environment
-- =============================================================================
--   Database  : HOSPITAL_360      (SNOWFLAKE_DATABASE in react-app/.env)
--   Warehouse : DEMO_WH           (SNOWFLAKE_WAREHOUSE in react-app/.env)
--   App role  : UNIFAI_USER       (SNOWFLAKE_ROLE in react-app/.env)
-- =============================================================================


-- =============================================================================
-- SECTION 1: Email notification integration
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Option A (default) — any verified email address of a user in this account.
-- Preferred for a demo, where the recipient list is not known ahead of time.
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS H360_EMAIL_INT
    TYPE = EMAIL
    ENABLED = TRUE
    COMMENT = 'Provider Central — SYSTEM$SEND_EMAIL for chat exports and alert notifications';

-- Option B — restrict delivery to a fixed list. Every address listed must
-- already be verified, or CREATE NOTIFICATION INTEGRATION fails outright.
-- Uncomment and drop/recreate the integration if you need this restriction.
--
-- CREATE OR REPLACE NOTIFICATION INTEGRATION H360_EMAIL_INT
--     TYPE = EMAIL
--     ENABLED = TRUE
--     ALLOWED_RECIPIENTS = ('presenter@example.com', 'demo-team@example.com')
--     COMMENT = 'Provider Central — restricted recipient list';

-- The app role calls SYSTEM$SEND_EMAIL directly (/api/email) and also owns the
-- alerts that call it on a schedule, so it needs USAGE on the integration.
GRANT USAGE ON INTEGRATION H360_EMAIL_INT TO ROLE UNIFAI_USER;


-- =============================================================================
-- SECTION 2: Alert execution privilege (ACCOUNTADMIN only)
-- =============================================================================

-- Required to create and run alerts at all. Without this, CREATE ALERT in
-- /api/alert fails even though the schema-level grants in Section 3 are present.
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE UNIFAI_USER;

-- Alerts run on the warehouse named in the CREATE ALERT statement, which
-- /api/alert takes from SNOWFLAKE_WAREHOUSE.
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE UNIFAI_USER;


-- =============================================================================
-- SECTION 3: ALERTS schema
-- =============================================================================
-- /api/alert issues CREATE OR REPLACE ALERT HOSPITAL_360.ALERTS.<NAME>.
-- The endpoint does not create this schema, so it must exist first.

USE ROLE UNIFAI_USER;

CREATE SCHEMA IF NOT EXISTS HOSPITAL_360.ALERTS
    COMMENT = 'Alerts created by the Provider Central app (/api/alert)';

-- Explicit grants, for the case where the app role does not own the database.
-- Harmless no-ops when the role is already the owner.
GRANT USAGE ON DATABASE HOSPITAL_360 TO ROLE UNIFAI_USER;
GRANT USAGE ON SCHEMA HOSPITAL_360.ALERTS TO ROLE UNIFAI_USER;
GRANT CREATE ALERT ON SCHEMA HOSPITAL_360.ALERTS TO ROLE UNIFAI_USER;

-- The six alert presets in /api/alert read from these marts. The alert owner
-- needs SELECT on whichever ones the demo will actually use.
GRANT SELECT ON HOSPITAL_360.CLINICAL.MART_READMISSION_LOS      TO ROLE UNIFAI_USER;
GRANT SELECT ON HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY        TO ROLE UNIFAI_USER;
GRANT SELECT ON HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY    TO ROLE UNIFAI_USER;
GRANT SELECT ON HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE    TO ROLE UNIFAI_USER;
GRANT SELECT ON HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE TO ROLE UNIFAI_USER;


-- =============================================================================
-- SECTION 4: Verification
-- =============================================================================

-- Integration exists and is enabled
SHOW INTEGRATIONS LIKE 'H360_EMAIL_INT';
DESCRIBE INTEGRATION H360_EMAIL_INT;

-- Schema exists
SHOW SCHEMAS LIKE 'ALERTS' IN DATABASE HOSPITAL_360;

-- Alerts created so far by the app
SHOW ALERTS IN SCHEMA HOSPITAL_360.ALERTS;

-- Smoke test — replace with a VERIFIED address of a user in this account.
-- This is the same call /api/email makes.
--
-- CALL SYSTEM$SEND_EMAIL(
--     'H360_EMAIL_INT',
--     'you@example.com',
--     'Provider 360 — integration test',
--     'If you received this, H360_EMAIL_INT is configured correctly.'
-- );

-- End-to-end alert test — mirrors what /api/alert builds for the
-- "readmission rate exceeds 15%" preset. Threshold is set to 0 so the
-- condition is guaranteed true on the next scheduled run.
--
-- CREATE OR REPLACE ALERT HOSPITAL_360.ALERTS.TEST_ALERT
--   WAREHOUSE = DEMO_WH
--   SCHEDULE = '60 MINUTE'
--   IF (EXISTS (
--     SELECT 1 FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
--     HAVING AVG(READMIT_30_FLAG::INT) * 100 > 0
--   ))
--   THEN
--     CALL SYSTEM$SEND_EMAIL('H360_EMAIL_INT', 'you@example.com',
--          'Provider 360 Alert: TEST_ALERT', 'Alert condition met.');
--
-- ALTER ALERT HOSPITAL_360.ALERTS.TEST_ALERT RESUME;   -- alerts start suspended
-- EXECUTE ALERT HOSPITAL_360.ALERTS.TEST_ALERT;        -- run immediately
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.ALERT_HISTORY())
--   WHERE NAME = 'TEST_ALERT' ORDER BY SCHEDULED_TIME DESC;
-- DROP ALERT HOSPITAL_360.ALERTS.TEST_ALERT;
