import React, { useState } from 'react'
import { supabase } from '../lib/supabase'

export default function Sidebar({ isSidebarCollapsed, setIsSidebarCollapsed }) {
  const [isAdminExpanded, setIsAdminExpanded] = useState(false)
  const userRole = supabase.auth.user()?.user_metadata?.role || 'customer'

  return (
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
          <li><a href="#">Reports</a></li>
          {userRole === 'admin' && (
            <li>
              <button 
                className="nav-section-toggle"
                onClick={() => setIsAdminExpanded(!isAdminExpanded)}
              >
                Admin {isAdminExpanded ? '▼' : '▶'}
              </button>
              {isAdminExpanded && (
                <ul className="nav-section">
                  <li><a href="#">Users</a></li>
                  <li><a href="#">Roles</a></li>
                  <li><a href="#">Permissions</a></li>
                  <li><a href="#">Organizations</a></li>
                  <li><a href="#">Teams</a></li>
                </ul>
              )}
            </li>
          )}
        </ul>
      </nav>
    </aside>
  )
} 