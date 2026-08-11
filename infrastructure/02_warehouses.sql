-- =============================================================================
-- Hospital360 Demo: Warehouse Setup
-- =============================================================================
-- Run as: SYSADMIN
-- =============================================================================

USE ROLE SYSADMIN;

-- -----------------------------------------------------------------------------
-- H360_LOAD_WH — Ingest workloads (Snowpipe, COPY INTO, etc.)
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS H360_LOAD_WH
  WAREHOUSE_SIZE   = 'MEDIUM'
  AUTO_SUSPEND     = 60
  AUTO_RESUME      = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Hospital360: Ingest / data loading warehouse';

-- -----------------------------------------------------------------------------
-- H360_XFM_WH — Transform workloads (dbt, Tasks, Dynamic Tables)
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS H360_XFM_WH
  WAREHOUSE_SIZE   = 'LARGE'
  AUTO_SUSPEND     = 120
  AUTO_RESUME      = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Hospital360: Transformation warehouse (dbt, tasks, dynamic tables)';

-- -----------------------------------------------------------------------------
-- H360_BI_WH — BI / Demo queries (multi-cluster for concurrency)
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS H360_BI_WH
  WAREHOUSE_SIZE      = 'MEDIUM'
  MIN_CLUSTER_COUNT   = 1
  MAX_CLUSTER_COUNT   = 3
  SCALING_POLICY      = 'STANDARD'
  AUTO_SUSPEND        = 300
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Hospital360: BI / demo query warehouse (multi-cluster)';

-- -----------------------------------------------------------------------------
-- H360_ML_WH — Cortex ML / AI workloads
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS H360_ML_WH
  WAREHOUSE_SIZE   = 'LARGE'
  AUTO_SUSPEND     = 120
  AUTO_RESUME      = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Hospital360: ML / Cortex AI warehouse';
