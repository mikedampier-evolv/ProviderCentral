"""
Hospital 360 — Operations Monitor
Pipeline status, data quality checks, model performance, and platform inventory.
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import chart_theme as ct  # noqa: F401 — registers h360_dark template

st.set_page_config(layout="wide")

session = st.connection("snowflake").session()

@st.cache_data(ttl=300)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

st.title("Operations Monitor")
st.caption("Pipeline execution, data quality, model performance, and platform health")

# ==========================================================================
# 1. Pipeline Status
# ==========================================================================
st.subheader("Pipeline Execution Log")

pipeline_log = run_query("""
    SELECT RUN_ID, RUN_TS, TASK_NAME, STATUS, ROWS_AFFECTED, DURATION_SECONDS, ERROR_MESSAGE
    FROM HOSPITAL360_ML.MONITORING.PIPELINE_RUN_LOG
    ORDER BY RUN_TS DESC
    LIMIT 50
""")

if pipeline_log.empty:
    st.info("No pipeline runs recorded yet. Execute the task DAG to populate this section.")
else:
    # Summary KPIs
    latest_run = pipeline_log.iloc[0]
    total_runs = len(pipeline_log)
    success_runs = len(pipeline_log[pipeline_log["STATUS"] == "SUCCESS"])
    fail_runs = len(pipeline_log[pipeline_log["STATUS"] == "FAILURE"])

    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Last Run", str(latest_run["RUN_TS"])[:19])
    k2.metric("Total Log Entries", f"{total_runs:,}")
    k3.metric("Successes", f"{success_runs:,}")
    k4.metric("Failures", f"{fail_runs:,}")

    # Task-level breakdown
    task_summary = pipeline_log.groupby("TASK_NAME").agg(
        RUNS=("STATUS", "count"),
        LAST_STATUS=("STATUS", "first"),
        TOTAL_ROWS=("ROWS_AFFECTED", "sum"),
    ).reset_index()

    fig_tasks = px.bar(
        task_summary, x="TASK_NAME", y="RUNS", color="LAST_STATUS",
        color_discrete_map={"SUCCESS": "#2ecc71", "FAILURE": "#e74c3c", "SKIPPED": "#f39c12"},
        title="Run Count by Task",
    )
    fig_tasks.update_layout(height=300, margin=dict(t=40, b=20))
    st.plotly_chart(fig_tasks, use_container_width=True)

    with st.expander("Pipeline Run Detail"):
        st.dataframe(pipeline_log, use_container_width=True, hide_index=True)

st.markdown("---")

# ==========================================================================
# 2. Data Quality Dashboard
# ==========================================================================
st.subheader("Data Quality Checks")

dq_results = run_query("""
    SELECT CHECK_ID, CHECK_TS, TABLE_NAME, CHECK_NAME, RESULT,
           EXPECTED_VALUE, ACTUAL_VALUE, DETAILS
    FROM HOSPITAL360_ML.MONITORING.DATA_QUALITY_CHECKS
    ORDER BY CHECK_TS DESC
    LIMIT 100
""")

if dq_results.empty:
    st.info("No data quality checks recorded yet. Run `CALL HOSPITAL360_ML.MONITORING.SP_RUN_DATA_QUALITY_CHECKS()` to populate.")
else:
    # Get the latest check batch (same CHECK_TS within a minute)
    latest_ts = dq_results["CHECK_TS"].max()
    latest_checks = dq_results[
        dq_results["CHECK_TS"] >= latest_ts - pd.Timedelta(minutes=5)
    ]

    pass_ct = len(latest_checks[latest_checks["RESULT"] == "PASS"])
    fail_ct = len(latest_checks[latest_checks["RESULT"] == "FAIL"])
    warn_ct = len(latest_checks[latest_checks["RESULT"] == "WARN"])
    total_ct = len(latest_checks)

    d1, d2, d3, d4 = st.columns(4)
    d1.metric("Total Checks", total_ct)
    d2.metric("Passed", pass_ct)
    d3.metric("Warnings", warn_ct)
    d4.metric("Failed", fail_ct)

    # Color-coded result table
    def color_result(val):
        if val == "PASS":
            return "background-color: #d4edda; color: #155724"
        elif val == "FAIL":
            return "background-color: #f8d7da; color: #721c24"
        elif val == "WARN":
            return "background-color: #fff3cd; color: #856404"
        return ""

    display_df = latest_checks[["TABLE_NAME", "CHECK_NAME", "RESULT", "EXPECTED_VALUE", "ACTUAL_VALUE", "DETAILS"]].copy()
    styled = display_df.style.map(color_result, subset=["RESULT"])
    st.dataframe(styled, use_container_width=True, hide_index=True)

    # Button to re-run checks
    if st.button("Re-run Data Quality Checks"):
        with st.spinner("Running DQ checks..."):
            result = session.sql("CALL HOSPITAL360_ML.MONITORING.SP_RUN_DATA_QUALITY_CHECKS()").collect()
            st.success(result[0][0])
            st.cache_data.clear()
            st.rerun()

st.markdown("---")

# ==========================================================================
# 3. Model Performance
# ==========================================================================
st.subheader("Model Performance Tracking")

model_perf = run_query("""
    SELECT LOG_ID, LOG_TS, MODEL_NAME, METRIC_NAME, METRIC_VALUE
    FROM HOSPITAL360_ML.MONITORING.MODEL_PERFORMANCE_LOG
    ORDER BY LOG_TS DESC
    LIMIT 50
""")

if model_perf.empty:
    st.info("No model performance metrics recorded yet. Run the pipeline to populate.")
else:
    # Pivot for display
    perf_pivot = model_perf.pivot_table(
        index="MODEL_NAME", columns="METRIC_NAME", values="METRIC_VALUE", aggfunc="last"
    ).reset_index()
    st.dataframe(perf_pivot, use_container_width=True, hide_index=True)

    # Time series of model metrics if multiple runs exist
    if len(model_perf["LOG_TS"].unique()) > 1:
        fig_perf = px.line(
            model_perf, x="LOG_TS", y="METRIC_VALUE", color="MODEL_NAME",
            facet_row="METRIC_NAME", title="Model Metrics Over Time",
        )
        fig_perf.update_layout(height=400)
        st.plotly_chart(fig_perf, use_container_width=True)

st.markdown("---")

# ==========================================================================
# 4. Platform Inventory
# ==========================================================================
st.subheader("Platform Inventory")

# Count objects across all H360 databases
inventory = run_query("""
    SELECT 'Tables' AS OBJECT_TYPE, COUNT(*) AS COUNT
    FROM (
        SELECT TABLE_NAME FROM HOSPITAL360_CUR.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA') AND TABLE_TYPE = 'BASE TABLE'
        UNION ALL
        SELECT TABLE_NAME FROM HOSPITAL360_ML.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA') AND TABLE_TYPE = 'BASE TABLE'
    )
    UNION ALL
    SELECT 'Views', COUNT(*) FROM (
        SELECT TABLE_NAME FROM HOSPITAL360_ML.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA') AND TABLE_TYPE = 'VIEW'
    )
    UNION ALL
    SELECT 'ML Feature Views', 4
    UNION ALL
    SELECT 'ML Models (Forecast)', 1
    UNION ALL
    SELECT 'ML Models (Anomaly Detection)', 1
    UNION ALL
    SELECT 'ML Models (Top Insights)', 2
    UNION ALL
    SELECT 'Prediction Tables', 4
    UNION ALL
    SELECT 'Semantic Views', 1
    UNION ALL
    SELECT 'Cortex Agents', 1
    UNION ALL
    SELECT 'Scheduled Tasks', 5
    UNION ALL
    SELECT 'Stored Procedures', 4
    UNION ALL
    SELECT 'Masking Policies', 6
    UNION ALL
    SELECT 'Row Access Policies', 2
    UNION ALL
    SELECT 'Governance Tags', 4
    UNION ALL
    SELECT 'Streamlit Pages', 9
    ORDER BY OBJECT_TYPE
""")

# Display as 4x4 grid of metrics
cols = st.columns(4)
for i, row in inventory.iterrows():
    cols[i % 4].metric(row["OBJECT_TYPE"], f"{int(row['COUNT']):,}")

st.markdown("---")

# ==========================================================================
# 5. Data Lineage DAG
# ==========================================================================
st.subheader("Data Lineage DAG")
st.caption("Table-level lineage: Dimensions → Facts → Marts → Feature Views → Predictions")

# --- Node definitions: (x_col, y_row) layout ---
# Layer x-positions
X_DIM, X_FACT, X_MART, X_FEAT, X_PRED = 0, 1, 2, 3, 4

# Nodes: {short_label: (x, y, full_name, layer)}
nodes = {
    # Dimensions (x=0)
    "DIM_PATIENT":         (X_DIM, 0.9, "CLINICAL.DIM_PATIENT (25K)", "Dimension"),
    "DIM_PROVIDER":        (X_DIM, 0.75, "CLINICAL.DIM_PROVIDER (200)", "Dimension"),
    "DIM_FACILITY":        (X_DIM, 0.6, "OPERATIONS.DIM_FACILITY", "Dimension"),
    "DIM_PAYER":           (X_DIM, 0.45, "FINANCIAL.DIM_PAYER", "Dimension"),
    "DIM_DRG":             (X_DIM, 0.3, "FINANCIAL.DIM_DRG (80)", "Dimension"),
    "DIM_PROCEDURE_CPT":   (X_DIM, 0.15, "CLINICAL.DIM_PROCEDURE_CPT (150)", "Dimension"),
    "DIM_DIAGNOSIS_ICD10": (X_DIM, 0.0, "CLINICAL.DIM_DIAGNOSIS_ICD10 (200)", "Dimension"),
    # Facts (x=1)
    "FCT_ENCOUNTER":  (X_FACT, 0.82, "CLINICAL.FCT_ENCOUNTER (200K)", "Fact"),
    "FCT_REFERRAL":   (X_FACT, 0.6, "CLINICAL.FCT_REFERRAL (50K)", "Fact"),
    "FCT_OR_CASE":    (X_FACT, 0.38, "OPERATIONS.FCT_OR_CASE (30K)", "Fact"),
    "FCT_CLAIM_LINE": (X_FACT, 0.15, "FINANCIAL.FCT_CLAIM_LINE (1.2M)", "Fact"),
    # Marts (x=2)
    "MART_READMISSION_LOS": (X_MART, 0.82, "MART_READMISSION_LOS", "Mart"),
    "MART_PATIENT_LEAKAGE": (X_MART, 0.6, "MART_PATIENT_LEAKAGE", "Mart"),
    "MART_OR_CAPACITY":     (X_MART, 0.38, "MART_OR_CAPACITY", "Mart"),
    "MART_DENIALS_REVCYCLE": (X_MART, 0.15, "MART_DENIALS_REVCYCLE", "Mart"),
    # Feature Views (x=3)
    "VW_ENCOUNTER_VOL":   (X_FEAT, 0.82, "VW_DAILY_ENCOUNTER_VOLUME", "Feature View"),
    "VW_DENIAL_VOL":      (X_FEAT, 0.38, "VW_DAILY_DENIAL_VOLUME", "Feature View"),
    "VW_READMIT_DRIVERS": (X_FEAT, 0.68, "VW_READMISSION_DRIVERS", "Feature View"),
    "VW_LEAK_DRIVERS":    (X_FEAT, 0.53, "VW_LEAKAGE_DRIVERS", "Feature View"),
    # Predictions (x=4)
    "PRED_ENCOUNTER_VOL":    (X_PRED, 0.82, "PRED_ENCOUNTER_VOLUME", "Prediction"),
    "PRED_DENIAL_ANOM":      (X_PRED, 0.38, "PRED_DENIAL_ANOMALIES", "Prediction"),
    "PRED_READMIT_DRIVERS":  (X_PRED, 0.68, "PRED_READMISSION_DRIVERS", "Prediction"),
    "PRED_LEAK_DRIVERS":     (X_PRED, 0.53, "PRED_LEAKAGE_DRIVERS", "Prediction"),
}

# --- Edges: (source, target) ---
edges = [
    # Dims → Facts
    ("DIM_PATIENT", "FCT_ENCOUNTER"), ("DIM_PROVIDER", "FCT_ENCOUNTER"),
    ("DIM_FACILITY", "FCT_ENCOUNTER"), ("DIM_PAYER", "FCT_ENCOUNTER"),
    ("DIM_DRG", "FCT_ENCOUNTER"),
    ("DIM_PATIENT", "FCT_REFERRAL"), ("DIM_PROVIDER", "FCT_REFERRAL"),
    ("DIM_FACILITY", "FCT_REFERRAL"),
    ("DIM_PATIENT", "FCT_OR_CASE"), ("DIM_PROVIDER", "FCT_OR_CASE"),
    ("DIM_FACILITY", "FCT_OR_CASE"), ("DIM_PROCEDURE_CPT", "FCT_OR_CASE"),
    ("DIM_PATIENT", "FCT_CLAIM_LINE"), ("DIM_PAYER", "FCT_CLAIM_LINE"),
    ("DIM_PROVIDER", "FCT_CLAIM_LINE"), ("DIM_DIAGNOSIS_ICD10", "FCT_CLAIM_LINE"),
    ("DIM_PROCEDURE_CPT", "FCT_CLAIM_LINE"),
    # Facts → Marts
    ("FCT_ENCOUNTER", "MART_READMISSION_LOS"),
    ("FCT_REFERRAL", "MART_PATIENT_LEAKAGE"),
    ("FCT_OR_CASE", "MART_OR_CAPACITY"),
    ("FCT_CLAIM_LINE", "MART_DENIALS_REVCYCLE"),
    # Marts → Feature Views
    ("MART_READMISSION_LOS", "VW_ENCOUNTER_VOL"),
    ("MART_READMISSION_LOS", "VW_READMIT_DRIVERS"),
    ("MART_PATIENT_LEAKAGE", "VW_LEAK_DRIVERS"),
    ("MART_DENIALS_REVCYCLE", "VW_DENIAL_VOL"),
    # Feature Views → Predictions
    ("VW_ENCOUNTER_VOL", "PRED_ENCOUNTER_VOL"),
    ("VW_DENIAL_VOL", "PRED_DENIAL_ANOM"),
    ("VW_READMIT_DRIVERS", "PRED_READMIT_DRIVERS"),
    ("VW_LEAK_DRIVERS", "PRED_LEAK_DRIVERS"),
]

# --- Layer colors ---
layer_colors = {
    "Dimension": "#7C3AED",     # Purple
    "Fact": "#29B5E8",          # Blue
    "Mart": "#10B981",          # Emerald
    "Feature View": "#F59E0B",  # Amber
    "Prediction": "#EF4444",    # Red
}

# --- Build Plotly figure ---
fig_dag = go.Figure()

# Draw edges
for src, tgt in edges:
    x0, y0 = nodes[src][0], nodes[src][1]
    x1, y1 = nodes[tgt][0], nodes[tgt][1]
    fig_dag.add_trace(go.Scatter(
        x=[x0, x1, None], y=[y0, y1, None],
        mode="lines",
        line=dict(color="rgba(255,255,255,0.6)", width=1.5),
        hoverinfo="skip",
        showlegend=False,
    ))

# Draw nodes by layer (for legend grouping)
for layer, color in layer_colors.items():
    layer_nodes = {k: v for k, v in nodes.items() if v[3] == layer}
    fig_dag.add_trace(go.Scatter(
        x=[v[0] for v in layer_nodes.values()],
        y=[v[1] for v in layer_nodes.values()],
        mode="markers+text",
        marker=dict(size=22, color=color, line=dict(width=1.5, color="rgba(255,255,255,0.3)")),
        text=[k.replace("_", " ").replace("VW ", "").replace("PRED ", "") for k in layer_nodes.keys()],
        textposition="top center",
        textfont=dict(size=9, color="#E0E0E0"),
        hovertext=[v[2] for v in layer_nodes.values()],
        hoverinfo="text",
        name=layer,
    ))

fig_dag.update_layout(
    template="h360_dark",
    height=600,
    margin=dict(l=10, r=10, t=30, b=30),
    xaxis=dict(
        showgrid=False, zeroline=False, showticklabels=True,
        tickvals=[0, 1, 2, 3, 4],
        ticktext=["Dimensions", "Facts", "Marts", "Feature Views", "Predictions"],
        tickfont=dict(size=12, color="#FFFFFF"),
    ),
    yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
    legend=dict(orientation="h", y=-0.05, x=0.5, xanchor="center"),
    hovermode="closest",
)
st.plotly_chart(fig_dag, use_container_width=True)

st.markdown("---")

# Task DAG status
st.subheader("Task DAG Overview")
task_info = run_query("""
    SELECT
        t.NAME AS TASK_NAME,
        t.STATE,
        t.WAREHOUSE,
        t.SCHEDULE,
        t.PREDECESSORS
    FROM TABLE(HOSPITAL360_ML.INFORMATION_SCHEMA.TASK_DEPENDENTS(
        TASK_NAME => 'HOSPITAL360_ML.MONITORING.TASK_REFRESH_PIPELINE',
        RECURSIVE => TRUE
    )) t
    ORDER BY t.NAME
""")

if not task_info.empty:
    st.dataframe(task_info, use_container_width=True, hide_index=True)
else:
    # Fallback if TASK_DEPENDENTS not available
    task_fallback = run_query("""
        SELECT 'TASK_REFRESH_PIPELINE' AS TASK_NAME, 'CRON 0 6 * * * UTC' AS SCHEDULE, 'H360_XFM_WH' AS WAREHOUSE, 'Root task' AS ROLE_IN_DAG
        UNION ALL
        SELECT 'TASK_REFRESH_MARTS', NULL, 'H360_XFM_WH', 'After: TASK_REFRESH_PIPELINE'
        UNION ALL
        SELECT 'TASK_RETRAIN_FORECAST', NULL, 'H360_ML_WH', 'After: TASK_REFRESH_MARTS'
        UNION ALL
        SELECT 'TASK_RETRAIN_ANOMALY', NULL, 'H360_ML_WH', 'After: TASK_REFRESH_MARTS'
        UNION ALL
        SELECT 'TASK_LOG_PIPELINE_RUN', NULL, 'H360_BI_WH', 'After: FORECAST + ANOMALY'
    """)
    st.dataframe(task_fallback, use_container_width=True, hide_index=True)

st.caption("Tasks are created in SUSPENDED state for demo safety. Use `EXECUTE TASK` for manual runs.")
