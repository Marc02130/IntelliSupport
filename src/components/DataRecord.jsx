import { useState, useEffect } from 'react'
import { useNavigate, useParams, useLocation } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import SearchTable from './SearchTable'

export default function DataRecord() {
  const { queryId, recordId } = useParams()
  const location = useLocation()
  const mode = recordId ? 'edit' : 'add'
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [queryDef, setQueryDef] = useState(null)
  const [formData, setFormData] = useState({})
  const [errors, setErrors] = useState({})
  const [foreignKeyOptions, setForeignKeyOptions] = useState({})
  const [childQueries, setChildQueries] = useState([])
  const navigate = useNavigate()

  // Get parent context from location state if it exists
  const parentContext = location.state || {}
  const { parentId, parentField, parentQueryId, parentUrl } = parentContext

  // Add this state for JSON validation errors
  const [jsonErrors, setJsonErrors] = useState({})

  // Load query definition and record data
  useEffect(() => {
    let mounted = true
    
    async function loadData() {
      try {
        setLoading(true)
        setError(null)

        // Load query definition
        const { data: queryData, error: queryError } = await supabase
          .from('search_queries')
          .select('*')
          .eq('id', queryId)
          .single()

        if (queryError) throw new Error(`Query definition error: ${queryError.message}`)
        if (!queryData) throw new Error('No query definition found')

        // Load child queries if this is an edit
        if (mode === 'edit') {
          const { data: childQueryData, error: childQueryError } = await supabase
            .from('search_query_relationships')
            .select(`
              child_search_query:search_queries!fk_search_query_relationships_child_search_query(
                id,
                name,
                description,
                base_table,
                parent_table,
                parent_field,
                query_definition,
                column_definitions,
                permissions_required,
                is_active
              )
            `)
            .eq('parent_search_query_id', queryId)

          if (childQueryError) throw new Error(`Child query load error: ${childQueryError.message}`)
          if (childQueryData) {
            // Extract the child query data from the relationships
            const childQueries = childQueryData.map(rel => rel.child_search_query)
            setChildQueries(childQueries)
          }
        }

        // If in edit mode, load the record data
        if (mode === 'edit' && recordId) {
          // Get the fields we need from column definitions, excluding computed fields
          const fields = queryData.column_definitions
            .filter(col => !col.hidden && col.type !== 'computed')
            .map(col => col.accessorKey)
            .filter(Boolean)
            .join(',')

          const { data: recordData, error: recordError } = await supabase
            .from(queryData.base_table)
            .select(fields)
            .eq('id', recordId)
            .single()
            .throwOnError()

          if (!recordData) throw new Error('Record not found')

          if (mounted) {
            setFormData(recordData)
          }
        }

        if (mounted) {
          setQueryDef(queryData)
          setLoading(false)
        }
      } catch (err) {
        console.error('Error in loadData:', err)
        if (mounted) {
          setError(err.message)
          setLoading(false)
        }
      }
    }

    loadData()
    return () => { mounted = false }
  }, [queryId, recordId, mode])

  // Add this effect to load foreign key options
  useEffect(() => {
    if (!queryDef) return

    async function loadForeignKeyOptions() {
      const options = {}
      
      for (const col of queryDef.column_definitions) {
        if (col.foreignKey) {
          const { table, value, label } = col.foreignKey
          console.log('Loading foreign key options:', { table, value, label })
          
          const { data, error } = await supabase
            .from(table)
            .select(`${value}, ${label}`)
            .order(label)

          console.log('Foreign key query result:', { data, error })

          if (!error && data) {
            options[col.accessorKey] = data
          }
        }
      }

      console.log('Final foreign key options:', options)
      setForeignKeyOptions(options)
    }

    loadForeignKeyOptions()
  }, [queryDef])

  const handleInputChange = (field, value, text) => {
    console.log('handleInputChange:', { field, value, text, formDataBefore: formData })
    setErrors(prev => ({ ...prev, [field]: null }))
    
    // If text starts with "Select ", set value to null
    const newValue = text?.startsWith('Select ') ? null : value
    
    setFormData(prev => ({ ...prev, [field]: newValue }))
    console.log('formData after update will be:', { ...formData, [field]: newValue })
  }

  const validateForm = () => {
    const newErrors = {}
    
    queryDef.column_definitions
      .filter(col => col.required)
      .forEach(column => {
        const value = formData[column.accessorKey]
        if (value === undefined || value === null || value === '') {
          newErrors[column.accessorKey] = `${column.header} is required`
        }
      })

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSave = async () => {
    if (!validateForm()) return
    
    setLoading(true)
    try {
      // Only include fields that are defined in column_definitions
      const cleanedData = {}
      queryDef.column_definitions
        .filter(col => !col.hidden && col.type !== 'computed' && col.accessorKey !== 'id')
        .forEach(col => {
          // Get value from form data
          const value = formData[col.accessorKey]
          
          // Handle foreign key fields and empty strings
          if (col.foreignKey && (value === '' || value === undefined || value?.startsWith('Select '))) {
            cleanedData[col.accessorKey] = null
          } else {
            cleanedData[col.accessorKey] = value
          }
        })

      // Add parent relationship if this is a child record
      if (mode === 'add' && parentId && parentField) {
        cleanedData[parentField] = parentId
      }

      // Remove alias fields
      queryDef.column_definitions
        .filter(col => col.foreignKey && col.aliasName)
        .forEach(col => {
          delete cleanedData[col.aliasName]
        })

      console.log('Saving data:', {
        mode,
        table: queryDef.base_table,
        data: cleanedData,
        recordId
      })

      const { data, error } = mode === 'edit'
        ? await supabase
            .from(queryDef.base_table)
            .update(cleanedData)
            .eq('id', recordId)
            .select('id')
        : await supabase
            .from(queryDef.base_table)
            .insert(cleanedData)
            .select('id')

      console.log('Save response:', { data, error })

      if (error) throw error
      if (!data || !data[0]) throw new Error('No data returned from save operation')
      
      // After successful save, navigate back to parent if we have parentUrl
      if (parentUrl) {
        navigate(parentUrl, { replace: true })
      } else {
        navigate(`/list/${queryId}`)
      }
    } catch (err) {
      console.error('Save error:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  // Add this function before renderField
  const isDisabled = (column) => {
    return column.disabled === true || 
           (mode === 'edit' && column.disableOnEdit) || 
           (mode === 'add' && column.disableOnAdd);
  };

  const renderField = (column) => {
    // Only add disabled prop if it's explicitly true
    const disabledProps = column.disabled === true ? {
      disabled: true,
      className: 'disabled'
    } : {}

    // Handle foreign key fields with select dropdown
    if (column.foreignKey) {
      const options = foreignKeyOptions[column.accessorKey] || []
      return (
        <select
          value={formData[column.accessorKey] || ''}
          onChange={(e) => handleInputChange(
            column.accessorKey, 
            e.target.value,
            e.target.options[e.target.selectedIndex].text
          )}
          {...disabledProps}
        >
          <option>Select {column.header}</option>
          {options.map(option => (
            <option 
              key={option[column.foreignKey.value]} 
              value={option[column.foreignKey.value]}
            >
              {option[column.foreignKey.label]}
            </option>
          ))}
        </select>
      )
    }

    // Handle select/enum fields using column.options from query definition
    if (column.type === 'select' && Array.isArray(column.options)) {
      return (
        <select
          value={formData[column.accessorKey] || ''}
          onChange={(e) => handleInputChange(column.accessorKey, e.target.value, e.target.options[e.target.selectedIndex].text)}
          {...disabledProps}
        >
          <option value="">Select {column.header}</option>
          {column.options.map(option => (
            <option key={option} value={option}>
              {option.charAt(0).toUpperCase() + option.slice(1)}
            </option>
          ))}
        </select>
      )
    }

    // Handle boolean fields
    if (column.type === 'boolean') {
      return (
        <select
          value={formData[column.accessorKey] || ''}
          onChange={(e) => handleInputChange(column.accessorKey, e.target.value === 'true', e.target.options[e.target.selectedIndex].text)}
          {...disabledProps}
        >
          <option value="">Select</option>
          <option value="true">Yes</option>
          <option value="false">No</option>
        </select>
      )
    }

    // Handle date/time fields
    if (column.type === 'datetime') {
      return (
        <input
          type="datetime-local"
          value={formData[column.accessorKey] || ''}
          onChange={(e) => handleInputChange(column.accessorKey, e.target.value)}
          {...disabledProps}
        />
      )
    }

    // Add special handling for JSON type fields
    if (column.type === 'json') {
      return (
        <div>
          <textarea
            id={column.accessorKey}
            name={column.accessorKey}
            value={formData[column.accessorKey] ? JSON.stringify(formData[column.accessorKey], null, 2) : ''}
            onChange={(e) => {
              try {
                // Try to parse as JSON to validate
                const jsonValue = e.target.value ? JSON.parse(e.target.value) : null;
                handleInputChange(column.accessorKey, jsonValue);
                // Clear error if parse succeeds
                setJsonErrors(prev => ({ ...prev, [column.accessorKey]: null }));
              } catch (err) {
                // Store the error message
                const errorMessage = `Invalid JSON: ${err.message}`;
                setJsonErrors(prev => ({ ...prev, [column.accessorKey]: errorMessage }));
                // Store the raw input
                handleInputChange(column.accessorKey, e.target.value);
              }
            }}
            className={`mt-1 block w-full rounded-md shadow-sm focus:ring-indigo-500 sm:text-sm dark:bg-gray-700 
              ${jsonErrors[column.accessorKey] 
                ? 'border-red-500 focus:border-red-500' 
                : 'border-gray-300 focus:border-indigo-500'}`}
            rows={10}
            disabled={isDisabled(column)}
          />
          {jsonErrors[column.accessorKey] && (
            <div className="text-red-500 text-sm mt-1">
              {jsonErrors[column.accessorKey]}
            </div>
          )}
        </div>
      );
    }

    // Default text input
    return (
      <input
        type="text"
        value={formData[column.accessorKey] || ''}
        onChange={(e) => handleInputChange(column.accessorKey, e.target.value)}
        {...disabledProps}
      />
    )
  }

  if (loading) return <div>Loading...</div>
  if (error) return <div className="error-message">{error}</div>
  if (!queryDef) return <div>No query definition found</div>

  return (
    <div className="data-record">
      <h2>{mode === 'add' ? 'Add New Record' : 'Edit Record'}</h2>
      
      <div className="form">
        {queryDef.column_definitions
          .filter(col => 
            !col.hidden && 
            col.accessorKey !== 'id' && 
            col.type !== 'computed'  // Ignore all computed fields
          )
          .map(column => (
            <div key={column.accessorKey} className="form-field">
              <label>
                {column.header}
                {column.required && <span className="required">*</span>}
              </label>
              
              {renderField(column)}
              
              {errors[column.accessorKey] && (
                <div className="error-message">{errors[column.accessorKey]}</div>
              )}
            </div>
          ))}

        {errors.submit && (
          <div className="error-message">{errors.submit}</div>
        )}

        <div className="button-group">
          <button onClick={handleSave} disabled={loading}>
            {loading ? 'Saving...' : 'Save'}
          </button>
          <button onClick={() => parentUrl ? navigate(parentUrl) : navigate(`/list/${queryId}`)}>
            Cancel
          </button>
        </div>
      </div>

      {/* Add child tables section */}
      {mode === 'edit' && childQueries.length > 0 && (
        <div className="child-tables">
          {childQueries.map(childQuery => (
            <div key={childQuery.id} className="child-table">
              <h3>{childQuery.name}</h3>
              <SearchTable 
                queryId={childQuery.id} 
                parentId={recordId}
                parentField={childQuery.parent_field}
                parentQueryId={queryId}
              />
            </div>
          ))}
        </div>
      )}

      <style>
        {`
          .data-record {
            padding: 20px;
            width: 100%;
          }

          .form {
            width: 100%;
            max-width: 1200px;
            margin: 0 auto;
          }

          .form-field {
            margin-bottom: 20px;
            width: 100%;
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

          .form-field .error {
            border-color: red;
          }

          .error-message {
            color: red;
            font-size: 12px;
            margin-top: 4px;
          }

          .required {
            color: red;
            margin-left: 4px;
          }

          .button-group {
            margin-top: 20px;
            display: flex;
            gap: 10px;
          }

          .button-group button {
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
          }

          .button-group button:first-child {
            background: #4CAF50;
            color: white;
            border: none;
          }

          .button-group button:last-child {
            background: #f5f5f5;
            border: 1px solid #ddd;
          }

          .disabled {
            background-color: #f5f5f5;
            cursor: not-allowed;
            opacity: 0.7;
          }

          .child-tables {
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid #ddd;
          }

          .child-table {
            margin-bottom: 2rem;
          }

          .child-table h3 {
            margin-bottom: 1rem;
          }
        `}
      </style>
    </div>
  )
} 