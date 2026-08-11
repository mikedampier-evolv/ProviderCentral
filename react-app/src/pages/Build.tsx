import { useState } from 'react';

const phases = [
  {
    number: '01',
    title: 'Infrastructure & Data Foundation',
    description: 'Cortex Code scaffolded the entire Snowflake data platform — 5 databases (medallion architecture), 4 warehouses, governance roles, and 22 SQL scripts.',
    details: [
      'Created HOSPITAL360_RAW, _INT, _CUR, _ML, _APP databases',
      'Built 10 dimension tables and 12 fact tables with synthetic data',
      'Generated 5M+ rows using Snowflake GENERATOR() functions',
      'Applied object tagging, masking policies, and row-access policies',
    ],
    tech: 'Snowflake SQL DDL → Seed Scripts → Governance Policies',
    prompt: '"Set up a full Hospital 360 demo environment with medallion architecture, synthetic data, and governance."',
    color: '#D15635',
  },
  {
    number: '02',
    title: 'Use-Case Marts',
    description: 'For each clinical/financial use case, Cortex Code designed the mart schema, wrote the INSERT logic joining multiple source tables, and seeded realistic data.',
    details: [
      'MART_READMISSION_LOS — FCT_ENCOUNTER + 6 dimension tables',
      'MART_PATIENT_LEAKAGE — FCT_REFERRAL + patient/provider dims',
      'MART_OR_CAPACITY — FCT_OR_CASE + provider/facility/CPT dims',
      'MART_DENIALS_REVCYCLE — FCT_CLAIM_LINE + payer/provider/DX dims',
      'MART_STAFFING_QUALITY — FCT_LABOR_HOUR + FCT_ENCOUNTER (cross-source)',
      'MART_FINANCIAL_PERFORMANCE — FCT_GL_TRANSACTION + encounter volume',
    ],
    tech: 'Star Schema Design → Complex JOINs → Window Functions → Date Spine',
    prompt: '"Is there a good use case for combining clinical data and labor data from Workday?"',
    color: '#10B981',
  },
  {
    number: '03',
    title: 'ML & Predictive Layer',
    description: 'Cortex Code built feature views and called Snowflake Cortex ML functions to generate predictions — all in SQL, no external infrastructure.',
    details: [
      'FORECAST — 90-day encounter volume prediction by type',
      'DETECT_ANOMALIES — denial volume anomaly detection',
      'CONTRIBUTION_EXPLORER — readmission & leakage drivers',
      'Feature views aggregate mart data into ML-ready shapes',
    ],
    tech: 'Cortex ML Functions → Feature Views → Prediction Tables',
    prompt: '"Add ML forecasting for encounter volume and anomaly detection for denials."',
    color: '#F59E0B',
  },
  {
    number: '04',
    title: 'Semantic View & Cortex Agent',
    description: 'A unified semantic view was created spanning all marts, enabling natural-language queries via Cortex Agent.',
    details: [
      'Semantic view with 6 logical tables, verified queries, and custom instructions',
      'Cortex Agent configured with text-to-SQL tool',
      'Guardrails: column-to-table mapping prevents cross-table errors',
      'SSE streaming for real-time thinking and response',
    ],
    tech: 'Semantic View DDL → Cortex Agent Config → REST API Integration',
    prompt: '"Create a Cortex Agent that can answer natural language questions across all our data."',
    color: '#7C3AED',
  },
  {
    number: '05',
    title: 'Streamlit Application',
    description: 'Cortex Code built a 10-page Streamlit app deployed on Snowflake Container Runtime — iteratively fixing charts, queries, and styling.',
    details: [
      '10 interactive pages with Plotly charts and dark theme',
      'Provider Chat page with SSE streaming to Cortex Agent',
      'Global filters propagated via session state',
      'Deployed to Snowflake with Container Runtime + PyPI access',
    ],
    tech: 'Streamlit → Plotly → Container Runtime → Snowflake Stage Deploy',
    prompt: '"Deploy the updated app to Snowflake." / "The heatmap on OR Capacity isn\'t rendering."',
    color: '#EC4899',
  },
  {
    number: '06',
    title: 'React Application (This App)',
    description: 'Cortex Code built this React frontend with the same data, charts, and chatbot — using a completely different tech stack in parallel.',
    details: [
      'Vite + React + TypeScript scaffolded and configured',
      'Flask proxy server for Snowflake SQL API (PAT auth)',
      'Custom Plotly component (ref-based, React 19 compatible)',
      'Floating chatbot with SSE streaming + Vega-Lite chart rendering',
      'All pages ported with correct SQL queries',
      'Iterative debugging of column names, data types, and chart rendering',
    ],
    tech: 'Vite → React → Flask → Snowflake REST API → Plotly → Vega-Lite',
    prompt: '"Create a React UI with top navigation and a floating chatbot."',
    color: '#EF4444',
  },
];

const stats = [
  { label: 'SQL Scripts Generated', value: '22' },
  { label: 'Data Rows Created', value: '5M+' },
  { label: 'Streamlit Pages', value: '10' },
  { label: 'React Pages', value: '11' },
  { label: 'Marts Built', value: '6' },
  { label: 'ML Models', value: '4' },
];

export default function Build() {
  const [activePhase, setActivePhase] = useState(0);
  const phase = phases[activePhase];

  return (
    <div className="max-w-5xl mx-auto space-y-10">
      {/* Header */}
      <div className="text-center py-8">
        <h1 className="text-3xl font-bold text-gray-900">Built with Cortex Code</h1>
        <p className="text-gray-600 mt-3 max-w-2xl mx-auto">
          This entire application — from Snowflake infrastructure to React frontend — was
          constructed through conversational AI using Snowflake's Cortex Code CLI.
          Step through each phase to see how it was built.
        </p>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        {stats.map(({ label, value }) => (
          <div key={label} className="text-center p-4 rounded-lg border border-[#D4CFC8] bg-white">
            <div className="text-2xl font-bold text-[#D15635]">{value}</div>
            <div className="text-xs text-gray-600 mt-1">{label}</div>
          </div>
        ))}
      </div>

      {/* Progress bar */}
      <div className="space-y-3">
        <div className="flex items-center gap-1">
          {phases.map((p, i) => (
            <button
              key={p.number}
              onClick={() => setActivePhase(i)}
              className="flex-1 h-2 rounded-full transition-all duration-300"
              style={{
                backgroundColor: i <= activePhase ? p.color : '#333',
                opacity: i === activePhase ? 1 : i < activePhase ? 0.6 : 0.3,
              }}
              title={p.title}
            />
          ))}
        </div>
        <div className="flex justify-between text-xs text-gray-500">
          <span>Phase 01</span>
          <span>Phase 0{phases.length}</span>
        </div>
      </div>

      {/* Active phase display */}
      <div
        className="rounded-xl border bg-[#FAF9F7] p-8 transition-all duration-500"
        style={{ borderColor: `${phase.color}40` }}
      >
        {/* Phase badge + title */}
        <div className="flex items-center gap-3 mb-4">
          <span
            className="text-sm font-bold px-3 py-1 rounded-full"
            style={{ backgroundColor: `${phase.color}20`, color: phase.color }}
          >
            PHASE {phase.number}
          </span>
          <h2 className="text-2xl font-bold text-gray-900">{phase.title}</h2>
        </div>

        {/* Description */}
        <p className="text-gray-700 mb-6">{phase.description}</p>

        {/* Two-column: details + prompt */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Details */}
          <div>
            <h4 className="text-xs uppercase tracking-wide text-gray-500 mb-2">What was built</h4>
            <ul className="space-y-2">
              {phase.details.map((d, i) => (
                <li key={i} className="text-sm text-gray-700 flex items-start gap-2">
                  <span style={{ color: phase.color }} className="mt-0.5">●</span>
                  {d}
                </li>
              ))}
            </ul>
          </div>

          {/* Prompt + tech */}
          <div className="space-y-4">
            <div>
              <h4 className="text-xs uppercase tracking-wide text-gray-500 mb-2">Example prompt</h4>
              <div className="bg-white border border-[#D4CFC8] rounded-lg p-3 text-sm text-gray-700 italic">
                {phase.prompt}
              </div>
            </div>
            <div>
              <h4 className="text-xs uppercase tracking-wide text-gray-500 mb-2">Tech stack</h4>
              <div className="text-sm text-gray-600">{phase.tech}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Navigation buttons */}
      <div className="flex justify-between items-center">
        <button
          onClick={() => setActivePhase(Math.max(0, activePhase - 1))}
          disabled={activePhase === 0}
          className="px-5 py-2 rounded-lg border border-[#D4CFC8] text-gray-700 text-sm hover:border-gray-500 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
        >
          ← Previous
        </button>
        <span className="text-sm text-gray-500">
          {activePhase + 1} of {phases.length}
        </span>
        <button
          onClick={() => setActivePhase(Math.min(phases.length - 1, activePhase + 1))}
          disabled={activePhase === phases.length - 1}
          className="px-5 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
          style={{ backgroundColor: `${phase.color}20`, color: phase.color, borderColor: `${phase.color}40` }}
        >
          Next →
        </button>
      </div>

      {/* Architecture Flow */}
      <div className="rounded-lg border border-[#D4CFC8] bg-[#FAF9F7] p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Architecture Flow</h2>
        <div className="flex flex-wrap items-center justify-center gap-2 text-xs">
          {[
            { label: 'Source Systems', sub: 'Epic, Workday, Kronos, EDI', color: '#D15635' },
            { label: '→', sub: '', color: '' },
            { label: 'Snowflake RAW', sub: 'Bronze Layer', color: '#6B7280' },
            { label: '→', sub: '', color: '' },
            { label: 'Snowflake CUR', sub: 'Gold Marts', color: '#10B981' },
            { label: '→', sub: '', color: '' },
            { label: 'Cortex ML', sub: 'Predictions', color: '#F59E0B' },
            { label: '→', sub: '', color: '' },
            { label: 'React + Flask', sub: 'This App', color: '#EF4444' },
          ].map((item, i) =>
            item.sub === '' ? (
              <span key={i} className="text-gray-600 text-lg">→</span>
            ) : (
              <div
                key={i}
                className="px-3 py-2 rounded border text-center min-w-[100px]"
                style={{ borderColor: `${item.color}50`, backgroundColor: `${item.color}10` }}
              >
                <div style={{ color: item.color }} className="font-medium">{item.label}</div>
                <div className="text-gray-500 mt-0.5">{item.sub}</div>
              </div>
            )
          )}
        </div>
      </div>

      {/* How it worked */}
      <div className="rounded-lg border border-[#D4CFC8] bg-[#FAF9F7] p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">How Cortex Code Built This</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 rounded-lg bg-white border border-[#D4CFC8]">
            <div className="text-2xl mb-2">💬</div>
            <h4 className="text-sm font-medium text-gray-900 mb-1">Conversational</h4>
            <p className="text-xs text-gray-600">
              Every feature was requested in natural language. "Build a staffing quality use case combining Kronos labor data with clinical outcomes."
            </p>
          </div>
          <div className="p-4 rounded-lg bg-white border border-[#D4CFC8]">
            <div className="text-2xl mb-2">🔄</div>
            <h4 className="text-sm font-medium text-gray-900 mb-1">Iterative</h4>
            <p className="text-xs text-gray-600">
              Charts not rendering? Wrong column names? Cortex Code debugged in real-time — testing queries, fixing types, adjusting margins.
            </p>
          </div>
          <div className="p-4 rounded-lg bg-white border border-[#D4CFC8]">
            <div className="text-2xl mb-2">⚡</div>
            <h4 className="text-sm font-medium text-gray-900 mb-1">Full-Stack</h4>
            <p className="text-xs text-gray-600">
              From CREATE DATABASE to npm run dev — infrastructure, data engineering, ML, Streamlit, and React all in one conversation.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
