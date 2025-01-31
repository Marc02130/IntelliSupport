import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './lib/supabaseClient'
import Auth from './components/Auth'
import Dashboard from './components/Dashboard'
import Layout from './components/Layout'
import ListView from './components/ListView'
import DataRecord from './components/DataRecord'
import MessagesRoutes from './routes/messages'

function App() {
  const [session, setSession] = useState(null)
  const [recoveryMode, setRecoveryMode] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    // Check for recovery flow
    const hashParams = new URLSearchParams(window.location.hash.substring(1))
    if (hashParams.get('type') === 'recovery') {
      setRecoveryMode(true)
    }

    return () => subscription.unsubscribe()
  }, [])

  // If in recovery mode, show the Auth component regardless of session
  if (recoveryMode) {
    return <Auth recoveryMode={true} />
  }

  if (loading) {
    return <div>Loading...</div>
  }

  if (!session) {
    return <Auth />
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout session={session} />}>
          <Route index element={<Dashboard />} />
          <Route path="list/:queryId" element={<ListView />} />
          <Route path="messages/*" element={<MessagesRoutes />} />
          <Route path="datarecord/add/:queryId" element={<DataRecord />} />
          <Route path="datarecord/edit/:queryId/:recordId" element={<DataRecord />} />
          <Route path="/admin/*" element={<Dashboard />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App