import React from 'react'
import { useState, useEffect } from 'react'
import { Link, useOutletContext } from 'react-router-dom'
import { SupabaseClient } from '@supabase/supabase-js'

interface Message {
  id: string
  content: string
  status: string
  created_at: string
  ticket: {
    subject: string
    customer_id: string
  }
}

interface OutletContext {
  session: any
  supabase: SupabaseClient
}

export default function MessageList() {
  console.log('MessageList rendering')
  const [messages, setMessages] = useState<Message[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { session, supabase } = useOutletContext<OutletContext>()
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')
  const [statusFilter, setStatusFilter] = useState<string>('all')

  useEffect(() => {
    if (!session) return

    const fetchMessages = async () => {
      try {
        const { data, error } = await supabase
          .from('messages')
          .select('*, ticket:tickets(*)')
          .order('created_at', { ascending: sortOrder === 'asc' })

        if (error) throw error
        setMessages(data || [])
      } catch (err) {
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchMessages()
  }, [sortOrder, session])

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-semibold text-gray-900">Messages</h1>
        <Link
          to="/messages/batch"
          className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          Batch Process
        </Link>
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-50 text-red-600 rounded-md">
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="mb-4 flex gap-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2 border rounded-md"
        >
          <option value="all">All Status</option>
          <option value="sent">Sent</option>
          <option value="draft">Draft</option>
          <option value="failed">Failed</option>
        </select>

        <button
          onClick={() => setSortOrder(order => order === 'asc' ? 'desc' : 'asc')}
          className="px-3 py-2 border rounded-md flex items-center gap-2"
        >
          Sort {sortOrder === 'asc' ? '↑' : '↓'}
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center p-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
      ) : (
        <div className="space-y-4">
          {messages.map(message => (
            <div 
              key={message.id}
              className="p-4 bg-white rounded-lg border border-gray-200"
            >
              <div className="flex justify-between items-start mb-2">
                <h3 className="font-medium">{message.ticket.subject}</h3>
                <span className={`px-2 py-1 text-sm rounded-full ${
                  message.status === 'sent' 
                    ? 'bg-green-100 text-green-800'
                    : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {message.status}
                </span>
              </div>
              <p className="text-gray-600 text-sm mb-2">{message.content}</p>
              <p className="text-xs text-gray-500">
                Sent: {new Date(message.created_at).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  )
} 