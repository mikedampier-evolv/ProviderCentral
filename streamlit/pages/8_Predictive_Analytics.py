"""
Hospital 360 — Predictive Analytics Dashboard
Consolidated view of all 4 Cortex ML model outputs.
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import chart_theme as ct
import pandas as pd

st.set_page_config(layout="wide")

session = st.connection("snowflake").session()

@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

st.title("Predictive Analytics")
st.caption("Cortex ML model outputs: Forecasting, Anomaly Detection, and Contribution Explorer")

# ---------------------------------------------------------------------------
# Model inventory
# ---------------------------------------------------------------------------
model_meta = run_query("""
    SELECT TABLE_NAME, ROW_COUNT
    FROM HOSPITAL360_ML.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'PREDICTIONS'
    ORDER BY TABLE_NAME
""")

st.subheader("Model Inventory")
m1, m2, m3, m4 = st.columns(4)
models = {
    "PRED_ENCOUNTER_VOLUME":    ("Encounter Forecast",     "FORECASTING"),
    "PRED_DENIAL_ANOMALIES":    ("Denial Anomaly Detect.", "ANOMALY_DETECTION"),
    "PRED_READMISSION_DRIVERS": ("Readmission Drivers",   "TOP_INSIGHTS"),
    "PRED_LEAKAGE_DRIVERS":     ("Leakage Drivers",       "TOP_INSIGHTS"),
}
for col, (tbl, (label, mtype)) in zip([m1, m2, m3, m4], models.items()):
    row_ct = model_meta.loc[model_meta["TABLE_NAME"] == tbl, "ROW_COUNT"]
    rows = int(row_ct.iloc[0]) if not row_ct.empty else 0
    col.metric(label, f"{rows:,} rows")
    col.caption(f"Type: {mtype}")

st.markdown("---")

# ===================================================================
# 1. ENCOUNTER VOLUME FORECAST
# ===================================================================
st.subheader("1. Encounter Volume Forecast")
st.caption("90-day forecast by encounter type with confidence intervals")

forecast = run_query("""
    SELECT ENCOUNTER_TYPE, FORECAST_DATE::DATE AS FORECAST_DATE,
           ROUND(FORECAST_COUNT, 0) AS FORECAST_COUNT,
           ROUND(LOWER_BOUND, 0) AS LOWER_BOUND,
           ROUND(UPPER_BOUND, 0) AS UPPER_BOUND
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_ENCOUNTER_VOLUME
    ORDER BY ENCOUNTER_TYPE, FORECAST_DATE
""")

# Get historical actuals for context
actuals = run_query("""
    SELECT ENCOUNTER_TYPE,
           TS::DATE AS DT,
           ENCOUNTER_COUNT AS ACTUAL
    FROM HOSPITAL360_ML.FEATURES.VW_DAILY_ENCOUNTER_VOLUME
    WHERE TS >= '2024-10-01'
    ORDER BY ENCOUNTER_TYPE, TS
""")

if not forecast.empty:
    sel_enc = st.selectbox("Encounter Type", forecast["ENCOUNTER_TYPE"].unique().tolist(),
                           key="ml_enc_type")

    fc = forecast[forecast["ENCOUNTER_TYPE"] == sel_enc]
    act = actuals[actuals["ENCOUNTER_TYPE"] == sel_enc] if not actuals.empty else pd.DataFrame()

    fig_fc = go.Figure()

    # Historical actuals
    if not act.empty:
        fig_fc.add_trace(go.Scatter(
            x=act["DT"], y=act["ACTUAL"],
            mode="lines", line=dict(color=ct.COLORS["muted"]),
            name="Historical Actual",
        ))

    # Confidence band
    fig_fc.add_trace(go.Scatter(
        x=pd.concat([fc["FORECAST_DATE"], fc["FORECAST_DATE"][::-1]]),
        y=pd.concat([fc["UPPER_BOUND"], fc["LOWER_BOUND"][::-1]]),
        fill="toself", fillcolor="rgba(41,181,232,0.15)",
        line=dict(color="rgba(41,181,232,0)"),
        name="95% CI",
    ))

    # Forecast line
    fig_fc.add_trace(go.Scatter(
        x=fc["FORECAST_DATE"], y=fc["FORECAST_COUNT"],
        mode="lines", line=dict(color=ct.COLORS["primary"], width=2),
        name="Forecast",
    ))

    ct.apply_style(fig_fc, height=400, legend_below=True)
    fig_fc.update_layout(xaxis_title="", yaxis_title="Daily Encounters")
    ct.glow_line(fig_fc, trace_idx=len(fig_fc.data) - 1, color=ct.COLORS["primary"])
    st.plotly_chart(fig_fc, use_container_width=True)

    with st.expander("Forecast Data"):
        st.dataframe(fc, use_container_width=True, hide_index=True)
else:
    st.info("No forecast data available.")

st.markdown("---")

# ===================================================================
# 2. DENIAL ANOMALY DETECTION
# ===================================================================
st.subheader("2. Denial Anomaly Detection")
st.caption("Daily denial volume with expected range and anomaly flags")

anom = run_query("""
    SELECT DENIAL_CATEGORY, TS, ACTUAL_COUNT, EXPECTED_COUNT,
           LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE,
           ACTUAL_CHARGES
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES
    ORDER BY DENIAL_CATEGORY, TS
""")

if not anom.empty:
    anom_cats = anom["DENIAL_CATEGORY"].unique().tolist()

    # Show all categories in tabs
    tabs = st.tabs(anom_cats)
    for tab, cat in zip(tabs, anom_cats):
        with tab:
            cat_data = anom[anom["DENIAL_CATEGORY"] == cat]
            anomalies = cat_data[cat_data["IS_ANOMALY"] == True]

            fig_a = go.Figure()
            fig_a.add_trace(go.Scatter(
                x=pd.concat([cat_data["TS"], cat_data["TS"][::-1]]),
                y=pd.concat([cat_data["UPPER_BOUND"], cat_data["LOWER_BOUND"][::-1]]),
                fill="toself", fillcolor="rgba(41,181,232,0.12)",
                line=dict(color="rgba(41,181,232,0)"),
                name="Expected Range",
            ))
            fig_a.add_trace(go.Scatter(
                x=cat_data["TS"], y=cat_data["EXPECTED_COUNT"],
                mode="lines", line=dict(color=ct.COLORS["primary"], dash="dash"),
                name="Expected",
            ))
            fig_a.add_trace(go.Scatter(
                x=cat_data["TS"], y=cat_data["ACTUAL_COUNT"],
                mode="lines+markers", line=dict(color=ct.COLORS["muted"]),
                marker=dict(size=4),
                name="Actual",
            ))
            if not anomalies.empty:
                fig_a.add_trace(go.Scatter(
                    x=anomalies["TS"], y=anomalies["ACTUAL_COUNT"],
                    mode="markers",
                    marker=dict(color=ct.COLORS["danger"], size=10, symbol="x"),
                    name="Anomaly",
                ))
            ct.apply_style(fig_a, height=340, legend_below=True)
            fig_a.update_layout(xaxis_title="", yaxis_title="Denial Count")
            st.plotly_chart(fig_a, use_container_width=True)

            st.info(f"**{anomalies.shape[0]}** anomalous periods detected | "
                    f"Total charges on anomaly days: "
                    f"${int(anomalies['ACTUAL_CHARGES'].sum()) if not anomalies.empty else 0:,}")
else:
    st.info("No anomaly detection data available.")

st.markdown("---")

# ===================================================================
# 3. READMISSION DRIVERS (Top Insights)
# ===================================================================
st.subheader("3. Readmission Rate Drivers")
st.caption("Cortex ML Top Insights: segments contributing to readmission rate changes")

readmit_drivers = run_query("""
    SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE,
           METRIC_CONTROL, METRIC_TEST
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_READMISSION_DRIVERS
    ORDER BY ABS(RELATIVE_CONTRIBUTION) DESC
""")

if not readmit_drivers.empty:
    rd_left, rd_right = st.columns([2, 1])
    with rd_left:
        fig_rd = px.bar(
            readmit_drivers.head(15),
            x="RELATIVE_CONTRIBUTION", y="CONTRIBUTOR",
            orientation="h", color="GROWTH_RATE",
            color_continuous_scale="RdYlGn_r",
            text=readmit_drivers.head(15)["RELATIVE_CONTRIBUTION"].apply(lambda x: f"{x:.1%}"),
        )
        ct.apply_style(fig_rd, height=450)
        ct.style_bars_gradient(fig_rd)
        fig_rd.update_layout(
            xaxis_title="Relative Contribution", yaxis_title="",
            yaxis=dict(autorange="reversed"),
        )
        st.plotly_chart(fig_rd, use_container_width=True)
    with rd_right:
        st.dataframe(
            readmit_drivers.rename(columns={
                "CONTRIBUTOR": "Segment",
                "RELATIVE_CONTRIBUTION": "Contribution",
                "GROWTH_RATE": "Growth Rate",
                "METRIC_CONTROL": "Control",
                "METRIC_TEST": "Test",
            }),
            hide_index=True,
            use_container_width=True,
        )
else:
    st.info("No readmission driver data available.")

st.markdown("---")

# ===================================================================
# 4. LEAKAGE DRIVERS (Top Insights)
# ===================================================================
st.subheader("4. Leakage Rate Drivers")
st.caption("Cortex ML Top Insights: segments contributing to leakage rate changes")

leak_drivers = run_query("""
    SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE,
           METRIC_CONTROL, METRIC_TEST
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_LEAKAGE_DRIVERS
    ORDER BY ABS(RELATIVE_CONTRIBUTION) DESC
""")

if not leak_drivers.empty:
    ld_left, ld_right = st.columns([2, 1])
    with ld_left:
        fig_ld = px.bar(
            leak_drivers.head(15),
            x="RELATIVE_CONTRIBUTION", y="CONTRIBUTOR",
            orientation="h", color="GROWTH_RATE",
            color_continuous_scale="RdYlGn_r",
            text=leak_drivers.head(15)["RELATIVE_CONTRIBUTION"].apply(lambda x: f"{x:.1%}"),
        )
        ct.apply_style(fig_ld, height=450)
        ct.style_bars_gradient(fig_ld)
        fig_ld.update_layout(
            xaxis_title="Relative Contribution", yaxis_title="",
            yaxis=dict(autorange="reversed"),
        )
        st.plotly_chart(fig_ld, use_container_width=True)
    with ld_right:
        st.dataframe(
            leak_drivers.rename(columns={
                "CONTRIBUTOR": "Segment",
                "RELATIVE_CONTRIBUTION": "Contribution",
                "GROWTH_RATE": "Growth Rate",
                "METRIC_CONTROL": "Control",
                "METRIC_TEST": "Test",
            }),
            hide_index=True,
            use_container_width=True,
        )
else:
    st.info("No leakage driver data available.")
