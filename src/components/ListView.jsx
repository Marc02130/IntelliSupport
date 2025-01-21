import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabaseClient'
import SearchTable from './SearchTable'
import DataRecord from './DataRecord'

export default function ListView({ queryId, onRecordSelect }) {
  const [queryDef, setQueryDef] = useState(null)
  const [data, setData] = useState([])
  const [selectedRecord, setSelectedRecord] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Log when component mounts with queryId
  console.log('ListView mounted with queryId:', queryId)

  // Load query definition
  useEffect(() => {
    let mounted = true
    console.log('ListView useEffect triggered with queryId:', queryId)
    
    async function loadData() {
      if (!queryId) {
        console.error('No queryId provided')
        setError('No query ID provided')
        setLoading(false)
        return
      }
      
      try {
        setLoading(true)
        setError(null)
        console.log('Loading query definition for ID:', queryId)
        
        // Load query definition with error logging
        const queryResult = await supabase
          .from('search_queries')
          .select('*')
          .eq('id', queryId)
          .single()
        
        console.log('Raw query result:', queryResult)

        if (queryResult.error) {
          console.error('Database error:', queryResult.error)
          throw new Error(`Database error: ${queryResult.error.message}`)
        }

        const queryData = queryResult.data
        console.log('Query definition loaded:', queryData)

        if (!queryData) {
          throw new Error('No query definition found')
        }

        // Validate column definitions
        if (!queryData.column_definitions) {
          console.error('No column_definitions in query data:', queryData)
          throw new Error('Query definition missing column definitions')
        }

        if (!Array.isArray(queryData.column_definitions)) {
          console.error('column_definitions is not an array:', queryData.column_definitions)
          throw new Error('Invalid column definitions format')
        }

        // Process column definitions
        const processedColumns = queryData.column_definitions.map(col => ({
          ...col,
          id: col.accessorKey || col.id || col.header
        }))
        console.log('Processed columns:', processedColumns)

        // Load the actual data with error logging
        let dataQuery = supabase.from(queryData.base_table)
        console.log('Building data query for table:', queryData.base_table)
        
        if (queryData.query_definition.select) {
          console.log('Adding select:', queryData.query_definition.select)
          dataQuery = dataQuery.select(queryData.query_definition.select)
        }
        
        if (queryData.query_definition.orderBy) {
          console.log('Adding order by:', queryData.query_definition.orderBy)
          for (const order of queryData.query_definition.orderBy) {
            dataQuery = dataQuery.order(order.id, { ascending: !order.desc })
          }
        }

        const dataResult = await dataQuery
        console.log('Raw data result:', dataResult)

        if (dataResult.error) {
          console.error('Data query error:', dataResult.error)
          throw new Error(`Data query error: ${dataResult.error.message}`)
        }

        const recordData = dataResult.data
        console.log('Data loaded successfully:', recordData)

        if (mounted) {
          setQueryDef({
            ...queryData,
            column_definitions: processedColumns
          })
          setData(recordData || [])
          setLoading(false)
          setError(null)
        }
      } catch (err) {
        console.error('Error in loadData:', err)
        if (mounted) {
          setError(err.message || 'An unexpected error occurred')
          setLoading(false)
          setData([])
          setQueryDef(null)
        }
      }
    }

    loadData()
    return () => { mounted = false }
  }, [queryId])

  const handleRowDoubleClick = (row) => {
    setSelectedRecord(row)
  }

  const handleSave = async (updatedRecord) => {
    setSelectedRecord(null)
  }

  const handleCancel = () => {
    setSelectedRecord(null)
  }

  const handleAdd = () => {
    setSelectedRecord({})
  }

  if (loading) {
    return (
      <div className="list-view loading">
        <div className="loading-spinner">Loading...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="list-view error">
        <div className="error-message">
          <h3>Error Loading Data</h3>
          <p>{error}</p>
          <button onClick={() => setLoading(true)}>Retry</button>
        </div>
      </div>
    )
  }

  if (!queryDef || !data) {
    return (
      <div className="list-view error">
        <div className="error-message">
          <p>No data available</p>
        </div>
      </div>
    )
  }

  // Debug column definitions in detail
  console.log('Query Definition:', {
    baseTable: queryDef.base_table,
    rawColumns: queryDef.column_definitions,
    processedColumns: queryDef.column_definitions.map(col => ({
      header: col.header,
      accessorKey: col.accessorKey,
      id: col.id,
      cell: col.cell
    }))
  })

  return (
    <div className="list-view">
      {selectedRecord ? (
        <DataRecord
          tableName={queryDef.base_table}
          record={selectedRecord}
          columns={queryDef.column_definitions}
          relatedTables={queryDef.related_tables}
          onSave={handleSave}
          onCancel={handleCancel}
        />
      ) : (
        <SearchTable
          data={data}
          columns={queryDef.column_definitions}
          queryId={queryId}
          onRowDoubleClick={handleRowDoubleClick}
          onAdd={handleAdd}
        />
      )}
    </div>
  )
} 