# Hospital 360 — Snowflake + Epic Demo Platform

A comprehensive healthcare analytics platform built entirely on Snowflake, demonstrating 8 use cases across a medallion architecture with synthetic Epic-style data, Cortex ML, Cortex Agent, Semantic Views, governance, and operational automation.

## Architecture Overview

```
                        ┌──────────────────────────────┐
                        │   HOSPITAL360_APP (Streamlit) │
                        │   9 pages + Cortex Agent      │
                        └──────────┬───────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
   ┌──────────▼─────────┐ ┌───────▼────────┐ ┌─────────▼──────────┐
   │  Semantic Views     │ │  Cortex Agent  │ │  Cortex Analyst    │
   │  (Unified Analytics)│ │  (Agentic NL)  │ │  (Text-to-SQL)     │
   └──────────┬─────────┘ └───────┬────────┘ └─────────┬──────────┘
              │                    │                     │
   ┌──────────▼─────────────────────────────────────────▼──────────┐
   │  HOSPITAL360_CUR — Curated Layer (28 tables)                  │
   │  10 Dimensions  │  12 Facts  │  4 Use-Case Marts              │
   │  + Governance: Tags, Masking, Row-Access Policies             │
   └──────────┬────────────────────────────────────────────────────┘
              │
   ┌──────────▼─────────────────────────────────────────────────────┐
   │  HOSPITAL360_ML — Machine Learning Layer                       │
   │  4 Feature Views │ 4 ML Models │ 4 Prediction Tables           │
   │  + Monitoring: Tasks, Pipeline Log, DQ Checks, Model Perf     │
   └────────────────────────────────────────────────────────────────┘
```

## 8 Use Cases

| # | Use Case | Data Layer | Snowflake Feature |
|---|----------|-----------|-------------------|
| 1 | Patient Referral Leakage | `MART_PATIENT_LEAKAGE` (48K rows) | Streamlit + Semantic View |
| 2 | Readmission & LOS Analysis | `MART_READMISSION_LOS` (107K rows) | Streamlit + Cortex ML Top Insights |
| 3 | OR Capacity & Utilization | `MART_OR_CAPACITY` (30K rows) | Streamlit + Semantic View |
| 4 | Claim Denials & Revenue Cycle | `MART_DENIALS_REVCYCLE` (116K rows) | Streamlit + Cortex ML Anomaly Detection |
| 5 | Encounter Volume Forecasting | `PRED_ENCOUNTER_VOLUME` (360 rows) | Cortex ML Forecast |
| 6 | Conversational Analytics | Semantic View (6 tables) | Cortex Analyst (Text-to-SQL) |
| 7 | Agentic Hospital Intelligence | Cortex Agent (YAML spec) | Cortex Agent + Container Runtime |
| 8 | Operational Automation | Task DAG (5 tasks) | Tasks, Stored Procedures, DQ Checks |

## Snowflake Features Demonstrated

- **Medallion Architecture**: RAW → INT → CUR → APP (5 databases, 30+ schemas)
- **Cortex ML Functions**: `FORECAST`, `ANOMALY_DETECTION`, `TOP_INSIGHTS`
- **Semantic Views**: Unified 6-table semantic view with relationships, metrics, verified queries
- **Cortex Agent**: Agentic text-to-SQL with multi-step reasoning
- **Cortex Analyst**: Natural language to SQL via semantic view
- **Streamlit in Snowflake**: 9-page app on container runtime (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`)
- **Data Governance**: 4 tags, 6 masking policies, 2 row-access policies, 6 functional roles
- **Snowflake Tasks**: 5-task DAG with daily CRON schedule for pipeline automation
- **Stored Procedures**: SQL procedures for mart refresh, ML prediction regeneration, data quality checks
- **Warehouses**: 4 purpose-built warehouses (Load, Transform, BI, ML)

## Data Model

### Dimensions (10 tables in HOSPITAL360_CUR)

| Table | Schema | Rows | Description |
|-------|--------|------|-------------|
| DIM_DATE | CLINICAL | 1,096 | Universal date spine (2023-2025) |
| DIM_PATIENT | CLINICAL | 25,000 | Patients with demographics, PII, HCC scores |
| DIM_PROVIDER | CLINICAL | 200 | Physicians with specialties and credentials |
| DIM_DEPARTMENT | OPERATIONS | 30 | Hospital departments across 5 facilities |
| DIM_FACILITY | OPERATIONS | 5 | 1 main hospital + 4 satellite facilities |
| DIM_PAYER | FINANCIAL | 15 | Insurance payers with timely-filing limits |
| DIM_DIAGNOSIS_ICD10 | CLINICAL | 98 | Common ICD-10 codes with HCC flags |
| DIM_PROCEDURE_CPT | CLINICAL | 91 | Common CPT codes with RVU values |
| DIM_DRG | FINANCIAL | 78 | MS-DRGs with weights and expected LOS |
| DIM_MEDICATION_RXNORM | CLINICAL | 78 | Medications with drug class and unit costs |

### Facts (12 tables in HOSPITAL360_CUR)

| Table | Schema | Rows | Grain |
|-------|--------|------|-------|
| FCT_ENCOUNTER | CLINICAL | 200,000 | 1 per encounter |
| FCT_ADT_EVENT | OPERATIONS | 396K | 1 per ADT event |
| FCT_OR_CASE | OPERATIONS | 30,000 | 1 per OR case |
| FCT_CLAIM_LINE | FINANCIAL | 1,200,000 | 1 per 837 claim line |
| FCT_REMITTANCE | FINANCIAL | 1,080K | 1 per 835 remit line |
| FCT_REFERRAL | CLINICAL | 50,000 | 1 per referral |
| FCT_CARE_GAP | POP_HEALTH | 75,000 | 1 per HEDIS measure-patient |
| FCT_EHR_USAGE | WORKFORCE | 78,400 | 1 per provider-day |
| FCT_LABOR_HOUR | WORKFORCE | 730,000 | 1 per employee-shift |
| FCT_GL_TRANSACTION | FINANCIAL | 500,000 | 1 per GL line |
| FCT_SUPPLY_USAGE | SUPPLY_CHAIN | 400,000 | 1 per item-encounter |
| FCT_BED_STATUS | OPERATIONS | 300,000 | 1 per status change |

### ML Layer (HOSPITAL360_ML)

| Object | Schema | Type | Description |
|--------|--------|------|-------------|
| VW_DAILY_ENCOUNTER_VOLUME | FEATURES | View | Daily encounter counts by type |
| VW_DAILY_DENIAL_VOLUME | FEATURES | View | Daily denial counts by category |
| VW_READMISSION_DRIVERS | FEATURES | View | Encounter features for Top Insights |
| VW_LEAKAGE_DRIVERS | FEATURES | View | Referral features for Top Insights |
| FORECAST_ENCOUNTER_VOLUME | MODELS | ML Forecast | 90-day encounter forecast |
| ANOMALY_DENIAL_VOLUME | MODELS | ML Anomaly | Denial volume anomaly detection |
| INSIGHTS_READMISSION | MODELS | ML Insights | Readmission rate drivers |
| INSIGHTS_LEAKAGE | MODELS | ML Insights | Leakage rate drivers |
| PRED_ENCOUNTER_VOLUME | PREDICTIONS | Table | 360 forecast rows |
| PRED_DENIAL_ANOMALIES | PREDICTIONS | Table | 736 anomaly detection rows |
| PRED_READMISSION_DRIVERS | PREDICTIONS | Table | 92 driver analysis rows |
| PRED_LEAKAGE_DRIVERS | PREDICTIONS | Table | 98 driver analysis rows |

### Monitoring (HOSPITAL360_ML.MONITORING)

| Object | Type | Description |
|--------|------|-------------|
| PIPELINE_RUN_LOG | Table | Task execution log with status, row counts, durations |
| MODEL_PERFORMANCE_LOG | Table | ML model metrics over time |
| DATA_QUALITY_CHECKS | Table | DQ check results (13 checks across 4 marts) |
| SP_REFRESH_MARTS | Procedure | Truncate + rebuild all 4 use-case marts |
| SP_REFRESH_FORECAST | Procedure | Regenerate encounter forecast predictions |
| SP_REFRESH_ANOMALY | Procedure | Regenerate denial anomaly predictions |
| SP_RUN_DATA_QUALITY_CHECKS | Procedure | Run 13 DQ checks and log results |
| TASK_REFRESH_PIPELINE | Task | Root task — daily at 6 AM UTC |
| TASK_REFRESH_MARTS | Task | Child — refreshes 4 marts |
| TASK_RETRAIN_FORECAST | Task | Child — regenerates forecasts |
| TASK_RETRAIN_ANOMALY | Task | Child — regenerates anomalies |
| TASK_LOG_PIPELINE_RUN | Task | Child — logs pipeline summary |

## Streamlit Application

9-page multi-page app running on container runtime:

| Page | File | Description |
|------|------|-------------|
| Executive Summary | `streamlit_app.py` | KPIs, trend sparklines, navigation |
| Readmission & LOS | `pages/1_readmission_los.py` | DRG analysis, LOS index, readmission trends |
| Patient Leakage | `pages/2_patient_leakage.py` | Referral leakage by specialty, revenue impact |
| OR Capacity | `pages/3_or_capacity.py` | Block utilization, delays, surgeon volumes |
| Denials & RevCycle | `pages/4_denials_revcycle.py` | Denial categories, appeal rates, CPT analysis |
| ML Insights | `pages/5_ml_insights.py` | Forecast charts, anomaly detection, top drivers |
| Cortex Analyst | `pages/6_cortex_analyst.py` | Natural language analytics chat interface |
| Cortex Agent | `pages/7_cortex_agent.py` | Agentic multi-step reasoning with auto-execution |
| Ops Monitor | `pages/8_ops_monitor.py` | Pipeline status, DQ results, platform inventory |

## Governance

| Layer | Objects | Description |
|-------|---------|-------------|
| Tags | DATA_CLASSIFICATION, PII_TYPE, DATA_DOMAIN, RETENTION_POLICY | Column and table-level classification |
| Masking | MASK_SSN, MASK_DOB, MASK_PATIENT_NAME, MASK_MRN, MASK_PHONE, MASK_EMAIL | Role-based differential masking |
| Row Access | RAP_DEPARTMENT, RAP_FACILITY | Role-to-department and role-to-facility mapping |
| Roles | H360_ADMIN, H360_ENGINEER, H360_ANALYST, H360_CLINICIAN, H360_EXEC, H360_FINANCE | Functional RBAC hierarchy |

## Quick Start — Execution Order

Run the infrastructure SQL scripts in order:

```
01_databases.sql          # 5 databases, 30+ schemas
02_warehouses.sql         # 4 warehouses
03_roles.sql              # 6 roles + grants
04_governance.sql         # Tags, masking, RAP policies
05_stages_and_file_formats.sql  # Internal stages, file formats
06_dimensions.sql         # 10 dimension table DDLs
07_facts.sql              # 12 fact table DDLs
08_seed_dimensions.sql    # Populate dimensions (synthetic data)
09_seed_facts.sql         # Populate facts (~5M rows, synthetic)
10_apply_governance.sql   # Apply tags, masking policies, RAP mapping
11_mart_ddls.sql          # 4 use-case mart DDLs
12_seed_marts.sql         # Populate marts from facts/dims
13_ml_feature_views.sql   # 4 ML feature engineering views
14_ml_models.sql          # Train 4 Cortex ML models
15_ml_predictions.sql     # Generate predictions into 4 tables
16_deploy_streamlit.sql   # Stage files + CREATE STREAMLIT
17_semantic_views.sql     # CREATE SEMANTIC VIEW (unified, 6 tables)
18_cortex_analyst_config.sql  # Grants for Cortex Analyst access
19_cortex_agent.sql       # CREATE AGENT with YAML spec
20_deploy_streamlit_container.sql  # Convert to container runtime
21_tasks_automation.sql   # Task DAG + stored procedures
22_monitoring_tables.sql  # Monitoring table DDLs
23_data_quality.sql       # DQ checks stored procedure
```

## Prerequisites

- Snowflake account with Cortex ML, Cortex Agent, and Streamlit enabled
- `SYSADMIN` role or equivalent with CREATE DATABASE, CREATE WAREHOUSE, CREATE ROLE privileges
- Compute pool `SYSTEM_COMPUTE_POOL_CPU` in ACTIVE state (for container runtime Streamlit)
- Snow CLI v3.x for file staging (`snow stage copy`)

## Data

All data is **synthetic** — generated in-place using Snowflake SQL `GENERATOR()` and `UNIFORM()`/`RANDOM()` functions. No external data files required. Data spans July 1, 2023 through December 30, 2024 (548 days) across 5 hospital facilities.

Key metrics:
- 200K encounters (35% ED, 45% IP, 10% OP, 10% OBS)
- 12% 30-day readmission rate
- 15.2% patient referral leakage rate
- 84.3% average OR utilization
- 10% claim denial rate across 4 categories
- 25,000 patients, 200 providers, 30 departments
# Provider360
# ProviderCentral
