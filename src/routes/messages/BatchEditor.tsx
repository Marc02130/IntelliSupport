import React from 'react'
import { useState, useEffect } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { MessagePreview, Template } from '../../types/message-editor'
import { useMessageValidation } from '../../hooks/useMessageValidation'
import { TemplateSelector } from '../../components/MessageEditor/TemplateSelector'
import { MessageEditor } from '../../components/MessageEditor'
import { SupabaseClient } from '@supabase/supabase-js'

interface Ticket {
  id: string
  subject: string
  status: string
  created_at: string
  customer_id: string
}

interface ErrorState {
  type: 'generation' | 'sending' | 'loading' | null
  message: string
}

interface PreviewStatus {
  id: string
  status: 'pending' | 'generating' | 'completed' | 'failed'
  error?: string
  progress?: {
    step: string
    percent: number
  }
}

interface OutletContext {
  session: any
  supabase: SupabaseClient
}

export default function BatchEditor() {
  const [selectedTickets, setSelectedTickets] = useState<string[]>([])
  const [tickets, setTickets] = useState<Ticket[]>([])
  const [previews, setPreviews] = useState<MessagePreview[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<ErrorState | null>(null)
  const [selectedPreview, setSelectedPreview] = useState<MessagePreview | null>(null)
  const { isValid, errors } = useMessageValidation(selectedPreview)
  const navigate = useNavigate()
  const { session, supabase } = useOutletContext<OutletContext>()
  const [sending, setSending] = useState(false)
  const [batchSending, setBatchSending] = useState(false)
  const [sentCount, setSentCount] = useState(0)
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null)
  const [isGenerating, setIsGenerating] = useState(false)
  const [loadingTickets, setLoadingTickets] = useState(true)
  const [previewStatuses, setPreviewStatuses] = useState<Record<string, PreviewStatus>>({})
  const [previewSubscription, setPreviewSubscription] = useState<any>(null)
  const [realtimeSubscription, setRealtimeSubscription] = useState<any>(null)
  const [editingPreview, setEditingPreview] = useState<MessagePreview | null>(null)
  const [editedContent, setEditedContent] = useState('')
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    if (!session) return

    const fetchTickets = async () => {
      try {
        setLoadingTickets(true)
        const { data, error } = await supabase
          .from('tickets')
          .select('*')
          .eq('status', 'open')
          .order('created_at', { ascending: false })

        if (error) throw error
        setTickets(data || [])
      } catch (err) {
        setError({ type: 'loading', message: err.message })
      } finally {
        setLoadingTickets(false)
      }
    }

    fetchTickets()
  }, [session])

  useEffect(() => {
    return () => {
      if (previewSubscription) {
        previewSubscription.unsubscribe()
      }
      if (realtimeSubscription) {
        realtimeSubscription.unsubscribe()
      }
    }
  }, [previewSubscription, realtimeSubscription])

  const handleGenerate = async () => {
    if (selectedTickets.length === 0) return
    
    setIsGenerating(true)
    setError(null)
    setPreviews([])
    
    const initialStatuses: Record<string, PreviewStatus> = {}
    selectedTickets.forEach(id => {
      initialStatuses[id] = { id, status: 'pending' }
    })
    setPreviewStatuses(initialStatuses)
    
    try {
      const { data, error } = await supabase.functions.invoke('preview-message-batch', {
        body: { 
          ticket_ids: selectedTickets,
          template_id: selectedTemplate?.id
        }
      })
      
      if (error) throw error
      
      // Subscribe to realtime updates
      const realtime = supabase
        .channel(`realtime-${data.batch_id}`)
        .on('broadcast', { event: 'generation_progress' }, payload => {
          const { ticket_id, step, percent } = payload
          setPreviewStatuses(prev => ({
            ...prev,
            [ticket_id]: {
              ...prev[ticket_id],
              status: 'generating',
              progress: { step, percent }
            }
          }))
        })
        .subscribe()
      
      setRealtimeSubscription(realtime)

      const subscription = supabase
        .channel(`preview-${data.batch_id}`)
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'message_previews',
          filter: `batch_id=eq.${data.batch_id}`
        }, payload => {
          const preview = payload.new as MessagePreview
          setPreviews(prev => [...prev, preview])
          setPreviewStatuses(prev => ({
            ...prev,
            [preview.ticket_id]: { 
              id: preview.ticket_id,
              status: 'completed'
            }
          }))
        })
        .on('postgres_changes', {
          event: 'UPDATE',
          schema: 'public',
          table: 'message_generation_logs',
          filter: `batch_id=eq.${data.batch_id}`
        }, payload => {
          if (payload.new.status === 'failed') {
            setPreviewStatuses(prev => ({
              ...prev,
              [payload.new.ticket_id]: {
                id: payload.new.ticket_id,
                status: 'failed',
                error: payload.new.error_message
              }
            }))
          }
        })
        .subscribe()
      
      setPreviewSubscription(subscription)
    } catch (err) {
      setError({ type: 'generation', message: err.message })
    } finally {
      setIsGenerating(false)
    }
  }

  const handleSend = async () => {
    if (!selectedPreview || !isValid) return
    
    setSending(true)
    try {
      const { error } = await supabase.functions.invoke('api-send-message', {
        body: {
          message_id: selectedPreview.id,
          customer_id: selectedPreview.ticket_id,
          channel: 'email'
        }
      })
      
      if (error) throw error
      
      // Remove sent preview from list
      setPreviews(previews.filter(p => p.id !== selectedPreview.id))
      setSelectedPreview(null)
    } catch (err) {
      setError({ type: 'sending', message: err.message })
    } finally {
      setSending(false)
    }
  }

  const handleBatchSend = async () => {
    if (previews.length === 0) return
    
    setBatchSending(true)
    setSentCount(0)
    
    try {
      // Send messages in batches of 5
      const batchSize = 5
      for (let i = 0; i < previews.length; i += batchSize) {
        const batch = previews.slice(i, i + batchSize)
        
        await Promise.all(batch.map(async (preview) => {
          try {
            const { error } = await supabase.functions.invoke('api-send-message', {
              body: {
                message_id: preview.id,
                customer_id: preview.ticket_id,
                channel: 'email'
              }
            })
            
            if (error) throw error
            setSentCount(count => count + 1)
          } catch (err) {
            console.error(`Failed to send message ${preview.id}:`, err)
          }
        }))
      }
      
      // Clear previews after sending
      setPreviews([])
      setSelectedPreview(null)
    } catch (err) {
      setError({ type: 'sending', message: err.message })
    } finally {
      setBatchSending(false)
    }
  }

  const handleEditStart = (preview: MessagePreview) => {
    setEditingPreview(preview)
    setEditedContent(preview.content)
  }

  const handleEditCancel = () => {
    setEditingPreview(null)
    setEditedContent('')
  }

  const handleEditSave = async () => {
    if (!editingPreview) return
    
    setIsSaving(true)
    try {
      const { data, error } = await supabase.functions.invoke('api-edit-message', {
        body: {
          message_id: editingPreview.id,
          content: editedContent,
          metadata: {
            ...editingPreview.metadata,
            edited: true
          }
        }
      })

      if (error) throw error

      // Update preview in list
      setPreviews(prev => prev.map(p => 
        p.id === editingPreview.id 
          ? { ...p, content: editedContent, metadata: { ...p.metadata, edited: true } }
          : p
      ))
      
      setEditingPreview(null)
      setEditedContent('')
    } catch (err) {
      setError({ type: 'generation', message: 'Failed to save edited message: ' + err.message })
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-semibold text-gray-900 mb-6">
        Batch Message Generation
      </h1>

      {error && error.type && (
        <div className={`mb-4 p-4 rounded-md ${
          error.type === 'generation' ? 'bg-red-50 text-red-600' :
          error.type === 'sending' ? 'bg-orange-50 text-orange-600' :
          'bg-yellow-50 text-yellow-600'
        }`}>
          <div className="font-medium">
            {error.type === 'generation' ? 'Generation Failed' :
             error.type === 'sending' ? 'Sending Failed' :
             'Loading Error'}
          </div>
          <div className="mt-1 text-sm">{error.message}</div>
        </div>
      )}

      {/* Ticket Selection */}
      {loadingTickets ? (
        <div className="flex justify-center p-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
      ) : (
        <div className="mb-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-medium">Select Tickets</h2>
            <span className="text-sm text-gray-600">
              {selectedTickets.length} tickets selected
            </span>
          </div>

          <div className="space-y-2">
            {tickets.map(ticket => (
              <label
                key={ticket.id}
                className="flex items-center p-3 bg-white rounded-lg border hover:border-blue-500 cursor-pointer"
              >
                <input
                  type="checkbox"
                  checked={selectedTickets.includes(ticket.id)}
                  onChange={(e) => {
                    if (e.target.checked) {
                      setSelectedTickets([...selectedTickets, ticket.id])
                    } else {
                      setSelectedTickets(selectedTickets.filter(id => id !== ticket.id))
                    }
                  }}
                  className="mr-3"
                />
                <div>
                  <h3 className="font-medium">{ticket.subject}</h3>
                  <p className="text-sm text-gray-600">
                    Created: {new Date(ticket.created_at).toLocaleDateString()}
                  </p>
                </div>
              </label>
            ))}
          </div>
        </div>
      )}
      
      {/* Template Selection */}
      <div className="mb-6">
        <TemplateSelector
          onSelect={setSelectedTemplate}
          selectedId={selectedTemplate?.id}
        />
      </div>
      
      {/* Preview Section */}
      {(previews.length > 0 || Object.keys(previewStatuses).length > 0) && (
        <div className="mt-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-medium">Generated Messages</h2>
            <div className="text-sm text-gray-600">
              {previews.length} / {Object.keys(previewStatuses).length} Generated
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            {Object.values(previewStatuses)
              .filter(status => status.status === 'pending' || status.status === 'generating')
              .map(status => (
                <div key={status.id} className="p-4 border rounded-lg border-gray-200">
                  <div className="flex flex-col space-y-2">
                    {status.progress ? (
                      <>
                        <div className="flex justify-between text-sm text-gray-600">
                          <span>{status.progress.step}</span>
                          <span>{Math.round(status.progress.percent)}%</span>
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div 
                            className="bg-blue-600 h-2 rounded-full transition-all duration-500"
                            style={{ width: `${status.progress.percent}%` }}
                          />
                        </div>
                      </>
                    ) : (
                      <div className="flex items-center space-x-2">
                        <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600" />
                        <span className="text-sm text-gray-600">Starting generation...</span>
                      </div>
                    )}
                  </div>
                </div>
              ))
            }
            {previews.map((preview, index) => (
              <div 
                key={preview.id}
                className={`p-4 border rounded-lg ${
                  selectedPreview?.id === preview.id ? 'border-blue-500' : 'border-gray-200'
                }`}
              >
                <div className="flex justify-between mb-2">
                  <span className="text-sm font-medium">Message {index + 1}</span>
                  <div className="flex items-center gap-2">
                    {preview.metadata?.edited && (
                      <span className="text-xs text-gray-500">(Edited)</span>
                    )}
                    {preview.style_feedback && (
                      <span className="text-sm text-gray-600">
                        Style Match: {Math.round(preview.style_feedback.tone_match * 100)}%
                      </span>
                    )}
                  </div>
                </div>
                {editingPreview?.id === preview.id ? (
                  <div className="space-y-3">
                    <textarea
                      value={editedContent}
                      onChange={(e) => setEditedContent(e.target.value)}
                      className="w-full h-32 p-2 text-sm border rounded-md focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
                      placeholder="Edit message..."
                    />
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={handleEditCancel}
                        className="px-3 py-1 text-sm text-gray-600 hover:text-gray-800"
                        disabled={isSaving}
                      >
                        Cancel
                      </button>
                      <button
                        onClick={handleEditSave}
                        disabled={isSaving || editedContent === preview.content}
                        className="px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700
                                 disabled:bg-gray-300 disabled:cursor-not-allowed"
                      >
                        {isSaving ? 'Saving...' : 'Save'}
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="group relative">
                    <p className="text-sm text-gray-600">{preview.content}</p>
                    <button
                      onClick={() => handleEditStart(preview)}
                      className="absolute top-0 right-0 p-1 text-gray-400 hover:text-gray-600 
                               opacity-0 group-hover:opacity-100 transition-opacity"
                      disabled={batchSending || sending}
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                              d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                  </div>
                )}
              </div>
            ))}
            {Object.values(previewStatuses)
              .filter(status => status.status === 'failed')
              .map(status => (
                <div key={status.id} className="p-4 border rounded-lg border-red-200 bg-red-50">
                  <div className="text-sm text-red-600">
                    <div className="font-medium">Generation Failed</div>
                    <div className="mt-1">{status.error}</div>
                  </div>
                </div>
              ))
            }
          </div>
        </div>
      )}

      {/* Validation Errors */}
      {errors.length > 0 && (
        <div className="mt-4 p-4 bg-red-50 rounded-lg">
          <ul className="text-sm text-red-600">
            {errors.map((error, i) => (
              <li key={i}>{error}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="flex justify-end gap-3 mt-6">
        <button
          onClick={() => navigate('/messages')}
          className="px-4 py-2 text-gray-600 hover:text-gray-800"
          disabled={isGenerating || batchSending}
        >
          Cancel
        </button>
        {selectedPreview && (
          <button
            onClick={handleSend}
            disabled={!isValid || sending || batchSending}
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700
                     disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            {sending ? 'Sending...' : 'Send Selected'}
          </button>
        )}
        {previews.length > 0 && (
          <button
            onClick={handleBatchSend}
            disabled={batchSending}
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700
                     disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            {batchSending ? `Sending ${sentCount}/${previews.length}...` : 'Send All'}
          </button>
        )}
        <button
          onClick={handleGenerate}
          disabled={selectedTickets.length === 0 || isGenerating || batchSending || loadingTickets}
          className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 
                   disabled:bg-gray-300 disabled:cursor-not-allowed"
        >
          {isGenerating ? (
            <span className="flex items-center">
              <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
              </svg>
              Generating...
            </span>
          ) : 'Generate Messages'}
        </button>
      </div>
    </div>
  )
} 