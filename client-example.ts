import { createClient } from "@supabase/supabase-js"

const supabase = createClient(
  'https://ntlxuoqhpzckyvzpmicn.supabase.co',
  process.env.SUPABASE_ANON_KEY || ''
)

const userId = 'f2674567-ae9a-4285-936e-529c8e6f5a3a' // Get from auth context

// UI update functions
const updatePreview = (text: string) => console.log('Preview:', text)
const showError = (error: string) => console.error('Error:', error)

// Request preview
const response = await fetch('/functions/v1/preview-message-realtime', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-user-id': userId
  },
  body: JSON.stringify({
    message_text: 'Hello...',
    customer_id: '...',
    style: 'professional'
  })
})
const data = await response.json()

const previewId = data?.preview_id // Get from preview response

// Subscribe to preview updates
const subscription = supabase
  .channel('preview-updates')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'message_previews',
      filter: `id=eq.${previewId}`
    },
    (payload) => {
      if (payload.new.status === 'completed') {
        // Update UI with preview
        updatePreview(payload.new.preview_text)
      } else if (payload.new.status === 'error') {
        // Show error
        showError(payload.new.error)
      }
    }
  )
  .subscribe()

// Return cleanup function
export async function setupPreviewSubscription(
  messageText: string,
  customerId: string,
  style: string = 'professional',
  onUpdate: (text: string) => void,
  onError: (error: string) => void
) {
  const supabase = createClient(
    'https://ntlxuoqhpzckyvzpmicn.supabase.co',
    process.env.SUPABASE_ANON_KEY || ''
  )

  // Request preview
  const response = await fetch('/functions/v1/preview-message-realtime', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': userId
    },
    body: JSON.stringify({ message_text: messageText, customer_id: customerId, style })
  })
  const data = await response.json()

  // Subscribe to updates
  const subscription = supabase
    .channel('preview-updates')
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'message_previews',
        filter: `id=eq.${data.preview_id}`
      },
      (payload) => {
        if (payload.new.status === 'completed') {
          onUpdate(payload.new.preview_text)
        } else if (payload.new.status === 'error') {
          onError(payload.new.error)
        }
      }
    )
    .subscribe()

  return () => subscription.unsubscribe()
} 