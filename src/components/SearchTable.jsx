import { useState, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import {
  useReactTable,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  flexRender,
} from '@tanstack/react-table'

export default function SearchTable({ 
  data = [], 
  columns = [], 
  queryId,
  onRowDoubleClick, 
  onAdd 
}) {
  console.log('SearchTable render:', { 
    dataLength: data?.length,
    columnCount: columns?.length,
    columns,
    queryId
  })

  const [sorting, setSorting] = useState([])
  const [globalFilter, setGlobalFilter] = useState('')
  const navigate = useNavigate()

  // Memoize the table columns to prevent unnecessary re-renders
  const tableColumns = useMemo(() => {
    // Add edit button column as the first column
    const editColumn = {
      id: 'edit',
      header: '',
      sticky: 'left',
      cell: info => (
        <button 
          className="action-button" 
          title="Edit"
          onClick={() => navigate(`/datarecord/${queryId}/${info.row.original.id}/edit`)}
        >
          ✏️
        </button>
      )
    }

    // Process the remaining columns
    const processedColumns = columns.map(col => {
      // Skip Actions column
      if (col.header === 'Actions') return null

      // Set header to "Active" for is_active column
      const header = col.accessorKey === 'is_active' ? 'Active' : col.header

      return {
        id: col.accessorKey || col.id || col.header,
        header,
        accessorKey: col.accessorKey,
        accessorFn: col.accessorFn,
        cell: typeof col.cell === 'function' 
          ? col.cell 
          : info => {
              const value = info.getValue()
              
              // Handle special columns
              if (col.accessorKey === 'is_active') {
                return (
                  <button 
                    className="action-button" 
                    title={value ? "Active" : "Inactive"}
                    onClick={() => handleToggleStatus(info.row.original)}
                  >
                    {value ? "🟢" : "🔴"}
                  </button>
                )
              }
              
              if (col.accessorKey === 'created_at') {
                return value ? new Date(value).toLocaleDateString() : ''
              }
              
              // Handle objects by converting to string
              if (typeof value === 'object' && value !== null) {
                return JSON.stringify(value)
              }
              
              // Handle all other values
              return value?.toString() || ''
            }
      }
    })
    .filter(col => col !== null && col.header !== 'Status') // Remove null and Status columns

    // Return edit column first, followed by other columns
    return [editColumn, ...processedColumns]
  }, [columns, navigate])

  // Memoize the table instance
  const table = useReactTable({
    data,
    columns: tableColumns,
    state: {
      sorting,
      globalFilter,
    },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  const handleToggleStatus = async (record) => {
    try {
      const { error } = await supabase
        .from('search_queries')
        .update({ is_active: !record.is_active })
        .eq('id', record.id)

      if (error) throw error

      // Refresh the page to show updated data
      window.location.reload()
    } catch (err) {
      console.error('Error toggling status:', err)
      alert('Failed to toggle status')
    }
  }

  if (!data.length || !columns.length) {
    return (
      <div className="search-table empty">
        <p>No data available</p>
        {onAdd && (
          <button 
            onClick={() => navigate(`/datarecord/${queryId}/add`)} 
            className="add-button"
          >
            Add New
          </button>
        )}
      </div>
    )
  }

  return (
    <div className="search-table">
      <div className="search-controls">
        <div className="left-controls">
          {onAdd && (
            <button 
              onClick={() => navigate(`/datarecord/${queryId}/add`)} 
              className="add-button"
            >
              Add New
            </button>
          )}
        </div>
        <div className="right-controls">
          <input
            type="text"
            value={globalFilter ?? ''}
            onChange={e => setGlobalFilter(e.target.value)}
            placeholder="Search all columns..."
            className="search-input"
          />
        </div>
      </div>

      <style>
        {`
          .table-container {
            overflow-x: scroll;
            scrollbar-width: thin;  /* For Firefox */
            scrollbar-color: #888 #f1f1f1;  /* For Firefox */
          }
          
          /* For Webkit browsers (Chrome, Safari) */
          .table-container::-webkit-scrollbar {
            height: 8px;
            width: 8px;
          }
          
          .table-container::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 4px;
          }
          
          .table-container::-webkit-scrollbar-thumb {
            background: #888;
            border-radius: 4px;
          }
          
          .table-container::-webkit-scrollbar-thumb:hover {
            background: #555;
          }
          
          /* Ensure table takes full width */
          .table-container table {
            min-width: 100%;
            width: max-content;
          }
        `}
      </style>

      <div className="table-container">
        <table>
          <thead>
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <th 
                    key={header.id}
                    onClick={header.column.getToggleSortingHandler()}
                    className={`${header.column.getCanSort() ? 'sortable' : ''} ${
                      header.id === 'edit' ? 'sticky-column' : ''
                    }`}
                  >
                    {flexRender(
                      header.column.columnDef.header,
                      header.getContext()
                    )}
                    {{
                      asc: ' 🔼',
                      desc: ' 🔽',
                    }[header.column.getIsSorted()] ?? null}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map(row => (
              <tr 
                key={row.id}
                onDoubleClick={() => onRowDoubleClick && onRowDoubleClick(row.original)}
                className="table-row"
              >
                {row.getVisibleCells().map(cell => (
                  <td 
                    key={cell.id}
                    className={cell.column.id === 'edit' ? 'sticky-column' : ''}
                  >
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>

        <style jsx>{`
          .table-container {
            overflow-x: auto;
            position: relative;
          }

          table {
            width: 100%;
            border-collapse: collapse;
          }

          th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
          }

          th {
            background: #f5f5f5;
            font-weight: 500;
          }

          .sticky-column {
            position: sticky;
            left: 0;
            z-index: 1;
            box-shadow: 2px 0 4px rgba(0, 0, 0, 0.1);
            background: white;
          }

          th.sticky-column {
            z-index: 2;
            background: #f5f5f5;
          }

          tr:hover td {
            background: #f9f9f9;
          }

          tr:hover td.sticky-column {
            background: #f9f9f9;
          }

          /* Add styles for alternating rows if needed */
          tr:nth-child(even) td.sticky-column {
            background: white;
          }

          tr:nth-child(even):hover td.sticky-column {
            background: #f9f9f9;
          }

          .action-button {
            background: none;
            border: none;
            cursor: pointer;
            padding: 4px;
            font-size: 16px;
          }

          .action-button:hover {
            transform: scale(1.1);
          }
        `}</style>
      </div>

      <div className="pagination">
        <button
          onClick={() => table.setPageIndex(0)}
          disabled={!table.getCanPreviousPage()}
        >
          {'<<'}
        </button>
        <button
          onClick={() => table.previousPage()}
          disabled={!table.getCanPreviousPage()}
        >
          {'<'}
        </button>
        <span>
          Page{' '}
          <strong>
            {table.getState().pagination.pageIndex + 1} of{' '}
            {table.getPageCount()}
          </strong>
        </span>
        <button
          onClick={() => table.nextPage()}
          disabled={!table.getCanNextPage()}
        >
          {'>'}
        </button>
        <button
          onClick={() => table.setPageIndex(table.getPageCount() - 1)}
          disabled={!table.getCanNextPage()}
        >
          {'>>'}
        </button>
      </div>
    </div>
  )
} 