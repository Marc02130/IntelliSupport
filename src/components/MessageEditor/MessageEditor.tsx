import { useState, useEffect } from 'react'
import { useSupabase } from '@/lib/supabase'
import { MessagePreview, GenerateMessageRequest } from '@/types'

interface MessageEditorProps {
  ticketId: string
  templateId?: string
  onSend: (message: MessagePreview) => void
  onCancel: () => void
}

export function MessageEditor({ ticketId, templateId, onSend, onCancel }: MessageEditorProps) {
  const [preview, setPreview] = useState<MessagePreview | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { supabase } = useSupabase()

  // Load initial preview
  useEffect(() => {
    const loadPreview = async () => {
      setIsLoading(true)
      setError(null)
      
      try {
        const request: GenerateMessageRequest = {
          ticket_id: ticketId,
          template_id: templateId,
          context: {
            include_history: true,
            include_preferences: true
          }
        }

        const { data, error } = await supabase
          .functions.invoke('preview-message', {
            body: request
          })

        if (error) throw error
        setPreview(data)
      } catch (e) {
        setError(e.message)
      } finally {
        setIsLoading(false)
      }
    }

    loadPreview()
  }, [ticketId, templateId])

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center p-8">
          <LoadingSpinner />
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="p-4 text-red-600 bg-red-50 rounded">
          {error}
        </div>
      )}

      {/* Editor */}
      {preview && (
        <div className="grid grid-cols-3 gap-4">
          {/* Message Content */}
          <div className="col-span-2">
            <MessageContent 
              preview={preview}
              onChange={setPreview}
            />
          </div>

          {/* Context Panel */}
          <div className="col-span-1">
            <ContextPanel 
              context={preview.context}
            />
          </div>

          {/* Actions */}
          <div className="col-span-3 flex justify-end gap-2">
            <button 
              onClick={onCancel}
              className="px-4 py-2 text-gray-600 hover:text-gray-800"
            >
              Cancel
            </button>
            <button
              onClick={() => onSend(preview)}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              Send Message
            </button>
          </div>
        </div>
      )}
    </div>
  )
} 