import { useQuery } from "@tanstack/react-query";
import { executeSQL } from "../lib/snowflake";
import { useRole } from "../context/RoleContext";

export function useSnowflakeQuery(key: string, sql: string, enabled = true) {
  const { role } = useRole();
  return useQuery({
    queryKey: [key, sql, role],
    queryFn: () => executeSQL(sql, role),
    enabled,
    staleTime: 5 * 60 * 1000,
  });
}
