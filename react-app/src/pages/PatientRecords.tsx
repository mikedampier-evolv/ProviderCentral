import DataTable from '../components/DataTable';
import { useSnowflakeQuery } from '../hooks/useSnowflakeQuery';
import { useRole } from '../context/RoleContext';

const roleVisibility = [
  { field: 'Name', clinician: 'Full name', finance: 'PATIENT_<hash>', exec: 'PATIENT_<hash>' },
  { field: 'DOB', clinician: 'Full date', finance: 'Year only', exec: 'Year only' },
  { field: 'SSN', clinician: 'Last 4 (XXX-XX-1234)', finance: '***-**-****', exec: '***-**-****' },
  { field: 'MRN', clinician: 'Full MRN', finance: '***MRN***', exec: '***MRN***' },
  { field: 'Phone', clinician: 'Full number', finance: 'Last 4 only', exec: '**********' },
  { field: 'Email', clinician: 'Full email', finance: 'Domain only', exec: 'Domain only' },
];

export default function PatientRecords() {
  const { role } = useRole();

  const patients = useSnowflakeQuery(
    'phi-demo-patients',
    `SELECT MRN, FIRST_NAME, LAST_NAME, DOB, SSN, PHONE, EMAIL, GENDER, HCC_SCORE
     FROM HOSPITAL_360.CLINICAL.DIM_PATIENT
     WHERE IS_ACTIVE = TRUE
     ORDER BY PATIENT_SK
     LIMIT 25`
  );

  const roleLabel = role.replace('H360_', '');

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Patient Records — PHI Masking Demo</h1>

      {/* Explanation banner */}
      <div className="rounded-lg border border-[#D15635]/30 bg-[#D15635]/5 p-4">
        <p className="text-sm text-gray-700">
          This page demonstrates <strong className="text-gray-900">Snowflake dynamic data masking</strong> policies.
          Switch the <strong className="text-[#D15635]">Role</strong> dropdown in the navigation bar to see how
          patient PHI (Protected Health Information) is masked or revealed based on the active role.
        </p>
        <p className="text-xs text-gray-600 mt-2">
          Current role: <span className="text-[#D15635] font-medium">{roleLabel}</span> — The same query returns different results depending on the Snowflake role executing it.
        </p>
      </div>

      {/* Masking legend */}
      <div>
        <h2 className="text-sm font-semibold text-gray-600 uppercase tracking-wide mb-2">Masking Policy by Role</h2>
        <div className="overflow-x-auto rounded-lg border border-[#D4CFC8]">
          <table className="w-full text-xs text-left">
            <thead className="bg-white text-gray-600 uppercase">
              <tr>
                <th className="px-4 py-2 font-medium">Field</th>
                <th className={`px-4 py-2 font-medium ${role === 'H360_CLINICIAN' ? 'text-[#D15635]' : ''}`}>Clinician</th>
                <th className={`px-4 py-2 font-medium ${role === 'H360_FINANCE' ? 'text-[#D15635]' : ''}`}>Finance</th>
                <th className={`px-4 py-2 font-medium ${role === 'H360_EXEC' ? 'text-[#D15635]' : ''}`}>Executive</th>
              </tr>
            </thead>
            <tbody>
              {roleVisibility.map((row, i) => (
                <tr key={row.field} className={`border-t border-[#D4CFC8] ${i % 2 === 0 ? 'bg-white' : 'bg-[#FAF9F7]'}`}>
                  <td className="px-4 py-2 text-gray-700 font-medium">{row.field}</td>
                  <td className={`px-4 py-2 ${role === 'H360_CLINICIAN' ? 'text-green-600' : 'text-gray-500'}`}>{row.clinician}</td>
                  <td className={`px-4 py-2 ${role === 'H360_FINANCE' ? 'text-yellow-600' : 'text-gray-500'}`}>{row.finance}</td>
                  <td className={`px-4 py-2 ${role === 'H360_EXEC' ? 'text-yellow-600' : 'text-gray-500'}`}>{row.exec}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Patient data table */}
      <div>
        <h2 className="text-sm font-semibold text-gray-600 uppercase tracking-wide mb-2">
          Patient Records <span className="text-gray-600">(as seen by {roleLabel})</span>
        </h2>
        {patients.isLoading ? (
          <div className="text-gray-600 text-sm p-4">Loading patient records...</div>
        ) : patients.error ? (
          <div className="text-red-400 text-sm p-4">
            Error loading data: {String(patients.error)}. This role may not have access to this table.
          </div>
        ) : patients.data && patients.data.length > 0 ? (
          <DataTable
            columns={[
              { key: 'MRN', label: 'MRN' },
              { key: 'FIRST_NAME', label: 'First Name' },
              { key: 'LAST_NAME', label: 'Last Name' },
              { key: 'DOB', label: 'Date of Birth' },
              { key: 'SSN', label: 'SSN' },
              { key: 'PHONE', label: 'Phone' },
              { key: 'EMAIL', label: 'Email' },
              { key: 'GENDER', label: 'Gender' },
              { key: 'HCC_SCORE', label: 'HCC Score' },
            ]}
            data={patients.data}
          />
        ) : (
          <div className="text-gray-500 text-sm p-4">No patient records returned for this role.</div>
        )}
      </div>
    </div>
  );
}
