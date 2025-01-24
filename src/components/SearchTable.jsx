import { useState, useEffect, useMemo } from 'react'
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

      if (!currentQueryDef) {
        throw new Error('Query definition not loaded')
      }

      // Get base query
      let query = supabase.from(currentQueryDef.base_table)

      // Add select
      if (currentQueryDef.query_definition.select) {
        query = query.select(currentQueryDef.query_definition.select)
      }

      // Handle where clauses
      let whereClause = currentQueryDef.query_definition.where || {}
      
      // Add parent filter if provided (for child tables)
      if (parentId && parentField) {
        whereClause = {
          ...whereClause,
          [parentField]: parentId
        }
      }

      // Apply where clauses
      if (Object.keys(whereClause).length > 0) {
        for (const [key, value] of Object.entries(whereClause)) {
          if (value === 'auth.uid()') {
            const { data: { user } } = await supabase.auth.getUser()
            query = query.eq(key, user.id)
          } else if (typeof value === 'string' && value.startsWith('(')) {
            // Handle SQL expressions/subqueries
            const { data: { user } } = await supabase.auth.getUser()
            const sqlWithUserId = value.replace('auth.uid()', `'${user.id}'`)
            const { data: subqueryData, error: rpcError } = await supabase.rpc('execute_sql', { 
              sql_query: sqlWithUserId.slice(1, -1)
            })
            if (rpcError) throw new Error(`RPC Error: ${rpcError.message}`)
            if (!subqueryData || !subqueryData[0]) throw new Error('No results from subquery')
            query = query.eq(key, subqueryData[0].result)
          } else {
            query = query.eq(key, value)
          }
        }
      }

      const { data: queryData, error: queryError } = await query
      if (queryError) throw queryError
      setData(queryData)
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

      // If this is a child table (has parent_field), use that for deletion
      if (queryDef.parent_field && queryDef.parent_table) {
        // For junction tables, we need both the parent field and the other key
        const keys = Object.keys(record).filter(key => 
          // Only include actual table fields, not computed or joined fields
          key !== 'created_at' && 
          key !== 'updated_at' &&
          !key.includes(':') && // Exclude joined fields (they have colons)
          !key.includes('_name') && // Exclude computed name fields
          !key.includes('tag_name') && // Specifically exclude tag_name
          !key.includes('user_domain') && // Exclude the problematic field
          record[key] !== null // Exclude null values
        )
        
        console.log('Deleting with keys:', keys.map(k => `${k}: ${record[k]}`))
        
        // Apply each key to the query, with additional null check
        keys.forEach(key => {
          if (record[key] !== null && record[key] !== undefined) {
            query = query.eq(key, record[key])
          }
        })
      } else {
        // Regular table with id column
        query = query.eq('id', record.id)
      }

      const { error } = await query
      if (error) throw error

      // Refresh data after delete
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