import { Link } from 'react-router-dom';
import DataTable from '../components/DataTable';

const dataSources = [
  { source: 'Epic EHR', data: 'ADT events, orders, diagnoses, procedures, scheduling, referrals, OpTime surgical cases' },
  { source: 'Workday ERP', data: 'General Ledger transactions, cost center accounting' },
  { source: 'Kronos HR', data: 'Timekeeping, shift schedules, labor hours by employee' },
  { source: 'Payer EDI', data: '837I/837P claim submissions, 835 electronic remittance advice' },
  { source: 'Supply Chain', data: 'Item master, purchase orders, supply usage by encounter' },
  { source: 'Active Directory', data: 'Login events, access logs, user authentication activity' },
  { source: 'RTLS / IoT', data: 'Real-time bed status changes, patient location tracking' },
  { source: 'Snowflake Marketplace', data: 'NPPES provider registry, CMS reference data, SDoH indices, Census demographics' },
];

const pages = [
  { to: '/dashboard', label: 'Provider Dashboard', desc: 'High-level KPIs across all domains', sources: 'Epic EHR, Payer EDI, Workday ERP, Kronos HR' },
  { to: '/readmission', label: 'Readmission & LOS', desc: 'Which DRGs and facilities drive readmission penalties?', sources: 'Epic EHR (ADT, DRG Grouper, Registration)' },
  { to: '/leakage', label: 'Patient Leakage', desc: 'Where are patients leaving the network and how much revenue is lost?', sources: 'Epic EHR (Referrals, Scheduling, Provider Directory)' },
  { to: '/or-capacity', label: 'OR Capacity', desc: 'Which OR blocks are underutilized and where are delays?', sources: 'Epic EHR (OpTime, Provider Directory)' },
  { to: '/staffing', label: 'Staffing & Quality', desc: 'Do understaffed units have higher readmission rates?', sources: 'Kronos HR + Epic EHR (Labor Hours + Encounters)' },
  { to: '/financial', label: 'Financial Performance', desc: 'What is our cost structure and where are the margin opportunities?', sources: 'Workday ERP (GL) + Epic EHR (Encounters, DRG)' },
  { to: '/denials', label: 'Denials & Rev Cycle', desc: 'What are the top denial categories and recovery opportunities?', sources: 'Payer EDI (835/837) + Epic EHR (Claims, Provider)' },
  { to: '/predictive', label: 'Predictive Analytics', desc: 'ML forecasts, anomaly detection, and key drivers', sources: 'Cortex ML (Forecast, Anomaly, Contribution Explorer)' },
  { to: '/ops', label: 'Ops Monitor', desc: 'Platform health, data quality, and pipeline status', sources: 'Snowflake Metadata (Information Schema)' },
];

export default function Home() {
  return (
    <div className="max-w-5xl mx-auto space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Provider Central — Demo Overview</h1>
        <p className="text-gray-600 mt-2">
          A hospital analytics dashboard powered by Snowflake, Cortex AI, and React.
        </p>
      </div>

      <section>
        <h2 className="text-xl font-semibold text-gray-900 mb-3">Data Sources</h2>
        <DataTable
          columns={[
            { key: 'source', label: 'Source System' },
            { key: 'data', label: 'Data Provided' },
          ]}
          data={dataSources}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold text-gray-900 mb-3">Platform Architecture</h2>
        <ul className="list-disc list-inside text-gray-700 space-y-1 text-sm">
          <li><strong>Ingestion:</strong> Snowflake Dynamic Tables (bronze → silver → gold) with incremental refresh</li>
          <li><strong>Curated Layer:</strong> <code>HOSPITAL360_CUR</code> — star-schema marts for each use case</li>
          <li><strong>ML Layer:</strong> <code>HOSPITAL360_ML</code> — Cortex ML forecasting, anomaly detection, classification</li>
          <li><strong>App Layer:</strong> <code>HOSPITAL360_APP</code> — React frontend, Provider Chat (Cortex Agent)</li>
          <li><strong>Compute:</strong> Container Runtime on <code>SYSTEM_COMPUTE_POOL_CPU</code> with PyPI access</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold text-gray-900 mb-3">Pages</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {pages.map(({ to, label, desc, sources }) => (
            <Link
              key={to}
              to={to}
              className="block p-4 rounded-lg border border-[#D4CFC8] bg-white hover:border-[#D15635] transition-colors"
            >
              <div className="text-gray-900 font-medium text-sm">{label}</div>
              <div className="text-gray-600 text-xs mt-1">{desc}</div>
              <div className="text-[#D15635] text-xs mt-2 opacity-75">{sources}</div>
            </Link>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold text-gray-900 mb-3">Glossary of Abbreviations</h2>
        <DataTable
          columns={[
            { key: 'abbr', label: 'Abbreviation' },
            { key: 'term', label: 'Full Term' },
          ]}
          data={[
            { abbr: 'ADT', term: 'Admission, Discharge, Transfer — the core hospital patient-movement system' },
            { abbr: 'ASA', term: 'American Society of Anesthesiologists — physical status classification (I–VI)' },
            { abbr: 'CPT', term: 'Current Procedural Terminology — standardized codes for medical procedures' },
            { abbr: 'CMS', term: 'Centers for Medicare & Medicaid Services — federal payer and DRG authority' },
            { abbr: 'DRG', term: 'Diagnosis-Related Group — patient classification for hospital reimbursement' },
            { abbr: 'DX', term: 'Diagnosis' },
            { abbr: 'ED', term: 'Emergency Department' },
            { abbr: 'EHR', term: 'Electronic Health Record' },
            { abbr: 'ETL', term: 'Extract, Transform, Load — data pipeline pattern' },
            { abbr: 'FTE', term: 'Full-Time Equivalent — staffing measurement' },
            { abbr: 'GL', term: 'General Ledger — accounting transaction record' },
            { abbr: 'HCC', term: 'Hierarchical Condition Category — CMS risk-adjustment score (higher = sicker)' },
            { abbr: 'ICD-10', term: 'International Classification of Diseases, 10th Revision — diagnosis code set' },
            { abbr: 'LOS', term: 'Length of Stay — days from admission to discharge' },
            { abbr: 'MDC', term: 'Major Diagnostic Category — top-level DRG grouping (e.g., nervous system, respiratory)' },
            { abbr: 'ML', term: 'Machine Learning' },
            { abbr: 'MRN', term: 'Medical Record Number — unique patient identifier within a health system' },
            { abbr: 'MS-DRG', term: 'Medicare Severity Diagnosis-Related Group — CMS severity-adjusted DRG' },
            { abbr: 'NPI', term: 'National Provider Identifier — 10-digit unique physician/facility ID' },
            { abbr: 'OR', term: 'Operating Room' },
            { abbr: 'PHI', term: 'Protected Health Information — HIPAA-regulated patient data' },
            { abbr: 'PII', term: 'Personally Identifiable Information' },
            { abbr: 'SDoH', term: 'Social Determinants of Health — non-clinical factors (housing, income, education)' },
            { abbr: 'SK', term: 'Surrogate Key — synthetic primary key in dimensional modeling' },
            { abbr: '835', term: 'HIPAA X12 835 transaction — electronic remittance advice from payers' },
            { abbr: '837I/837P', term: 'HIPAA X12 837 Institutional/Professional — electronic claim submissions' },
          ]}
        />
      </section>
    </div>
  );
}
