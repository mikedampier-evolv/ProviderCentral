import Plot from '../components/Plot';
import KPICard from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { COLORS, COLOR_SEQ, darkLayout } from '../lib/chartTheme';

export default function ReadmissionFacilitySpecialty() {
  const kpi = useSnowflakeQuery(
    'readmit-fs-kpi',
    `SELECT
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS READMIT_RATE,
      COUNT(*) AS TOTAL_ENCOUNTERS,
      COUNT(DISTINCT FACILITY_NAME) AS FACILITY_COUNT,
      COUNT(DISTINCT SPECIALTY) AS SPECIALTY_COUNT
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE SPECIALTY IS NOT NULL`
  );

  // Heatmap data: facility x specialty
  const heatmap = useSnowflakeQuery(
    'readmit-fs-heatmap',
    `SELECT FACILITY_NAME, SPECIALTY,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE,
      COUNT(*) AS N
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE SPECIALTY IS NOT NULL
    GROUP BY 1, 2
    HAVING COUNT(*) >= 30
    ORDER BY 1, 2`
  );

  // Top 10 facility+specialty combos by readmission rate
  const topCombos = useSnowflakeQuery(
    'readmit-fs-top',
    `SELECT FACILITY_NAME || ' — ' || SPECIALTY AS COMBO,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE,
      COUNT(*) AS N
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE SPECIALTY IS NOT NULL
    GROUP BY 1
    HAVING COUNT(*) >= 30
    ORDER BY 2 DESC
    LIMIT 10`
  );

  // Readmission rate by facility (bar chart)
  const byFacility = useSnowflakeQuery(
    'readmit-fs-facility',
    `SELECT FACILITY_NAME,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE SPECIALTY IS NOT NULL
    GROUP BY 1
    ORDER BY 2 DESC`
  );

  // Shewhart control chart data (p-chart)
  const controlData = useSnowflakeQuery(
    'readmit-fs-control',
    `SELECT DATE_TRUNC('MONTH', DISCHARGE_DATE)::DATE AS MONTH,
      COUNT(*) AS N,
      SUM(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END) AS READMITS,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100, 2) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE DISCHARGE_DATE IS NOT NULL
    GROUP BY 1 ORDER BY 1`
  );

  // Monthly trend by facility
  const trendByFacility = useSnowflakeQuery(
    'readmit-fs-trend',
    `SELECT DATE_TRUNC('MONTH', DISCHARGE_DATE)::DATE AS MONTH, FACILITY_NAME,
      ROUND(AVG(CASE WHEN READMIT_30_FLAG THEN 1 ELSE 0 END)*100,1) AS RATE
    FROM HOSPITAL_360.CLINICAL.MART_READMISSION_LOS
    WHERE SPECIALTY IS NOT NULL
    GROUP BY 1, 2
    ORDER BY 1, 2`
  );

  if (kpi.isLoading) return <div className="text-gray-600 p-8">Loading...</div>;

  // Build Shewhart p-chart (proportion control chart)
  const buildControlChart = () => {
    if (!controlData.data || controlData.data.length === 0) return null;

    const months = controlData.data.map((r: any) => r.MONTH);
    const rates = controlData.data.map((r: any) => r.RATE);
    const ns = controlData.data.map((r: any) => r.N);
    const readmits = controlData.data.map((r: any) => r.READMITS);

    // Calculate p-bar (overall proportion)
    const totalReadmits = readmits.reduce((a: number, b: number) => a + b, 0);
    const totalN = ns.reduce((a: number, b: number) => a + b, 0);
    const pBar = totalReadmits / totalN; // as proportion (0-1)
    const pBarPct = pBar * 100;

    // Calculate per-month UCL and LCL (3-sigma limits for p-chart)
    const ucl = ns.map((n: number) => Math.min(100, (pBar + 3 * Math.sqrt(pBar * (1 - pBar) / n)) * 100));
    const lcl = ns.map((n: number) => Math.max(0, (pBar - 3 * Math.sqrt(pBar * (1 - pBar) / n)) * 100));

    // Identify out-of-control points
    const oocMonths: string[] = [];
    const oocRates: number[] = [];
    rates.forEach((rate: number, i: number) => {
      if (rate > ucl[i] || rate < lcl[i]) {
        oocMonths.push(months[i]);
        oocRates.push(rate);
      }
    });

    const traces: any[] = [
      // Actual rate
      {
        x: months,
        y: rates,
        type: 'scatter',
        mode: 'lines+markers',
        name: 'Readmission Rate',
        line: { color: COLORS.primary, width: 2 },
        marker: { size: 7 },
      },
      // Center line
      {
        x: months,
        y: months.map(() => pBarPct),
        type: 'scatter',
        mode: 'lines',
        name: `CL (p̄ = ${pBarPct.toFixed(2)}%)`,
        line: { color: '#6B7280', width: 2, dash: 'dash' },
      },
      // UCL
      {
        x: months,
        y: ucl,
        type: 'scatter',
        mode: 'lines',
        name: 'UCL (+3σ)',
        line: { color: COLORS.danger, width: 1.5, dash: 'dot' },
      },
      // LCL
      {
        x: months,
        y: lcl,
        type: 'scatter',
        mode: 'lines',
        name: 'LCL (−3σ)',
        line: { color: COLORS.success, width: 1.5, dash: 'dot' },
      },
    ];

    // Out-of-control points overlay
    if (oocMonths.length > 0) {
      traces.push({
        x: oocMonths,
        y: oocRates,
        type: 'scatter',
        mode: 'markers',
        name: 'Out of Control',
        marker: { color: COLORS.danger, size: 12, symbol: 'diamond', line: { color: '#fff', width: 1.5 } },
      });
    }

    return (
      <Plot
        data={traces}
        layout={{
          ...darkLayout,
          title: undefined,
          legend: { font: { color: '#a0a0a0', size: 10 }, orientation: 'h', y: -0.25 },
          margin: { t: 10, b: 70, l: 55, r: 20 },
          yaxis: { ...darkLayout.yaxis, title: 'Readmission Rate %' },
          xaxis: { ...darkLayout.xaxis, title: 'Month' },
          annotations: [{
            x: 0.5,
            y: -0.38,
            xref: 'paper',
            yref: 'paper',
            text: `p-chart: CL = ${pBarPct.toFixed(2)}% | UCL/LCL = ±3σ based on monthly sample size (n ≈ ${Math.round(totalN / months.length).toLocaleString()})`,
            showarrow: false,
            font: { color: '#6B7280', size: 10 },
          }],
        }}
        config={{ displayModeBar: false, responsive: true }}
        style={{ width: '100%', height: '400px' }}
      />
    );
  };

  // Build heatmap traces
  const buildHeatmap = () => {
    if (!heatmap.data || heatmap.data.length === 0) return null;

    const facilities = [...new Set(heatmap.data.map((r: any) => r.FACILITY_NAME))];
    const specialties = [...new Set(heatmap.data.map((r: any) => r.SPECIALTY))];

    const zValues = facilities.map((fac) =>
      specialties.map((spec) => {
        const row = heatmap.data!.find((r: any) => r.FACILITY_NAME === fac && r.SPECIALTY === spec);
        return row ? row.RATE : null;
      })
    );

    return (
      <Plot
        data={[{
          z: zValues,
          x: specialties,
          y: facilities,
          type: 'heatmap',
          colorscale: [
            [0, '#064E3B'],
            [0.4, '#065F46'],
            [0.6, '#F59E0B'],
            [0.8, '#DC2626'],
            [1, '#7F1D1D'],
          ],
          hoverongaps: false,
          text: zValues.map(row => row.map(v => v !== null ? `${v}%` : '')),
          texttemplate: '%{text}',
          textfont: { color: '#ffffff', size: 10 },
          colorbar: { title: 'Rate %', ticksuffix: '%', titlefont: { color: '#e0e0e0' }, tickfont: { color: '#a0a0a0' } },
        }]}
        layout={{
          ...darkLayout,
          title: undefined,
          xaxis: { ...darkLayout.xaxis, tickangle: -45, tickfont: { color: '#a0a0a0', size: 10 } },
          yaxis: { ...darkLayout.yaxis, tickfont: { color: '#a0a0a0', size: 10 } },
          margin: { t: 10, b: 120, l: 200, r: 80 },
        }}
        config={{ displayModeBar: false, responsive: true }}
        style={{ width: '100%', height: '400px' }}
      />
    );
  };

  // Build trend lines by facility
  const buildTrend = () => {
    if (!trendByFacility.data || trendByFacility.data.length === 0) return null;

    const facilities = [...new Set(trendByFacility.data.map((r: any) => r.FACILITY_NAME))];

    const traces = facilities.map((fac, i) => {
      const rows = trendByFacility.data!.filter((r: any) => r.FACILITY_NAME === fac);
      return {
        x: rows.map((r: any) => r.MONTH),
        y: rows.map((r: any) => r.RATE),
        type: 'scatter' as const,
        mode: 'lines+markers' as const,
        name: fac,
        line: { color: COLOR_SEQ[i % COLOR_SEQ.length] },
      };
    });

    return (
      <Plot
        data={traces}
        layout={{
          ...darkLayout,
          title: undefined,
          legend: { font: { color: '#a0a0a0', size: 10 }, orientation: 'h', y: -0.3 },
          margin: { t: 10, b: 80, l: 50, r: 20 },
          yaxis: { ...darkLayout.yaxis, title: 'Readmission Rate %' },
        }}
        config={{ displayModeBar: false, responsive: true }}
        style={{ width: '100%', height: '380px' }}
      />
    );
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Readmissions by Facility & Specialty</h1>
      <p className="text-sm text-gray-600">CMS HRRP drill-down — 30-day readmission rates across facilities and attending specialties</p>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KPICard title="Readmission Rate" value={`${kpi.data?.[0]?.READMIT_RATE}%`} tooltip="30-Day Readmission Rate — percentage of discharges resulting in a readmission within 30 days (CMS HRRP penalty metric)" />
        <KPICard title="Encounters" value={kpi.data?.[0]?.TOTAL_ENCOUNTERS?.toLocaleString()} tooltip="Total encounters included in this analysis (specialty not null)" />
        <KPICard title="Facilities" value={kpi.data?.[0]?.FACILITY_COUNT} tooltip="Number of distinct facilities in the analysis" />
        <KPICard title="Specialties" value={kpi.data?.[0]?.SPECIALTY_COUNT} tooltip="Number of distinct attending specialties in the analysis" />
      </div>

      {/* Full-width heatmap */}
      <ChartCard title="Readmission Rate Heatmap — Facility vs. Specialty">
        {buildHeatmap()}
      </ChartCard>

      {/* Shewhart Control Chart */}
      <ChartCard title="Shewhart Control Chart — 30-Day Readmission Rate (p-chart)">
        {buildControlChart()}
        <p className="text-xs text-gray-500 mt-2">
          Points outside the control limits (red diamonds) indicate statistically unusual variation requiring investigation.
          Limits are calculated per-month based on sample size using the p-chart formula: p̄ ± 3√(p̄(1−p̄)/n).
        </p>
      </ChartCard>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Top 10 Facility + Specialty Combinations">
          {topCombos.data && (
            <Plot
              data={[{
                y: topCombos.data.map((r: any) => r.COMBO),
                x: topCombos.data.map((r: any) => r.RATE),
                type: 'bar',
                orientation: 'h',
                marker: { color: COLORS.danger },
                text: topCombos.data.map((r: any) => `${r.RATE}% (n=${r.N})`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0', size: 10 },
              }]}
              layout={{
                ...darkLayout,
                title: undefined,
                margin: { t: 10, b: 30, l: 280, r: 80 },
                yaxis: { ...darkLayout.yaxis, autorange: 'reversed' },
                xaxis: { ...darkLayout.xaxis, title: 'Readmission Rate %' },
              }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>

        <ChartCard title="Readmission Rate by Facility">
          {byFacility.data && (
            <Plot
              data={[{
                x: byFacility.data.map((r: any) => r.FACILITY_NAME),
                y: byFacility.data.map((r: any) => r.RATE),
                type: 'bar',
                marker: { color: COLOR_SEQ.slice(0, byFacility.data.length) },
                text: byFacility.data.map((r: any) => `${r.RATE}%`),
                textposition: 'outside',
                textfont: { color: '#e0e0e0' },
              }]}
              layout={{
                ...darkLayout,
                title: undefined,
                yaxis: { ...darkLayout.yaxis, title: 'Readmission Rate %' },
                xaxis: { ...darkLayout.xaxis, tickangle: -20 },
              }}
              config={{ displayModeBar: false, responsive: true }}
              style={{ width: '100%', height: '380px' }}
            />
          )}
        </ChartCard>
      </div>

      {/* Full-width trend */}
      <ChartCard title="Monthly Readmission Rate Trend by Facility">
        {buildTrend()}
      </ChartCard>
    </div>
  );
}
