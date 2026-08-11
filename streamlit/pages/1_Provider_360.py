"""
Hospital 360 Dashboard — Provider 360 Executive Summary
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import chart_theme as ct

st.set_page_config(layout="wide")

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------
session = st.connection("snowflake").session()

# ---------------------------------------------------------------------------
# Helper — run SQL and return pandas DataFrame
# ---------------------------------------------------------------------------
@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

# ---------------------------------------------------------------------------
# Sidebar — global filters (shared across pages via session_state)
# ---------------------------------------------------------------------------
st.sidebar.image(
    "https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/"
    "Snowflake_Logo.svg/1280px-Snowflake_Logo.svg.png",
    width=180,
)
st.sidebar.title("Provider 360")
st.sidebar.markdown("---")

# Facility filter
facilities = run_query(
    "SELECT DISTINCT FACILITY_NAME FROM HOSPITAL360_CUR.OPERATIONS.DIM_FACILITY ORDER BY 1"
)
facility_options = ["All Facilities"] + facilities["FACILITY_NAME"].tolist()
selected_facility = st.sidebar.selectbox(
    "Facility",
    facility_options,
    index=0,
    key="global_facility",
)

# Date range filter
date_bounds = run_query("""
    SELECT MIN(ADMIT_DATE) AS MIN_DT, MAX(ADMIT_DATE) AS MAX_DT
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
""")
min_date = pd.to_datetime(date_bounds["MIN_DT"].iloc[0]).date()
max_date = pd.to_datetime(date_bounds["MAX_DT"].iloc[0]).date()

date_range = st.sidebar.date_input(
    "Date Range",
    value=(min_date, max_date),
    min_value=min_date,
    max_value=max_date,
    key="global_date_range",
)

# Store in session state for child pages
if isinstance(date_range, tuple) and len(date_range) == 2:
    st.session_state["filter_start"] = str(date_range[0])
    st.session_state["filter_end"] = str(date_range[1])
else:
    st.session_state["filter_start"] = str(min_date)
    st.session_state["filter_end"] = str(max_date)

st.session_state["filter_facility"] = selected_facility

st.sidebar.markdown("---")
st.sidebar.caption("Powered by Snowflake + Streamlit")

# ---------------------------------------------------------------------------
# Build WHERE clause helpers
# ---------------------------------------------------------------------------
def facility_clause(col: str = "FACILITY_NAME") -> str:
    if selected_facility == "All Facilities":
        return ""
    return f" AND {col} = '{selected_facility}'"

start_dt = st.session_state["filter_start"]
end_dt = st.session_state["filter_end"]

# ---------------------------------------------------------------------------
# Page header
# ---------------------------------------------------------------------------
st.title("Provider 360")
st.caption(f"Data from {start_dt} to {end_dt}")

# ---------------------------------------------------------------------------
# KPI row — 6 headline metrics
# ---------------------------------------------------------------------------
kpi_encounters = run_query(f"""
    SELECT COUNT(*) AS N
    FROM HOSPITAL360_CUR.CLINICAL.FCT_ENCOUNTER
    WHERE ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
""")

kpi_readmit = run_query(f"""
    SELECT ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
""")

kpi_leakage = run_query(f"""
    SELECT ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE REFERRAL_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
""")

kpi_or = run_query(f"""
    SELECT ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS UTIL
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE CASE_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
""")

kpi_denials = run_query(f"""
    SELECT ROUND(SUM(CHARGE_AMT), 0) AS AMT
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE SERVICE_DATE BETWEEN '{start_dt}' AND '{end_dt}'
""")

kpi_ml = run_query("""
    SELECT SUM(ROW_COUNT) AS N
    FROM HOSPITAL360_ML.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'PREDICTIONS'
""")

c1, c2, c3, c4, c5, c6 = st.columns(6)
c1.metric("Total Encounters", f"{int(kpi_encounters['N'].iloc[0]):,}")
c2.metric("Readmission Rate", f"{kpi_readmit['RATE'].iloc[0]}%")
c3.metric("Leakage Rate", f"{kpi_leakage['RATE'].iloc[0]}%")
c4.metric("OR Utilization", f"{kpi_or['UTIL'].iloc[0]}%")
c5.metric("Denied Charges", f"${int(kpi_denials['AMT'].iloc[0]):,}")
c6.metric("ML Predictions", f"{int(kpi_ml['N'].iloc[0]):,}")

st.markdown("---")

# ---------------------------------------------------------------------------
# Trend row — 3 monthly sparklines
# ---------------------------------------------------------------------------
col_left, col_mid, col_right = st.columns(3)

# --- Monthly encounters ---
trend_enc = run_query(f"""
    SELECT DATE_TRUNC('MONTH', ADMIT_DATE)::DATE AS MONTH,
           COUNT(*) AS ENCOUNTERS
    FROM HOSPITAL360_CUR.CLINICAL.FCT_ENCOUNTER
    WHERE ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
    GROUP BY 1 ORDER BY 1
""")
with col_left:
    st.subheader("Monthly Encounters")
    fig_enc = px.area(trend_enc, x="MONTH", y="ENCOUNTERS",
                      color_discrete_sequence=[ct.COLORS["primary"]])
    ct.apply_style(fig_enc, height=250)
    ct.style_area(fig_enc, ct.COLORS["primary"])
    fig_enc.update_layout(xaxis_title="", yaxis_title="", showlegend=False)
    st.plotly_chart(fig_enc, use_container_width=True)

# --- Monthly readmission rate ---
trend_readmit = run_query(f"""
    SELECT ADMIT_MONTH AS MONTH,
           ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS READMIT_RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
    GROUP BY 1 ORDER BY 1
""")
with col_mid:
    st.subheader("Readmission Rate Trend")
    fig_readmit = px.line(trend_readmit, x="MONTH", y="READMIT_RATE",
                          color_discrete_sequence=[ct.COLORS["danger"]])
    ct.apply_style(fig_readmit, height=250)
    ct.glow_line(fig_readmit, 0, ct.COLORS["danger"])
    fig_readmit.update_layout(xaxis_title="", yaxis_title="%", showlegend=False)
    st.plotly_chart(fig_readmit, use_container_width=True)

# --- Monthly leakage rate ---
trend_leak = run_query(f"""
    SELECT REFERRAL_MONTH AS MONTH,
           ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS LEAK_RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE REFERRAL_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    {facility_clause()}
    GROUP BY 1 ORDER BY 1
""")
with col_right:
    st.subheader("Leakage Rate Trend")
    fig_leak = px.line(trend_leak, x="MONTH", y="LEAK_RATE",
                       color_discrete_sequence=[ct.COLORS["warning"]])
    ct.apply_style(fig_leak, height=250)
    ct.glow_line(fig_leak, 0, ct.COLORS["warning"])
    fig_leak.update_layout(xaxis_title="", yaxis_title="%", showlegend=False)
    st.plotly_chart(fig_leak, use_container_width=True)

st.markdown("---")

# ---------------------------------------------------------------------------
# Bottom row — Use-case summary cards
# ---------------------------------------------------------------------------
st.subheader("Use-Case Highlights")

uc1, uc2, uc3, uc4 = st.columns(4)

# UC2 — Readmission & LOS
top_drg = run_query(f"""
    SELECT DRG_DESCRIPTION, COUNT(*) AS N
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE READMIT_30_FLAG = TRUE
      AND ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'
      {facility_clause()}
    GROUP BY 1 ORDER BY 2 DESC LIMIT 1
""")
with uc1:
    st.markdown("**Readmission & LOS**")
    if not top_drg.empty:
        st.markdown(f"Top readmitted DRG: **{top_drg['DRG_DESCRIPTION'].iloc[0]}**")
    st.page_link("pages/2_Readmission_LOS.py", label="View Details →")

# UC1 — Patient Leakage
top_spec = run_query(f"""
    SELECT REFERRED_TO_SPECIALTY, ROUND(SUM(LOST_REVENUE), 0) AS LOST
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE LEAKAGE_FLAG = TRUE
      AND REFERRAL_DATE BETWEEN '{start_dt}' AND '{end_dt}'
      {facility_clause()}
    GROUP BY 1 ORDER BY 2 DESC LIMIT 1
""")
with uc2:
    st.markdown("**Patient Leakage**")
    if not top_spec.empty:
        st.markdown(
            f"Highest lost revenue: **{top_spec['REFERRED_TO_SPECIALTY'].iloc[0]}** "
            f"(${int(top_spec['LOST'].iloc[0]):,})"
        )
    st.page_link("pages/3_Patient_Leakage.py", label="View Details →")

# UC3 — OR Capacity
low_block = run_query(f"""
    SELECT BLOCK_NAME, ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS UTIL
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE CASE_DATE BETWEEN '{start_dt}' AND '{end_dt}'
      {facility_clause()}
    GROUP BY 1 ORDER BY 2 ASC LIMIT 1
""")
with uc3:
    st.markdown("**OR Capacity**")
    if not low_block.empty:
        st.markdown(
            f"Lowest utilization: **{low_block['BLOCK_NAME'].iloc[0]}** "
            f"({low_block['UTIL'].iloc[0]}%)"
        )
    st.page_link("pages/4_OR_Capacity.py", label="View Details →")

# UC4 — Denials
top_cat = run_query(f"""
    SELECT DENIAL_CATEGORY, COUNT(*) AS N
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE SERVICE_DATE BETWEEN '{start_dt}' AND '{end_dt}'
    GROUP BY 1 ORDER BY 2 DESC LIMIT 1
""")
with uc4:
    st.markdown("**Denials & RevCycle**")
    if not top_cat.empty:
        st.markdown(f"Top denial category: **{top_cat['DENIAL_CATEGORY'].iloc[0]}**")
    st.page_link("pages/7_Denials_RevCycle.py", label="View Details →")

st.markdown("---")

# ---------------------------------------------------------------------------
# ML Quick-Look
# ---------------------------------------------------------------------------
st.subheader("ML Quick-Look")

ml1, ml2 = st.columns(2)

# Encounter forecast preview
forecast = run_query("""
    SELECT ENCOUNTER_TYPE, FORECAST_DATE, FORECAST_COUNT, LOWER_BOUND, UPPER_BOUND
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_ENCOUNTER_VOLUME
    ORDER BY ENCOUNTER_TYPE, FORECAST_DATE
""")
with ml1:
    st.markdown("**Encounter Volume Forecast** (next 90 days)")
    fig_fc = px.line(forecast, x="FORECAST_DATE", y="FORECAST_COUNT",
                     color="ENCOUNTER_TYPE",
                     color_discrete_sequence=ct.COLOR_SEQ)
    ct.apply_style(fig_fc, height=280, legend_below=True)
    fig_fc.update_layout(xaxis_title="", yaxis_title="Forecasted Count")
    st.plotly_chart(fig_fc, use_container_width=True)

# Anomaly preview
anomalies = run_query("""
    SELECT DENIAL_CATEGORY, TS, ACTUAL_COUNT, EXPECTED_COUNT,
           LOWER_BOUND, UPPER_BOUND, IS_ANOMALY
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES
    ORDER BY DENIAL_CATEGORY, TS
""")
with ml2:
    st.markdown("**Denial Anomaly Detection**")
    anom_count = anomalies[anomalies["IS_ANOMALY"] == True].shape[0]
    st.markdown(f"{anom_count} anomalous periods detected across all categories")
    st.page_link("pages/8_Predictive_Analytics.py", label="Explore Predictive Analytics →")

st.markdown("---")

# ---------------------------------------------------------------------------
# Provider Chat link
# ---------------------------------------------------------------------------
st.subheader("Agentic Analytics")
st.markdown(
    "Multi-step reasoning agent that plans, queries, and synthesizes "
    "answers across all Hospital 360 data domains automatically."
)
st.page_link("pages/9_Provider_Chat.py", label="Open Provider Chat →")

st.markdown("---")

# ---------------------------------------------------------------------------
# Operations Monitor link
# ---------------------------------------------------------------------------
st.subheader("Operations Monitor")
st.markdown(
    "Pipeline execution status, data quality check results, "
    "ML model performance tracking, and platform inventory — "
    "the operational health dashboard for the Hospital 360 platform."
)
st.page_link("pages/10_Ops_Monitor.py", label="Open Operations Monitor →")
