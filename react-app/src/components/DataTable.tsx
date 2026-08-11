interface DataTableProps {
  columns: { key: string; label: string }[];
  data: any[];
}

export default function DataTable({ columns, data }: DataTableProps) {
  return (
    <div className="overflow-x-auto rounded-lg border border-[#D4CFC8]">
      <table className="w-full text-sm text-left">
        <thead className="bg-[#E8E4DE] text-gray-600 uppercase text-xs">
          <tr>
            {columns.map((col) => (
              <th key={col.key} className="px-4 py-3 font-medium">
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row, i) => (
            <tr
              key={i}
              className={`border-t border-[#E8E4DE] ${i % 2 === 0 ? 'bg-white' : 'bg-[#FAF9F7]'}`}
            >
              {columns.map((col) => (
                <td key={col.key} className="px-4 py-2.5 text-gray-700">
                  {row[col.key] ?? '—'}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
