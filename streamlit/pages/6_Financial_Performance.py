"""
Hospital 360 — Financial Performance Dashboard (UC6)
Department-level cost structure, margins, and volume from Workday GL data.
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
st.title("Financial Performance")
st.caption("Department-level cost structure, operating margins, and volume metrics from Workday GL")

start_dt = st.session_state.get("filter_start", "2023-07-01")
end_dt = st.session_state.get("filter_end", "2024-12-30")
facility = st.session_state.get("filter_facility", "All Facilities")

col_f1, col_f2 = st.columns(2)

dept_types = run_query(
    "SELECT DISTINCT DEPT_TYPE FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE ORDER BY 1"
)
with col_f1:
    sel_dept_type = st.multiselect(
        "Department Type", dept_types["DEPT_TYPE"].tolist(),
        default=dept_types["DEPT_TYPE"].tolist(),
    )

facilities = run_query(
    "SELECT DISTINCT FACILITY_NAME FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE ORDER BY 1"
)
with col_f2:
    sel_facility = st.multiselect(
        "Facility", facilities["FACILITY_NAME"].tolist(),
        default=facilities["FACILITY_NAME"].tolist(),
    )

# Build WHERE
def build_where() -> str:
    clauses = [f"PERIOD_DATE BETWEEN '{start_dt}' AND '{end_dt}'"]
    if facility != "All Facilities":
        clauses.append(f"FACILITY_NAME = '{facility}'")
    if sel_dept_type:
        dt_list = ",".join(f"'{d}'" for d in sel_dept_type)
        clauses.append(f"DEPT_TYPE IN ({dt_list})")
    if sel_facility:
        f_list = ",".join(f"'{f}'" for f in sel_facility)
        clauses.append(f"FACILITY_NAME IN ({f_list})")
    return " AND ".join(clauses)

where = build_where()

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpis = run_query(f"""
    SELECT
        ROUND(SUM(TOTAL_REVENUE) / 1e6, 1)             AS REVENUE_M,
        ROUND(SUM(TOTAL_EXPENSE) / 1e6, 1)             AS EXPENSE_M,
        ROUND((SUM(TOTAL_REVENUE) - SUM(TOTAL_EXPENSE))
              / NULLIF(SUM(TOTAL_REVENUE), 0) * 100, 1) AS MARGIN_PCT,
        ROUND(AVG(COST_PER_CMI_DISCHARGE), 0)           AS AVG_COST_CMI,
        ROUND(AVG(LABOR_PCT) * 100, 1)                  AS AVG_LABOR_PCT
    FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE {where}
""")

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("Revenue", f"${kpis['REVENUE_M'].iloc[0]}M")
k2.metric("Expense", f"${kpis['EXPENSE_M'].iloc[0]}M")
k3.metric("Operating Margin", f"{kpis['MARGIN_PCT'].iloc[0]}%")
k4.metric("Cost/CMI Discharge", f"${int(kpis['AVG_COST_CMI'].iloc[0]):,}")
k5.metric("Labor Cost %", f"{kpis['AVG_LABOR_PCT'].iloc[0]}%")

st.markdown("---")

# ---------------------------------------------------------------------------
# Row 1: Revenue vs Expense trend + Cost breakdown
# ---------------------------------------------------------------------------
r1_left, r1_right = st.columns(2)

trend = run_query(f"""
    SELECT PERIOD_DATE AS MONTH,
           ROUND(SUM(TOTAL_REVENUE) / 1e6, 2) AS REVENUE_M,
           ROUND(SUM(TOTAL_EXPENSE) / 1e6, 2) AS EXPENSE_M,
           ROUND((SUM(TOTAL_REVENUE) - SUM(TOTAL_EXPENSE))
                 / NULLIF(SUM(TOTAL_REVENUE), 0) * 100, 1) AS MARGIN_PCT
    FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE {where}
    GROUP BY 1 ORDER BY 1
""")
with r1_left:
    st.subheader("Revenue vs. Expense (Monthly)")
    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=trend["MONTH"], y=trend["REVENUE_M"],
        name="Revenue ($M)", marker_color=ct.COLORS["success"]
    ))
    fig.add_trace(go.Bar(
        x=trend["MONTH"], y=trend["EXPENSE_M"],
        name="Expense ($M)", marker_color=ct.COLORS["danger"]
    ))
    fig.add_trace(go.Scatter(
        x=trend["MONTH"], y=trend["MARGIN_PCT"],
        name="Margin %", yaxis="y2",
        line=dict(color=ct.COLORS["primary"], width=2)
    ))
    ct.apply_style(fig, height=340)
    fig.update_layout(
        barmode="group",
        yaxis=dict(title="$M"),
        yaxis2=dict(title="Margin %", side="right", overlaying="y"),
        legend=dict(orientation="h", y=-0.2),
    )
    st.plotly_chart(fig, use_container_width=True)

cost_breakdown = run_query(f"""
    SELECT PERIOD_DATE AS MONTH,
           ROUND(SUM(LABOR_COST) / 1e6, 2)         AS LABOR,
           ROUND(SUM(SUPPLY_COST) / 1e6, 2)        AS SUPPLIES,
           ROUND(SUM(OVERHEAD_COST) / 1e6, 2)      AS OVERHEAD,
           ROUND(SUM(DEPRECIATION_COST) / 1e6, 2)  AS DEPRECIATION
    FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE {where}
    GROUP BY 1 ORDER BY 1
""")
with r1_right:
    st.subheader("Cost Breakdown by Category")
    fig2 = go.Figure()
    for cat, color in [("LABOR", ct.COLORS["primary"]),
                       ("SUPPLIES", ct.COLORS["warning"]),
                       ("OVERHEAD", ct.COLORS["info"]),
                       ("DEPRECIATION", ct.COLORS["muted"])]:
        fig2.add_trace(go.Bar(
            x=cost_breakdown["MONTH"], y=cost_breakdown[cat],
            name=cat.title(), marker_color=color
        ))
    ct.apply_style(fig2, height=340)
    fig2.update_layout(
        barmode="stack",
        yaxis_title="$M",
        legend=dict(orientation="h", y=-0.2),
    )
    st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Row 2: Cost per discharge by dept + Margin by facility
# ---------------------------------------------------------------------------
st.markdown("---")
r2_left, r2_right = st.columns(2)

dept_cost = run_query(f"""
    SELECT DEPT_NAME,
           ROUND(AVG(COST_PER_CMI_DISCHARGE), 0) AS COST_PER_CMI,
           ROUND(AVG(OPERATING_MARGIN) * 100, 1) AS MARGIN_PCT
    FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE {where} AND COST_PER_CMI_DISCHARGE IS NOT NULL
    GROUP BY 1
    ORDER BY COST_PER_CMI DESC
    LIMIT 12
""")
with r2_left:
    st.subheader("Cost per CMI-Adjusted Discharge by Dept")
    fig3 = px.bar(
        dept_cost, x="COST_PER_CMI", y="DEPT_NAME", orientation="h",
        color="MARGIN_PCT", color_continuous_scale="RdYlGn",
        text="COST_PER_CMI",
    )
    ct.apply_style(fig3, height=380)
    fig3.update_layout(
        xaxis_title="Cost / CMI Discharge ($)",
        yaxis_title="",
        yaxis=dict(autorange="reversed"),
        coloraxis_colorbar_title="Margin %",
    )
    ct.style_bars_gradient(fig3)
    fig3.update_traces(texttemplate="$%{text:,.0f}", textposition="outside")
    st.plotly_chart(fig3, use_container_width=True)

fac_margin = run_query(f"""
    SELECT FACILITY_NAME,
           ROUND(SUM(TOTAL_REVENUE) / 1e6, 1) AS REVENUE_M,
           ROUND(SUM(TOTAL_EXPENSE) / 1e6, 1) AS EXPENSE_M,
           ROUND((SUM(TOTAL_REVENUE) - SUM(TOTAL_EXPENSE))
                 / NULLIF(SUM(TOTAL_REVENUE), 0) * 100, 1) AS MARGIN_PCT
    FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE {where}
    GROUP BY 1 ORDER BY MARGIN_PCT DESC
""")
with r2_right:
    st.subheader("Operating Margin by Facility")
    fig4 = px.bar(
        fac_margin, x="FACILITY_NAME", y="MARGIN_PCT",
        color="MARGIN_PCT", color_continuous_scale="RdYlGn",
        text="MARGIN_PCT",
    )
    ct.apply_style(fig4, height=380)
    fig4.update_layout(
        xaxis_title="", yaxis_title="Operating Margin %",
        coloraxis_showscale=False,
    )
    ct.style_bars_gradient(fig4)
    fig4.update_traces(texttemplate="%{text}%", textposition="outside")
    st.plotly_chart(fig4, use_container_width=True)

# ---------------------------------------------------------------------------
# Detail table
# ---------------------------------------------------------------------------
st.markdown("---")
with st.expander("Department-Month Detail Table"):
    detail = run_query(f"""
        SELECT DEPT_NAME, FACILITY_NAME, PERIOD_DATE,
               ROUND(TOTAL_REVENUE, 0) AS REVENUE,
               ROUND(TOTAL_EXPENSE, 0) AS EXPENSE,
               ROUND(NET_REVENUE, 0) AS NET_REVENUE,
               ROUND(OPERATING_MARGIN * 100, 1) AS MARGIN_PCT,
               DISCHARGES, ROUND(PATIENT_DAYS, 0) AS PATIENT_DAYS,
               ROUND(COST_PER_DISCHARGE, 0) AS COST_PER_DC,
               ROUND(COST_PER_CMI_DISCHARGE, 0) AS COST_PER_CMI_DC,
               ROUND(LABOR_PCT * 100, 1) AS LABOR_PCT,
               ROUND(SUPPLY_PCT * 100, 1) AS SUPPLY_PCT
        FROM HOSPITAL360_CUR.FINANCIAL.MART_FINANCIAL_PERFORMANCE
        WHERE {where}
        ORDER BY PERIOD_DATE DESC, DEPT_NAME
        LIMIT 500
    """)
    st.dataframe(detail, use_container_width=True, hide_index=True)
