import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './lib/supabaseClient'
import Auth from './components/Auth'
import Dashboard from './components/Dashboard'

function App() {
  const [session, setSession] = useState(null)
  const [recoveryMode, setRecoveryMode] = useState(false)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
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

  if (!session) {
    return <Auth />
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Dashboard session={session} />} />
        <Route path="/list/:queryId" element={<Dashboard session={session} />} />
        <Route path="/datarecord/:queryId/:recordId/edit" element={<Dashboard session={session} />} />
        <Route path="/datarecord/:queryId/add" element={<Dashboard session={session} />} />
        <Route path="/admin/*" element={<Dashboard session={session} />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
