"""
Hospital 360 — OR Capacity Dashboard (UC3)
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
st.title("OR Capacity & Utilization")

start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

col_f1, col_f2, col_f3 = st.columns(3)

blocks = run_query(
    "SELECT DISTINCT BLOCK_NAME FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY ORDER BY 1"
)
with col_f1:
    sel_block = st.multiselect(
        "Block", blocks["BLOCK_NAME"].tolist(),
        default=[],
        help="Leave empty to include all",
    )

specs = run_query(
    "SELECT DISTINCT SPECIALTY FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY WHERE SPECIALTY IS NOT NULL ORDER BY 1"
)
with col_f2:
    sel_spec = st.multiselect(
        "Specialty", specs["SPECIALTY"].tolist(),
        default=[],
    )

days_of_week = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
with col_f3:
    sel_dow = st.multiselect(
        "Day of Week", days_of_week,
        default=[],
    )

def build_where() -> str:
    clauses = [f"CASE_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if facility != "All Facilities":
        clauses.append(f"FACILITY_NAME = '{facility}'")
    if sel_block:
        vals = ",".join(f"'{v}'" for v in sel_block)
        clauses.append(f"BLOCK_NAME IN ({vals})")
    if sel_spec:
        vals = ",".join(f"'{v}'" for v in sel_spec)
        clauses.append(f"SPECIALTY IN ({vals})")
    if sel_dow:
        vals = ",".join(f"'{v}'" for v in sel_dow)
        clauses.append(f"CASE_DAY_OF_WEEK IN ({vals})")
    return " AND ".join(clauses)

where = build_where()
st.caption(f"Filtered: {start_dt} to {end_dt} | {facility}")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(AVG(UTILIZATION_PCT) * 100, 1)                              AS AVG_UTIL,
        ROUND(AVG(CASE WHEN FIRST_CASE_ON_TIME THEN 1 ELSE 0 END)*100,1) AS FCOT_PCT,
        ROUND(AVG(DELAY_MINUTES), 1)                                      AS AVG_DELAY,
        COUNT(*)                                                           AS TOTAL_CASES,
        ROUND(AVG(CASE_MINUTES), 0)                                       AS AVG_CASE_MIN
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where}
""")

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("Avg Utilization", f"{kpis['AVG_UTIL'].iloc[0]}%")
k2.metric("First-Case On-Time", f"{kpis['FCOT_PCT'].iloc[0]}%")
k3.metric("Avg Delay (min)", f"{kpis['AVG_DELAY'].iloc[0]}")
k4.metric("Total Cases", f"{int(kpis['TOTAL_CASES'].iloc[0]):,}")
k5.metric("Avg Case Duration", f"{int(kpis['AVG_CASE_MIN'].iloc[0])} min")

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Utilization heatmap (block × day of week)
# ---------------------------------------------------------------------------
st.subheader("Block Utilization Heatmap")

heatmap_data = run_query(f"""
    SELECT BLOCK_NAME, CASE_DAY_OF_WEEK AS DAY_OF_WEEK,
           ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS UTIL
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where}
    GROUP BY 1, 2
""")

if not heatmap_data.empty:
    dow_order = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    pivot = heatmap_data.pivot_table(
        index="BLOCK_NAME", columns="DAY_OF_WEEK", values="UTIL", aggfunc="mean"
    )
    # Reorder columns by day of week
    ordered_cols = [d for d in dow_order if d in pivot.columns]
    pivot = pivot[ordered_cols]

    fig_hm = px.imshow(
        pivot, text_auto=".1f",
        color_continuous_scale="RdYlGn",
        aspect="auto",
        labels=dict(color="Util %"),
    )
    ct.apply_style(fig_hm, height=320)
    ct.style_heatmap(fig_hm)
    fig_hm.update_layout(xaxis_title="", yaxis_title="")
    st.plotly_chart(fig_hm, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Monthly trend + Delay distribution
# ---------------------------------------------------------------------------
r2_left, r2_right = st.columns(2)

trend = run_query(f"""
    SELECT CASE_MONTH AS MONTH, BLOCK_NAME,
           ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS UTIL
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where}
    GROUP BY 1, 2 ORDER BY 1
""")
with r2_left:
    st.subheader("Monthly Utilization by Block")
    fig_trend = px.line(trend, x="MONTH", y="UTIL", color="BLOCK_NAME",
                        color_discrete_sequence=ct.COLOR_SEQ)
    ct.apply_style(fig_trend, height=320, legend_below=True)
    fig_trend.update_layout(xaxis_title="", yaxis_title="Utilization %")
    st.plotly_chart(fig_trend, use_container_width=True)

delays = run_query(f"""
    SELECT DELAY_MINUTES
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where} AND DELAY_MINUTES > 0 AND DELAY_MINUTES <= 120
""")
with r2_right:
    st.subheader("Delay Distribution (1-120 min)")
    fig_delay = px.histogram(delays, x="DELAY_MINUTES", nbins=30,
                             color_discrete_sequence=[ct.COLORS["danger"]])
    ct.apply_style(fig_delay, height=320)
    ct.style_bars(fig_delay, ct.COLORS["danger"])
    fig_delay.update_layout(xaxis_title="Delay (minutes)", yaxis_title="Count")
    st.plotly_chart(fig_delay, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 3: Top surgeons + Under/Over utilization
# ---------------------------------------------------------------------------
r3_left, r3_right = st.columns(2)

surgeons = run_query(f"""
    SELECT SURGEON_NAME, SPECIALTY,
           COUNT(*) AS CASES,
           ROUND(AVG(UTILIZATION_PCT) * 100, 1) AS AVG_UTIL,
           ROUND(AVG(CASE_MINUTES), 0) AS AVG_CASE_MIN
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where}
    GROUP BY 1, 2
    ORDER BY CASES DESC
    LIMIT 10
""")
with r3_left:
    st.subheader("Top 10 Surgeons by Case Volume")
    fig_surg = px.bar(surgeons, x="CASES", y="SURGEON_NAME", orientation="h",
                      color="AVG_UTIL", color_continuous_scale="RdYlGn",
                      text="CASES")
    ct.apply_style(fig_surg, height=380)
    fig_surg.update_layout(
        xaxis_title="Cases", yaxis_title="",
        yaxis=dict(autorange="reversed"),
        coloraxis_colorbar_title="Util %",
    )
    fig_surg.update_traces(textposition="outside")
    st.plotly_chart(fig_surg, use_container_width=True)

under_over = run_query(f"""
    SELECT BLOCK_NAME,
           SUM(CASE WHEN IS_UNDERUTILIZED THEN 1 ELSE 0 END) AS UNDER,
           SUM(CASE WHEN IS_OVERTIME THEN 1 ELSE 0 END) AS OVER,
           COUNT(*) - SUM(CASE WHEN IS_UNDERUTILIZED THEN 1 ELSE 0 END)
                     - SUM(CASE WHEN IS_OVERTIME THEN 1 ELSE 0 END) AS NORMAL
    FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
    WHERE {where}
    GROUP BY 1 ORDER BY 1
""")
with r3_right:
    st.subheader("Under / Normal / Overtime by Block")
    fig_uo = go.Figure()
    fig_uo.add_trace(go.Bar(name="Underutilized", x=under_over["BLOCK_NAME"],
                            y=under_over["UNDER"], marker_color=ct.COLORS["danger"]))
    fig_uo.add_trace(go.Bar(name="Normal", x=under_over["BLOCK_NAME"],
                            y=under_over["NORMAL"], marker_color=ct.COLORS["primary"]))
    fig_uo.add_trace(go.Bar(name="Overtime", x=under_over["BLOCK_NAME"],
                            y=under_over["OVER"], marker_color=ct.COLORS["warning"]))
    ct.apply_style(fig_uo, height=380, legend_below=True)
    fig_uo.update_layout(
        barmode="stack",
        xaxis_title="", yaxis_title="Cases",
    )
    st.plotly_chart(fig_uo, use_container_width=True)

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("OR Case Detail Table"):
    detail = run_query(f"""
        SELECT CASE_ID, OR_ROOM_ID, FACILITY_NAME, SURGEON_NAME, SPECIALTY,
               BLOCK_NAME, CASE_DATE, CASE_DAY_OF_WEEK,
               DELAY_MINUTES, CASE_MINUTES, TURNOVER_MINUTES,
               ROUND(UTILIZATION_PCT * 100, 1) AS UTIL_PCT,
               FIRST_CASE_ON_TIME, IS_UNDERUTILIZED, IS_OVERTIME,
               CPT_DESCRIPTION
        FROM HOSPITAL360_CUR.OPERATIONS.MART_OR_CAPACITY
        WHERE {where}
        ORDER BY CASE_DATE DESC
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
