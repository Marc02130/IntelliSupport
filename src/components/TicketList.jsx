import { useState, useEffect, useMemo } from 'react'
import { supabase } from '../lib/supabaseClient'
import SearchTable from './SearchTable'

export default function TicketList({ userRole, userId }) {
  const [tickets, setTickets] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('my-tickets')
  const [userOrgs, setUserOrgs] = useState([])

  const columns = useMemo(
    () => [
      {
        header: 'Subject',
        accessorKey: 'subject',
      },
      {
        header: 'Status',
        accessorKey: 'status',
      },
      {
        header: 'Priority',
        accessorKey: 'priority',
      },
      {
        header: 'Created By',
        accessorFn: row => `${row.created_by.first_name} ${row.created_by.last_name}`,
      },
      {
        header: 'Assigned To',
        accessorFn: row => row.assigned_to 
          ? `${row.assigned_to.first_name} ${row.assigned_to.last_name}`
          : 'Unassigned',
      },
      {
        header: 'Organization',
        accessorFn: row => row.organization?.name || 'N/A',
      },
      {
        header: 'Created At',
        accessorKey: 'created_at',
        cell: info => new Date(info.getValue()).toLocaleDateString(),
      },
    ],
    []
  )

  // ... rest of your existing code for fetchUserOrganizations and fetchTickets ...

  return (
    <div className="ticket-list">
      <div className="ticket-filters">
        {/* ... your existing filter buttons ... */}
      </div>

      {loading ? (
        <div className="loading">Loading tickets...</div>
      ) : (
        <SearchTable 
          data={tickets}
          columns={columns}
        />
      )}
    </div>
  )
} 