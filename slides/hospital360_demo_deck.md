<!-- Hospital 360 Demo Deck — Slide Separator: --- -->
<!-- Use with Marp, reveal.js, Slidev, or any markdown-to-slides tool -->

---

# Hospital 360

## Snowflake + Epic Healthcare Analytics Platform

**Built 100% on Snowflake** — from raw data ingestion to agentic AI analytics

5 Databases | 28+ Tables | 4 ML Models | 9 Streamlit Pages | 1 Cortex Agent

---

# The Vision

## One platform. Eight use cases. Zero data movement.

Hospital 360 consolidates clinical, financial, and operational data from Epic-style sources into a single Snowflake platform — eliminating data silos and enabling analytics from self-service dashboards to AI-driven decision support.

### What It Delivers

- **4 clinical/financial/operational dashboards** with interactive drill-downs
- **ML-powered forecasting and anomaly detection** using Cortex ML (no Python, no notebooks)
- **Natural language analytics** via Cortex Analyst — ask questions, get SQL + charts
- **Agentic AI** via Cortex Agent — multi-step reasoning with auto-execution
- **HIPAA-aligned governance** — differential masking, row-level security, tag-based classification
- **Automated pipelines** — Snowflake Task DAG refreshes marts and ML predictions daily

### 8 Use Cases

| # | Use Case | Category |
|---|----------|----------|
| 1 | Patient Referral Leakage | Clinical |
| 2 | Readmission & Length-of-Stay | Clinical |
| 3 | OR Capacity & Utilization | Operations |
| 4 | Claim Denials & Revenue Cycle | Financial |
| 5 | Encounter Volume Forecasting | Predictive ML |
| 6 | Conversational Analytics | AI / NLP |
| 7 | Agentic Hospital Intelligence | AI / Agentic |
| 8 | Operational Automation & Monitoring | DataOps |

---

# Platform at a Glance

## Key Numbers

| Metric | Value |
|--------|-------|
| Databases | 5 (RAW, INT, CUR, ML, APP) |
| Schemas | 30+ |
| Dimension Tables | 10 (25K patients, 200 providers, 5 facilities) |
| Fact Tables | 12 (~5M total rows) |
| Use-Case Marts | 4 (48K – 116K rows each) |
| ML Models | 4 (Forecast, Anomaly Detection, 2x Top Insights) |
| ML Predictions | 1,286 rows across 4 tables |
| Semantic Views | 1 unified (6 tables, 18 metrics, 12 verified queries) |
| Cortex Agents | 1 (agentic text-to-SQL with auto-execution) |
| Streamlit Pages | 9 (container runtime on compute pool) |
| Snowflake Tasks | 5-task DAG (daily pipeline refresh) |
| Governance Objects | 4 tags, 6 masking policies, 2 row-access policies |
| Functional Roles | 6 (Admin, Engineer, Analyst, Clinician, Finance, Executive) |
| Warehouses | 4 (Load, Transform, BI, ML) |
| Data Range | Jul 2023 – Dec 2024 (548 days, 5 facilities) |

---

# Architecture

## Medallion Architecture on Snowflake

```
 Epic / EHR / Claims / ERP Sources
              │
    ┌─────────▼──────────┐
    │  HOSPITAL360_RAW    │   8 source schemas (EPIC, ERP, HR, CLAIMS, ...)
    │  Landing Zone       │   File formats, stages, raw ingestion
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │  HOSPITAL360_INT    │   5 domain schemas (CLINICAL, FINANCIAL, OPS, ...)
    │  Integration Layer  │   Conforming, cleansing, deduplication
    └─────────┬──────────┘
              │
    ┌─────────▼──────────────────────────────────────────────┐
    │  HOSPITAL360_CUR — Curated Layer                       │
    │                                                        │
    │  10 Dimensions    12 Facts    4 Use-Case Marts         │
    │  ──────────────   ────────    ────────────────          │
    │  DIM_PATIENT      FCT_ENCOUNTER    MART_READMISSION_LOS│
    │  DIM_PROVIDER     FCT_CLAIM_LINE   MART_PATIENT_LEAKAGE│
    │  DIM_FACILITY     FCT_OR_CASE      MART_OR_CAPACITY    │
    │  DIM_PAYER        FCT_REFERRAL     MART_DENIALS_REVCYCLE│
    │  + 6 more         + 8 more                             │
    │                                                        │
    │  GOVERNANCE: Tags, Masking Policies, Row-Access Policies│
    └─────────┬──────────────────────────────────────────────┘
              │
    ┌─────────▼──────────────────────────────────────────────┐
    │  HOSPITAL360_ML — Machine Learning Layer               │
    │  4 Feature Views → 4 Models → 4 Prediction Tables      │
    │  + MONITORING: Task DAG, Pipeline Logs, DQ Checks      │
    └─────────┬──────────────────────────────────────────────┘
              │
    ┌─────────▼──────────────────────────────────────────────┐
    │  HOSPITAL360_APP — Application Layer                   │
    │  Streamlit (9 pages, container runtime)                │
    │  Semantic View (6 tables, 18 metrics)                  │
    │  Cortex Agent (agentic text-to-SQL)                    │
    └────────────────────────────────────────────────────────┘
```

---

# Technology Stack

## Snowflake Features Demonstrated

| Capability | Snowflake Feature | Hospital 360 Usage |
|-----------|-------------------|-------------------|
| Data Modeling | Multi-database medallion | 5 databases, RAW → INT → CUR → APP |
| BI / Dashboards | Streamlit in Snowflake | 9-page app, container runtime, Plotly charts |
| Machine Learning | Cortex ML Functions | FORECAST, ANOMALY_DETECTION, TOP_INSIGHTS |
| Natural Language | Cortex Analyst | Text-to-SQL via unified semantic view |
| Agentic AI | Cortex Agent | Multi-step reasoning, auto SQL execution |
| Semantic Layer | Semantic Views | 6 tables, 18 metrics, 12 verified queries |
| Governance | Tags + Masking + RAP | HIPAA-aligned: 6 masking policies, 2 RAPs |
| Automation | Snowflake Tasks | 5-task DAG, stored procedures, daily schedule |
| Data Quality | Stored Procedures | 13 automated checks (row counts, NULLs, metric bounds) |
| Security | RBAC + Dynamic Masking | 6 functional roles, differential PHI visibility |

---

# Business Problem 1: Readmission & Length of Stay

## The Problem

Hospitals face CMS penalties for excess 30-day readmissions. Extended length of stay drives up costs. Clinical leaders need to identify which DRGs, payers, and departments drive readmission risk.

## What Hospital 360 Shows

- **12% overall 30-day readmission rate** across 107K inpatient/observation encounters
- **LOS Index** (actual / expected by DRG) identifies patients staying 1.5x+ longer than benchmark
- **Top 10 DRGs** by readmission rate with drill-down
- **Cortex ML Top Insights** automatically surfaces which patient segments (DRG, payer, age bucket, department) are driving readmission rate changes

## Snowflake Differentiator

`SNOWFLAKE.ML.TOP_INSIGHTS` — zero-code ML driver analysis. No data science team needed. Automatically decomposes rate changes into contributing segments with growth rates and relative contributions.

---

# Business Problem 2: Patient Referral Leakage

## The Problem

When referred patients seek care outside the health system network, revenue is lost. Average health systems lose 10-30% of referral revenue to leakage, often without visibility into which specialties or providers are affected.

## What Hospital 360 Shows

- **15.2% leakage rate** across 48K referrals — patients referred out but treated elsewhere
- **$M in lost revenue** broken down by referred-to specialty, referring provider, and facility
- **High-value leak identification** — referrals over $5K that leaked to external providers
- **Cortex ML Top Insights** identifies which specialty + payer + geography combinations drive the highest leakage rates

## Snowflake Differentiator

Unified semantic view allows executives to ask "Which specialties lose the most revenue to leakage?" in plain English via Cortex Analyst — no dashboard training required.

---

# Business Problem 3: OR Capacity & Utilization

## The Problem

Operating rooms are the most expensive real estate in a hospital. Underutilized blocks waste capacity while other surgeons wait. Late first-case starts cascade into delays all day.

## What Hospital 360 Shows

- **84.3% average OR utilization** across 30K cases and 6 surgical blocks
- **Block utilization heatmap** by day of week — visual identification of under/over-utilized blocks
- **First-case-on-time rate** by block and surgeon
- **Delay distribution analysis** — average delay minutes by surgeon, block, and day
- **Underutilized vs. overtime** blocks flagged automatically

## Snowflake Differentiator

Streamlit in Snowflake delivers interactive Plotly heatmaps and drill-downs — no ETL to an external BI tool. Data stays in Snowflake, governed by the same masking and access policies.

---

# Business Problem 4: Claim Denials & Revenue Cycle

## The Problem

Denied claims represent billions in lost revenue industry-wide. Revenue cycle teams need to identify denial patterns, prioritize appeals, and detect anomalous spikes before they become systemic.

## What Hospital 360 Shows

- **116K denied claim lines** across 4 categories: Eligibility, Prior Auth, Coding, Medical Necessity
- **Appeal success rates** by category (Coding errors: 65% recovery, Medical Necessity: 35%)
- **Timely filing compliance** by payer — flags claims filed past the payer's deadline
- **Cortex ML Anomaly Detection** flags unusual daily denial volume spikes — 4+ anomalous periods detected

## Snowflake Differentiator

`SNOWFLAKE.ML.ANOMALY_DETECTION` runs directly on Snowflake tables. Time-series anomaly detection without external model training or deployment. Anomaly flags are joined back to actuals for root-cause analysis in the same Streamlit page.

---

# Executive Summary

## Hospital 360: The Complete Snowflake Healthcare Platform

### The Challenge

Health systems operate across siloed clinical, financial, and operational systems. Traditional BI requires months of ETL development, separate ML platforms, and disconnected governance layers.

### The Snowflake Approach

Hospital 360 demonstrates that **a single Snowflake account** can replace the patchwork:

| Traditional Stack | Hospital 360 on Snowflake |
|------------------|--------------------------|
| Separate data warehouse + data lake | Medallion architecture (5 databases) |
| External BI tool (Tableau, Power BI) | Streamlit in Snowflake (9 pages) |
| Separate ML platform (SageMaker, Vertex) | Cortex ML (Forecast, Anomaly, Insights) |
| Custom NLP chatbot | Cortex Analyst + Cortex Agent |
| Manual governance tagging | Native tags, masking policies, RAPs |
| External orchestration (Airflow) | Snowflake Tasks (5-task DAG) |
| Separate data quality tool | SQL stored procedures + monitoring tables |

### Key Outcomes

- **Readmissions**: Identify top DRGs and patient segments driving 30-day readmits — target interventions
- **Leakage**: Recover $M by identifying specialty + payer combinations with highest referral leakage
- **OR Capacity**: Optimize block scheduling by surfacing underutilized time and chronic delays
- **Denials**: Prioritize appeals by category and detect anomalous denial spikes early
- **All governed** by HIPAA-aligned masking — clinicians see full PHI, executives see pseudonymized data

---

# Demo Script: Executive Dashboard & Use-Case Drill-Downs

## Page: Executive Summary (streamlit_app.py)

### Setup
Open the Streamlit app in Snowsight. The Executive Summary page loads automatically.

### Walkthrough (3-4 minutes)

1. **KPI Row** — Point out the 6 headline metrics across the top:
   - "200K encounters across 5 facilities over 18 months"
   - "12% readmission rate — we'll explore what's driving that"
   - "15.2% leakage rate — that's revenue walking out the door"
   - "84.3% OR utilization — room for optimization"
   - "Denied charges total — the revenue cycle opportunity"
   - "1,286 ML predictions running natively in Snowflake"

2. **Trend Sparklines** — Show the 3 monthly trend charts:
   - "Encounter volume is seasonal — you can see the dip around holidays"
   - "Readmission rate has been stable at 12% — but are certain DRGs worse?"
   - "Leakage rate varies by quarter — let's drill into that"

3. **Use-Case Cards** — Click into each one to demonstrate:
   - "Top readmitted DRG, highest leakage specialty, lowest utilized OR block, top denial category — each links to a deep-dive page"

4. **ML Quick-Look** — Show the forecast chart and anomaly summary:
   - "This 90-day encounter forecast was generated by Cortex ML FORECAST — no Python, no notebooks. And we've detected anomalous denial patterns that revenue cycle should investigate."

5. **Drill into Readmission & LOS page** — Click "View Details":
   - Show facility filter, encounter type filter, payer filter
   - Point out the Top 10 DRGs by readmission rate bar chart
   - Expand the ML Drivers section: "Cortex ML TOP_INSIGHTS automatically identified which patient segments are driving readmission changes — DRG, payer type, age bucket"
   - Toggle to the detail table for patient-level drill-down

6. **Repeat for Patient Leakage** — Show lost revenue by specialty treemap, high-value leak count

7. **Show OR Capacity** — Block utilization heatmap (blocks x day of week), surgeon case volume

8. **Show Denials** — Stacked area chart of monthly denial trends, appeal outcome rates, anomaly detection overlay

---

# Demo Script: Cortex Analyst (Conversational Analytics)

## Page: Cortex Analyst (pages/6_cortex_analyst.py)

### Setup
Navigate to the Cortex Analyst page from the sidebar or the Executive Summary card.

### Walkthrough (3-4 minutes)

1. **Explain the foundation**:
   - "Behind this chat interface is a Semantic View — a unified data model spanning 6 tables: our 4 use-case marts plus 2 ML prediction tables"
   - "It has 18 pre-defined metrics like readmission_rate, leakage_rate, and avg_utilization, plus 12 verified queries that ensure accuracy"

2. **Ask a verified question** — Click or type:
   > "What is the readmission rate by facility?"
   - Watch the SQL get generated automatically
   - Show the results table and chart
   - "No SQL knowledge needed. The semantic view ensures the correct joins and aggregations"

3. **Ask a cross-domain question**:
   > "Which facilities have both high readmission rates and high denial charges?"
   - "This query spans two different marts — the semantic view's relationships handle the join automatically"

4. **Ask about ML predictions**:
   > "Show me the encounter volume forecast for the next 90 days"
   - "The semantic view also exposes our ML prediction tables — users can query forecasts and anomalies in natural language"

5. **Ask a trending question**:
   > "What is the monthly leakage rate trend by specialty?"
   - Show the generated Plotly chart

6. **Key talking point**: "Every query respects the same role-based governance. An H360_EXEC user asking about patients would see masked names and DOBs — the masking policies apply to the Cortex Analyst queries just like direct SQL."

---

# Demo Script: Cortex Agent (Agentic Analytics)

## Page: Cortex Agent (pages/7_cortex_agent.py)

### Setup
Navigate to the Cortex Agent page. Note: This page runs on container runtime (compute pool) — required for Agent API calls.

### Walkthrough (3-4 minutes)

1. **Explain the difference from Cortex Analyst**:
   - "Cortex Analyst generates one SQL query per question. The Agent is different — it can plan multi-step analyses, run multiple queries, and synthesize findings into a narrative answer."
   - "The Agent uses the same semantic view but adds orchestration: it breaks complex questions into sub-tasks."

2. **Ask a simple question** first:
   > "What is the 30-day readmission rate by facility?"
   - Show the Agent's reasoning: it selects the Hospital360Analyst tool, generates SQL, executes it, and formats the answer
   - "Notice it auto-executed the SQL and returned formatted results — you didn't have to click 'run'"

3. **Ask a complex, multi-part question**:
   > "Compare readmission rates and average LOS across all five facilities, and tell me which facility should be investigated first"
   - Watch the Agent break this into steps: query readmission rates, query LOS, synthesize a recommendation
   - "The Agent is doing what a data analyst would do — running multiple queries and connecting the dots"

4. **Ask a follow-up**:
   > "For that facility, what are the top denial categories?"
   - "The Agent maintains conversation context — it knows which facility we were discussing"

5. **Ask an anomaly question**:
   > "Are there any anomalies in recent denial patterns? If so, which categories are affected?"
   - The Agent queries the ML anomaly detection predictions and interprets the results

6. **Key talking points**:
   - "The Agent runs with a 60-second budget and 16K token limit — it's designed for fast, focused analysis"
   - "This is a Snowflake-native agent object — no external LLM deployment, no API keys to manage"
   - "Accessible via Snowsight's native agent UI AND this Streamlit page"

---

# Demo Script: Governance & Security

## Demonstrated via SQL and Snowsight

### Setup
Open a Snowflake worksheet (or use the Streamlit app to narrate while showing worksheet queries).

### Walkthrough (3-4 minutes)

1. **Show the role hierarchy**:
   ```
   SYSADMIN
     └── H360_ADMIN
           ├── H360_ENGINEER   (full access, last-4 SSN)
           ├── H360_ANALYST    (CUR read-only, masked PHI)
           ├── H360_CLINICIAN  (CUR read-only, UNMASKED PHI)
           ├── H360_FINANCE    (financial schemas only)
           └── H360_EXEC       (CUR read-only, FULLY masked PHI)
   ```

2. **Demonstrate differential masking**:
   ```sql
   -- As H360_CLINICIAN (sees real patient data):
   USE ROLE H360_CLINICIAN;
   SELECT MRN, FIRST_NAME, LAST_NAME, DOB, SSN
   FROM HOSPITAL360_CUR.CLINICAL.DIM_PATIENT LIMIT 5;
   -- Shows: MRN-0001, John, Smith, 1985-03-15, XXX-XX-1234

   -- As H360_EXEC (sees pseudonymized data):
   USE ROLE H360_EXEC;
   SELECT MRN, FIRST_NAME, LAST_NAME, DOB, SSN
   FROM HOSPITAL360_CUR.CLINICAL.DIM_PATIENT LIMIT 5;
   -- Shows: ***MRN***, PATIENT_a3f2c8b1, PATIENT_7e9d4c02, 1985-01-01, ***-**-****
   ```
   - "Same table, same query — different roles see different data. The masking policies are enforced at the Snowflake engine level, not in the application."

3. **Show tag-based classification**:
   ```sql
   SELECT * FROM TABLE(
     HOSPITAL360_CUR.INFORMATION_SCHEMA.TAG_REFERENCES(
       'HOSPITAL360_CUR.CLINICAL.DIM_PATIENT.SSN', 'COLUMN'
     )
   );
   -- Shows: DATA_CLASSIFICATION = 'PHI', PII_TYPE = 'SSN'
   ```
   - "Every PHI/PII column is tagged. These tags drive automatic policy attachment and audit reporting."

4. **Show row-access policies**:
   - "H360_FINANCE can only see 3 of our 5 facilities. H360_ADMIN sees all."
   ```sql
   USE ROLE H360_FINANCE;
   SELECT DISTINCT FACILITY_NAME FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY;
   -- Returns: 3 facilities (Main Hospital, Northgate, Eastside)

   USE ROLE H360_ADMIN;
   SELECT DISTINCT FACILITY_NAME FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY;
   -- Returns: All 5 facilities
   ```

5. **Key talking point**: "All of this governance — tags, masking, row-access — applies everywhere: direct SQL, Streamlit, Cortex Analyst, and the Cortex Agent. One governance model, enforced consistently."

---

# Demo Script: Operational Automation & Monitoring

## Page: Operations Monitor (pages/8_ops_monitor.py) + SQL Worksheet

### Setup
Navigate to the Ops Monitor page. Optionally have a SQL worksheet open to trigger the pipeline.

### Walkthrough (3-4 minutes)

1. **Show the Task DAG** (bottom of Ops Monitor page or in worksheet):
   ```
   TASK_REFRESH_PIPELINE          (Root — daily at 6 AM UTC)
     └── TASK_REFRESH_MARTS       (Rebuilds 4 use-case marts)
           ├── TASK_RETRAIN_FORECAST  (Regenerates 90-day forecast)
           ├── TASK_RETRAIN_ANOMALY   (Regenerates anomaly detection)
           └── TASK_LOG_PIPELINE_RUN  (Logs completion to monitoring)
   ```
   - "This entire pipeline is Snowflake-native — no Airflow, no external orchestrator. The Task DAG handles dependencies: forecast and anomaly detection only run after marts are rebuilt."

2. **Trigger the pipeline manually** (if time allows):
   ```sql
   EXECUTE TASK HOSPITAL360_ML.MONITORING.TASK_REFRESH_PIPELINE;
   ```
   - "In production, this runs daily at 6 AM. For the demo, we trigger it manually."

3. **Show Pipeline Execution Log** (top of Ops Monitor page):
   - KPIs: last run time, total runs, success/failure counts
   - Bar chart of run counts by task name
   - Expandable detail table with row counts and durations

4. **Show Data Quality Dashboard** (middle of Ops Monitor page):
   - "13 automated checks run against our 4 marts: row count minimums, NULL primary key checks, metric reasonableness bounds, and date freshness"
   - Point out the color-coded PASS/FAIL/WARN indicators
   - "Readmission rate is 12.02% — within our 5-25% expected range. OR utilization is 84.27% — within the 60-95% expected range."
   - Click "Re-run Data Quality Checks" button to demonstrate live execution

5. **Show Platform Inventory** (bottom of Ops Monitor page):
   - Metric cards showing object counts: Tables, Views, ML Models, Semantic Views, Agents, Tasks, Masking Policies, etc.
   - "This is the health dashboard for the entire platform — one place to see everything that's deployed"

6. **Key talking point**: "Observability is built in, not bolted on. Every pipeline run logs its status, every ML model tracks its predictions, and every data quality check is recorded with expected vs. actual values."

---

<!-- END OF DECK -->
