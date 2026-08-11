"""
Provider 360 — Demo Overview & Talk Tracks
Landing page for the Hospital 360 Demo on Snowflake + Epic.
"""

import streamlit as st

# ---------------------------------------------------------------------------
# Page config
# ---------------------------------------------------------------------------
st.set_page_config(
    page_title="Provider 360",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Style page_link elements as visible blue links
st.markdown("""
<style>
    a[data-testid="stPageLink-NavLink"] {
        color: #29B5E8 !important;
        font-weight: 600;
    }
    a[data-testid="stPageLink-NavLink"]:hover {
        color: #5EC8EE !important;
        text-decoration: underline !important;
    }
</style>
""", unsafe_allow_html=True)

# ---------------------------------------------------------------------------
# Sidebar
# ---------------------------------------------------------------------------
st.sidebar.image(
    "https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/"
    "Snowflake_Logo.svg/1280px-Snowflake_Logo.svg.png",
    width=180,
)
st.sidebar.title("Provider 360")
st.sidebar.markdown("---")
st.sidebar.caption("Powered by Snowflake + Streamlit")

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
st.title("Provider 360 — Demo Overview")
st.markdown(
    "Welcome to the **Provider 360** analytics platform built on "
    "**Snowflake** and **Epic** data. This page provides the demo talk "
    "tracks and navigation for each use case."
)
st.markdown("---")

# ---------------------------------------------------------------------------
# Architecture Overview
# ---------------------------------------------------------------------------
st.subheader("Platform Architecture")

st.markdown("**Data Sources**")
st.markdown("""
| Source System | Data Provided |
|---|---|
| Epic EHR | ADT events, orders, diagnoses, procedures, scheduling, referrals, OpTime surgical cases |
| Workday ERP | General Ledger transactions, cost center accounting |
| Kronos HR | Timekeeping, shift schedules, labor hours by employee |
| Payer EDI | 837I/837P claim submissions, 835 electronic remittance advice |
| Supply Chain | Item master, purchase orders, supply usage by encounter |
| Active Directory | Login events, access logs, user authentication activity |
| RTLS / IoT | Real-time bed status changes, patient location tracking |
| Snowflake Marketplace | NPPES provider registry, CMS reference data, SDoH indices, Census demographics |
""")

st.markdown("""
- **Ingestion**: Snowflake Dynamic Tables (bronze → silver → gold) with incremental refresh
- **Curated Layer**: `HOSPITAL360_CUR` — star-schema marts for each use case
- **ML Layer**: `HOSPITAL360_ML` — Cortex ML forecasting, anomaly detection, classification
- **App Layer**: `HOSPITAL360_APP` — Streamlit in Snowflake (this app), Provider Chat
- **Compute**: Container Runtime on `SYSTEM_COMPUTE_POOL_CPU` with PyPI access
""")
st.markdown("---")

# ---------------------------------------------------------------------------
# Talk Track Sections
# ---------------------------------------------------------------------------

# --- 1. Provider 360 Dashboard ---
st.subheader("1. Provider 360 Dashboard")
st.markdown("""
**What it shows**: Executive-level KPI summary across all clinical and financial domains.

**Talk Track**:
- Start here to set the context — show the 6 headline KPIs (encounters, readmission rate, leakage rate, OR utilization, denied charges, ML prediction count)
- Highlight the global facility/date filters in the sidebar that propagate to every page
- Point out the monthly trend sparklines — encounters, readmissions, leakage
- Walk through the use-case cards at the bottom that link to detailed pages
- Mention the ML Quick-Look section showing forecast and anomaly detection previews

**Key Talking Points**:
- Single pane of glass for hospital executives
- Real-time data from Snowflake Dynamic Tables (no batch ETL delays)
- Filters are session-aware and propagate across all pages

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Epic ADT | `FCT_ENCOUNTER` (200K rows) | Aggregated for encounter count KPI |
| Epic ADT + DRG Grouper | `MART_READMISSION_LOS` | Aggregated for readmission rate KPI |
| Epic Referral Mgmt | `MART_PATIENT_LEAKAGE` | Aggregated for leakage rate KPI |
| Epic OpTime | `MART_OR_CAPACITY` | AVG(UTILIZATION_PCT) for OR util KPI |
| Epic Claims + Payer 835s | `MART_DENIALS_REVCYCLE` | SUM(CHARGE_AMT) for denied charges KPI |
| Cortex ML Predictions | `HOSPITAL360_ML.PREDICTIONS.*` | Row count for ML predictions KPI |

Each mart is **pre-joined/denormalized** — the dashboard queries them directly with facility and date filters. No runtime JOINs needed.
""")
st.caption("📂 Navigate via sidebar → **Provider 360**")
st.markdown("---")

# --- 2. Readmission & LOS ---
st.subheader("2. Readmission & Length-of-Stay")
st.markdown("""
**What it shows**: 30-day readmission rates and average length-of-stay by DRG, facility, and provider.

**Talk Track**:
- Filter by encounter type, DRG, and facility to drill into problem areas
- Show the monthly readmission trend with target line at 12%
- Highlight top DRGs driving readmissions (bar chart)
- Demonstrate the LOS distribution histogram and identify outliers
- Point to the facility comparison heatmap

**Key Talking Points**:
- Identifies which DRGs and facilities are driving readmission penalties
- Actionable insights: which patient cohorts need post-discharge follow-up
- LOS outlier detection helps spot documentation or discharge planning issues

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Epic ADT | `FCT_ENCOUNTER` | Base encounter grain (admit/discharge dates, LOS) |
| Epic DRG Grouper + CMS | `DIM_DRG` | JOIN on DRG_SK → DRG weight, expected LOS, MDC |
| Epic Registration | `DIM_PATIENT` | JOIN on PATIENT_SK → age, gender, HCC risk score |
| Epic Claims | `DIM_PAYER` | JOIN on PAYER_SK → payer type/name |
| Epic ADT | `DIM_FACILITY`, `DIM_DEPARTMENT` | JOIN on FACILITY_ID, DEPT_ID → names |
| Epic Provider Directory | `DIM_PROVIDER` | JOIN on PROVIDER_SK → attending physician, specialty |

**Mart Build**: `MART_READMISSION_LOS` = `FCT_ENCOUNTER` ⟕ `DIM_PATIENT` ⟕ `DIM_DRG` ⟕ `DIM_PAYER` ⟕ `DIM_FACILITY` ⟕ `DIM_PROVIDER`. Readmit flag via window function: `LEAD(ADMIT_DATE) OVER (PARTITION BY MRN ORDER BY ADMIT_DATE) - DISCHARGE_DATE <= 30`.
""")
st.caption("📂 Navigate via sidebar → **Readmission & LOS**")
st.markdown("---")

# --- 3. Patient Leakage ---
st.subheader("3. Patient Leakage")
st.markdown("""
**What it shows**: Referral patterns where patients leave the network, with associated lost revenue.

**Talk Track**:
- Explain leakage: patient referred internally but goes out-of-network
- Show leakage rate trend over time — is it improving or worsening?
- Drill into top specialties losing patients (e.g., Orthopedics, Cardiology)
- Highlight the lost revenue waterfall — quantifies the financial impact
- Show the referring provider breakdown — who is sending patients away?

**Key Talking Points**:
- Revenue recovery opportunity — each percentage point of leakage = $X million
- Enables targeted outreach to referring providers
- Network adequacy analysis for strategic planning

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Epic Referral Mgmt | `FCT_REFERRAL` (50K rows) | Base referral grain (date, status, leakage flag) |
| Epic Registration | `DIM_PATIENT` | JOIN on PATIENT_SK → demographics, payer type, ZIP |
| Epic Provider Directory | `DIM_PROVIDER` | JOIN on REFERRING_PROVIDER_SK → referring provider name/specialty |
| Epic Scheduling | External NPI → `REFERRED_TO_SPECIALTY` | Target provider specialty from referral order |
| Epic ADT | `DIM_FACILITY` | JOIN on FACILITY_ID → originating facility name |

**Mart Build**: `MART_PATIENT_LEAKAGE` = `FCT_REFERRAL` ⟕ `DIM_PATIENT` ⟕ `DIM_PROVIDER` ⟕ `DIM_FACILITY`. Leakage flag = referral completed out-of-network. Lost revenue = expected revenue when leakage_flag = TRUE.
""")
st.caption("📂 Navigate via sidebar → **Patient Leakage**")
st.markdown("---")

# --- 4. OR Capacity ---
st.subheader("4. OR Capacity & Utilization")
st.markdown("""
**What it shows**: Operating room block utilization, scheduling efficiency, and capacity optimization.

**Talk Track**:
- Show overall OR utilization gauge — target is 75-85%
- Walk through the block-level heatmap — which blocks are underutilized?
- Highlight the daily utilization timeline — are there patterns by day of week?
- Show the surgeon-level efficiency metrics
- Discuss release and reallocation opportunities for underused blocks

**Key Talking Points**:
- Each OR minute = ~$30-40 in contribution margin
- Identifies blocks that could be released or reallocated
- Supports evidence-based negotiations with surgical departments

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Epic OpTime | `FCT_OR_CASE` (30K cases) | Base surgical case grain (scheduled/actual times, block assignment) |
| Epic Provider Directory | `DIM_PROVIDER` | JOIN on SURGEON_SK → surgeon name, specialty |
| Epic OpTime Blocks | Block name/minutes embedded in `FCT_OR_CASE` | Block allocation from OpTime scheduling |
| Epic ADT | `DIM_FACILITY` | JOIN on FACILITY_ID → facility name |
| CPT Reference | `DIM_PROCEDURE_CPT` | JOIN on PRIMARY_CPT_SK → CPT code/description |

**Mart Build**: `MART_OR_CAPACITY` = `FCT_OR_CASE` ⟕ `DIM_PROVIDER` ⟕ `DIM_FACILITY` ⟕ `DIM_PROCEDURE_CPT`. Utilization = `CASE_MINUTES / BLOCK_MINUTES`. Delay = `ACTUAL_START - SCHEDULED_START`. Day-of-week and prime-time flags derived at load time.
""")
st.caption("📂 Navigate via sidebar → **OR Capacity**")
st.markdown("---")

# --- 5. Staffing & Quality ---
st.subheader("5. Staffing & Quality")
st.markdown("""
**What it shows**: Correlation between labor staffing levels (from Kronos/Workday) and clinical outcomes (readmissions, LOS).

**Talk Track**:
- Start with the KPI comparison: readmission rate on understaffed days vs. adequately staffed days
- Show the dual-axis trend: hours-per-patient declining while readmissions rise
- Walk through the scatter plot: departments with lower staffing have worse outcomes
- Highlight overtime as a leading indicator of quality risk
- Show the day-of-week heatmap — weekends are consistently understaffed

**Key Talking Points**:
- Connects workforce investment directly to patient outcomes — CFO and CNO both care
- Identifies specific departments and shifts where staffing gaps create risk
- Overtime > 15% is a burnout signal that predicts quality degradation
- Actionable: target float pool and agency staff to highest-risk units

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Kronos HR | `FCT_LABOR_HOUR` (730K rows) | Aggregated by DEPT_ID + SHIFT_DATE → daily staffing totals |
| Epic ADT | `FCT_ENCOUNTER` (200K rows) | Patient census = encounters active on a given date in a department |
| Epic ADT | `DIM_DEPARTMENT` | JOIN on DEPT_ID → department name, type, bed count |
| Epic ADT | `DIM_FACILITY` | JOIN on FACILITY_ID → facility name |

**Mart Build**: `MART_STAFFING_QUALITY` = `FCT_LABOR_HOUR` (aggregated) ⟕ `FCT_ENCOUNTER` (census via date spine) ⟕ `DIM_DEPARTMENT` ⟕ `DIM_FACILITY`. Grain: 1 row per department per day. Understaffed flag = hrs/patient below threshold (8 for IP/ICU, 4 for others).
""")
st.caption("📂 Navigate via sidebar → **Staffing & Quality**")
st.markdown("---")

# --- 6. Financial Performance ---
st.subheader("6. Financial Performance")
st.markdown("""
**What it shows**: Department-level cost structure, operating margins, and volume metrics from Workday General Ledger data.

**Talk Track**:
- Start with the headline: revenue vs. expense and overall operating margin
- Show the monthly trend — are margins improving or deteriorating?
- Walk through the cost breakdown: labor is typically 50%+ of hospital expenses
- Drill into cost-per-CMI-adjusted-discharge by department — normalize for acuity
- Compare facilities — which ones are margin-positive?

**Key Talking Points**:
- First time combining ERP financial data with clinical volume in one view
- CMI-adjusted cost per discharge removes acuity bias from department comparisons
- Labor cost % is the #1 lever for margin improvement
- Connects directly to the Staffing & Quality page — staffing decisions have financial consequences

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Workday ERP | `FCT_GL_TRANSACTION` (500K rows) | Aggregated by DEPT_ID + FISCAL_PERIOD → revenue & expense by category |
| Epic ADT | `FCT_ENCOUNTER` (200K rows) | Discharge volume by DEPT_ID + month |
| CMS DRG | `DIM_DRG` | JOIN on DRG_SK → DRG weight for CMI adjustment |
| Org Structure | `DIM_DEPARTMENT`, `DIM_FACILITY` | JOIN on DEPT_ID, FACILITY_ID → names and types |

**Mart Build**: `MART_FINANCIAL_PERFORMANCE` = `FCT_GL_TRANSACTION` (pivoted by CATEGORY) ⟕ `FCT_ENCOUNTER` (discharge volume) ⟕ `DIM_DRG` ⟕ `DIM_DEPARTMENT` ⟕ `DIM_FACILITY`. Grain: 1 row per department per month. Operating margin = (revenue - expense) / revenue.
""")
st.caption("📂 Navigate via sidebar → **Financial Performance**")
st.markdown("---")

# --- 7. Denials & RevCycle ---
st.subheader("7. Denials & Revenue Cycle")
st.markdown("""
**What it shows**: Claim denial rates, denial categories, payer-level analysis, and appeal success rates.

**Talk Track**:
- Start with total denied charges — the dollar impact
- Break down by denial category (auth, medical necessity, coding, etc.)
- Show denial rate trend — are process improvements working?
- Drill into payer-level denial rates — which payers are most problematic?
- Highlight the appeal success rate and recovery opportunity

**Key Talking Points**:
- Industry average denial rate is 5-10%; show where this org stands
- Root cause analysis enables targeted process fixes (e.g., prior auth workflows)
- Appeal prioritization based on dollar value and win probability

**Data Sources & Lineage**:
| Source System | Tables | Join Logic |
|---|---|---|
| Epic Claims (837P/837I) | `FCT_CLAIM_LINE` (1.2M lines) | Base claim line grain (charges, denial flag/reason) |
| Payer Remittances (835) | `FCT_REMITTANCE` → `ALLOWED_AMT`, `PAID_AMT` | Joined on CLAIM_ID + LINE_NUMBER |
| Epic Claims | `DIM_PAYER` | JOIN on PAYER_SK → payer name/type, timely filing limit |
| Epic Provider Directory | `DIM_PROVIDER` | JOIN on PROVIDER_SK → rendering provider |
| ICD-10 Reference | `DIM_DIAGNOSIS_ICD10` | JOIN on DX_SK → diagnosis code/description |
| CPT Reference | `DIM_PROCEDURE_CPT` | JOIN on PROC_SK → CPT code/category |
| Epic Appeals Workflow | Appeal outcome embedded in mart | IS_APPEALED, APPEAL_OUTCOME from workflow status |

**Mart Build**: `MART_DENIALS_REVCYCLE` = `FCT_CLAIM_LINE` (WHERE DENIED_FLAG=TRUE) ⟕ `DIM_PAYER` ⟕ `DIM_PROVIDER` ⟕ `DIM_DIAGNOSIS_ICD10` ⟕ `DIM_PROCEDURE_CPT`. Denial category mapped from DENIAL_REASON. Estimated recovery = `ALLOWED_AMT * appeal_success_probability`.
""")
st.caption("📂 Navigate via sidebar → **Denials & RevCycle**")
st.markdown("---")

# --- 8. Predictive Analytics ---
st.subheader("8. Predictive Analytics")
st.markdown("""
**What it shows**: Snowflake Cortex ML outputs — encounter volume forecasting, denial anomaly detection, readmission risk scoring.

**Talk Track**:
- Show the 90-day encounter volume forecast by type (Inpatient, Outpatient, ED)
- Highlight confidence intervals and explain how forecasting helps staffing
- Switch to anomaly detection — denial spikes that warrant investigation
- Show readmission risk scores — which current patients are highest risk?
- Discuss the model monitoring dashboard (drift, accuracy over time)

**Key Talking Points**:
- All ML runs natively in Snowflake — no external infrastructure
- Cortex ML functions (FORECAST, DETECT_ANOMALIES, CLASSIFICATION) — SQL-accessible
- Predictions refresh automatically via Dynamic Tables
- Explainability: feature importance shows why a patient is high-risk

**Data Sources & Lineage**:
| Cortex ML Function | Input (Feature View) | Output (Prediction Table) | Source Mart |
|---|---|---|---|
| `FORECAST` | `VW_DAILY_ENCOUNTER_VOLUME` | `PRED_ENCOUNTER_VOLUME` | `FCT_ENCOUNTER` aggregated by date + type |
| `DETECT_ANOMALIES` | `VW_DAILY_DENIAL_VOLUME` | `PRED_DENIAL_ANOMALIES` | `MART_DENIALS_REVCYCLE` aggregated by date + category |
| `CONTRIBUTION_EXPLORER` | `VW_READMISSION_DRIVERS` | `PRED_READMISSION_DRIVERS` | `MART_READMISSION_LOS` feature columns |
| `CONTRIBUTION_EXPLORER` | `VW_LEAKAGE_DRIVERS` | `PRED_LEAKAGE_DRIVERS` | `MART_PATIENT_LEAKAGE` feature columns |

**Pipeline**: Feature views (in `HOSPITAL360_ML.FEATURES`) aggregate CUR-layer marts into time-series or feature matrices → Cortex ML functions consume these views → write results to `HOSPITAL360_ML.PREDICTIONS`. Model performance tracked in `HOSPITAL360_ML.MONITORING.MODEL_PERFORMANCE_LOG`.
""")
st.caption("📂 Navigate via sidebar → **Predictive Analytics**")
st.markdown("---")

# --- 9. Provider Chat ---
st.subheader("9. Provider Chat — Agentic Analytics")
st.markdown("""
**What it shows**: Multi-step reasoning agent that plans, queries, and synthesizes complex analytical answers.

**Talk Track**:
- Show how the Agent can chain multiple queries and reason across domains
- Demo a multi-step question: "Compare readmission rates to denial rates — is there a correlation by facility?"
- Show the real-time thinking stream — transparent reasoning process
- Point out how the agent formulates a plan, executes queries, then synthesizes
- Highlight tool use: the agent queries via the semantic view

**Key Talking Points**:
- Agentic AI: plans → executes → synthesizes (not just single-shot SQL generation)
- Real-time streaming shows the thought process (builds trust)
- Can combine data across multiple marts in a single answer
- Guardrails: only accesses data the user's role permits

**Suggested Demo Questions**:
1. "Which facilities have both high readmission rates AND high denial rates? What might explain this?"
2. "Analyze OR utilization trends and forecast if we need additional capacity next quarter"
3. "Summarize the top 3 revenue recovery opportunities across all domains"
""")
st.caption("📂 Navigate via sidebar → **Provider Chat**")
st.markdown("---")

# --- 10. Ops Monitor ---
st.subheader("10. Operations Monitor")
st.markdown("""
**What it shows**: Pipeline health, data quality checks, ML model performance, and platform inventory.

**Talk Track**:
- Start with the Task DAG — show the dependency graph of all data pipelines
- Highlight task execution history — are pipelines running on time?
- Show data quality check results — freshness, row counts, schema drift
- Walk through ML model monitoring — accuracy trends, prediction drift
- Show the platform inventory — tables, views, stages, tasks, models

**Key Talking Points**:
- Full observability of the data platform — not just analytics
- Early warning system for pipeline failures or data quality degradation
- ML model monitoring prevents silent model decay
- Everything runs within Snowflake — no external orchestration tools needed
""")
st.caption("📂 Navigate via sidebar → **Ops Monitor**")
st.markdown("---")

# ---------------------------------------------------------------------------
# Demo Tips
# ---------------------------------------------------------------------------
st.subheader("Demo Tips")
st.markdown("""
- **Start with this page** to set context and frame the narrative
- **Use the Provider 360 Dashboard** as the executive entry point
- **Pick 2-3 use cases** to deep-dive based on audience interest
- **Always end with Provider Chat** — the AI capabilities are the wow factor
- **Ops Monitor** is great for technical audiences (data engineers, platform teams)
- **Global filters** in the sidebar persist across pages — set them once, show everywhere
- **Dark theme** is intentional — optimized for presentation on projectors/screens
""")

# ---------------------------------------------------------------------------
# Medical & Technical Abbreviations
# ---------------------------------------------------------------------------
st.subheader("Glossary of Abbreviations")
st.markdown("""
| Abbreviation | Full Term |
|---|---|
| **ADT** | Admission, Discharge, Transfer — the core hospital patient-movement system |
| **ASA** | American Society of Anesthesiologists — physical status classification (I–VI) |
| **CPT** | Current Procedural Terminology — standardized codes for medical procedures |
| **CMS** | Centers for Medicare & Medicaid Services — federal payer and DRG authority |
| **DRG** | Diagnosis-Related Group — patient classification for hospital reimbursement |
| **DX** | Diagnosis |
| **ED** | Emergency Department |
| **EHR** | Electronic Health Record |
| **ETL** | Extract, Transform, Load — data pipeline pattern |
| **FTE** | Full-Time Equivalent — staffing measurement |
| **GL** | General Ledger — accounting transaction record |
| **HCC** | Hierarchical Condition Category — CMS risk-adjustment score (higher = sicker) |
| **ICD-10** | International Classification of Diseases, 10th Revision — diagnosis code set |
| **LOS** | Length of Stay — days from admission to discharge |
| **MDC** | Major Diagnostic Category — top-level DRG grouping (e.g., nervous system, respiratory) |
| **ML** | Machine Learning |
| **MRN** | Medical Record Number — unique patient identifier within a health system |
| **MS-DRG** | Medicare Severity Diagnosis-Related Group — CMS severity-adjusted DRG |
| **NPI** | National Provider Identifier — 10-digit unique physician/facility ID |
| **OR** | Operating Room |
| **PHI** | Protected Health Information — HIPAA-regulated patient data |
| **PII** | Personally Identifiable Information |
| **SDOH** | Social Determinants of Health — non-clinical factors (housing, income, education) |
| **SK** | Surrogate Key — synthetic primary key in dimensional modeling |
| **835** | HIPAA X12 835 transaction — electronic remittance advice from payers |
| **837I/837P** | HIPAA X12 837 Institutional/Professional — electronic claim submissions |
""")
