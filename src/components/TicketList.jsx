import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function TicketList({ userRole, userId }) {
  const [tickets, setTickets] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('my-tickets') // my-tickets, org-tickets
  const [userOrg, setUserOrg] = useState(null)

  // Fetch user's organization on component mount
  useEffect(() => {
    const fetchUserOrg = async () => {
      const { data, error } = await supabase
        .from('users')
        .select('organization_id, organizations(name)')
        .eq('id', userId)
        .single()

      if (!error && data?.organization_id) {
        setUserOrg(data)
      }
    }

    if (userRole === 'customer') {
      fetchUserOrg()
    }
  }, [userId, userRole])

  useEffect(() => {
    fetchTickets()
  }, [filter, userRole, userId, userOrg])

  const fetchTickets = async () => {
    setLoading(true)
    let query = supabase.from('tickets').select(`
      *,
      assigned_to:users!assigned_to(first_name, last_name),
      created_by:users!created_by(first_name, last_name, organization_id)
    `)

    // Apply filters based on role and filter selection
    switch (userRole) {
      case 'customer':
        if (filter === 'org-tickets' && userOrg?.organization_id) {
          query = query.eq('created_by.organization_id', userOrg.organization_id)
        } else {
          query = query.eq('created_by', userId)
        }
        break
      
      case 'agent':
        if (filter === 'default') {
          query = query.is('assigned_to', null)
        } else if (filter === 'my-tickets') {
          query = query.eq('assigned_to', userId)
        }
        break
      
      case 'admin':
        if (filter === 'default') {
          query = query.is('assigned_to', null)
        } else if (filter === 'my-tickets') {
          query = query.eq('assigned_to', userId)
        } else if (filter === 'all-tickets') {
          // No filter for all tickets - admin sees everything
        }
        break
    }

    const { data, error } = await query.order('created_at', { ascending: false })
    
    if (error) {
      console.error('Error fetching tickets:', error)
    } else {
      setTickets(data)
    }
    setLoading(false)
  }

  const renderFilterButtons = () => {
    const customerOptions = [
      { value: 'my-tickets', label: 'My Tickets' },
      ...(userOrg ? [{ value: 'org-tickets', label: `${userOrg.organizations.name} Tickets` }] : [])
    ]

    const agentOptions = [
      { value: 'default', label: 'Unassigned Tickets' },
      { value: 'my-tickets', label: 'My Tickets' }
    ]

    const adminOptions = [
      { value: 'default', label: 'Unassigned Tickets' },
      { value: 'my-tickets', label: 'My Tickets' },
      { value: 'all-tickets', label: 'All Tickets' }
    ]

    const options = userRole === 'customer' 
      ? customerOptions 
      : userRole === 'admin' 
        ? adminOptions 
        : agentOptions

    return (
      <div className="filter-select">
        <select 
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="ticket-filter-dropdown"
        >
          {options.map(option => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </div>
    )
  }

  return (
    <div className="ticket-list">
      <div className="ticket-filters">
        {renderFilterButtons()}
      </div>

      {loading ? (
        <div className="loading">Loading tickets...</div>
      ) : (
        <div className="tickets-grid">
          {tickets.map(ticket => (
            <div key={ticket.id} className="ticket-card">
              <h3>{ticket.title}</h3>
              <p className="ticket-status">{ticket.status}</p>
              <p className="ticket-created">
                Created by: {ticket.created_by.first_name} {ticket.created_by.last_name}
              </p>
              {ticket.assigned_to && (
                <p className="ticket-assigned">
                  Assigned to: {ticket.assigned_to.first_name} {ticket.assigned_to.last_name}
                </p>
              )}
              <p className="ticket-date">
                {new Date(ticket.created_at).toLocaleDateString()}
              </p>
            </div>
          ))}
          {tickets.length === 0 && (
            <p className="no-tickets">No tickets found</p>
          )}
        </div>
      )}
    </div>
  )
} 