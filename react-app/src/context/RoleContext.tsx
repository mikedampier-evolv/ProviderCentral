import { createContext, useContext, useState, type ReactNode } from 'react';

export const ALLOWED_ROLES = [
  'H360_CLINICIAN',
  'H360_FINANCE',
  'H360_EXEC',
] as const;

export type AppRole = (typeof ALLOWED_ROLES)[number];

interface RoleContextValue {
  role: AppRole;
  setRole: (role: AppRole) => void;
}

const RoleContext = createContext<RoleContextValue | undefined>(undefined);

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<AppRole>('H360_CLINICIAN');
  return (
    <RoleContext.Provider value={{ role, setRole }}>
      {children}
    </RoleContext.Provider>
  );
}

export function useRole() {
  const ctx = useContext(RoleContext);
  if (!ctx) throw new Error('useRole must be used within RoleProvider');
  return ctx;
}
