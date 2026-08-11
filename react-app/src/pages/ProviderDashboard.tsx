import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';
import { Link } from 'react-router-dom';

export default function ProviderDashboard() {
  // KPIs
  const encounters = useSnowflakeQuery(
    'dash-encounters',
    `SELECT COUNT(*) AS N FROM HOSPITAL_360.CLINICAL.FCT_ENCOUNTER`
  );
  const readmission = useSnowflakeQuery(
    'dash-readmission',
    `SELECT ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS`
  );
  const leakage = useSnowflakeQuery(
    'dash-leakage',
    `SELECT ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE`
  );
  const orUtil = useSnowflakeQuery(
    'dash-or-util',
    `SELECT ROUND(AVG(UTILIZATION_PCT)*100,1) AS RATE FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY`
  );
  const denied = useSnowflakeQuery(
    'dash-denied',
    `SELECT ROUND(SUM(CHARGE_AMT)/1e6,1) AS AMT FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE`
  );
  const mlPred = useSnowflakeQuery(
    'dash-predictions',
    `SELECT SUM(ROW_COUNT) AS N FROM HOSPITAL_360.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ML_PREDICTIONS'`
  );

  // Trend sparklines
  const trendEnc = useSnowflakeQuery(
    'dash-trend-enc',
    `SELECT DATE_TRUNC('MONTH', ADMIT_DATE)::DATE AS MONTH, COUNT(*) AS ENCOUNTERS FROM HOSPITAL_360.CLINICAL.FCT_ENCOUNTER GROUP BY 1 ORDER BY 1`
  );
  const trendReadmit = useSnowflakeQuery(
    'dash-trend-readmit',
    `SELECT ADMIT_MONTH AS MONTH, ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS READMIT_RATE FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS GROUP BY 1 ORDER BY 1`
  );
  const trendLeak = useSnowflakeQuery(
    'dash-trend-leak',
    `SELECT REFERRAL_MONTH AS MONTH, ROUND(AVG(CASE WHEN LEAKAGE_FLAG THEN 1 ELSE 0 END)*100,1) AS LEAK_RATE FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE GROUP BY 1 ORDER BY 1`
  );

  // Use-case highlights
  const topDrg = useSnowflakeQuery(
    'dash-top-drg',
    `SELECT DRG_DESCRIPTION, COUNT(*) AS N FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS WHERE READMIT_30_FLAG = TRUE GROUP BY 1 ORDER BY 2 DESC LIMIT 1`
  );
  const topSpec = useSnowflakeQuery(
    'dash-top-spec',
    `SELECT REFERRED_TO_SPECIALTY, ROUND(SUM(LOST_REVENUE),0) AS LOST FROM HOSPITAL_360.CLINICAL.MART_PATIENT_LEAKAGE WHERE LEAKAGE_FLAG GROUP BY 1 ORDER BY 2 DESC LIMIT 1`
  );
  const lowBlock = useSnowflakeQuery(
    'dash-low-block',
    `SELECT BLOCK_NAME, ROUND(AVG(UTILIZATION_PCT)*100,1) AS UTIL FROM HOSPITAL_360.OPERATIONS.MART_OR_CAPACITY GROUP BY 1 ORDER BY 2 ASC LIMIT 1`
  );
  const topCat = useSnowflakeQuery(
    'dash-top-cat',
    `SELECT DENIAL_CATEGORY, COUNT(*) AS N FROM HOSPITAL_360.FINANCIAL.MART_DENIALS_REVCYCLE GROUP BY 1 ORDER BY 2 DESC LIMIT 1`
  );

  // ML Quick-Look
  const forecast = useSnowflakeQuery(
    'dash-forecast',
    `SELECT ENCOUNTER_TYPE, FORECAST_DATE, FORECAST_COUNT FROM HOSPITAL_360.ML_PREDICTIONS.PRED_ENCOUNTER_VOLUME ORDER BY ENCOUNTER_TYPE, FORECAST_DATE`
  );
  const anomalies = useSnowflakeQuery(
    'dash-anomalies',
    `SELECT TS, ACTUAL_COUNT, EXPECTED_COUNT, IS_ANOMALY
     FROM HOSPITAL_360.ML_PREDICTIONS.PRED_DENIAL_ANOMALIES
     ORDER BY TS`
  );

  // Build forecast chart traces grouped by encounter type
  const forecastTraces = () => {
    if (!forecast.data) return [];
    const types = [...new Set(forecast.data.map((r: any) => r.ENCOUNTER_TYPE))];
    return types.map((t, i) => {
      const rows = forecast.data!.filter((r: any) => r.ENCOUNTER_TYPE === t);
      return {
        x: rows.map((r: any) => r.FORECAST_DATE),
        y: rows.map((r: any) => Number(r.FORECAST_COUNT)),
        name: t as string,
        type: 'scatter' as const,
        mode: 'lines' as const,
        line: { color: COLOR_SEQ[i % COLOR_SEQ.length], width: 2 },
      };
    });
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Provider Central Dashboard</h1>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <KPICard title="Total Encounters" value={encounters.data?.[0]?.N ? Number(encounters.data[0].N).toLocaleString() : undefined} isLoading={encounters.isLoading} tooltip="Total Encounters — total number of inpatient, outpatient, and ED visits recorded across all facilities" />
        <KPICard title="Readmission Rate" value={readmission.data?.[0]?.RATE != null ? `${readmission.data[0].RATE}%` : undefined} isLoading={readmission.isLoading} tooltip="30-Day Readmission Rate — percentage of discharged patients readmitted within 30 days, a CMS penalty measure" />
        <KPICard title="Leakage Rate" value={leakage.data?.[0]?.RATE != null ? `${leakage.data[0].RATE}%` : undefined} isLoading={leakage.isLoading} tooltip="Patient Leakage Rate — percentage of referrals where the patient received care outside the network" />
        <KPICard title="OR Utilization" value={orUtil.data?.[0]?.RATE != null ? `${orUtil.data[0].RATE}%` : undefined} isLoading={orUtil.isLoading} tooltip="OR Utilization — average percentage of scheduled block time actually used for surgical cases" />
        <KPICard title="Denied Charges" value={denied.data?.[0]?.AMT != null ? `$${denied.data[0].AMT}M` : undefined} isLoading={denied.isLoading} tooltip="Total Denied Charges — aggregate dollar amount of claims denied by payers across all categories" />
        <KPICard title="ML Predictions" value={mlPred.data?.[0]?.N ? Number(mlPred.data[0].N).toLocaleString() : undefined} isLoading={mlPred.isLoading} tooltip="ML Prediction Rows — total number of forecast, anomaly, and driver records generated by Cortex ML models" />
      </div>

      {/* Trend Sparklines */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border border-[#D15635] rounded-lg p-4">
          <h3 className="text-sm font-medium text-gray-600 mb-2">Monthly Encounters</h3>
          {trendEnc.data && (
            <Plot
              data={[{ x: trendEnc.data.map((r: any) => r.MONTH), y: trendEnc.data.map((r: any) => Number(r.ENCOUNTERS)), type: 'scatter', mode: 'lines', fill: 'tozeroy', line: { color: COLORS.primary, width: 2 }, fillcolor: `${COLORS.primary}20` }]}
              layout={{ ...darkLayout, height: 200, margin: { t: 10, b: 30, l: 40, r: 10 }, xaxis: { ...darkLayout.xaxis, showticklabels: true }, yaxis: { ...darkLayout.yaxis } }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '200px' }}
            />
          )}
        </div>
        <div className="border border-[#D15635] rounded-lg p-4">
          <h3 className="text-sm font-medium text-gray-600 mb-2">Readmission Rate Trend</h3>
          {trendReadmit.data && (
            <Plot
              data={[{ x: trendReadmit.data.map((r: any) => r.MONTH), y: trendReadmit.data.map((r: any) => Number(r.READMIT_RATE)), type: 'scatter', mode: 'lines', line: { color: COLORS.danger, width: 2 } }]}
              layout={{ ...darkLayout, height: 200, margin: { t: 10, b: 30, l: 40, r: 10 }, yaxis: { ...darkLayout.yaxis, title: '%' } }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '200px' }}
            />
          )}
        </div>
        <div className="border border-[#D15635] rounded-lg p-4">
          <h3 className="text-sm font-medium text-gray-600 mb-2">Leakage Rate Trend</h3>
          {trendLeak.data && (
            <Plot
              data={[{ x: trendLeak.data.map((r: any) => r.MONTH), y: trendLeak.data.map((r: any) => Number(r.LEAK_RATE)), type: 'scatter', mode: 'lines', line: { color: COLORS.warning, width: 2 } }]}
              layout={{ ...darkLayout, height: 200, margin: { t: 10, b: 30, l: 40, r: 10 }, yaxis: { ...darkLayout.yaxis, title: '%' } }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '200px' }}
            />
          )}
        </div>
      </div>

      {/* Use-Case Highlights */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Use-Case Highlights</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="border border-[#D15635] rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-1">Readmission & LOS</h4>
            {topDrg.data?.[0] && <p className="text-xs text-gray-600">Top readmitted DRG: <span className="text-gray-900 font-medium">{topDrg.data[0].DRG_DESCRIPTION}</span></p>}
            <Link to="/readmission" className="text-xs text-[#D15635] hover:underline mt-2 inline-block">View Details →</Link>
          </div>
          <div className="border border-[#D15635] rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-1">Patient Leakage</h4>
            {topSpec.data?.[0] && <p className="text-xs text-gray-600">Highest lost revenue: <span className="text-gray-900 font-medium">{topSpec.data[0].REFERRED_TO_SPECIALTY}</span> (${Number(topSpec.data[0].LOST).toLocaleString()})</p>}
            <Link to="/leakage" className="text-xs text-[#D15635] hover:underline mt-2 inline-block">View Details →</Link>
          </div>
          <div className="border border-[#D15635] rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-1">OR Capacity</h4>
            {lowBlock.data?.[0] && <p className="text-xs text-gray-600">Lowest utilization: <span className="text-gray-900 font-medium">{lowBlock.data[0].BLOCK_NAME}</span> ({lowBlock.data[0].UTIL}%)</p>}
            <Link to="/or-capacity" className="text-xs text-[#D15635] hover:underline mt-2 inline-block">View Details →</Link>
          </div>
          <div className="border border-[#D15635] rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-1">Denials & RevCycle</h4>
            {topCat.data?.[0] && <p className="text-xs text-gray-600">Top denial category: <span className="text-gray-900 font-medium">{topCat.data[0].DENIAL_CATEGORY}</span></p>}
            <Link to="/denials" className="text-xs text-[#D15635] hover:underline mt-2 inline-block">View Details →</Link>
          </div>
        </div>
      </div>

      {/* ML Quick-Look */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-3">Predictive Analytics</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="border border-[#D15635] rounded-lg p-4">
            <h3 className="text-sm font-medium text-gray-600 mb-2">Encounter Volume Forecast (next 90 days)</h3>
            {forecast.data && (
              <Plot
                data={forecastTraces()}
                layout={{ ...darkLayout, height: 280, margin: { t: 10, b: 30, l: 50, r: 10 }, yaxis: { ...darkLayout.yaxis, title: 'Forecasted Count' }, legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } } }}
                config={{ displayModeBar: false, responsive: true }}
                style={{ width: '100%', height: '280px' }}
              />
            )}
          </div>
          <div className="border border-[#D15635] rounded-lg p-4">
            <h3 className="text-sm font-medium text-gray-600 mb-2">Denial Anomaly Detection</h3>
            {anomalies.isLoading ? (
              <div className="h-8 w-32 bg-white/10 animate-pulse rounded" />
            ) : anomalies.data && anomalies.data.length > 0 ? (
              <>
                <p className="text-lg font-bold text-gray-900 mb-2">
                  {anomalies.data.filter((r: any) => r.IS_ANOMALY).length} <span className="text-sm font-normal text-gray-600">anomalous periods detected</span>
                </p>
                <Plot
                  data={[
                    {
                      x: anomalies.data.map((r: any) => r.TS),
                      y: anomalies.data.map((r: any) => r.ACTUAL_COUNT),
                      type: 'scatter',
                      mode: 'lines',
                      name: 'Actual',
                      line: { color: COLORS.primary, width: 1.5 },
                    },
                    {
                      x: anomalies.data.map((r: any) => r.TS),
                      y: anomalies.data.map((r: any) => r.EXPECTED_COUNT),
                      type: 'scatter',
                      mode: 'lines',
                      name: 'Expected',
                      line: { color: COLORS.muted, width: 1, dash: 'dot' },
                    },
                    {
                      x: anomalies.data.filter((r: any) => r.IS_ANOMALY).map((r: any) => r.TS),
                      y: anomalies.data.filter((r: any) => r.IS_ANOMALY).map((r: any) => r.ACTUAL_COUNT),
                      type: 'scatter',
                      mode: 'markers',
                      name: 'Anomaly',
                      marker: { color: COLORS.danger, size: 9, symbol: 'diamond' },
                    },
                  ]}
                  layout={{ ...darkLayout, height: 220, margin: { t: 5, b: 30, l: 40, r: 10 }, showlegend: false }}
                  style={{ width: '100%', height: '220px' }}
                />
              </>
            ) : (
              <p className="text-gray-500 text-sm">No anomaly data</p>
            )}
            <Link to="/predictive" className="text-sm text-[#D15635] hover:underline mt-2 inline-block">Explore Predictive Analytics →</Link>
          </div>
        </div>
      </div>
    </div>
  );
}
