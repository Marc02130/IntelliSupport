import React, { Dispatch, SetStateAction } from 'react'
import { useOutletContext } from 'react-router-dom'
import { SupabaseClient } from '@supabase/supabase-js'

interface Template {
  id: string
  template_text: string
  context_type: string
  metadata: Record<string, any>
}

interface TemplateSelectorProps {
  onSelect: (template: Template | null) => void | Dispatch<SetStateAction<Template | null>>
  selectedId?: string
}

interface ContextType {
  session: any
  supabase: SupabaseClient
}

export function TemplateSelector({ onSelect, selectedId }: TemplateSelectorProps) {
  const [templates, setTemplates] = React.useState<Template[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const { session, supabase } = useOutletContext<ContextType>()

  React.useEffect(() => {
    const fetchTemplates = async () => {
      try {
        const { data, error } = await supabase
          .from('message_templates')
          .select('*')
          .order('created_at', { ascending: false })

        if (error) throw error
        setTemplates(data || [])
      } catch (err) {
        console.error('Error fetching templates:', err)
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    if (session) {
      fetchTemplates()
    }
  }, [session])

  if (loading) {
    return <div className="animate-pulse">Loading templates...</div>
  }

  if (error) {
    return <div className="text-red-500">Error: {error}</div>
  }

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-medium">Select Template</h2>
      <div className="grid grid-cols-1 gap-2">
        {templates.map((template) => (
          <button
            key={template.id}
            onClick={() => onSelect(template)}
            className={`p-4 text-left border rounded-lg transition-colors ${
              selectedId === template.id
                ? 'border-blue-500 bg-blue-50'
                : 'border-gray-200 hover:border-blue-300'
            }`}
          >
            <div className="font-medium">{template.context_type}</div>
            <div className="text-sm text-gray-600 mt-1 line-clamp-2">
              {template.template_text}
            </div>
          </button>
        ))}
      </div>
    </div>
  )
} 