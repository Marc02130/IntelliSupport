import { useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import TicketList from './TicketList'

export default function Dashboard({ session }) {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false)

  // Get full name from user metadata
  const fullName = session.user.user_metadata?.full_name || session.user.email
  const [firstName, lastName] = fullName.split(' ')

  // Get user role from metadata
  const userRole = session.user.user_metadata?.role || 'customer'

  const handleSignOut = async () => {
    await supabase.auth.signOut()
  }

  return (
    <div className="dashboard-container">
      {/* Sidebar */}
      <aside className={`sidebar ${isSidebarCollapsed ? 'collapsed' : ''}`}>
        <div className="sidebar-header">
        </div>
        <div className="sidebar-search">
          <input type="search" placeholder="Search..." />
          <button 
            className="collapse-button"
            onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
          >
            {isSidebarCollapsed ? '→' : '←'}
          </button>
        </div>
        <nav className="sidebar-nav">
          <ul>
            <li><a href="#" className="active">Dashboard</a></li>
            <li><a href="#">Submit New Ticket</a></li>
            <li><a href="#">Knowledge Base</a></li>
            <li><a href="#">Reports</a></li>
            <li><a href="#">Settings</a></li>
          </ul>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="main-content">
        {/* Header */}
        <header className="dashboard-header">
          <div className="header-brand">
            <h1 className="brand-text">
              Intelli<span className="support-text">Support</span>
            </h1>
          </div>
          <div className="header-actions">
            <span className="user-name">{firstName} {lastName}</span>
            <button onClick={handleSignOut} className="sign-out-button">
              Sign Out
            </button>
          </div>
        </header>

        {/* Body */}
        <div className="dashboard-body">
          <TicketList 
            userRole={userRole} 
            userId={session.user.id}
          />
        </div>
      </main>
    </div>
  )
} 