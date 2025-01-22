import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import SearchTable from './SearchTable'

export default function DataRecord({ queryId, recordId, mode }) {
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [queryDef, setQueryDef] = useState(null)
  const [formData, setFormData] = useState({})
  const [errors, setErrors] = useState({})
  const navigate = useNavigate()
  const [childQueries, setChildQueries] = useState([])

  // Load query definition and record data
  useEffect(() => {
    let mounted = true
    
    async function loadData() {
      try {
        setLoading(true)
        setError(null)
        console.log('Loading query definition for ID:', queryId)

        // Load query definition
        const { data: queryData, error: queryError } = await supabase
          .from('search_queries')
          .select('*')
          .eq('id', queryId)
          .single()

        if (queryError) throw queryError
        if (!queryData) throw new Error('Query definition not found')
        
        console.log('Query definition loaded:', {
          id: queryData.id,
          base_table: queryData.base_table,
          column_definitions: queryData.column_definitions
        })

        // Load record data if editing
        let recordData = {}
        if (mode === 'edit') {
          console.log('Loading record data for ID:', recordId)
          const { data, error: recordError } = await supabase
            .from(queryData.base_table)
            .select(queryData.query_definition.select || '*')
            .eq('id', recordId)
            .single()

          if (recordError) throw recordError
          if (!data) throw new Error('Record not found')
          recordData = data
          console.log('Record data loaded:', recordData)
        }

        if (mounted) {
          setQueryDef(queryData)
          setFormData(recordData)
          setLoading(false)
        }
      } catch (err) {
        console.error('Error loading data:', err)
        if (mounted) {
          setError(err.message)
          setLoading(false)
        }
      }
    }

    loadData()
    return () => { mounted = false }
  }, [queryId, recordId, mode])

  useEffect(() => {
    async function loadChildQueries() {
      try {
        const { data, error } = await supabase
          .from('search_queries')
          .select('*')
          .eq('parent_query_id', queryId)
          .order('name')

        if (error) throw error
        setChildQueries(data || [])
      } catch (err) {
        console.error('Error loading child queries:', err)
      }
    }

    loadChildQueries()
  }, [queryId])

  const handleInputChange = (field, value) => {
    setErrors(prev => ({ ...prev, [field]: null }))
    
    const column = queryDef.column_definitions.find(col => col.accessorKey === field)
    if (!column) return

    try {
      // Handle different field types based on column definition
      if (column.type === 'boolean' || typeof formData[field] === 'boolean') {
        value = value === 'true'
      } else if (column.type === 'json' || typeof formData[field] === 'object') {
        value = value.trim() ? JSON.parse(value) : null
      } else if (column.type === 'array') {
        value = value.split(',').map(v => v.trim()).filter(Boolean)
      }

      setFormData(prev => ({
        ...prev,
        [field]: value
      }))
    } catch (err) {
      setErrors(prev => ({
        ...prev,
        [field]: `Invalid ${column.type || 'value'} format`
      }))
    }
  }

  const validateForm = () => {
    const newErrors = {}
    
    // Validate only fields from the query definition
    queryDef.column_definitions
      .filter(col => !col.hidden && col.accessorKey !== 'id')
      .forEach(column => {
        const value = formData[column.accessorKey]
        
        // Check required fields
        if (column.required && (value === undefined || value === null || value === '')) {
          newErrors[column.accessorKey] = `${column.header} is required`
        }
        
        // Validate JSON fields
        if ((column.type === 'json' || typeof value === 'object') && value) {
          try {
            if (typeof value === 'string') {
              JSON.parse(value)
            }
          } catch (err) {
            newErrors[column.accessorKey] = 'Invalid JSON format'
          }
        }
      })

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSave = async () => {
    if (!validateForm()) return
    
    setLoading(true)
    try {
      const { data, error } = mode === 'edit'
        ? await supabase
            .from(queryDef.base_table)
            .update(formData)
            .eq('id', recordId)
            .select()
        : await supabase
            .from(queryDef.base_table)
            .insert(formData)
            .select()

      if (error) throw error
      
      // Navigate back to list view
      navigate(`/list/${queryId}`)
    } catch (err) {
      console.error('Save error:', err)
      setErrors(prev => ({ 
        ...prev, 
        submit: err.message.includes('unique constraint') 
          ? 'A record with this name already exists'
          : err.message
      }))
    } finally {
      setLoading(false)
    }
  }

  const handleCancel = () => {
    navigate(`/list/${queryId}`)
  }

  if (loading) {
    return (
      <div className="data-record loading">
        <div className="loading-spinner">Loading...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="data-record error">
        <div className="error-message">
          <h3>Error</h3>
          <p>{error}</p>
          <button onClick={handleCancel}>Back to List</button>
        </div>
      </div>
    )
  }

  if (!queryDef) {
    return (
      <div className="data-record error">
        <div className="error-message">
          <p>No query definition found</p>
          <button onClick={handleCancel}>Back to List</button>
        </div>
      </div>
    )
  }

  return (
    <div className="data-record">
      <div className="data-record-header">
        <h2>{mode === 'add' ? 'Add New Record' : 'Edit Record'}</h2>
        <p>{queryDef.description}</p>
      </div>

      <div className="data-record-content">
        <div className="data-record-main">
          {/* Log the column definitions being used */}
          {console.log('Rendering fields from column definitions:', queryDef.column_definitions)}
          
          {queryDef.column_definitions
            .filter(col => {
              // Only filter out system fields and Actions column
              const shouldRender = col.accessorKey !== 'id' && 
                col.header !== 'Actions' &&
                col.accessorKey !== 'created_at' && 
                col.accessorKey !== 'updated_at'
              
              console.log(`Column ${col.header}: ${shouldRender ? 'rendering' : 'filtered out'}`, col)
              return shouldRender
            })
            .map(column => {
              const error = errors[column.accessorKey]
              const value = formData[column.accessorKey]
              console.log(`Rendering field:`, { header: column.header, type: column.type, value })

              // Special handling for boolean fields
              if (column.type === 'boolean' || typeof value === 'boolean') {
                return (
                  <div key={column.accessorKey} className="form-field">
                    <label>{column.header}</label>
                    <select
                      value={value?.toString() || 'false'}
                      onChange={e => handleInputChange(column.accessorKey, e.target.value)}
                    >
                      <option value="true">Yes</option>
                      <option value="false">No</option>
                    </select>
                    {error && <div className="error-message">{error}</div>}
                  </div>
                )
              }

              // Special handling for date fields
              if (column.type === 'date' || column.accessorKey.includes('_at')) {
                return (
                  <div key={column.accessorKey} className="form-field">
                    <label>{column.header}</label>
                    <input
                      type="date"
                      value={value ? new Date(value).toISOString().split('T')[0] : ''}
                      onChange={e => handleInputChange(column.accessorKey, e.target.value)}
                      className={error ? 'error' : ''}
                    />
                    {error && <div className="error-message">{error}</div>}
                  </div>
                )
              }

              // Special handling for JSON fields
              if (column.type === 'json' || typeof value === 'object') {
                return (
                  <div key={column.accessorKey} className="form-field">
                    <label>{column.header}</label>
                    <textarea
                      value={value ? JSON.stringify(value, null, 2) : ''}
                      onChange={e => handleInputChange(column.accessorKey, e.target.value)}
                      rows={8}
                      className={error ? 'error' : ''}
                    />
                    {error && <div className="error-message">{error}</div>}
                  </div>
                )
              }

              // Special handling for array fields
              if (column.type === 'array') {
                return (
                  <div key={column.accessorKey} className="form-field">
                    <label>{column.header}</label>
                    <input
                      type="text"
                      value={Array.isArray(value) ? value.join(', ') : ''}
                      onChange={e => handleInputChange(column.accessorKey, e.target.value)}
                      className={error ? 'error' : ''}
                      placeholder="Enter values separated by commas"
                    />
                    {error && <div className="error-message">{error}</div>}
                  </div>
                )
              }

              // Default text input for all other fields
              return (
                <div key={column.accessorKey} className="form-field">
                  <label>{column.header}</label>
                  <input
                    type="text"
                    value={value || ''}
                    onChange={e => handleInputChange(column.accessorKey, e.target.value)}
                    className={error ? 'error' : ''}
                    placeholder={column.placeholder || `Enter ${column.header.toLowerCase()}`}
                  />
                  {error && <div className="error-message">{error}</div>}
                </div>
              )
            })}

          {errors.submit && (
            <div className="error-message submit-error">
              {errors.submit}
            </div>
          )}
        </div>

        <div className="data-record-footer">
          <div className="button-group">
            <button onClick={handleSave} disabled={loading}>
              {loading ? 'Saving...' : 'Save'}
            </button>
            <button onClick={handleCancel} disabled={loading}>
              Cancel
            </button>
          </div>
        </div>
      </div>

      {/* Related data tables section */}
      <div className="related-data-sections">
        {mode !== 'add' && !loading && childQueries.map(query => (
          <div key={query.id} className="related-data-section">
            <h3>{query.name}</h3>
            <SearchTable
              queryId={query.id}
              parentRecord={formData}
              onRowDoubleClick={(row) => {
                console.log('Related record clicked:', row)
              }}
            />
          </div>
        ))}
      </div>

      <style jsx>{`
        .data-record {
          display: flex;
          flex-direction: column;
          height: 100%;
          overflow: hidden; /* Prevent double scrollbars */
        }

        .data-record-content {
          flex: 1;
          display: flex;
          flex-direction: column;
          min-height: 400px; /* Important for Firefox */
        }

        .data-record-main {
          flex: 1;
          padding: 20px;
          overflow-y: auto; /* Enable vertical scrolling */
          overflow-x: hidden; /* Hide horizontal scrolling */
        }

        .data-record-footer {
          position: sticky;
          bottom: 0;
          background: white;
          padding: 20px;
          border-top: 1px solid #eee;
          box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
          z-index: 10;
        }

        .related-data-sections {
          overflow-x: auto;
          overflow-y: auto;
          flex: 1;
          padding: 20px;
          border-top: 1px solid #eee;
          background: #f9f9f9;
        }

        .related-data-section {
          margin-bottom: 30px;
        }

        .related-data-section:last-child {
          margin-bottom: 0;
        }

        .related-data-section h3 {
          margin: 0 0 15px 0;
          color: #333;
        }

        .form-field {
          margin-bottom: 20px;
        }

        .form-field label {
          display: block;
          margin-bottom: 8px;
          font-weight: 500;
        }

        .form-field input,
        .form-field select,
        .form-field textarea {
          width: 100%;
          padding: 8px;
          border: 1px solid #ddd;
          border-radius: 4px;
        }

        .form-field textarea {
          font-family: monospace;
          resize: vertical;
        }

        .button-group {
          display: flex;
          gap: 10px;
          justify-content: flex-end;
        }

        .button-group button {
          padding: 8px 16px;
          border: none;
          border-radius: 4px;
          cursor: pointer;
        }

        .button-group button:first-child {
          background: #4CAF50;
          color: white;
        }

        .button-group button:last-child {
          background: #f5f5f5;
          border: 1px solid #ddd;
        }

        .button-group button:disabled {
          opacity: 0.7;
          cursor: not-allowed;
        }
      `}</style>
    </div>
  )
} 