"""
Hospital 360 — Staffing & Quality Dashboard (UC5)
Correlates labor staffing levels with clinical outcomes (readmissions, LOS).
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
st.title("Staffing & Quality")
st.caption("Correlating labor staffing levels with clinical outcomes")

start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

col_f1, col_f2 = st.columns(2)

dept_types = run_query(
    "SELECT DISTINCT DEPT_TYPE FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY ORDER BY 1"
)
with col_f1:
    sel_dept_type = st.multiselect(
        "Department Type", dept_types["DEPT_TYPE"].tolist(),
        default=dept_types["DEPT_TYPE"].tolist(),
    )

depts = run_query(
    "SELECT DISTINCT DEPT_NAME FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY ORDER BY 1"
)
with col_f2:
    sel_dept = st.multiselect(
        "Department (optional)", depts["DEPT_NAME"].tolist(),
        default=[],
        help="Leave empty to include all",
    )

# Build WHERE
def build_where() -> str:
    clauses = [f"SHIFT_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if facility != "All Facilities":
        clauses.append(f"FACILITY_NAME = '{facility}'")
    if sel_dept_type:
        dt_list = ",".join(f"'{d}'" for d in sel_dept_type)
        clauses.append(f"DEPT_TYPE IN ({dt_list})")
    if sel_dept:
        d_list = ",".join(f"'{d}'" for d in sel_dept)
        clauses.append(f"DEPT_NAME IN ({d_list})")
    return " AND ".join(clauses)

where = build_where()
st.caption(f"Filtered: {start_dt} to {end_dt} | {facility}")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(AVG(HRS_PER_PATIENT), 1)                          AS AVG_HRS_PER_PATIENT,
        ROUND(AVG(OT_PCT) * 100, 1)                             AS AVG_OT_PCT,
        ROUND(SUM(CASE WHEN IS_UNDERSTAFFED THEN 1 ELSE 0 END)::FLOAT
              / NULLIF(COUNT(*), 0) * 100, 1)                   AS UNDERSTAFFED_DAY_PCT,
        ROUND(AVG(CASE WHEN IS_UNDERSTAFFED AND READMIT_RATE IS NOT NULL
              THEN READMIT_RATE END) * 100, 1)                  AS READMIT_UNDERSTAFFED,
        ROUND(AVG(CASE WHEN NOT IS_UNDERSTAFFED AND READMIT_RATE IS NOT NULL
              THEN READMIT_RATE END) * 100, 1)                  AS READMIT_ADEQUATE
    FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
    WHERE {where} AND PATIENT_CENSUS > 0
""")

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("Avg Hrs/Patient", f"{kpis['AVG_HRS_PER_PATIENT'].iloc[0]}")
k2.metric("Avg Overtime %", f"{kpis['AVG_OT_PCT'].iloc[0]}%")
k3.metric("Understaffed Days", f"{kpis['UNDERSTAFFED_DAY_PCT'].iloc[0]}%")
k4.metric("Readmit (Understaffed)", f"{kpis['READMIT_UNDERSTAFFED'].iloc[0]}%")
k5.metric("Readmit (Adequate)", f"{kpis['READMIT_ADEQUATE'].iloc[0]}%")

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Staffing vs Readmission trend (dual-axis) + Scatter
# ---------------------------------------------------------------------------
r1_left, r1_right = st.columns(2)

trend = run_query(f"""
    SELECT SHIFT_MONTH AS MONTH,
           ROUND(AVG(HRS_PER_PATIENT), 1) AS HRS_PER_PATIENT,
           ROUND(AVG(CASE WHEN READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT_RATE
    FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
    WHERE {where} AND PATIENT_CENSUS > 0
    GROUP BY 1 ORDER BY 1
""")
with r1_left:
    st.subheader("Staffing vs. Readmission Rate (Monthly)")
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=trend["MONTH"], y=trend["HRS_PER_PATIENT"],
        name="Hrs/Patient", yaxis="y",
        line=dict(color=ct.COLORS["primary"], width=2)
    ))
    fig.add_trace(go.Scatter(
        x=trend["MONTH"], y=trend["READMIT_RATE"],
        name="Readmit Rate %", yaxis="y2",
        line=dict(color=ct.COLORS["danger"], width=2, dash="dot")
    ))
    ct.apply_style(fig, height=340)
    fig.update_layout(
        yaxis=dict(title="Hrs / Patient", side="left"),
        yaxis2=dict(title="Readmit Rate %", side="right", overlaying="y"),
        legend=dict(orientation="h", y=-0.2),
    )
    st.plotly_chart(fig, use_container_width=True)

scatter = run_query(f"""
    SELECT DEPT_NAME, DEPT_TYPE,
           ROUND(AVG(HRS_PER_PATIENT), 1) AS HRS_PER_PATIENT,
           ROUND(AVG(CASE WHEN READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT_RATE,
           SUM(PATIENT_CENSUS) AS TOTAL_PATIENTS
    FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
    WHERE {where} AND PATIENT_CENSUS > 0 AND READMIT_RATE IS NOT NULL
    GROUP BY 1, 2
    HAVING COUNT(*) >= 30
""")
with r1_right:
    st.subheader("Staffing Level vs. Readmissions by Dept")
    fig2 = px.scatter(
        scatter, x="HRS_PER_PATIENT", y="READMIT_RATE",
        size="TOTAL_PATIENTS", color="DEPT_TYPE",
        hover_name="DEPT_NAME",
        color_discrete_sequence=ct.COLOR_SEQ,
    )
    ct.apply_style(fig2, height=340)
    fig2.update_layout(
        xaxis_title="Avg Hrs / Patient",
        yaxis_title="Readmission Rate %",
    )
    st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Overtime by department + Day-of-week heatmap
# ---------------------------------------------------------------------------
st.markdown("---")
r2_left, r2_right = st.columns(2)

ot_by_dept = run_query(f"""
    SELECT DEPT_NAME,
           ROUND(AVG(OT_PCT) * 100, 1) AS OT_PCT,
           ROUND(AVG(CASE WHEN READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT_RATE
    FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
    WHERE {where} AND PATIENT_CENSUS > 0
    GROUP BY 1
    HAVING COUNT(*) >= 30
    ORDER BY OT_PCT DESC
    LIMIT 12
""")
with r2_left:
    st.subheader("Overtime % by Department")
    fig3 = px.bar(
        ot_by_dept, x="OT_PCT", y="DEPT_NAME", orientation="h",
        color="READMIT_RATE", color_continuous_scale="RdYlGn_r",
        text="OT_PCT",
    )
    ct.apply_style(fig3, height=380)
    fig3.update_layout(
        xaxis_title="Overtime %", yaxis_title="",
        yaxis=dict(autorange="reversed"),
        coloraxis_colorbar_title="Readmit %",
    )
    ct.style_bars_gradient(fig3)
    fig3.update_traces(texttemplate="%{text}%", textposition="outside")
    st.plotly_chart(fig3, use_container_width=True)

dow_heatmap = run_query(f"""
    SELECT DAY_OF_WEEK,
           DEPT_NAME,
           ROUND(AVG(HRS_PER_PATIENT), 1) AS HRS_PER_PATIENT
    FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
    WHERE {where} AND PATIENT_CENSUS > 0
    GROUP BY 1, 2
    HAVING COUNT(*) >= 5
""")
with r2_right:
    st.subheader("Staffing by Day of Week")
    if not dow_heatmap.empty:
        dow_order = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        pivot = dow_heatmap.pivot_table(
            index="DEPT_NAME", columns="DAY_OF_WEEK",
            values="HRS_PER_PATIENT", aggfunc="mean"
        )
        # Reorder columns to match day order where possible
        ordered_cols = [d for d in dow_order if d in pivot.columns]
        pivot = pivot[ordered_cols] if ordered_cols else pivot
        fig4 = px.imshow(
            pivot, color_continuous_scale="RdYlGn",
            aspect="auto",
        )
        ct.apply_style(fig4, height=380)
        fig4.update_layout(
            xaxis_title="", yaxis_title="",
            coloraxis_colorbar_title="Hrs/Pt",
        )
        st.plotly_chart(fig4, use_container_width=True)
    else:
        st.info("Not enough data for heatmap.")

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("Department-Day Detail Table"):
    detail = run_query(f"""
        SELECT DEPT_NAME, FACILITY_NAME, SHIFT_DATE, DAY_OF_WEEK,
               STAFF_COUNT, TOTAL_WORKED_HRS, TOTAL_OT_HRS,
               ROUND(OT_PCT * 100, 1) AS OT_PCT,
               PATIENT_CENSUS, HRS_PER_PATIENT,
               ADMITS, DISCHARGES, READMIT_COUNT,
               ROUND(READMIT_RATE * 100, 1) AS READMIT_RATE_PCT,
               ROUND(AVG_LOS_DAYS, 1) AS AVG_LOS,
               IS_UNDERSTAFFED, HIGH_OT_FLAG
        FROM HOSPITAL360_CUR.WORKFORCE.MART_STAFFING_QUALITY
        WHERE {where} AND PATIENT_CENSUS > 0
        ORDER BY SHIFT_DATE DESC
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
