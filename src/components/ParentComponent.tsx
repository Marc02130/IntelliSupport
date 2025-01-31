import { useState } from 'react'
import BatchEditor from './BatchEditor'

const ParentComponent = () => {
  const [messages, setMessages] = useState<Message[]>([])
  const [previewResults, setPreviewResults] = useState<any[]>([])
  const [error, setError] = useState<string>('')

  return (
    <div>
      {/* Other components */}
      <BatchEditor
        messages={messages}
        setPreviewResults={setPreviewResults}
        setError={setError}
      />
      {error && <div className="error">{error}</div>}
      {/* Display preview results */}
    </div>
  )
}

export default ParentComponent 