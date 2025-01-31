interface ContextPanelProps {
  context: MessagePreview['context']
}

export function ContextPanel({ context }: ContextPanelProps) {
  return (
    <div className="flex flex-col gap-6 p-5 bg-gray-50 rounded-lg border border-gray-200">
      {/* Customer Info */}
      <section className="space-y-3">
        <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <UserIcon className="w-4 h-4 text-gray-600" />
          Customer Preferences
        </h4>
        <div className="text-sm space-y-2 bg-white p-3 rounded-md shadow-sm">
          <p className="flex justify-between">
            <span className="text-gray-600">Style:</span>
            <span className="font-medium">{context.customer.preferences.preferred_style}</span>
          </p>
          <p className="flex justify-between">
            <span className="text-gray-600">Best Time:</span>
            <span className="font-medium">{context.customer.preferences.preferred_times}</span>
          </p>
        </div>
      </section>

      {/* Ticket Info */}
      <section className="space-y-3">
        <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <TicketIcon className="w-4 h-4 text-gray-600" />
          Ticket Details
        </h4>
        <div className="bg-white p-3 rounded-md shadow-sm space-y-2">
          <p className="font-medium text-gray-900">{context.ticket.subject}</p>
          <p className="text-sm text-gray-600">{context.ticket.description}</p>
          <div className="flex flex-wrap gap-1 mt-2">
            {context.ticket.tags.map(tag => (
              <span key={tag} 
                className="px-2 py-1 bg-blue-50 text-blue-700 rounded-full text-xs font-medium">
                {tag}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* Communication History */}
      <section className="space-y-3">
        <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <HistoryIcon className="w-4 h-4 text-gray-600" />
          Recent Communications
        </h4>
        <div className="space-y-2">
          {context.customer.history.map(msg => (
            <div key={msg.id} 
              className="text-sm p-3 bg-white rounded-md shadow-sm border-l-4 border-blue-500">
              <p className="text-gray-800 whitespace-pre-wrap">{msg.message_text}</p>
              <p className="text-xs text-gray-500 mt-2 flex items-center gap-1">
                <CalendarIcon className="w-3 h-3" />
                {new Date(msg.sent_at).toLocaleDateString()}
              </p>
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}

// Add these minimal icons or use your preferred icon library
function UserIcon(props) {
  return <svg {...props} viewBox="0 0 20 20" fill="currentColor"><path d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" /></svg>
}

function TicketIcon(props) {
  return <svg {...props} viewBox="0 0 20 20" fill="currentColor"><path d="M2 6a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 100 4v2a2 2 0 01-2 2H4a2 2 0 01-2-2v-2a2 2 0 100-4V6z" /></svg>
}

function HistoryIcon(props) {
  return <svg {...props} viewBox="0 0 20 20" fill="currentColor"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" /></svg>
}

function CalendarIcon(props) {
  return <svg {...props} viewBox="0 0 20 20" fill="currentColor"><path d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" /></svg>
} 