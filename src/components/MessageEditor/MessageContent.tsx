interface MessageContentProps {
  preview: MessagePreview
  onChange: (preview: MessagePreview) => void
}

export function MessageContent({ preview, onChange }: MessageContentProps) {
  const handleEdit = (content: string) => {
    onChange({
      ...preview,
      content,
      metadata: {
        ...preview.metadata,
        edited: true
      }
    })
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold text-gray-900">Message Preview</h3>
        <StyleFeedback feedback={preview.style_feedback} />
      </div>

      <div className="relative">
        <textarea
          value={preview.content}
          onChange={(e) => handleEdit(e.target.value)}
          className="w-full min-h-[300px] p-4 border border-gray-300 rounded-lg
                   focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                   resize-y text-gray-800 leading-relaxed
                   placeholder-gray-400 transition-all duration-200"
          placeholder="Message content..."
        />
        
        {/* Character count */}
        <div className="absolute bottom-3 right-3 text-sm text-gray-500">
          {preview.content.length} characters
        </div>
      </div>

      {/* Style suggestions */}
      {preview.style_feedback?.style_suggestions?.length > 0 && (
        <div className="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <h4 className="text-sm font-medium text-yellow-800 mb-1">Style Suggestions</h4>
          <ul className="text-sm text-yellow-700 space-y-1">
            {preview.style_feedback.style_suggestions.map((suggestion, i) => (
              <li key={i} className="flex items-start gap-2">
                <span className="mt-1">•</span>
                <span>{suggestion}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

function StyleFeedback({ feedback }: { feedback?: MessagePreview['style_feedback'] }) {
  if (!feedback) return null

  const score = feedback.tone_match * 100
  const getColor = (score: number) => {
    if (score >= 90) return 'text-green-600 bg-green-50'
    if (score >= 70) return 'text-yellow-600 bg-yellow-50'
    return 'text-red-600 bg-red-50'
  }

  return (
    <div className={`px-3 py-1 rounded-full text-sm font-medium ${getColor(score)}`}>
      Style Match: {score}%
    </div>
  )
} 