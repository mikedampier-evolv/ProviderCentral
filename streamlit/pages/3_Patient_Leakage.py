"""
Hospital 360 — Patient Leakage Dashboard (UC1)
"""

import streamlit as st
import plotly.express as px
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
st.title("Patient Leakage")

start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

col_f1, col_f2, col_f3 = st.columns(3)

ref_specs = run_query(
    "SELECT DISTINCT REFERRING_SPECIALTY FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE WHERE REFERRING_SPECIALTY IS NOT NULL ORDER BY 1"
)
with col_f1:
    sel_ref_spec = st.multiselect(
        "Referring Specialty", ref_specs["REFERRING_SPECIALTY"].tolist(),
        default=[],
        help="Leave empty to include all",
    )

to_specs = run_query(
    "SELECT DISTINCT REFERRED_TO_SPECIALTY FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE WHERE REFERRED_TO_SPECIALTY IS NOT NULL ORDER BY 1"
)
with col_f2:
    sel_to_spec = st.multiselect(
        "Referred-To Specialty", to_specs["REFERRED_TO_SPECIALTY"].tolist(),
        default=[],
        help="Leave empty to include all",
    )

pay_types = run_query(
    "SELECT DISTINCT PATIENT_PAYER_TYPE FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE WHERE PATIENT_PAYER_TYPE IS NOT NULL ORDER BY 1"
)
with col_f3:
    sel_payer = st.multiselect(
        "Payer Type", pay_types["PATIENT_PAYER_TYPE"].tolist(),
        default=[],
        help="Leave empty to include all",
    )

def build_where() -> str:
    clauses = [f"REFERRAL_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if facility != "All Facilities":
        clauses.append(f"FACILITY_NAME = '{facility}'")
    if sel_ref_spec:
        vals = ",".join(f"'{v}'" for v in sel_ref_spec)
        clauses.append(f"REFERRING_SPECIALTY IN ({vals})")
    if sel_to_spec:
        vals = ",".join(f"'{v}'" for v in sel_to_spec)
        clauses.append(f"REFERRED_TO_SPECIALTY IN ({vals})")
    if sel_payer:
        vals = ",".join(f"'{v}'" for v in sel_payer)
        clauses.append(f"PATIENT_PAYER_TYPE IN ({vals})")
    return " AND ".join(clauses)

where = build_where()
st.caption(f"Filtered: {start_dt} to {end_dt} | {facility}")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS LEAK_RATE,
        ROUND(SUM(LOST_REVENUE), 0)                                     AS LOST_REV,
        SUM(CASE WHEN LEAKAGE_FLAG AND IS_HIGH_VALUE THEN 1 ELSE 0 END) AS HV_LEAKED,
        COUNT(*)                                                         AS TOTAL_REF
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where}
""")

top_leaked = run_query(f"""
    SELECT REFERRED_TO_SPECIALTY, COUNT(*) AS N
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where} AND LEAKAGE_FLAG = TRUE
    GROUP BY 1 ORDER BY 2 DESC LIMIT 1
""")

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("Leakage Rate", f"{kpis['LEAK_RATE'].iloc[0]}%")
k2.metric("Lost Revenue", f"${int(kpis['LOST_REV'].iloc[0]):,}")
k3.metric("High-Value Leaked", f"{int(kpis['HV_LEAKED'].iloc[0]):,}")
k4.metric("Total Referrals", f"{int(kpis['TOTAL_REF'].iloc[0]):,}")
if not top_leaked.empty:
    k5.metric("Top Leaked Specialty", top_leaked["REFERRED_TO_SPECIALTY"].iloc[0])

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Trend + by specialty
# ---------------------------------------------------------------------------
r1_left, r1_right = st.columns(2)

trend = run_query(f"""
    SELECT REFERRAL_MONTH AS MONTH,
           ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS LEAK_RATE,
           COUNT(*) AS REFERRALS
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where}
    GROUP BY 1 ORDER BY 1
""")
with r1_left:
    st.subheader("Monthly Leakage Rate")
    fig = px.line(trend, x="MONTH", y="LEAK_RATE",
                  color_discrete_sequence=[ct.COLORS["warning"]])
    ct.apply_style(fig, height=320)
    fig.update_layout(xaxis_title="", yaxis_title="Rate %")
    ct.glow_line(fig, 0, ct.COLORS["warning"])
    st.plotly_chart(fig, use_container_width=True)

by_spec = run_query(f"""
    SELECT REFERRED_TO_SPECIALTY AS SPECIALTY,
           COUNT(*) AS TOTAL,
           SUM(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) AS LEAKED,
           ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE,
           ROUND(SUM(LOST_REVENUE), 0) AS LOST_REV
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where}
    GROUP BY 1 ORDER BY LOST_REV DESC
    LIMIT 10
""")
with r1_right:
    st.subheader("Leakage by Referred-To Specialty")
    fig2 = px.bar(by_spec, x="LOST_REV", y="SPECIALTY", orientation="h",
                  color="RATE", color_continuous_scale="OrRd",
                  text=by_spec["LOST_REV"].apply(lambda x: f"${x:,.0f}"))
    ct.apply_style(fig2, height=320)
    fig2.update_layout(xaxis_title="Lost Revenue ($)", yaxis_title="",
                       yaxis=dict(autorange="reversed"),
                       coloraxis_colorbar_title="Leak %")
    ct.style_bars_gradient(fig2)
    fig2.update_traces(textposition="outside")
    st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Lost revenue by referring specialty + Payer breakdown
# ---------------------------------------------------------------------------
r2_left, r2_right = st.columns(2)

by_ref = run_query(f"""
    SELECT REFERRING_SPECIALTY AS SPECIALTY,
           ROUND(SUM(LOST_REVENUE), 0) AS LOST_REV,
           COUNT(*) AS REFERRALS
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where} AND LEAKAGE_FLAG = TRUE
    GROUP BY 1 ORDER BY LOST_REV DESC
""")
with r2_left:
    st.subheader("Lost Revenue by Referring Specialty")
    fig3 = px.treemap(by_ref, path=["SPECIALTY"], values="LOST_REV",
                      color="LOST_REV", color_continuous_scale="Reds")
    ct.apply_style(fig3, height=350)
    st.plotly_chart(fig3, use_container_width=True)

by_payer = run_query(f"""
    SELECT PATIENT_PAYER_TYPE AS PAYER,
           COUNT(*) AS TOTAL,
           SUM(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) AS LEAKED,
           ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END) * 100, 1) AS RATE
    FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE {where}
    GROUP BY 1 ORDER BY RATE DESC
""")
with r2_right:
    st.subheader("Leakage Rate by Payer Type")
    fig4 = px.pie(by_payer, names="PAYER", values="LEAKED",
                  color_discrete_sequence=ct.COLOR_SEQ,
                  hole=0.4)
    ct.apply_style(fig4, height=350)
    ct.style_pie(fig4)
    st.plotly_chart(fig4, use_container_width=True)

# ---------------------------------------------------------------------------
# ML Section — Leakage Drivers
# ---------------------------------------------------------------------------
st.markdown("---")
st.subheader("ML Insights — Leakage Drivers")
st.caption("Cortex ML Top Insights: segments driving leakage rate changes")

drivers = run_query("""
    SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE,
           METRIC_CONTROL, METRIC_TEST
    FROM HOSPITAL360_ML.PREDICTIONS.PRED_LEAKAGE_DRIVERS
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
    st.info("No leakage driver data available.")

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("Referral Detail Table"):
    detail = run_query(f"""
        SELECT REFERRAL_ID, MRN, PATIENT_NAME, REFERRING_PROVIDER,
               REFERRING_SPECIALTY, REFERRED_TO_SPECIALTY,
               REFERRAL_DATE, STATUS, LEAKAGE_FLAG, IS_HIGH_VALUE,
               EXPECTED_REVENUE, LOST_REVENUE, FACILITY_NAME
        FROM HOSPITAL360_CUR.CLINICAL.MART_PATIENT_LEAKAGE
        WHERE {where}
        ORDER BY REFERRAL_DATE DESC
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
