import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function ORCapacity() {
  const kpi = useSnowflakeQuery(
    'or-kpi',
    `SELECT
      ROUND(AVG(UTILIZATION_PCT)*100,1) AS AVG_UTIL,
      ROUND(AVG(CASE WHEN FIRST_CASE_ON_TIME THEN 1 ELSE 0 END)*100,1) AS FCOT_PCT,
      ROUND(AVG(DELAY_MINUTES),1) AS AVG_DELAY,
      COUNT(*) AS TOTAL_CASES,
      ROUND(AVG(CASE_MINUTES),0) AS AVG_CASE_MIN
    FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY`
  );

  const heatmap = useSnowflakeQuery(
    'or-heatmap',
    `SELECT BLOCK_NAME, CASE_DAY_OF_WEEK AS DOW, ROUND(AVG(UTILIZATION_PCT)*100,1) AS UTIL
    FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY
    GROUP BY 1, 2`
  );

  const monthly = useSnowflakeQuery(
    'or-monthly',
    `SELECT CASE_MONTH AS MONTH, BLOCK_NAME,
      ROUND(AVG(UTILIZATION_PCT)*100,1) AS UTIL
    FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY
    GROUP BY 1, 2 ORDER BY 1`
  );

  const topSurgeons = useSnowflakeQuery(
    'or-surgeons',
    `SELECT SURGEON_NAME, COUNT(*) AS CASES, ROUND(AVG(UTILIZATION_PCT)*100,1) AS UTIL
    FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY
    GROUP BY 1 ORDER BY CASES DESC LIMIT 10`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  // Pivot heatmap data
  const dowOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const blocks = [...new Set(heatmap.data?.map((r: any) => r.BLOCK_NAME) ?? [])];
  const heatZ = blocks.map(block =>
    dowOrder.map(day => {
      const row = heatmap.data?.find((r: any) => r.BLOCK_NAME === block && r.DOW === day);
      return row?.UTIL ?? null;
    })
  );

  // Group monthly by block
  const blockNames = [...new Set(monthly.data?.map((r: any) => r.BLOCK_NAME) ?? [])];
  const monthlyTraces = blockNames.slice(0, 6).map((block, i) => {
    const rows = monthly.data?.filter((r: any) => r.BLOCK_NAME === block) ?? [];
    return {
      x: rows.map((r: any) => r.MONTH),
      y: rows.map((r: any) => r.UTIL),
      type: 'scatter' as const,
      mode: 'lines' as const,
      name: block as string,
      line: { color: COLOR_SEQ[i % COLOR_SEQ.length], width: 2 },
    };
  });

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">OR Capacity & Utilization</h1>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KPICard title="Avg Utilization" value={`${kpi.data?.[0]?.AVG_UTIL}%`} tooltip="Average OR Utilization — mean percentage of allocated block time actually used for surgical cases across all operating rooms" />
        <KPICard title="First-Case On-Time" value={`${kpi.data?.[0]?.FCOT_PCT}%`} tooltip="First-Case On-Time Start — percentage of first surgical cases that begin within the scheduled start window, a key OR efficiency indicator" />
        <KPICard title="Avg Delay (min)" value={kpi.data?.[0]?.AVG_DELAY} tooltip="Average Delay Minutes — mean number of minutes cases start late relative to their scheduled time, including turnover and prep delays" />
        <KPICard title="Total Cases" value={kpi.data?.[0]?.TOTAL_CASES?.toLocaleString()} tooltip="Total Surgical Cases — total number of operating room cases performed during the analysis period" />
        <KPICard title="Avg Case Duration" value={`${kpi.data?.[0]?.AVG_CASE_MIN} min`} tooltip="Average Case Duration — mean time in minutes from incision to close for surgical procedures, used for block scheduling optimization" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Block Utilization Heatmap (%)">
          {heatmap.data && heatmap.data.length > 0 && (
            <Plot
              data={[{
                z: heatZ,
                x: dowOrder.filter(d => heatmap.data!.some((r: any) => r.DOW === d)),
                y: blocks,
                type: 'heatmap',
                colorscale: 'RdYlGn',
                text: heatZ.map(row => row.map(v => v != null ? `${v}%` : '')),
                texttemplate: '%{text}',
                hoverinfo: 'z',
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 40, l: 140, r: 20 } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Monthly Utilization by Block (%)">
          {monthly.data && monthly.data.length > 0 && (
            <Plot
              data={monthlyTraces}
              layout={{ ...darkLayout, title: undefined, yaxis: { ...darkLayout.yaxis, title: 'Utilization %' }, legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Top Surgeons by Case Volume">
          {topSurgeons.data && (
            <Plot
              data={[{
                y: topSurgeons.data.map((r: any) => r.SURGEON_NAME),
                x: topSurgeons.data.map((r: any) => r.CASES),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.primary },
                text: topSurgeons.data.map((r: any) => `${r.CASES} (${r.UTIL}%)`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 200, r: 80 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Cases' } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
