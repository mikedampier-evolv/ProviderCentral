import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RoleProvider } from './context/RoleContext';
import TopNav from './components/TopNav';
import ChatWidget from './components/ChatWidget';
import ErrorBoundary from './components/ErrorBoundary';
import Home from './pages/Home';
import ProviderDashboard from './pages/ProviderDashboard';
import ReadmissionLOS from './pages/ReadmissionLOS';
import PatientLeakage from './pages/PatientLeakage';
import ORCapacity from './pages/ORCapacity';
import StaffingQuality from './pages/StaffingQuality';
import FinancialPerformance from './pages/FinancialPerformance';
import DenialsRevCycle from './pages/DenialsRevCycle';
import PredictiveAnalytics from './pages/PredictiveAnalytics';
import OpsMonitor from './pages/OpsMonitor';
import Build from './pages/Build';
import PatientRecords from './pages/PatientRecords';
import ReadmissionFacilitySpecialty from './pages/ReadmissionFacilitySpecialty';

const queryClient = new QueryClient();

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <RoleProvider>
        <BrowserRouter>
          <div className="min-h-screen bg-[#F5F2ED] text-gray-900">
            <TopNav />
            <main className="pt-14 px-6 pb-6">
              <ErrorBoundary>
                <Routes>
                  <Route path="/" element={<Home />} />
                  <Route path="/dashboard" element={<ProviderDashboard />} />
                  <Route path="/readmission" element={<ReadmissionLOS />} />
                  <Route path="/leakage" element={<PatientLeakage />} />
                  <Route path="/or-capacity" element={<ORCapacity />} />
                  <Route path="/staffing" element={<StaffingQuality />} />
                  <Route path="/financial" element={<FinancialPerformance />} />
                  <Route path="/denials" element={<DenialsRevCycle />} />
                  <Route path="/predictive" element={<PredictiveAnalytics />} />
                  <Route path="/ops" element={<OpsMonitor />} />
                  <Route path="/patient-records" element={<PatientRecords />} />
                  <Route path="/readmission-facility" element={<ReadmissionFacilitySpecialty />} />
                  <Route path="/build" element={<Build />} />
                </Routes>
              </ErrorBoundary>
            </main>
            <ChatWidget />
          </div>
        </BrowserRouter>
      </RoleProvider>
    </QueryClientProvider>
  );
}
