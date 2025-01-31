import React from 'react'
import { useOutletContext } from 'react-router-dom'
import { SupabaseClient } from '@supabase/supabase-js'

interface OutletContext {
  session: any
  supabase: SupabaseClient
}

interface Message {
  text: string
  customerId: string
  style?: string
}

interface BatchEditorProps {
  messages: Message[]
  setPreviewResults: (results: any[]) => void
  setError: (error: string) => void
}

const BatchEditor: React.FC<BatchEditorProps> = ({ 
  messages, 
  setPreviewResults, 
  setError 
}) => {
  const { supabase } = useOutletContext<OutletContext>()

  const handleGenerate = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const batchId = crypto.randomUUID()
      
      // Ensure messages array exists and has items
      if (!messages || messages.length === 0) {
        throw new Error('No messages to process')
      }

      const payload = {
        messages: messages.map(msg => ({
          message_text: msg.text,
          customer_id: msg.customerId,
          style: msg.style || undefined // Only include if defined
        })),
        batch_id: batchId
      }

      console.log('Sending request payload:', payload)

      const { data, error } = await supabase.functions.invoke('preview-message-batch', {
        body: payload,
        headers: {
          Authorization: `Bearer ${session?.access_token}`,
          'Content-Type': 'application/json',
        }
      })

      if (error) throw error
      console.log('Response:', data)
      
      if (data?.success) {
        setPreviewResults(data.results)
      } else {
        throw new Error(data?.error || 'Failed to generate previews')
      }

    } catch (error) {
      console.error('Error generating messages:', error)
      setError(error.message)
    }
  }

  return (
    <div>
      <button onClick={handleGenerate}>
        Generate Previews
      </button>
    </div>
  )
}

export default BatchEditor 