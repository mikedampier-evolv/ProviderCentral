import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function PatientLeakage() {
  const kpi = useSnowflakeQuery(
    'leakage-kpi',
    `SELECT
      ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END)*100,1) AS LEAKAGE_RATE,
      COUNT(*) AS TOTAL_REFERRALS,
      COUNT(CASE WHEN LEAKAGE_FLAG THEN 1 END) AS LEAKED_REFERRALS
    FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE`
  );

  const trend = useSnowflakeQuery(
    'leakage-trend',
    `SELECT DATE_TRUNC('MONTH', REFERRAL_DATE) AS MONTH,
      ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE
    GROUP BY 1 ORDER BY 1`
  );

  const bySpecialty = useSnowflakeQuery(
    'leakage-specialty',
    `SELECT REFERRED_TO_SPECIALTY AS SPECIALTY, ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE
    WHERE REFERRED_TO_SPECIALTY IS NOT NULL
    GROUP BY 1 ORDER BY 2 DESC LIMIT 10`
  );

  const byProvider = useSnowflakeQuery(
    'leakage-provider',
    `SELECT REFERRING_PROVIDER, COUNT(CASE WHEN LEAKAGE_FLAG THEN 1 END) AS LEAKED
    FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE
    GROUP BY 1 ORDER BY 2 DESC LIMIT 10`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Patient Leakage</h1>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <KPICard title="Leakage Rate" value={`${kpi.data?.[0]?.LEAKAGE_RATE}%`} tooltip="Patient Leakage Rate — percentage of referrals where the patient received care at a facility outside the network, representing lost revenue opportunity" />
        <KPICard title="Total Referrals" value={kpi.data?.[0]?.TOTAL_REFERRALS?.toLocaleString()} tooltip="Total Referrals — total number of patient referrals issued by providers in the network during the analysis period" />
        <KPICard title="Leaked Referrals" value={kpi.data?.[0]?.LEAKED_REFERRALS?.toLocaleString()} tooltip="Leaked Referrals — count of referrals where the patient went to an out-of-network provider instead of staying within the system" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Leakage Rate Trend (Monthly)">
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

        <ChartCard title="Leakage Rate by Specialty (%)">
          {bySpecialty.data && (
            <Plot
              data={[{
                y: bySpecialty.data.map(r => r.SPECIALTY),
                x: bySpecialty.data.map(r => r.RATE),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.danger },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 200, r: 40 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Leakage Rate %' } }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '340px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Top Referring Providers (Leaked Count)">
          {byProvider.data && (
            <Plot
              data={[{
                y: byProvider.data.map(r => r.REFERRING_PROVIDER),
                x: byProvider.data.map(r => r.LEAKED),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLOR_SEQ[2] },
              }]}
              layout={{ ...darkLayout, title: undefined, margin: { t: 10, b: 30, l: 250, r: 40 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Leaked Referrals' } }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>
      </div>
    </div>
  );
}
