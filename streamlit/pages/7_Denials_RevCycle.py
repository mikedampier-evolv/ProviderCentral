"""
Hospital 360 — Denials & Revenue Cycle Dashboard (UC4)
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import chart_theme as ct

st.set_page_config(layout="wide")

session = st.connection("snowflake").session()

@st.cache_data(ttl=600)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------
st.title("Denials & Revenue Cycle")

start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

col_f1, col_f2, col_f3 = st.columns(3)

payers = run_query(
    "SELECT DISTINCT PAYER_TYPE FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE WHERE PAYER_TYPE IS NOT NULL ORDER BY 1"
)
with col_f1:
    sel_payer = st.multiselect(
        "Payer Type", payers["PAYER_TYPE"].tolist(), default=[],
    )

categories = run_query(
    "SELECT DISTINCT DENIAL_CATEGORY FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE ORDER BY 1"
)
with col_f2:
    sel_cat = st.multiselect(
        "Denial Category", categories["DENIAL_CATEGORY"].tolist(), default=[],
    )

cpt_cats = run_query(
    "SELECT DISTINCT CPT_CATEGORY FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE WHERE CPT_CATEGORY IS NOT NULL ORDER BY 1"
)
with col_f3:
    sel_cpt_cat = st.multiselect(
        "CPT Category", cpt_cats["CPT_CATEGORY"].tolist(), default=[],
    )

def build_where() -> str:
    clauses = [f"SERVICE_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if sel_payer:
        vals = ",".join(f"'{v}'" for v in sel_payer)
        clauses.append(f"PAYER_TYPE IN ({vals})")
    if sel_cat:
        vals = ",".join(f"'{v}'" for v in sel_cat)
        clauses.append(f"DENIAL_CATEGORY IN ({vals})")
    if sel_cpt_cat:
        vals = ",".join(f"'{v}'" for v in sel_cpt_cat)
        clauses.append(f"CPT_CATEGORY IN ({vals})")
    return " AND ".join(clauses)

where = build_where()
st.caption(f"Filtered: {start_dt} to {end_dt}")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(SUM(CHARGE_AMT), 0)                                         AS TOTAL_DENIED,
        ROUND(AVG(CASE WHEN IS_APPEALED THEN 1 ELSE 0 END) * 100, 1)    AS APPEAL_RATE,
        ROUND(SUM(ESTIMATED_RECOVERY), 0)                                 AS EST_RECOVERY,
        ROUND(AVG(DAYS_TO_FILE), 1)                                       AS AVG_DTF,
        ROUND(AVG(CASE WHEN IS_TIMELY_FILED THEN 1 ELSE 0 END)*100, 1)  AS TIMELY_PCT,
        COUNT(*)                                                           AS TOTAL_CLAIMS
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where}
""")

k1, k2, k3, k4, k5, k6 = st.columns(6)
k1.metric("Denied Charges", f"${int(kpis['TOTAL_DENIED'].iloc[0]):,}")
k2.metric("Appeal Rate", f"{kpis['APPEAL_RATE'].iloc[0]}%")
k3.metric("Est. Recovery", f"${int(kpis['EST_RECOVERY'].iloc[0]):,}")
k4.metric("Avg Days to File", f"{kpis['AVG_DTF'].iloc[0]}")
k5.metric("Timely Filed", f"{kpis['TIMELY_PCT'].iloc[0]}%")
k6.metric("Denied Claims", f"{int(kpis['TOTAL_CLAIMS'].iloc[0]):,}")

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Monthly trend by category + Category donut
# ---------------------------------------------------------------------------
r1_left, r1_right = st.columns([2, 1])

trend = run_query(f"""
    SELECT SERVICE_MONTH AS MONTH, DENIAL_CATEGORY,
           COUNT(*) AS CLAIMS,
           ROUND(SUM(CHARGE_AMT), 0) AS CHARGES
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where}
    GROUP BY 1, 2 ORDER BY 1
""")
with r1_left:
    st.subheader("Monthly Denial Trend by Category")
    fig = px.area(trend, x="MONTH", y="CLAIMS", color="DENIAL_CATEGORY",
                  color_discrete_sequence=ct.COLOR_SEQ)
    ct.apply_style(fig, height=340, legend_below=True)
    ct.style_area(fig)
    fig.update_layout(xaxis_title="", yaxis_title="Denied Claims")
    st.plotly_chart(fig, use_container_width=True)

cat_summary = run_query(f"""
    SELECT DENIAL_CATEGORY, COUNT(*) AS CLAIMS, ROUND(SUM(CHARGE_AMT), 0) AS CHARGES
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where}
    GROUP BY 1 ORDER BY CLAIMS DESC
""")
with r1_right:
    st.subheader("Category Breakdown")
    fig2 = px.pie(cat_summary, names="DENIAL_CATEGORY", values="CHARGES",
                  hole=0.45,
                  color_discrete_sequence=ct.COLOR_SEQ)
    ct.apply_style(fig2, height=340)
    ct.style_pie(fig2)
    st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Top CPT codes + Timely filing by payer
# ---------------------------------------------------------------------------
r2_left, r2_right = st.columns(2)

top_cpt = run_query(f"""
    SELECT CPT_CODE || ' - ' || CPT_DESCRIPTION AS CPT_LABEL,
           COUNT(*) AS CLAIMS,
           ROUND(SUM(CHARGE_AMT), 0) AS CHARGES
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where}
    GROUP BY 1 ORDER BY CHARGES DESC
    LIMIT 10
""")
with r2_left:
    st.subheader("Top 10 CPT Codes by Denied Charges")
    fig3 = px.bar(top_cpt, x="CHARGES", y="CPT_LABEL", orientation="h",
                  color="CHARGES", color_continuous_scale="Reds",
                  text=top_cpt["CHARGES"].apply(lambda x: f"${x:,.0f}"))
    ct.apply_style(fig3, height=380)
    fig3.update_layout(
        xaxis_title="Denied Charges ($)", yaxis_title="",
        yaxis=dict(autorange="reversed"),
        coloraxis_showscale=False,
    )
    fig3.update_traces(textposition="outside")
    st.plotly_chart(fig3, use_container_width=True)

timely_payer = run_query(f"""
    SELECT PAYER_TYPE,
           COUNT(*) AS TOTAL,
           ROUND(AVG(CASE WHEN IS_TIMELY_FILED THEN 1 ELSE 0 END) * 100, 1) AS TIMELY_PCT,
           ROUND(AVG(DAYS_TO_FILE), 1) AS AVG_DTF
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where}
    GROUP BY 1 ORDER BY TIMELY_PCT
""")
with r2_right:
    st.subheader("Timely Filing Compliance by Payer")
    fig4 = px.bar(timely_payer, x="PAYER_TYPE", y="TIMELY_PCT",
                  color="TIMELY_PCT", color_continuous_scale="RdYlGn",
                  text="TIMELY_PCT")
    ct.apply_style(fig4, height=380)
    fig4.update_layout(
        xaxis_title="", yaxis_title="Timely Filed %",
        coloraxis_showscale=False,
    )
    fig4.update_traces(texttemplate="%{text}%", textposition="outside")
    st.plotly_chart(fig4, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 3: Appeal outcomes
# ---------------------------------------------------------------------------
st.subheader("Appeal Outcomes")

appeals = run_query(f"""
    SELECT DENIAL_CATEGORY, APPEAL_OUTCOME,
           COUNT(*) AS CLAIMS,
           ROUND(SUM(CHARGE_AMT), 0) AS CHARGES
    FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
    WHERE {where} AND IS_APPEALED = TRUE
    GROUP BY 1, 2 ORDER BY 1, 2
""")

if not appeals.empty:
    fig5 = px.bar(appeals, x="DENIAL_CATEGORY", y="CLAIMS", color="APPEAL_OUTCOME",
                  barmode="group",
                  color_discrete_sequence=ct.COLOR_SEQ)
    ct.apply_style(fig5, height=320, legend_below=True)
    fig5.update_layout(xaxis_title="", yaxis_title="Appealed Claims")
    st.plotly_chart(fig5, use_container_width=True)

# ---------------------------------------------------------------------------
# ML Section — Denial Anomaly Detection
# ---------------------------------------------------------------------------
st.markdown("---")
st.subheader("ML Insights — Denial Anomaly Detection")
st.caption("Cortex ML anomaly detection: actual vs expected denial volume with confidence bands")

anom = run_query("""
    SELECT DENIAL_CATEGORY, TS, ACTUAL_COUNT, EXPECTED_COUNT,
           LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, ACTUAL_CHARGES
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_DENIAL_ANOMALIES
    ORDER BY DENIAL_CATEGORY, TS
""")

if not anom.empty:
    sel_anom_cat = st.selectbox(
        "Select Category",
        anom["DENIAL_CATEGORY"].unique().tolist(),
    )
    cat_data = anom[anom["DENIAL_CATEGORY"] == sel_anom_cat].copy()

    fig_anom = go.Figure()
    # Confidence band
    fig_anom.add_trace(go.Scatter(
        x=pd.concat([cat_data["TS"], cat_data["TS"][::-1]]),
        y=pd.concat([cat_data["UPPER_BOUND"], cat_data["LOWER_BOUND"][::-1]]),
        fill="toself", fillcolor="rgba(41,181,232,0.15)",
        line=dict(color="rgba(41,181,232,0)"),
        name="Expected Range",
    ))
    # Expected line
    fig_anom.add_trace(go.Scatter(
        x=cat_data["TS"], y=cat_data["EXPECTED_COUNT"],
        mode="lines", line=dict(color="#29B5E8", dash="dash"),
        name="Expected",
    ))
    # Actual line
    fig_anom.add_trace(go.Scatter(
        x=cat_data["TS"], y=cat_data["ACTUAL_COUNT"],
        mode="lines+markers", line=dict(color="#333"),
        name="Actual",
    ))
    # Anomaly points
    anomalies = cat_data[cat_data["IS_ANOMALY"] == True]
    if not anomalies.empty:
        fig_anom.add_trace(go.Scatter(
            x=anomalies["TS"], y=anomalies["ACTUAL_COUNT"],
            mode="markers", marker=dict(color="red", size=10, symbol="x"),
            name="Anomaly",
        ))

    ct.apply_style(fig_anom, height=380, legend_below=True)
    fig_anom.update_layout(xaxis_title="", yaxis_title="Denial Count")
    st.plotly_chart(fig_anom, use_container_width=True)

    anom_count = anomalies.shape[0]
    st.info(f"{anom_count} anomalous period(s) detected for **{sel_anom_cat}**")
else:
    st.info("No anomaly detection data available.")

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("Claim Detail Table"):
    detail = run_query(f"""
        SELECT CLAIM_ID, LINE_NUMBER, MRN, PATIENT_NAME, PAYER_NAME, PAYER_TYPE,
               SERVICE_DATE, DENIAL_CATEGORY, DENIAL_REASON, CHARGE_AMT, ALLOWED_AMT,
               IS_APPEALED, APPEAL_OUTCOME, CPT_CODE, CPT_DESCRIPTION,
               DAYS_TO_FILE, IS_TIMELY_FILED, ESTIMATED_RECOVERY
        FROM HOSPITAL360_CUR.FINANCIAL.MART_DENIALS_REVCYCLE
        WHERE {where}
        ORDER BY SERVICE_DATE DESC
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
