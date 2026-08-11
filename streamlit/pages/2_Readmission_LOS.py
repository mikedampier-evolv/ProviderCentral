"""
Hospital 360 — Readmission & Length-of-Stay Dashboard (UC2)
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
st.title("Readmission & Length-of-Stay")

# Inherit global filters
start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

# Page-specific filters
col_f1, col_f2, col_f3 = st.columns(3)

enc_types = run_query(
    "SELECT DISTINCT ENCOUNTER_TYPE FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS ORDER BY 1"
)
with col_f1:
    sel_enc_type = st.multiselect(
        "Encounter Type", enc_types["ENCOUNTER_TYPE"].tolist(),
        default=enc_types["ENCOUNTER_TYPE"].tolist(),
    )

payers = run_query(
    "SELECT DISTINCT PAYER_TYPE FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS ORDER BY 1"
)
with col_f2:
    sel_payer = st.multiselect(
        "Payer Type", payers["PAYER_TYPE"].tolist(),
        default=payers["PAYER_TYPE"].tolist(),
    )

drgs = run_query("""
    SELECT DISTINCT DRG_DESCRIPTION
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE DRG_DESCRIPTION IS NOT NULL
    ORDER BY 1
""")
with col_f3:
    sel_drg = st.multiselect(
        "DRG (optional — leave empty for all)", drgs["DRG_DESCRIPTION"].tolist(),
        default=[],
    )

# Build WHERE
def build_where() -> str:
    clauses = [f"ADMIT_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if facility != "All Facilities":
        clauses.append(f"FACILITY_NAME = '{facility}'")
    if sel_enc_type:
        enc_list = ",".join(f"'{e}'" for e in sel_enc_type)
        clauses.append(f"ENCOUNTER_TYPE IN ({enc_list})")
    if sel_payer:
        pay_list = ",".join(f"'{p}'" for p in sel_payer)
        clauses.append(f"PAYER_TYPE IN ({pay_list})")
    if sel_drg:
        drg_list = ",".join(f"'{d.replace(chr(39), chr(39)+chr(39))}'" for d in sel_drg)
        clauses.append(f"DRG_DESCRIPTION IN ({drg_list})")
    return " AND ".join(clauses)

where = build_where()
st.caption(f"Filtered: {start_dt} to {end_dt} | {facility}")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS READMIT_RATE,
        ROUND(AVG(LOS_INDEX), 2)                                          AS AVG_LOS_INDEX,
        ROUND(AVG(CASE WHEN IS_LONG_STAY THEN 1 ELSE 0 END) * 100, 1)   AS LONG_STAY_PCT,
        ROUND(AVG(COST_PER_DAY), 0)                                       AS AVG_CPD,
        COUNT(*)                                                           AS TOTAL_ENC
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE {where}
""")

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("Readmission Rate", f"{kpis['READMIT_RATE'].iloc[0]}%")
k2.metric("Avg LOS Index", f"{kpis['AVG_LOS_INDEX'].iloc[0]}")
k3.metric("Long-Stay %", f"{kpis['LONG_STAY_PCT'].iloc[0]}%")
k4.metric("Avg Cost/Day", f"${int(kpis['AVG_CPD'].iloc[0]):,}")
k5.metric("Encounters", f"{int(kpis['TOTAL_ENC'].iloc[0]):,}")

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Readmission trend + LOS distribution
# ---------------------------------------------------------------------------
r1_left, r1_right = st.columns(2)

trend = run_query(f"""
    SELECT ADMIT_MONTH AS MONTH,
           ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS READMIT_RATE,
           COUNT(*) AS ENCOUNTERS
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE {where}
    GROUP BY 1 ORDER BY 1
""")
with r1_left:
    st.subheader("Monthly Readmission Rate")
    fig = px.line(trend, x="MONTH", y="READMIT_RATE",
                  color_discrete_sequence=[ct.COLORS["danger"]])
    ct.apply_style(fig, height=320)
    fig.update_layout(xaxis_title="", yaxis_title="Rate %")
    ct.glow_line(fig, 0, ct.COLORS["danger"])
    st.plotly_chart(fig, use_container_width=True)

los_dist = run_query(f"""
    SELECT LOS_DAYS
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE {where} AND LOS_DAYS <= 30
""")
with r1_right:
    st.subheader("LOS Distribution (capped at 30d)")
    fig2 = px.histogram(los_dist, x="LOS_DAYS", nbins=30,
                        color_discrete_sequence=[ct.COLORS["primary"]])
    ct.apply_style(fig2, height=320)
    fig2.update_layout(xaxis_title="Length of Stay (days)", yaxis_title="Count")
    ct.style_bars(fig2, ct.COLORS["primary"])
    st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Top DRGs by readmission + Readmission by payer
# ---------------------------------------------------------------------------
r2_left, r2_right = st.columns(2)

top_drg = run_query(f"""
    SELECT DRG_DESCRIPTION,
           COUNT(*) AS TOTAL,
           SUM(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) AS READMITS,
           ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE {where} AND DRG_DESCRIPTION IS NOT NULL
    GROUP BY 1
    HAVING COUNT(*) >= 50
    ORDER BY RATE DESC
    LIMIT 10
""")
with r2_left:
    st.subheader("Top 10 DRGs by Readmission Rate")
    fig3 = px.bar(top_drg, x="RATE", y="DRG_DESCRIPTION", orientation="h",
                  color="RATE", color_continuous_scale="Reds",
                  text="RATE")
    ct.apply_style(fig3, height=380)
    fig3.update_layout(xaxis_title="Readmission Rate %", yaxis_title="",
                       yaxis=dict(autorange="reversed"), coloraxis_showscale=False)
    ct.style_bars_gradient(fig3)
    fig3.update_traces(texttemplate="%{text}%", textposition="outside")
    st.plotly_chart(fig3, use_container_width=True)

payer_readmit = run_query(f"""
    SELECT PAYER_TYPE,
           COUNT(*) AS TOTAL,
           ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
    WHERE {where}
    GROUP BY 1 ORDER BY RATE DESC
""")
with r2_right:
    st.subheader("Readmission Rate by Payer")
    fig4 = px.bar(payer_readmit, x="PAYER_TYPE", y="RATE",
                  color="RATE", color_continuous_scale="Reds",
                  text="RATE")
    ct.apply_style(fig4, height=380)
    fig4.update_layout(xaxis_title="", yaxis_title="Rate %",
                       coloraxis_showscale=False)
    ct.style_bars_gradient(fig4)
    fig4.update_traces(texttemplate="%{text}%", textposition="outside")
    st.plotly_chart(fig4, use_container_width=True)

# ---------------------------------------------------------------------------
# ML Section — Readmission Drivers
# ---------------------------------------------------------------------------
st.markdown("---")
st.subheader("ML Insights — Readmission Drivers")
st.caption("Cortex ML Top Insights: segments driving readmission rate changes")

drivers = run_query("""
    SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE,
           METRIC_CONTROL, METRIC_TEST
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_READMISSION_DRIVERS
    ORDER BY ABS(RELATIVE_CONTRIBUTION) DESC
    LIMIT 15
""")

if not drivers.empty:
    drv_left, drv_right = st.columns([2, 1])
    with drv_left:
        fig_drv = px.bar(
            drivers.head(10), x="RELATIVE_CONTRIBUTION", y="CONTRIBUTOR",
            orientation="h", color="GROWTH_RATE",
            color_continuous_scale="RdYlGn_r",
            text=drivers.head(10)["RELATIVE_CONTRIBUTION"].apply(lambda x: f"{x:.1%}"),
        )
        ct.apply_style(fig_drv, height=380)
        fig_drv.update_layout(
            xaxis_title="Relative Contribution", yaxis_title="",
            yaxis=dict(autorange="reversed"),
        )
        ct.style_bars_gradient(fig_drv)
        st.plotly_chart(fig_drv, use_container_width=True)
    with drv_right:
        st.dataframe(
            drivers[["CONTRIBUTOR", "RELATIVE_CONTRIBUTION", "GROWTH_RATE"]].rename(
                columns={
                    "CONTRIBUTOR": "Segment",
                    "RELATIVE_CONTRIBUTION": "Rel. Contribution",
                    "GROWTH_RATE": "Growth Rate",
                }
            ),
            hide_index=True,
            use_container_width=True,
        )
else:
    st.info("No readmission driver data available.")

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("Encounter Detail Table"):
    detail = run_query(f"""
        SELECT ENCOUNTER_ID, MRN, PATIENT_NAME, PATIENT_AGE, PATIENT_GENDER,
               ENCOUNTER_TYPE, ADMIT_DATE, DISCHARGE_DATE, LOS_DAYS, LOS_INDEX,
               IS_LONG_STAY, READMIT_30_FLAG, DRG_DESCRIPTION, PAYER_TYPE,
               FACILITY_NAME, TOTAL_CHARGES, NET_REVENUE
        FROM HOSPITAL360_CUR.CLINICAL.MART_READMISSION_LOS
        WHERE {where}
        ORDER BY ADMIT_DATE DESC
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
