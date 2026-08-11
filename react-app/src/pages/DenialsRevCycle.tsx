import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function DenialsRevCycle() {
  const kpi = useSnowflakeQuery(
    'denials-kpi',
    `SELECT
      COUNT(*) AS TOTAL_DENIALS,
      ROUND(SUM(CHARGE_AMT)/1e6,1) AS DENIED_AMT_M,
      ROUND(AVG(DAYS_TO_FILE),0) AS AVG_DAYS_TO_FILE,
      ROUND(AVG(CASE WHEN IS_APPEALED AND APPEAL_OUTCOME = 'WON' THEN 1 WHEN IS_APPEALED THEN 0 END)*100,1) AS APPEAL_WIN_PCT,
      ROUND(SUM(ESTIMATED_RECOVERY)/1e6,1) AS RECOVERY_M
    FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE`
  );

  const byCategory = useSnowflakeQuery(
    'denials-category',
    `SELECT DENIAL_CATEGORY, COUNT(*) AS CNT, ROUND(SUM(CHARGE_AMT)/1e6,2) AS AMT
    FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE
    GROUP BY 1 ORDER BY 3 DESC`
  );

  const trend = useSnowflakeQuery(
    'denials-trend',
    `SELECT SERVICE_MONTH AS MONTH,
      COUNT(*) AS CNT,
      ROUND(SUM(CHARGE_AMT)/1e6,2) AS AMT
    FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE
    GROUP BY 1 ORDER BY 1`
  );

  const byPayer = useSnowflakeQuery(
    'denials-payer',
    `SELECT PAYER_NAME, COUNT(*) AS CNT, ROUND(SUM(CHARGE_AMT)/1e6,2) AS AMT
    FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE
    GROUP BY 1 ORDER BY 3 DESC LIMIT 8`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Denials & Revenue Cycle</h1>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KPICard title="Total Denials" value={kpi.data?.[0]?.TOTAL_DENIALS?.toLocaleString()} tooltip="Total Denials — count of all claims denied by payers, including initial denials across all denial categories" />
        <KPICard title="Denied Amount" value={`$${kpi.data?.[0]?.DENIED_AMT_M}M`} tooltip="Denied Charge Amount — total dollar value of denied claims in millions, representing revenue at risk until resolved" />
        <KPICard title="Avg Days to File" value={kpi.data?.[0]?.AVG_DAYS_TO_FILE} tooltip="Average Days to File — mean number of days between date of service and initial claim submission, shorter is better for cash flow" />
        <KPICard title="Appeal Win Rate" value={`${kpi.data?.[0]?.APPEAL_WIN_PCT}%`} tooltip="Appeal Win Rate — percentage of appealed denials that were overturned in the provider's favor, indicating appeal effectiveness" />
        <KPICard title="Est. Recovery" value={`$${kpi.data?.[0]?.RECOVERY_M}M`} tooltip="Estimated Recovery — projected dollar amount recoverable through appeals, rebilling, and denial resolution workflows" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Denied Charges by Category ($M)">
          {byCategory.data && byCategory.data.length > 0 && (
            <Plot
              data={[{
                x: byCategory.data.map((r: any) => r.DENIAL_CATEGORY),
                y: byCategory.data.map((r: any) => r.AMT),
                type: 'bar',
                marker: { color: COLORS.danger },
                text: byCategory.data.map((r: any) => `$${r.AMT}M`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, yaxis: { ...darkLayout.yaxis, title: '$ Millions' } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Monthly Denial Trend">
          {trend.data && trend.data.length > 0 && (
            <Plot
              data={[
                {
                  x: trend.data.map((r: any) => r.MONTH),
                  y: trend.data.map((r: any) => r.CNT),
                  type: 'scatter',
                  mode: 'lines',
                  name: 'Count',
                  line: { color: COLORS.primary, width: 2 },
                },
                {
                  x: trend.data.map((r: any) => r.MONTH),
                  y: trend.data.map((r: any) => r.AMT),
                  type: 'scatter',
                  mode: 'lines',
                  name: 'Amount ($M)',
                  yaxis: 'y2',
                  line: { color: COLORS.warning, width: 2 },
                },
              ]}
              layout={{
                ...darkLayout,
                title: undefined,
                yaxis: { ...darkLayout.yaxis, title: 'Count' },
                yaxis2: { title: '$ Millions', overlaying: 'y', side: 'right', gridcolor: '#1a1a1a', titlefont: { color: '#e0e0e0' }, tickfont: { color: '#e0e0e0' } },
                legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } },
              }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Denied Charges by Payer ($M)">
          {byPayer.data && byPayer.data.length > 0 && (
            <Plot
              data={[{
                x: byPayer.data.map((r: any) => r.PAYER_NAME),
                y: byPayer.data.map((r: any) => r.AMT),
                type: 'bar',
                marker: { color: COLOR_SEQ[4] },
                text: byPayer.data.map((r: any) => `$${r.AMT}M`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, yaxis: { ...darkLayout.yaxis, title: '$ Millions' } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
