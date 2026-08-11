import axios from "axios";

export async function executeSQL(sql: string, role?: string): Promise<any[]> {
  const res = await axios.post("/api/sql", { sql, role });
  return res.data.data;
}
