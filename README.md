# Provider Central — Snowflake + Epic Healthcare Analytics Demo

A healthcare analytics demo platform built entirely on Snowflake, with synthetic Epic-style data across clinical, financial, operational, and workforce domains. It demonstrates a medallion architecture, Cortex ML predictions, a Cortex Agent for conversational analytics, semantic views, and PHI governance through dynamic data masking.

The whole platform — infrastructure SQL, data model, ML layer, and both frontends — was built conversationally with Snowflake Cortex Code. The in-app **Build** page walks through how.

---

## Repository Layout

| Directory | Contents | Status |
|-----------|----------|--------|
| `react-app/` | React 19 + Vite frontend, Flask proxy backend | **Active** — the current app |
| `infrastructure/` | 22 SQL scripts that build the Snowflake platform | Reference — see [Deployment Reality](#deployment-reality) |
| `streamlit/` | 10-page Streamlit-in-Snowflake app | Superseded — stale table references |
| `slides/` | Demo deck (Markdown + PPTX) and persona demo scripts | Supporting material |
| `plans/`, `.cortex/plans/` | 29 Cortex Code session plans (Apr 29 – Aug 11, 2026) | Build history |

---

## Deployment Reality

**Read this before running any SQL.** The `infrastructure/` scripts describe the *original* five-database design. That is not what is deployed.

On 2026-08-11 the platform was collapsed into a **single database, `HOSPITAL_360`**, running on warehouse `DEMO_WH` under role `UNIFAI_USER`. The React app queries only these consolidated names.

| Original (in `infrastructure/*.sql`) | Deployed (in `HOSPITAL_360`) |
|--------------------------------------|------------------------------|
| `HOSPITAL360_CUR.CLINICAL` | `HOSPITAL_360.CLINICAL` |
| `HOSPITAL360_CUR.FINANCIAL` | `HOSPITAL_360.FINANCIAL` |
| `HOSPITAL360_CUR.OPERATIONS` | `HOSPITAL_360.OPERATIONS` |
| `HOSPITAL360_CUR.WORKFORCE` | `HOSPITAL_360.WORKFORCE` |
| `HOSPITAL360_CUR.SUPPLY_CHAIN` | `HOSPITAL_360.SUPPLY_CHAIN` |
| `HOSPITAL360_CUR.GOVERNANCE` | `HOSPITAL_360.GOVERNANCE` |
| `HOSPITAL360_ML.FEATURES` | `HOSPITAL_360.ML_FEATURES` |
| `HOSPITAL360_ML.MODELS` | `HOSPITAL_360.ML_MODELS` |
| `HOSPITAL360_ML.PREDICTIONS` | `HOSPITAL_360.ML_PREDICTIONS` |
| `HOSPITAL360_ML.MONITORING` | `HOSPITAL_360.ML_MONITORING` |
| `HOSPITAL360_APP.SEMANTIC_VIEWS` | `HOSPITAL_360.SEMANTIC_VIEWS` |
| `HOSPITAL360_APP.CORTEX_ANALYST` | `HOSPITAL_360.CORTEX_ANALYST` |

Skipped during that deployment: custom roles (`03`), warehouses (`02`), stages (`05`), Streamlit deploy (`16`, `20`), Cortex Analyst role grants (`18`), row-access policies, and all `GRANT` statements. Full detail in `.cortex/plans/plan_2026-08-11_1616.md`.

**Consequence:** the Streamlit app still queries `HOSPITAL360_CUR.*` and `HOSPITAL360_ML.*` and will fail against the current database. Only the React app is wired to the live schema.

---

## Architecture

```
                    ┌────────────────────────────────┐
                    │  React SPA (Vite, port 5173)   │
                    │  13 routes + floating chat     │
                    └───────────────┬────────────────┘
                                    │  /api proxy
                    ┌───────────────▼────────────────┐
                    │  Flask proxy (port 3001)       │
                    │  /api/sql  /api/agent          │
                    │  /api/email  /api/alert        │
                    └───────────────┬────────────────┘
                                    │  PAT auth, REST v2
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                            │
┌───────▼────────┐    ┌─────────────▼──────────┐   ┌────────────▼─────────┐
│ SQL REST API   │    │  Cortex Agent (SSE)    │   │  SYSTEM$SEND_EMAIL   │
│ role-scoped    │    │  HOSPITAL360_AGENT     │   │  + CREATE ALERT      │
└───────┬────────┘    └─────────────┬──────────┘   └──────────────────────┘
        │                           │
        │             ┌─────────────▼──────────┐
        │             │  Semantic View         │
        │             │  HOSPITAL360_ANALYTICS │
        │             │  (6 logical tables)    │
        │             └─────────────┬──────────┘
        │                           │
┌───────▼───────────────────────────▼───────────────────────────────────┐
│  HOSPITAL_360 — curated layer                                          │
│  10 dimensions │ 12 facts │ 6 use-case marts                          │
│  + tags, masking policies                                              │
├────────────────────────────────────────────────────────────────────────┤
│  ML_FEATURES │ ML_MODELS │ ML_PREDICTIONS │ ML_MONITORING             │
│  4 feature views │ 4 Cortex ML models │ 4 prediction tables           │
│  + task DAG, pipeline log, data-quality checks                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## React Application

### Stack

- **Frontend** — React 19, React Router 7, TanStack Query 5, Tailwind CSS 4, TypeScript 6, Vite 8
- **Charts** — Plotly (`plotly.js-dist-min`) for dashboard visuals; Vega-Lite / vega-embed for charts returned by the Cortex Agent
- **Backend** — Flask + flask-cors, proxying the Snowflake SQL REST API v2 with programmatic access token (PAT) auth

### Running locally

```bash
cd react-app
npm install
pip install -r server/requirements.txt
npm run dev          # runs Flask on :3001 and Vite on :5173 concurrently
```

Vite proxies `/api` → `http://localhost:3001`. Other scripts: `npm run server` (Flask only), `npm run build`, `npm run lint`.

### Environment

`react-app/.env` (gitignored — not committed):

```
SNOWFLAKE_ACCOUNT=<account>.snowflakecomputing.com
SNOWFLAKE_WAREHOUSE=DEMO_WH
SNOWFLAKE_ROLE=UNIFAI_USER
SNOWFLAKE_DATABASE=HOSPITAL_360
SNOWFLAKE_PAT=<programmatic access token>
```

The PAT expires. A wall of `401 Unauthorized` in `server/flask.log` means it needs regenerating — the app will render but every panel will error.

### Backend endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/sql` | Executes SQL via the Snowflake REST API under the caller's selected role. Polls for async completion and coerces Snowflake wire types (epoch-day dates, epoch timestamps, `FIXED` numerics) into JSON-friendly values. |
| `POST /api/agent` | Streams the Cortex Agent SSE response straight through to the browser. |
| `POST /api/email` | Sends a chat result by email via `SYSTEM$SEND_EMAIL` using the `H360_EMAIL_INT` notification integration. |
| `POST /api/alert` | Creates and resumes a Snowflake Alert from one of six metric presets (readmission rate, avg LOS, OR utilization, overtime %, denial rate, operating margin), with an email action. |

### Pages

| Route | Component | Description |
|-------|-----------|-------------|
| `/` | `Home` | Demo overview — source systems and page guide |
| `/dashboard` | `ProviderDashboard` | Cross-domain KPIs, trend sparklines, ML quick-look |
| `/readmission` | `ReadmissionLOS` | 30-day readmission rates, LOS index, DRG analysis |
| `/readmission-facility` | `ReadmissionFacilitySpecialty` | CMS HRRP drill-down by facility and attending specialty |
| `/leakage` | `PatientLeakage` | Out-of-network referrals and lost revenue by specialty |
| `/or-capacity` | `ORCapacity` | Block utilization, delays, turnover, surgeon volumes |
| `/staffing` | `StaffingQuality` | Labor hours and overtime correlated with clinical outcomes |
| `/financial` | `FinancialPerformance` | Department cost structure, margin, revenue trends |
| `/denials` | `DenialsRevCycle` | Denial categories, appeal rates, recovery opportunity |
| `/predictive` | `PredictiveAnalytics` | Cortex ML forecasts, anomalies, and top drivers |
| `/ops` | `OpsMonitor` | Platform inventory, row counts, prediction-table health |
| `/patient-records` | `PatientRecords` | PHI masking demo — same query, different role |
| `/build` | `Build` | How Cortex Code built the platform, phase by phase |

### Role switching and PHI masking

The role selector in the top nav (Clinician / Finance / Executive) is the governance demo. Selecting a role updates `RoleContext`, which is part of every TanStack Query key, so all queries refetch; the role is passed to `/api/sql` and used as the Snowflake execution role. Dynamic masking policies then return different values for the *same* query — most visibly on `/patient-records`:

| Field | Clinician | Finance | Executive |
|-------|-----------|---------|-----------|
| Name | Full name | `PATIENT_<hash>` | `PATIENT_<hash>` |
| DOB | Full date | Year only | Year only |
| SSN | Last 4 | `***-**-****` | `***-**-****` |
| MRN | Full MRN | `***MRN***` | `***MRN***` |
| Phone | Full number | Last 4 only | Masked |
| Email | Full email | Domain only | Domain only |

### Chat widget

A floating, resizable panel backed by the Cortex Agent. It streams SSE events — `response.text.delta`, `response.thinking.delta`, `response.status`, `response.tool_use` (including generated SQL), and `response.chart` — rendering the reasoning trace alongside the answer and drawing any returned Vega-Lite specs inline. Each assistant message can be emailed or turned into a scheduled Snowflake Alert. Typing "email this to someone@example.com" is recognized inline.

---

## Data Model

### Dimensions (10)

| Table | Schema | Rows | Description |
|-------|--------|------|-------------|
| `DIM_DATE` | CLINICAL | 1,096 | Date spine (2023–2025) |
| `DIM_PATIENT` | CLINICAL | 25,000 | Demographics, PHI columns, HCC scores |
| `DIM_PROVIDER` | CLINICAL | 200 | Physicians with specialties and credentials |
| `DIM_DEPARTMENT` | OPERATIONS | 30 | Departments across 5 facilities |
| `DIM_FACILITY` | OPERATIONS | 5 | 1 main hospital + 4 satellites |
| `DIM_PAYER` | FINANCIAL | 15 | Payers with timely-filing limits |
| `DIM_DIAGNOSIS_ICD10` | CLINICAL | 98 | ICD-10 codes with HCC flags |
| `DIM_PROCEDURE_CPT` | CLINICAL | 91 | CPT codes with RVU values |
| `DIM_DRG` | FINANCIAL | 78 | MS-DRGs with weights and expected LOS |
| `DIM_MEDICATION_RXNORM` | CLINICAL | 78 | Medications with drug class and unit cost |

### Facts (12)

| Table | Schema | Rows | Grain |
|-------|--------|------|-------|
| `FCT_ENCOUNTER` | CLINICAL | 200,000 | 1 per encounter |
| `FCT_ADT_EVENT` | OPERATIONS | 396,000 | 1 per ADT event |
| `FCT_OR_CASE` | OPERATIONS | 30,000 | 1 per OR case |
| `FCT_CLAIM_LINE` | FINANCIAL | 1,200,000 | 1 per 837 claim line |
| `FCT_REMITTANCE` | FINANCIAL | 1,080,000 | 1 per 835 remit line |
| `FCT_REFERRAL` | CLINICAL | 50,000 | 1 per referral |
| `FCT_CARE_GAP` | POP_HEALTH | 75,000 | 1 per HEDIS measure-patient |
| `FCT_EHR_USAGE` | WORKFORCE | 78,400 | 1 per provider-day |
| `FCT_LABOR_HOUR` | WORKFORCE | 730,000 | 1 per employee-shift |
| `FCT_GL_TRANSACTION` | FINANCIAL | 500,000 | 1 per GL line |
| `FCT_SUPPLY_USAGE` | SUPPLY_CHAIN | 400,000 | 1 per item-encounter |
| `FCT_BED_STATUS` | OPERATIONS | 300,000 | 1 per status change |

### Use-case marts (6)

| Mart | Schema | Built from |
|------|--------|-----------|
| `MART_READMISSION_LOS` | CLINICAL | `FCT_ENCOUNTER` + 6 dimensions |
| `MART_PATIENT_LEAKAGE` | CLINICAL | `FCT_REFERRAL` + patient/provider dims |
| `MART_OR_CAPACITY` | OPERATIONS | `FCT_OR_CASE` + provider/facility/CPT dims |
| `MART_DENIALS_REVCYCLE` | FINANCIAL | `FCT_CLAIM_LINE` + payer/provider/diagnosis dims |
| `MART_STAFFING_QUALITY` | WORKFORCE | `FCT_LABOR_HOUR` + `FCT_ENCOUNTER` (cross-source) |
| `MART_FINANCIAL_PERFORMANCE` | FINANCIAL | `FCT_GL_TRANSACTION` + encounter volume |

### ML layer

| Object | Schema | Type | Description |
|--------|--------|------|-------------|
| `VW_DAILY_ENCOUNTER_VOLUME` | ML_FEATURES | View | Daily encounter counts by type |
| `VW_DAILY_DENIAL_VOLUME` | ML_FEATURES | View | Daily denial counts by category |
| `VW_READMISSION_DRIVERS` | ML_FEATURES | View | Encounter features for Top Insights |
| `VW_LEAKAGE_DRIVERS` | ML_FEATURES | View | Referral features for Top Insights |
| `FORECAST_ENCOUNTER_VOLUME` | ML_MODELS | `SNOWFLAKE.ML.FORECAST` | 90-day encounter forecast |
| `ANOMALY_DENIAL_VOLUME` | ML_MODELS | `SNOWFLAKE.ML.ANOMALY_DETECTION` | Denial volume anomalies |
| `INSIGHTS_READMISSION` | ML_MODELS | `SNOWFLAKE.ML.TOP_INSIGHTS` | Readmission rate drivers |
| `INSIGHTS_LEAKAGE` | ML_MODELS | `SNOWFLAKE.ML.TOP_INSIGHTS` | Leakage rate drivers |
| `PRED_ENCOUNTER_VOLUME` | ML_PREDICTIONS | Table | 360 forecast rows |
| `PRED_DENIAL_ANOMALIES` | ML_PREDICTIONS | Table | 736 anomaly rows |
| `PRED_READMISSION_DRIVERS` | ML_PREDICTIONS | Table | 92 driver rows |
| `PRED_LEAKAGE_DRIVERS` | ML_PREDICTIONS | Table | 98 driver rows |

### Semantic view and agent

`HOSPITAL360_ANALYTICS` spans six logical tables — the four core marts plus the encounter-forecast and denial-anomaly prediction tables — with relationships, facts, dimensions, metrics, and verified queries. `HOSPITAL360_AGENT` sits on top of it with a single `cortex_analyst_text_to_sql` tool (`Hospital360Analyst`), a 60-second / 16k-token orchestration budget, and sample questions.

### Automation and monitoring

`ML_MONITORING` holds `PIPELINE_RUN_LOG`, `MODEL_PERFORMANCE_LOG`, and `DATA_QUALITY_CHECKS`, plus four stored procedures (`SP_REFRESH_MARTS`, `SP_REFRESH_FORECAST`, `SP_REFRESH_ANOMALY`, `SP_RUN_DATA_QUALITY_CHECKS`) driven by a five-task DAG rooted at `TASK_REFRESH_PIPELINE`, scheduled daily at 6 AM UTC.

---

## Infrastructure Scripts

Written against the original five-database layout. Run in order, translating schema names per [Deployment Reality](#deployment-reality).

| Script | Purpose |
|--------|---------|
| `01_databases.sql` | 5 databases, 30+ schemas |
| `02_warehouses.sql` | 4 purpose-built warehouses (Load, Transform, BI, ML) |
| `03_roles.sql` | 6 functional roles + grants |
| `04_governance.sql` | Tags, masking policies, row-access policies |
| `05_stages_and_file_formats.sql` | Internal stages and file formats |
| `06_dimensions.sql` | 10 dimension DDLs |
| `07_facts.sql` | 12 fact DDLs (**DDL only — no seed data**) |
| `08_seed_dimensions.sql` | Populate all 10 dimensions |
| `10_apply_governance.sql` | Apply tags, masking, row-access mapping |
| `11_mart_ddls.sql` | 6 use-case mart DDLs |
| `12_seed_marts.sql` | Populate marts from facts and dimensions |
| `13_ml_feature_views.sql` | 4 feature-engineering views |
| `14_ml_models.sql` | Train 4 Cortex ML models |
| `15_ml_predictions.sql` | Generate predictions into 4 tables |
| `16_deploy_streamlit.sql` | Stage files + `CREATE STREAMLIT` |
| `17_semantic_views.sql` | `CREATE SEMANTIC VIEW` |
| `18_cortex_analyst_config.sql` | Cortex Analyst access grants |
| `19_cortex_agent.sql` | `CREATE AGENT` with YAML spec |
| `20_deploy_streamlit_container.sql` | Convert Streamlit to container runtime |
| `21_tasks_automation.sql` | Task DAG + refresh procedures |
| `22_monitoring_tables.sql` | Monitoring table DDLs |
| `23_data_quality.sql` | Data-quality check procedure |
| `24_notifications_and_alerts.sql` | `H360_EMAIL_INT` integration + `ALERTS` schema (needed by `/api/email` and `/api/alert`) |

There is **no `09_seed_facts.sql`** — the fact-table seeding step is missing from this repo. Fact data was generated inline during deployment and is not reproducible from these scripts.

### Governance objects

| Layer | Objects |
|-------|---------|
| Tags | `DATA_CLASSIFICATION`, `PII_TYPE`, `DATA_DOMAIN`, `RETENTION_POLICY` |
| Masking | `MASK_SSN`, `MASK_DOB`, `MASK_PATIENT_NAME`, `MASK_MRN`, `MASK_PHONE`, `MASK_EMAIL` |
| Row access | `RAP_DEPARTMENT`, `RAP_FACILITY` (not deployed — require custom roles) |
| Roles | `H360_ADMIN`, `H360_ENGINEER`, `H360_ANALYST`, `H360_CLINICIAN`, `H360_EXEC`, `H360_FINANCE` |

---

## Streamlit Application (superseded)

A 10-page Streamlit app predating the React frontend. It queries the original `HOSPITAL360_CUR.*` / `HOSPITAL360_ML.*` names and **will not run against the current `HOSPITAL_360` database** without a schema rewrite.

| File | Page |
|------|------|
| `Home.py` | Demo overview and talk tracks |
| `pages/1_Provider_360.py` | Executive KPI summary |
| `pages/2_Readmission_LOS.py` | Readmission and LOS analysis |
| `pages/3_Patient_Leakage.py` | Referral leakage |
| `pages/4_OR_Capacity.py` | OR utilization |
| `pages/5_Staffing_Quality.py` | Staffing vs. outcomes |
| `pages/6_Financial_Performance.py` | Financial performance |
| `pages/7_Denials_RevCycle.py` | Denials and revenue cycle |
| `pages/8_Predictive_Analytics.py` | ML forecasts and anomalies |
| `pages/9_Provider_Chat.py` | Cortex Agent chat (SSE) |
| `pages/10_Ops_Monitor.py` | Pipeline status and data quality |

---

## Data

All data is **synthetic**, generated in-place with Snowflake `GENERATOR()`, `UNIFORM()`, and `RANDOM()`. No external files required. Coverage: July 1, 2023 – December 30, 2024 (548 days) across 5 facilities.

Headline metrics: 200K encounters (35% ED, 45% IP, 10% OP, 10% OBS), 12% 30-day readmission rate, 15.2% referral leakage, 84.3% average OR utilization, 10% claim denial rate, 25,000 patients, 200 providers, 30 departments.

---

## Known Gaps

- **Missing fact seeding.** No `09_seed_facts.sql` — the platform cannot be rebuilt end-to-end from `infrastructure/` alone.
- **Email delivery is restricted to verified account users.** Snowflake only delivers `SYSTEM$SEND_EMAIL` to addresses belonging to a verified user in the same account. The chat widget's "email this" box and `/api/alert` both accept arbitrary addresses, which will silently fail for anyone outside the account. Verify presenter addresses before a demo. (The integration itself is now created by `24_notifications_and_alerts.sql`.)
- **`npm run build` fails typechecking.** Seven pre-existing TypeScript errors across `ChartCard.tsx`, `ErrorBoundary.tsx`, `Plot.tsx`, `useChatAgent.ts`, and `FinancialPerformance.tsx` — type-only import violations under `verbatimModuleSyntax`, unused imports, duplicate object keys, and missing Plotly types. `npm run dev` works because Vite does not typecheck, so this only bites on a production build.
- **Streamlit schema drift.** The Streamlit app targets the retired `HOSPITAL360_CUR/_ML` database names and will not run against `HOSPITAL_360`.

---

## Prerequisites

- Snowflake account with Cortex ML, Cortex Agent, and Cortex Analyst enabled
- A warehouse and a role with access to the `HOSPITAL_360` database
- A valid programmatic access token (PAT) for the SQL REST API
- For the email and alert features: `24_notifications_and_alerts.sql` applied (needs `ACCOUNTADMIN` for the integration and the `EXECUTE ALERT` grant)
- Node.js 20+ and Python 3.11+ for local development
- For the Streamlit path only: compute pool `SYSTEM_COMPUTE_POOL_CPU` in `ACTIVE` state and Snow CLI v3.x
