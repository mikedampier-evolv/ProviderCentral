-- =============================================================================
-- Hospital360 Demo: Database & Schema Setup
-- =============================================================================
-- Run as: SNOWFLAKE-ILABS-EMERGEPR (or SYSADMIN)
-- =============================================================================

USE ROLE SYSADMIN;

-- -----------------------------------------------------------------------------
-- 1. HOSPITAL360_RAW — Bronze / Landing Zone
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HOSPITAL360_RAW
  COMMENT = 'Hospital360 Demo: Bronze layer — raw ingested data from Epic, ERP, HR, Claims, IoT';

CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.EPIC
  COMMENT = 'Epic Clarity & Caboodle mock data';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.ERP
  COMMENT = 'Workday-shaped ERP / GL data';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.HR
  COMMENT = 'Kronos-shaped HR / timekeeping data';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.CLAIMS
  COMMENT = 'Payer 835/837 EDI parsed to JSON';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.SUPPLY_CHAIN
  COMMENT = 'Supply chain item master and transactions';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.AD_LOGS
  COMMENT = 'Active Directory login/access logs';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.IOT
  COMMENT = 'RTLS / IoT bed-status streaming data';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_RAW.MARKETPLACE
  COMMENT = 'Data from Snowflake Marketplace (NPPES, CMS, SDoH, Census)';

-- -----------------------------------------------------------------------------
-- 2. HOSPITAL360_INT — Silver / Integrated
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HOSPITAL360_INT
  COMMENT = 'Hospital360 Demo: Silver layer — cleansed, conformed, PHI-tagged';

CREATE SCHEMA IF NOT EXISTS HOSPITAL360_INT.CLINICAL
  COMMENT = 'Integrated clinical data (encounters, diagnoses, procedures, orders)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_INT.FINANCIAL
  COMMENT = 'Integrated financial data (claims, remittance, GL)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_INT.OPERATIONS
  COMMENT = 'Integrated operations data (OR cases, ADT events, bed status)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_INT.WORKFORCE
  COMMENT = 'Integrated workforce data (EHR usage, labor hours, HR events)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_INT.SUPPLY_CHAIN
  COMMENT = 'Integrated supply chain data';

-- -----------------------------------------------------------------------------
-- 3. HOSPITAL360_CUR — Gold / Curated
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HOSPITAL360_CUR
  COMMENT = 'Hospital360 Demo: Gold layer — analytics-ready dims, facts, and marts';

CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.CLINICAL
  COMMENT = 'Clinical dims/facts (DIM_PATIENT, DIM_PROVIDER, FCT_ENCOUNTER, etc.)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.FINANCIAL
  COMMENT = 'Financial dims/facts (DIM_PAYER, FCT_CLAIM_LINE, FCT_REMITTANCE, etc.)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.OPERATIONS
  COMMENT = 'Operations dims/facts (DIM_DEPARTMENT, FCT_OR_CASE, FCT_BED_STATUS, etc.)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.WORKFORCE
  COMMENT = 'Workforce dims/facts (FCT_EHR_USAGE, FCT_LABOR_HOUR, etc.)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.SUPPLY_CHAIN
  COMMENT = 'Supply chain dims/facts (FCT_SUPPLY_USAGE, etc.)';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.POPULATION_HEALTH
  COMMENT = 'Population health / HEDIS care gap measures';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_CUR.GOVERNANCE
  COMMENT = 'Governance objects: tags, masking policies, row-access policies, mapping tables';

-- -----------------------------------------------------------------------------
-- 4. HOSPITAL360_ML — Feature Store + Model Registry
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HOSPITAL360_ML
  COMMENT = 'Hospital360 Demo: ML layer — feature store, models, predictions, monitoring';

CREATE SCHEMA IF NOT EXISTS HOSPITAL360_ML.FEATURES
  COMMENT = 'Feature tables for ML models';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_ML.MODELS
  COMMENT = 'Cortex ML model registry and artifacts';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_ML.PREDICTIONS
  COMMENT = 'Scored predictions / inference results';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_ML.MONITORING
  COMMENT = 'Model drift and performance monitoring';

-- -----------------------------------------------------------------------------
-- 5. HOSPITAL360_APP — Application Layer
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HOSPITAL360_APP
  COMMENT = 'Hospital360 Demo: App layer — Streamlit, semantic views, Cortex Analyst';

CREATE SCHEMA IF NOT EXISTS HOSPITAL360_APP.STREAMLIT
  COMMENT = 'Streamlit-in-Snowflake application objects';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_APP.SEMANTIC_VIEWS
  COMMENT = 'Semantic view definitions for Cortex Analyst';
CREATE SCHEMA IF NOT EXISTS HOSPITAL360_APP.CORTEX_ANALYST
  COMMENT = 'Cortex Analyst configuration and sample prompts';
