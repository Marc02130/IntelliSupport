import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { API_ENDPOINTS } from '../lib/config'
import {
  useReactTable,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  flexRender,
} from '@tanstack/react-table'

export default function SearchTable({ queryId, parentId = null, parentField = null, parentQueryId = null }) {
  const [queryDef, setQueryDef] = useState(null)
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [sorting, setSorting] = useState([])
  const [globalFilter, setGlobalFilter] = useState('')
  const navigate = useNavigate()

  // Determine if we're in a child table context
  const isChildTable = Boolean(parentId && parentField)

  // Load query definition and data
  useEffect(() => {
    async function init() {
      try {
        setLoading(true)
        // First get the query definition
        const { data: queryData, error: queryError } = await supabase
          .from('search_queries')
          .select('*')
          .eq('id', queryId)
          .single()

        if (queryError) throw queryError
        setQueryDef(queryData)
        
        // Now load the data using our loadData function with the query definition
        await loadData(queryData)
      } catch (err) {
        console.error('Error initializing:', err)
        setError(err.message)
      }
    }

    init()
  }, [queryId])

  // Load data based on query definition
  const loadData = async (currentQueryDef) => {
    try {
      setLoading(true)
      setError(null)

      // Get the current session
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) throw new Error('No session')

      const response = await fetch(API_ENDPOINTS.SEARCH_TABLE, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
          'x-user-id': session.user.id
        },
        body: JSON.stringify({
          queryId,
          filters: {},
          parentId,
          parentField
        })
      })

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.message || 'Failed to fetch data')
      }

      const { data: queryData, queryDef: newQueryDef } = await response.json()
      setData(queryData)
      if (!currentQueryDef) {
        setQueryDef(newQueryDef)
      }

    } catch (err) {
      console.error('Error loading data:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  // Handle navigation to add/edit
  const handleNavigation = (path, recordId = null) => {
    if (isChildTable) {
      // For child tables, we want to return to the parent page
      const parentUrl = `/datarecord/edit/${parentQueryId}/${parentId}`

      if (recordId) {
        // Edit - include parent context
        navigate(`/datarecord/edit/${queryId}/${recordId}`, {
          state: {
            parentId,
            parentField,
            parentQueryId,
            parentUrl  // This will be used to navigate back to parent page
          }
        })
      } else {
        // Add new - include parent context
        navigate(`/datarecord/add/${queryId}`, {
          state: {
            parentId,
            parentField,
            parentQueryId,
            parentUrl  // This will be used to navigate back to parent page
          }
        })
      }
    } else {
      // Regular list view navigation
      navigate(recordId ? `/datarecord/edit/${queryId}/${recordId}` : `/datarecord/add/${queryId}`)
    }
  }

  // Modify the Add New button to use the new navigation
  const handleAddNew = () => {
    handleNavigation(`/datarecord/add/${queryId}`)
  }

  // Add delete function
  const handleDelete = async (record) => {
    try {
      let query = supabase.from(queryDef.base_table).delete()

      // Get the column definitions that are actual table fields (not computed/joined)
      const tableColumns = queryDef.column_definitions.filter(col => 
        !col.hidden && 
        !col.type?.includes('computed') &&
        col.accessorKey // Must have an accessor key
      )

      // Use the accessorKey values to build the delete query
      tableColumns.forEach(col => {
        const value = record[col.accessorKey]
        if (value !== null && value !== undefined) {
          query = query.eq(col.accessorKey, value)
        }
      })

      const { error } = await query
      if (error) throw error

      await loadData(queryDef)
    } catch (err) {
      console.error('Error deleting record:', err)
      setError(err.message)
    }
  }

  // Modify getColumns to pass the entire record to handleDelete
  const getColumns = (queryDef) => {
    if (!queryDef) return []
    
    return [
      {
        id: 'actions',
        header: '',
        accessorKey: 'id',
        cell: info => (
          <div className="action-buttons">
            <button
              className="edit-button"
              onClick={() => handleNavigation(`/datarecord/edit/${queryId}/${info.getValue()}`, info.getValue())}
            >
              Edit
            </button>
            {isChildTable && (
              <button
                className="delete-button"
                onClick={() => handleDelete(info.row.original)}  // Pass entire record
              >
                Delete
              </button>
            )}
          </div>
        ),
        size: isChildTable ? 100 : 50,
      },
      // Add other columns
      ...queryDef.column_definitions
        .filter(col => !col.hidden)
        .map(col => {
          // Base column definition
          const column = {
            header: col.header,
            accessorKey: col.accessorKey,
          }

          // Handle different field types
          column.cell = info => {
            let value = info.getValue()

            // If foreign key with alias, use the alias value
            if (col.foreignKey && col.aliasName) {
              const aliasValue = info.row.original[col.aliasName]
              value = aliasValue?.[col.foreignKey.label] || ''
            }

            // Handle computed fields
            if (col.type === 'computed') {
              // Use aliasName if provided to get the computed value
              if (col.aliasName) {
                value = info.row.original[col.aliasName]
              }

              switch (col.computedType) {
                case 'count':
                  // Handle various count value formats
                  if (Array.isArray(value)) {
                    return value.length
                  }
                  if (typeof value === 'object' && value !== null) {
                    return value.count || 0
                  }
                  return value || 0
                
                case 'array':
                  // For array fields (like tags)
                  if (Array.isArray(value)) {
                    return value.join(', ')
                  }
                  // Handle case where value is an object with nested arrays
                  if (value && typeof value === 'object') {
                    const tags = Object.values(value).flat()
                    return tags.join(', ')
                  }
                  return ''
                
                default:
                  return value || ''
              }
            }

            // Format based on type
            if (col.type === 'boolean') {
              return value ? '✓' : '✗'
            }

            if (col.type === 'datetime') {
              return value ? new Date(value).toLocaleString() : ''
            }

            // Handle JSONB columns
            if (typeof value === 'object' && value !== null) {
              return JSON.stringify(value)
            }

            return value || ''
          }

          return column
        })
    ]
  }

  const columns = useMemo(() => getColumns(queryDef), [queryDef])

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  })

  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error}</div>

  return (
    <div className="table-container">
      <div className="table-header">
        <button 
          className="add-button"
          onClick={handleAddNew}
        >
          Add New
        </button>
      </div>

      <div className="table-scroll">
        <table>
          <thead>
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <th 
                    key={header.id}
                    className={header.column.id === 'actions' ? 'sticky-col' : ''}
                  >
                    {flexRender(
                      header.column.columnDef.header,
                      header.getContext()
                    )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map(row => (
              <tr key={row.id}>
                {row.getVisibleCells().map(cell => (
                  <td 
                    key={cell.id}
                    className={cell.column.id === 'actions' ? 'sticky-col' : ''}
                  >
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <style jsx>{`
        .table-container {
          display: flex;
          flex-direction: column;
          height: 100%;
        }

        .table-header {
          padding: 16px;
          background: white;
          border-bottom: 1px solid #eee;
          display: flex;
          justify-content: flex-end;
          position: sticky;
          top: 0;
          z-index: 2;
        }

        .table-scroll {
          overflow: auto;
          flex: 1;
        }

        table {
          width: 100%;
          border-collapse: collapse;
        }

        thead {
          position: sticky;
          top: 0;
          z-index: 1;
          background: white;
        }

        th, td {
          padding: 12px;
          text-align: left;
          border-bottom: 1px solid #ddd;
        }

        th {
          background-color: #f5f5f5;
          font-weight: 500;
        }

        .sticky-col {
          position: sticky;
          left: 0;
          background: white;
          z-index: 1;
          box-shadow: 2px 0 4px rgba(0,0,0,0.1);
        }

        thead .sticky-col {
          background: #f5f5f5;
        }

        .add-button, .edit-button {
          padding: 8px 16px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 14px;
        }

        .add-button {
          background: #4CAF50;
          color: white;
          border: none;
        }

        .edit-button {
          background: #2196F3;
          color: white;
          border: none;
        }

        .add-button:hover {
          background: #45a049;
        }

        .edit-button:hover {
          background: #1976D2;
        }

        .action-buttons {
          display: flex;
          gap: 8px;
        }

        .delete-button {
          padding: 8px 16px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 14px;
          background: #dc3545;
          color: white;
          border: none;
        }

        .delete-button:hover {
          background: #c82333;
        }
      `}</style>
    </div>
  )
} 