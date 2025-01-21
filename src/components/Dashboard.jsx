import { useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import Header from './Header'
import Sidebar from './Sidebar'
import DashboardBody from './DashboardBody'

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
      <Sidebar 
        isSidebarCollapsed={isSidebarCollapsed}
        setIsSidebarCollapsed={setIsSidebarCollapsed}
      />
      <main className="main-content">
        <Header 
          firstName={firstName}
          lastName={lastName}
          handleSignOut={handleSignOut}
        />
        <DashboardBody 
          userRole={userRole}
          userId={session.user.id}
        />
      </main>
    </div>
  )
} 