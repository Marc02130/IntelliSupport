import { useState, useEffect } from 'react'
import { useLocation, useParams, useOutletContext } from 'react-router-dom'
import Header from './Header'
import Sidebar from './Sidebar'
import DashboardBody from './DashboardBody'

export default function Dashboard() {
  const { session, supabase } = useOutletContext()
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false)
  const [queryId, setQueryId] = useState(null)
  const [mode, setMode] = useState('dashboard') // 'dashboard', 'list', or 'record'
  const [recordId, setRecordId] = useState(null)
  const location = useLocation()
  const params = useParams()

  if (!session) {
    return <div>Loading...</div>
  }

  // Log when component renders
  console.log('Dashboard rendering with params:', params, 'pathname:', location.pathname)

  // Handle URL parameters and location state changes
  useEffect(() => {
    const path = location.pathname
    
    if (path.startsWith('/datarecord/')) {
      setQueryId(params.queryId)
      setMode('record')
      setRecordId(params.recordId || 'add')
    } else if (path.startsWith('/list/')) {
      setQueryId(params.queryId)
      setMode('list')
      setRecordId(null)
    } else {
      setMode('dashboard')
      setQueryId(null)
      setRecordId(null)
    }
  }, [location, params])

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
        userRole={userRole}
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
          queryId={queryId}
          mode={mode}
          recordId={recordId}
        />
      </main>
    </div>
  )
} 