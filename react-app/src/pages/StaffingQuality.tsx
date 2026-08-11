import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function StaffingQuality() {
  const kpi = useSnowflakeQuery(
    'staff-kpi',
    `SELECT
      ROUND(AVG(HRS_PER_PATIENT), 1) AS AVG_HRS,
      ROUND(AVG(OT_PCT) * 100, 1) AS AVG_OT,
      ROUND(SUM(CASE WHEN IS_UNDERSTAFFED THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, 1) AS UNDER_PCT,
      ROUND(AVG(CASE WHEN IS_UNDERSTAFFED AND READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT_UNDER,
      ROUND(AVG(CASE WHEN NOT IS_UNDERSTAFFED AND READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT_OK
    FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY
    WHERE PATIENT_CENSUS > 0`
  );

  const trend = useSnowflakeQuery(
    'staff-trend',
    `SELECT SHIFT_MONTH AS MONTH,
      ROUND(AVG(HRS_PER_PATIENT), 1) AS HRS,
      ROUND(AVG(CASE WHEN READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT
    FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY
    WHERE PATIENT_CENSUS > 0
    GROUP BY 1 ORDER BY 1`
  );

  const scatter = useSnowflakeQuery(
    'staff-scatter',
    `SELECT DEPT_NAME, DEPT_TYPE,
      ROUND(AVG(HRS_PER_PATIENT), 1) AS HRS,
      ROUND(AVG(CASE WHEN READMIT_RATE IS NOT NULL THEN READMIT_RATE END) * 100, 1) AS READMIT,
      SUM(PATIENT_CENSUS) AS TOTAL
    FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY
    WHERE PATIENT_CENSUS > 0 AND READMIT_RATE IS NOT NULL
    GROUP BY 1, 2
    HAVING COUNT(*) >= 30`
  );

  const otByDept = useSnowflakeQuery(
    'staff-ot',
    `SELECT DEPT_NAME, ROUND(AVG(OT_PCT) * 100, 1) AS OT_PCT
    FROM HOSPITAL_360.WORKFORCE.MART_STAFFING_QUALITY
    WHERE PATIENT_CENSUS > 0
    GROUP BY 1
    HAVING COUNT(*) >= 30
    ORDER BY OT_PCT DESC
    LIMIT 12`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Staffing & Quality</h1>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <KPICard title="Avg Hrs/Patient" value={kpi.data?.[0]?.AVG_HRS} tooltip="Average Hours per Patient — mean nursing/clinical hours worked per patient day, a measure of staffing intensity" />
        <KPICard title="Avg Overtime %" value={`${kpi.data?.[0]?.AVG_OT}%`} tooltip="Average Overtime Percentage — proportion of total labor hours that are overtime, indicating staffing strain and budget pressure" />
        <KPICard title="Understaffed Days" value={`${kpi.data?.[0]?.UNDER_PCT}%`} tooltip="Understaffed Days — percentage of shift-days where staffing fell below the minimum safe threshold for the unit census" />
        <KPICard title="Readmit (Understaffed)" value={`${kpi.data?.[0]?.READMIT_UNDER}%`} tooltip="Readmission Rate on Understaffed Days — 30-day readmission rate for patients discharged during periods of inadequate staffing" />
        <KPICard title="Readmit (Adequate)" value={`${kpi.data?.[0]?.READMIT_OK}%`} tooltip="Readmission Rate on Adequately Staffed Days — 30-day readmission rate for patients discharged when staffing met or exceeded thresholds" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Staffing vs. Readmission Rate (Monthly)">
          {trend.data && trend.data.length > 0 && (
            <Plot
              data={[
                {
                  x: trend.data.map((r: any) => r.MONTH),
                  y: trend.data.map((r: any) => r.HRS),
                  type: 'scatter',
                  mode: 'lines',
                  name: 'Hrs/Patient',
                  line: { color: COLORS.primary, width: 2 },
                },
                {
                  x: trend.data.map((r: any) => r.MONTH),
                  y: trend.data.map((r: any) => r.READMIT),
                  type: 'scatter',
                  mode: 'lines',
                  name: 'Readmit Rate %',
                  yaxis: 'y2',
                  line: { color: COLORS.danger, width: 2, dash: 'dot' },
                },
              ]}
              layout={{
                ...darkLayout,
                title: undefined,
                yaxis: { ...darkLayout.yaxis, title: 'Hrs / Patient', side: 'left' },
                yaxis2: { title: 'Readmit Rate %', overlaying: 'y', side: 'right', gridcolor: '#1a1a1a', titlefont: { color: '#e0e0e0' }, tickfont: { color: '#e0e0e0' } },
                legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } },
              }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Staffing Level vs. Readmissions by Dept">
          {scatter.data && scatter.data.length > 0 && (
            <Plot
              data={[{
                x: scatter.data.map((r: any) => r.HRS),
                y: scatter.data.map((r: any) => r.READMIT),
                text: scatter.data.map((r: any) => r.DEPT_NAME),
                type: 'scatter',
                mode: 'markers',
                marker: {
                  color: scatter.data.map((r: any) => {
                    const types = [...new Set(scatter.data!.map((d: any) => d.DEPT_TYPE))];
                    return COLOR_SEQ[types.indexOf(r.DEPT_TYPE) % COLOR_SEQ.length];
                  }),
                  size: scatter.data.map((r: any) => Math.max(8, Math.min(25, r.TOTAL / 500))),
                },
                hovertemplate: '%{text}<br>Hrs/Patient: %{x}<br>Readmit: %{y}%<extra></extra>',
              }]}
              layout={{ ...darkLayout, title: undefined, xaxis: { ...darkLayout.xaxis, title: 'Avg Hrs / Patient' }, yaxis: { ...darkLayout.yaxis, title: 'Readmission Rate %' } }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Overtime % by Department">
          {otByDept.data && otByDept.data.length > 0 && (
            <Plot
              data={[{
                y: otByDept.data.map((r: any) => r.DEPT_NAME),
                x: otByDept.data.map((r: any) => r.OT_PCT),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.warning },
                text: otByDept.data.map((r: any) => `${r.OT_PCT}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 180, r: 60 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Overtime %' } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
