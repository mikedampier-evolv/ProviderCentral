import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, darkLayout } from '../lib/chartTheme';

export default function FinancialPerformance() {
  const kpi = useSnowflakeQuery(
    'fin-kpi',
    `SELECT
      ROUND(SUM(TOTAL_REVENUE)/1e6,1) AS REV,
      ROUND(SUM(TOTAL_EXPENSE)/1e6,1) AS EXP,
      ROUND((SUM(TOTAL_REVENUE)-SUM(TOTAL_EXPENSE))/NULLIF(SUM(TOTAL_REVENUE),0)*100,1) AS MARGIN,
      ROUND(AVG(COST_PER_CMI_DISCHARGE),0) AS CPD,
      ROUND(AVG(LABOR_PCT)*100,1) AS LABOR
    FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE`
  );

  const monthly = useSnowflakeQuery(
    'fin-monthly',
    `SELECT PERIOD_DATE AS MONTH,
      ROUND(SUM(TOTAL_REVENUE)/1e6,2) AS REV,
      ROUND(SUM(TOTAL_EXPENSE)/1e6,2) AS EXP,
      ROUND((SUM(TOTAL_REVENUE)-SUM(TOTAL_EXPENSE))/NULLIF(SUM(TOTAL_REVENUE),0)*100,1) AS MARGIN
    FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    GROUP BY 1 ORDER BY 1`
  );

  const costBreakdown = useSnowflakeQuery(
    'fin-cost-breakdown',
    `SELECT PERIOD_DATE AS MONTH,
      ROUND(SUM(LABOR_COST)/1e6,2) AS LABOR,
      ROUND(SUM(SUPPLY_COST)/1e6,2) AS SUPPLIES,
      ROUND(SUM(OVERHEAD_COST)/1e6,2) AS OVERHEAD,
      ROUND(SUM(DEPRECIATION_COST)/1e6,2) AS DEPRECIATION
    FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    GROUP BY 1 ORDER BY 1`
  );

  const deptCost = useSnowflakeQuery(
    'fin-dept-cost',
    `SELECT DEPT_NAME,
      ROUND(AVG(COST_PER_CMI_DISCHARGE),0) AS COST,
      ROUND(AVG(OPERATING_MARGIN)*100,1) AS MARGIN
    FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    WHERE COST_PER_CMI_DISCHARGE IS NOT NULL
    GROUP BY 1 ORDER BY COST DESC LIMIT 12`
  );

  const facilityMargin = useSnowflakeQuery(
    'fin-facility',
    `SELECT FACILITY_NAME,
      ROUND((SUM(TOTAL_REVENUE)-SUM(TOTAL_EXPENSE))/NULLIF(SUM(TOTAL_REVENUE),0)*100,1) AS MARGIN
    FROM HOSPITAL_360.FINANCIAL.MART_FINANCIAL_PERFORMANCE
    GROUP BY 1 ORDER BY MARGIN DESC`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Financial Performance</h1>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KPICard title="Revenue" value={`$${kpi.data?.[0]?.REV}M`} tooltip="Total Revenue — aggregate gross patient revenue across all facilities and service lines, in millions" />
        <KPICard title="Expense" value={`$${kpi.data?.[0]?.EXP}M`} tooltip="Total Expense — aggregate operating expenses including labor, supplies, overhead, and depreciation, in millions" />
        <KPICard title="Operating Margin" value={`${kpi.data?.[0]?.MARGIN}%`} tooltip="Operating Margin — (Revenue − Expense) / Revenue × 100, measuring profitability from core operations before non-operating items" />
        <KPICard title="Cost/CMI Discharge" value={`$${kpi.data?.[0]?.CPD?.toLocaleString()}`} tooltip="Cost per CMI-Adjusted Discharge — average cost per discharge normalized by Case Mix Index, enabling fair comparison across facilities with different acuity levels" />
        <KPICard title="Labor Cost %" value={`${kpi.data?.[0]?.LABOR}%`} tooltip="Labor Cost Percentage — proportion of total operating expense attributable to wages, benefits, and contract labor (typically 50-60% for hospitals)" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Revenue vs. Expense (Monthly)">
          {monthly.data && monthly.data.length > 0 && (
            <Plot
              data={[
                {
                  x: monthly.data.map((r: any) => r.MONTH),
                  y: monthly.data.map((r: any) => r.REV),
                  type: 'bar',
                  name: 'Revenue ($M)',
                  marker: { color: COLORS.success },
                },
                {
                  x: monthly.data.map((r: any) => r.MONTH),
                  y: monthly.data.map((r: any) => r.EXP),
                  type: 'bar',
                  name: 'Expense ($M)',
                  marker: { color: COLORS.danger },
                },
                {
                  x: monthly.data.map((r: any) => r.MONTH),
                  y: monthly.data.map((r: any) => r.MARGIN),
                  type: 'scatter',
                  mode: 'lines',
                  name: 'Margin %',
                  yaxis: 'y2',
                  line: { color: COLORS.primary, width: 2 },
                },
              ]}
              layout={{
                ...darkLayout,
                title: undefined,
                barmode: 'group',
                yaxis: { ...darkLayout.yaxis, title: '$M' },
                yaxis2: { title: 'Margin %', overlaying: 'y', side: 'right', gridcolor: '#1a1a1a', titlefont: { color: '#e0e0e0' }, tickfont: { color: '#e0e0e0' } },
                legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } },
              }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Cost Breakdown by Category (Monthly)">
          {costBreakdown.data && costBreakdown.data.length > 0 && (
            <Plot
              data={[
                { x: costBreakdown.data.map((r: any) => r.MONTH), y: costBreakdown.data.map((r: any) => r.LABOR), type: 'bar', name: 'Labor', marker: { color: COLORS.primary } },
                { x: costBreakdown.data.map((r: any) => r.MONTH), y: costBreakdown.data.map((r: any) => r.SUPPLIES), type: 'bar', name: 'Supplies', marker: { color: COLORS.warning } },
                { x: costBreakdown.data.map((r: any) => r.MONTH), y: costBreakdown.data.map((r: any) => r.OVERHEAD), type: 'bar', name: 'Overhead', marker: { color: COLORS.info } },
                { x: costBreakdown.data.map((r: any) => r.MONTH), y: costBreakdown.data.map((r: any) => r.DEPRECIATION), type: 'bar', name: 'Depreciation', marker: { color: COLORS.muted } },
              ]}
              layout={{ ...darkLayout, title: undefined, barmode: 'stack', yaxis: { ...darkLayout.yaxis, title: '$M' }, legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Cost per CMI-Adjusted Discharge by Dept">
          {deptCost.data && deptCost.data.length > 0 && (
            <Plot
              data={[{
                y: deptCost.data.map((r: any) => r.DEPT_NAME),
                x: deptCost.data.map((r: any) => r.COST),
                type: 'bar',
                orientation: 'h',
                marker: { color: deptCost.data.map((r: any) => r.MARGIN >= 0 ? COLORS.success : COLORS.danger) },
                text: deptCost.data.map((r: any) => `$${r.COST?.toLocaleString()}`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 180, r: 70 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Cost / CMI Discharge ($)' } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Operating Margin by Facility (%)">
          {facilityMargin.data && facilityMargin.data.length > 0 && (
            <Plot
              data={[{
                x: facilityMargin.data.map((r: any) => r.FACILITY_NAME),
                y: facilityMargin.data.map((r: any) => r.MARGIN),
                type: 'bar',
                marker: { color: facilityMargin.data.map((r: any) => r.MARGIN >= 0 ? COLORS.success : COLORS.danger) },
                text: facilityMargin.data.map((r: any) => `${r.MARGIN}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, yaxis: { ...darkLayout.yaxis, title: 'Margin %' } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
