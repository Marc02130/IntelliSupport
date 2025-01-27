import { useState, useEffect } from 'react'
import { useNavigate, useParams, useLocation } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import SearchTable from './SearchTable'
import CommentTemplateSelector from './CommentTemplateSelector'
import JSONEditor from 'react-json-editor-ajrm/es'
import locale from 'react-json-editor-ajrm/locale/en'
import AttachmentsTab from './AttachmentsTab'

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
  const [activeTab, setActiveTab] = useState('details')

  // Get parent context from location state if it exists
  const parentContext = location.state || {}
  const { parentId, parentField, parentQueryId, parentUrl } = parentContext

  // Add this state for JSON validation errors
  const [jsonErrors, setJsonErrors] = useState({})

  // Add state for template selector modal
  const [showTemplateSelector, setShowTemplateSelector] = useState(false)
  const [activeSelectorField, setActiveSelectorField] = useState(null)

  // Load query definition and record data
  useEffect(() => {
    let mounted = true
    
    async function loadData() {
      try {
        setLoading(true)
        
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
            const childQueries = childQueryData.map(rel => rel.child_search_query)
            setChildQueries(childQueries)
          }
        }

        // If in edit mode, load the record data
        if (mode === 'edit' && recordId) {
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
        } else if (mode === 'add' && parentId && parentField) {
          // Initialize form data with parent context for child records
          setFormData({
            [parentField]: parentId
          })
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
  }, [queryId, recordId, mode, parentId, parentField])

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
      // Debug logging
      console.log('Form data before save:', formData)
      console.log('Query definition:', queryDef)

      // Only include fields that are defined in column_definitions
      const cleanedData = {}
      queryDef.column_definitions
        .filter(col => !col.hidden && col.type !== 'computed' && col.accessorKey !== 'id')
        .forEach(col => {
          // Get value from form data
          const value = formData[col.accessorKey]
          
          // Debug logging
          console.log(`Processing field ${col.accessorKey}:`, value)
          
          // Handle foreign key fields and empty strings
          if (value === '') {
            cleanedData[col.accessorKey] = null
          } else {
            cleanedData[col.accessorKey] = value
          }
        })

      // Debug logging
      console.log('Cleaned data for save:', cleanedData)

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

  // Add function to handle template selection
  const handleTemplateSelect = (template) => {
    if (activeSelectorField) {
      // Append template to existing content or set as new content
      const currentContent = formData[activeSelectorField] || '';
      const newContent = currentContent ? `${currentContent}\n\n${template.content}` : template.content;
      
      // Update the content
      handleInputChange(activeSelectorField, newContent);
      
      // If template is private, set the is_private field to true
      if (template.is_private) {
        handleInputChange('is_private', true);
      }
      
      setShowTemplateSelector(false);
    }
  };

  const renderField = (column) => {
    // Special handling for ticket comments content field
    if (queryDef.base_table === 'ticket_comments' && column.accessorKey === 'content') {
      return (
        <div className="relative">
          <textarea
            id={column.accessorKey}
            name={column.accessorKey}
            value={formData[column.accessorKey] || ''}
            onChange={(e) => handleInputChange(column.accessorKey, e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-gray-700 dark:border-gray-600"
            rows={5}
            disabled={isDisabled(column)}
          />
          <button
            type="button"
            onClick={() => {
              setActiveSelectorField(column.accessorKey);
              setShowTemplateSelector(true);
            }}
            className="absolute top-2 right-2 px-2 py-1 text-sm bg-indigo-500 text-white rounded hover:bg-indigo-600 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            📝 Templates
          </button>
          
          {/* Template selector modal */}
          {showTemplateSelector && activeSelectorField === column.accessorKey && (
            <div className="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50">
              <div className="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-lg w-full mx-4">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-lg font-medium">Select Template</h3>
                  <button
                    onClick={() => setShowTemplateSelector(false)}
                    className="text-gray-500 hover:text-gray-700"
                  >
                    ✕
                  </button>
                </div>
                <CommentTemplateSelector 
                  onSelect={(template) => handleTemplateSelect(template)} 
                />
              </div>
            </div>
          )}
        </div>
      );
    }

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
      const jsonValue = formData[column.accessorKey] || {};
      
      return (
        <div>
          <JSONEditor
            id={column.accessorKey}
            placeholder={jsonValue}
            locale={locale}
            height="200px"
            width="100%"
            onBlur={(value) => {
              if (value.error) {
                setJsonErrors(prev => ({ 
                  ...prev, 
                  [column.accessorKey]: value.error.reason 
                }));
              } else {
                try {
                  const parsedJson = value.jsObject || null;
                  handleInputChange(column.accessorKey, parsedJson);
                  setJsonErrors(prev => ({ 
                    ...prev, 
                    [column.accessorKey]: null 
                  }));
                } catch (err) {
                  setJsonErrors(prev => ({ 
                    ...prev, 
                    [column.accessorKey]: `Invalid JSON: ${err.message}` 
                  }));
                }
              }
            }}
            viewOnly={isDisabled(column)}
            theme="light_mitsuketa_tribute"
            colors={{
              default: '#000000',
              background: '#ffffff',
              background_warning: '#fef3c7',
              string: '#22863a',
              number: '#005cc5',
              colon: '#000000',
              keys: '#d73a49',
              keys_whiteSpace: '#af00db',
              primitive: '#6f42c1'
            }}
            style={{
              container: {
                borderRadius: '0.375rem',
                border: jsonErrors[column.accessorKey] 
                  ? '2px solid #ef4444' 
                  : '1px solid #d1d5db'
              },
              body: {
                fontSize: '0.875rem'
              }
            }}
          />
          {jsonErrors[column.accessorKey] && (
            <div className="text-red-500 text-sm mt-1">
              {jsonErrors[column.accessorKey]}
            </div>
          )}
        </div>
      );
    }

    // Add handling for template selector
    if (column.templateSelector) {
      return (
        <div>
          <textarea
            id={column.accessorKey}
            name={column.accessorKey}
            value={formData[column.accessorKey] || ''}
            onChange={(e) => handleInputChange(column.accessorKey, e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-gray-700 dark:border-gray-600"
            rows={5}
            disabled={isDisabled(column)}
          />
          <div className="mt-2">
            <CommentTemplateSelector 
              onSelect={(template) => handleTemplateSelect(template)} 
            />
          </div>
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
      
      {mode === 'edit' && (
        <div className="tabs">
          <button 
            className={`tab ${activeTab === 'details' ? 'active' : ''}`}
            onClick={() => setActiveTab('details')}
          >
            Details
          </button>
          {childQueries.length > 0 && (
            <button 
              className={`tab ${activeTab === 'related' ? 'active' : ''}`}
              onClick={() => setActiveTab('related')}
            >
              Related Items
            </button>
          )}
          <button 
            className={`tab ${activeTab === 'attachments' ? 'active' : ''}`}
            onClick={() => setActiveTab('attachments')}
          >
            Attachments
          </button>
        </div>
      )}

      {/* Show form always in add mode, or when in details tab for edit mode */}
      {(mode === 'add' || activeTab === 'details') && (
        <div className="form">
          {queryDef.column_definitions
            .filter(col => 
              !col.hidden && 
              col.accessorKey !== 'id' && 
              col.type !== 'computed'
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
      )}

      {/* Only show these in edit mode */}
      {mode === 'edit' && (
        <>
          {activeTab === 'related' && childQueries.length > 0 && (
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

          {activeTab === 'attachments' && (
            <AttachmentsTab recordId={recordId} type="ticket" />
          )}
        </>
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

          .tabs {
            display: flex;
            gap: 1rem;
            padding: 1rem;
            border-bottom: 1px solid #ddd;
          }
          .tab {
            padding: 0.5rem 1rem;
            border: none;
            background: none;
            cursor: pointer;
            font-size: 1rem;
            color: #666;
          }
          .tab.active {
            color: #000;
            border-bottom: 2px solid #000;
          }
          .tab:hover {
            color: #000;
          }
        `}
      </style>
    </div>
  )
} 