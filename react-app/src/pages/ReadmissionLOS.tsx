import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function ReadmissionLOS() {
  const kpi = useSnowflakeQuery(
    'readmit-kpi',
    `SELECT
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS READMIT_RATE,
      ROUND(AVG(LOS_DAYS),1) AS AVG_LOS,
      COUNT(*) AS TOTAL_ENCOUNTERS
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS`
  );

  const trend = useSnowflakeQuery(
    'readmit-trend',
    `SELECT DATE_TRUNC('MONTH', DISCHARGE_DATE) AS MONTH,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    GROUP BY 1 ORDER BY 1`
  );

  const losHist = useSnowflakeQuery(
    'readmit-los-hist',
    `SELECT LOS_DAYS, COUNT(*) AS CNT
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    GROUP BY 1 ORDER BY 1`
  );

  const topDrg = useSnowflakeQuery(
    'readmit-drg',
    `SELECT DRG_DESCRIPTION,
       ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
     FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
     WHERE DRG_DESCRIPTION IS NOT NULL
     GROUP BY 1
     HAVING COUNT(*) >= 50
     ORDER BY RATE DESC
     LIMIT 10`
  );

  const byPayer = useSnowflakeQuery(
    'readmit-payer',
    `SELECT PAYER_NAME, ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    GROUP BY 1 ORDER BY 2 DESC`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Readmission & Length of Stay</h1>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <KPICard title="30-Day Readmission" value={`${kpi.data?.[0]?.READMIT_RATE}%`} tooltip="30-Day Readmission Rate — percentage of discharged patients who are readmitted to the hospital within 30 days, a key CMS quality and penalty measure" />
        <KPICard title="Avg LOS (days)" value={kpi.data?.[0]?.AVG_LOS} tooltip="Average Length of Stay — mean number of days patients remain admitted from admission to discharge, used to assess efficiency and resource utilization" />
        <KPICard title="Total Encounters" value={kpi.data?.[0]?.TOTAL_ENCOUNTERS?.toLocaleString()} tooltip="Total Encounters — total number of inpatient admissions included in the readmission analysis" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Readmission Rate Trend (Monthly)">
          {trend.data && (
            <Plot
              data={[{
                x: trend.data.map(r => r.MONTH),
                y: trend.data.map(r => r.RATE),
                type: 'scatter',
                mode: 'lines+markers',
                line: { color: COLORS.primary },
              }]}
              layout={{ ...darkLayout, title: undefined }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Length of Stay Distribution (Days)">
          {losHist.data && (
            <Plot
              data={[{
                x: losHist.data.map(r => r.LOS_DAYS),
                y: losHist.data.map(r => r.CNT),
                type: 'bar',
                marker: { color: COLORS.secondary },
              }]}
              layout={{ ...darkLayout, title: undefined, xaxis: { ...darkLayout.xaxis, title: 'Days' }, yaxis: { ...darkLayout.yaxis, title: 'Count' } }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Top DRGs by Readmission Rate">
          {topDrg.data && (
            <Plot
              data={[{
                y: topDrg.data.map(r => r.DRG_DESCRIPTION),
                x: topDrg.data.map(r => r.RATE),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLOR_SEQ[0] },
                text: topDrg.data.map(r => `${r.RATE}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 280, r: 60 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Readmission Rate %' } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Readmission Rate by Payer">
          {byPayer.data && (
            <Plot
              data={[{
                x: byPayer.data.map(r => r.PAYER_NAME),
                y: byPayer.data.map(r => r.RATE),
                type: 'bar',
                marker: { color: COLOR_SEQ[1] },
              }]}
              layout={{ ...darkLayout, title: undefined }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
