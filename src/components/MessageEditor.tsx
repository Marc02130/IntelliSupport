import React from 'react'
import { useEffect, useState } from 'react'
import { config } from '../config'

interface MessageEditorProps {
  initialText: string
  customerContext: any
  contextType: string
  onUpdate: (text: string) => void
}

export function MessageEditor({ initialText, customerContext, contextType, onUpdate }: MessageEditorProps) {
  const [text, setText] = useState(initialText)
  const [suggestions, setSuggestions] = useState<string[]>([])
  const [socket, setSocket] = useState<WebSocket | null>(null)
  const [isConnected, setIsConnected] = useState(false)

  useEffect(() => {
    const ws = new WebSocket(config.ws.preview)
    
    ws.onopen = () => {
      setIsConnected(true)
      console.log('Connected to preview service')
    }

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      if (data.type === 'suggestion') {
        setSuggestions(prev => [...prev, data.content])
      }
    }

    ws.onerror = (error) => {
      console.error('WebSocket error:', error)
    }

    ws.onclose = () => {
      setIsConnected(false)
      console.log('Disconnected from preview service')
    }

    setSocket(ws)

    return () => {
      ws.close()
    }
  }, [])

  // Request suggestions when text changes
  const requestSuggestions = () => {
    if (socket && isConnected) {
      socket.send(JSON.stringify({
        customer_context: customerContext,
        context_type: contextType,
        draft_text: text
      }))
    }
  }

  return (
    <div className="message-editor">
      <textarea
        value={text}
        onChange={(e) => {
          setText(e.target.value)
          onUpdate(e.target.value)
        }}
        onKeyUp={requestSuggestions}
        className="w-full p-2 border rounded"
        rows={5}
      />
      
      {suggestions.length > 0 && (
        <div className="suggestions mt-4">
          <h3 className="font-bold">Suggestions:</h3>
          <div className="space-y-2">
            {suggestions.map((suggestion, i) => (
              <div 
                key={i}
                className="p-2 bg-gray-50 rounded cursor-pointer hover:bg-gray-100"
                onClick={() => {
                  setText(suggestion)
                  onUpdate(suggestion)
                }}
              >
                {suggestion}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
} 