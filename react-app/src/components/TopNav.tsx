import { NavLink } from 'react-router-dom';
import { useRole, ALLOWED_ROLES, type AppRole } from '../context/RoleContext';
import { useQueryClient } from '@tanstack/react-query';

const links = [
  { to: '/dashboard', label: 'Dashboard', desc: 'Provider Dashboard — high-level KPIs and metrics across the provider network' },
  { to: '/readmission', label: 'Readmission', desc: 'Readmission & LOS — 30-day readmission rates and length-of-stay trends' },
  { to: '/readmission-facility', label: 'Readmit Detail', desc: 'Readmissions by Facility & Specialty — CMS HRRP drill-down by facility and attending specialty' },
  { to: '/leakage', label: 'Leakage', desc: 'Patient Leakage — patients referred outside the network and revenue lost' },
  { to: '/or-capacity', label: 'OR Capacity', desc: 'OR Capacity — operating room utilization, scheduling, and throughput' },
  { to: '/staffing', label: 'Staffing', desc: 'Staffing & Quality — staffing levels, quality scores, and workforce analytics' },
  { to: '/financial', label: 'Financial', desc: 'Financial Performance — revenue, cost, margin analysis, and financial trends' },
  { to: '/denials', label: 'Denials', desc: 'Denials & RevCycle — claims denial rates, root causes, and revenue cycle impact' },
  { to: '/predictive', label: 'Predictive', desc: 'Predictive Analytics — ML-driven forecasts for patient volume, risk, and outcomes' },
  { to: '/ops', label: 'Ops', desc: 'Ops Monitor — operational monitoring for system health and data pipelines' },
  { to: '/patient-records', label: 'PHI Demo', desc: 'Patient Records — demonstrates data masking and PHI access control by role' },
  { to: '/build', label: 'Build', desc: 'Build — configuration and development tools for the Provider Central platform' },
];

const roleLabels: Record<AppRole, string> = {
  H360_CLINICIAN: 'Clinician',
  H360_FINANCE: 'Finance',
  H360_EXEC: 'Executive',
};

export default function TopNav() {
  const { role, setRole } = useRole();
  const queryClient = useQueryClient();

  const handleRoleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setRole(e.target.value as AppRole);
    queryClient.invalidateQueries();
  };

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 h-14 bg-[#F0EDE8] border-b border-[#D4CFC8] flex items-center px-6">
      <NavLink to="/" className="flex items-baseline gap-2 text-[#D15635] font-bold text-lg mr-8 whitespace-nowrap">
        <img src="/evolv-logo.webp" alt="Evolv" className="h-4 w-auto self-baseline translate-y-[1px]" />
        Provider Central
      </NavLink>
      <div className="flex gap-1 overflow-x-auto">
        {links.map(({ to, label, desc }) => (
          <NavLink
            key={to}
            to={to}
            title={desc}
            className={({ isActive }) =>
              `px-3 py-1.5 text-sm rounded transition-colors whitespace-nowrap ${
                isActive
                  ? 'text-[#D15635] border-b-2 border-[#D15635]'
                  : 'text-gray-600 hover:text-gray-900'
              }`
            }
          >
            {label}
          </NavLink>
        ))}
      </div>
      <div className="ml-auto flex items-center gap-2">
        <span className="text-xs text-gray-500">Role:</span>
        <select
          value={role}
          onChange={handleRoleChange}
          className="bg-white border border-[#D4CFC8] text-gray-800 text-xs rounded px-2 py-1 focus:outline-none focus:border-[#D15635]"
          title="Switch Snowflake role — controls data masking and access policies"
        >
          {ALLOWED_ROLES.map((r) => (
            <option key={r} value={r}>{roleLabels[r]}</option>
          ))}
        </select>
      </div>
    </nav>
  );
}
