import Plot from '../components/Plot';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function PredictiveAnalytics() {
  const forecast = useSnowflakeQuery(
    'pred-forecast',
    `SELECT ENCOUNTER_TYPE, FORECAST_DATE, FORECAST_COUNT, LOWER_BOUND, UPPER_BOUND
     FROM HOSPITAL_360.ML_PREDICTIONS.PRED_ENCOUNTER_VOLUME
     ORDER BY ENCOUNTER_TYPE, FORECAST_DATE`
  );

  const actuals = useSnowflakeQuery(
    'pred-actuals',
    `SELECT ENCOUNTER_TYPE, ADMIT_DATE::DATE AS DT, COUNT(*) AS CNT
     FROM HOSPITAL_360.CLINICAL.FCT_ENCOUNTER
     WHERE ADMIT_DATE >= '2024-10-01' AND ADMIT_DATE <= '2024-12-30'
     GROUP BY 1, 2 ORDER BY 1, 2`
  );

  const anomalies = useSnowflakeQuery(
    'pred-anomalies',
    `SELECT TS, ACTUAL_COUNT, EXPECTED_COUNT, LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, DENIAL_CATEGORY
     FROM HOSPITAL_360.ML_PREDICTIONS.PRED_DENIAL_ANOMALIES
     ORDER BY TS`
  );

  const readmitDrivers = useSnowflakeQuery(
    'pred-readmit-drivers',
    `SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE
     FROM HOSPITAL_360.ML_PREDICTIONS.PRED_READMISSION_DRIVERS
     WHERE CONTRIBUTOR != '["Overall"]'
     ORDER BY ABS(RELATIVE_CONTRIBUTION) DESC
     LIMIT 10`
  );

  const leakageDrivers = useSnowflakeQuery(
    'pred-leakage-drivers',
    `SELECT CONTRIBUTOR, RELATIVE_CONTRIBUTION, GROWTH_RATE
     FROM HOSPITAL_360.ML_PREDICTIONS.PRED_LEAKAGE_DRIVERS
     WHERE CONTRIBUTOR != '["Overall"]'
     ORDER BY ABS(RELATIVE_CONTRIBUTION) DESC
     LIMIT 10`
  );

  // Build forecast traces grouped by encounter type (actuals = solid, forecast = dashed + band)
  const forecastTraces = () => {
    if (!forecast.data) return [];
    const types = [...new Set(forecast.data.map((r: any) => r.ENCOUNTER_TYPE))];
    const traces: any[] = [];
    types.forEach((t, i) => {
      const color = COLOR_SEQ[i % COLOR_SEQ.length];
      const fRows = forecast.data!.filter((r: any) => r.ENCOUNTER_TYPE === t);
      const aRows = actuals.data?.filter((r: any) => r.ENCOUNTER_TYPE === t) ?? [];

      // Actual baseline (solid line)
      if (aRows.length > 0) {
        traces.push({
          x: aRows.map((r: any) => r.DT),
          y: aRows.map((r: any) => r.CNT),
          type: 'scatter',
          mode: 'lines',
          name: `${t} (Actual)`,
          line: { color, width: 2 },
          legendgroup: t,
        });
      }

      // Confidence band
      traces.push({
        x: [...fRows.map((r: any) => r.FORECAST_DATE), ...fRows.map((r: any) => r.FORECAST_DATE).reverse()],
        y: [...fRows.map((r: any) => r.UPPER_BOUND), ...fRows.map((r: any) => r.LOWER_BOUND).reverse()],
        fill: 'toself',
        fillcolor: `${color}20`,
        line: { width: 0 },
        showlegend: false,
        type: 'scatter',
        legendgroup: t,
      });

      // Forecast line (dashed)
      traces.push({
        x: fRows.map((r: any) => r.FORECAST_DATE),
        y: fRows.map((r: any) => r.FORECAST_COUNT),
        type: 'scatter',
        mode: 'lines',
        name: `${t} (Forecast)`,
        line: { color, width: 2, dash: 'dash' },
        legendgroup: t,
      });
    });
    return traces;
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Predictive Analytics</h1>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Encounter Volume Forecast (90 days)">
          {forecast.isLoading ? (
            <div className="text-gray-600 text-sm p-4">Loading...</div>
          ) : forecast.data && forecast.data.length > 0 ? (
            <Plot
              data={forecastTraces()}
              layout={{ ...darkLayout, height: 340, margin: { t: 10, b: 40, l: 50, r: 20 }, yaxis: { ...darkLayout.yaxis, title: 'Forecasted Count' }, legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } } }}
              style={{ width: '100%', height: '340px' }}
            />
          ) : (
            <div className="text-gray-500 text-sm p-4">No forecast data available</div>
          )}
        </ChartCard>

        <ChartCard title="Denial Anomaly Detection">
          {anomalies.isLoading ? (
            <div className="text-gray-600 text-sm p-4">Loading...</div>
          ) : anomalies.data && anomalies.data.length > 0 ? (
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
                  marker: { color: COLORS.danger, size: 10, symbol: 'diamond' },
                },
              ]}
              layout={{ ...darkLayout, height: 340, margin: { t: 10, b: 40, l: 50, r: 20 }, legend: { orientation: 'h', y: -0.2, font: { color: '#a0a0a0' } } }}
              style={{ width: '100%', height: '340px' }}
            />
          ) : (
            <div className="text-gray-500 text-sm p-4">No anomaly data available</div>
          )}
        </ChartCard>

        <ChartCard title="Readmission Drivers (Top Insights)">
          {readmitDrivers.isLoading ? (
            <div className="text-gray-600 text-sm p-4">Loading...</div>
          ) : readmitDrivers.data && readmitDrivers.data.length > 0 ? (
            <Plot
              data={[{
                y: readmitDrivers.data.map((r: any) => String(r.CONTRIBUTOR).replace(/[\[\]"]/g, '')),
                x: readmitDrivers.data.map((r: any) => r.RELATIVE_CONTRIBUTION),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.accent },
                text: readmitDrivers.data.map((r: any) => `${(r.RELATIVE_CONTRIBUTION * 100).toFixed(1)}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, height: 380, margin: { t: 10, b: 30, l: 300, r: 70 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Relative Contribution' } }}
              style={{ width: '100%', height: '380px' }}
            />
          ) : (
            <div className="text-gray-500 text-sm p-4">No readmission driver data available</div>
          )}
        </ChartCard>

        <ChartCard title="Leakage Drivers (Top Insights)">
          {leakageDrivers.isLoading ? (
            <div className="text-gray-600 text-sm p-4">Loading...</div>
          ) : leakageDrivers.data && leakageDrivers.data.length > 0 ? (
            <Plot
              data={[{
                y: leakageDrivers.data.map((r: any) => String(r.CONTRIBUTOR).replace(/[\[\]"]/g, '')),
                x: leakageDrivers.data.map((r: any) => r.RELATIVE_CONTRIBUTION),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.secondary },
                text: leakageDrivers.data.map((r: any) => `${(r.RELATIVE_CONTRIBUTION * 100).toFixed(1)}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{ ...darkLayout, height: 380, margin: { t: 10, b: 30, l: 300, r: 70 }, yaxis: { ...darkLayout.yaxis, autorange: 'reversed' }, xaxis: { ...darkLayout.xaxis, title: 'Relative Contribution' } }}
              style={{ width: '100%', height: '380px' }}
            />
          ) : (
            <div className="text-gray-500 text-sm p-4">No leakage driver data available</div>
          )}
        </ChartCard>
      </div>
    </div>
  );
}
