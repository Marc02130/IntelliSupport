import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './lib/supabaseClient'
import Auth from './components/Auth'
import Dashboard from './components/Dashboard'
import Layout from './components/Layout'
import ListView from './components/ListView'
import DataRecord from './components/DataRecord'
import SearchTable from './components/SearchTable'
import DataRecordEdit from './components/DataRecordEdit'
import DataRecordAdd from './components/DataRecordAdd'

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
        <Route path="/" element={<Layout session={session} />}>
          <Route index element={<Dashboard session={session} />} />
          <Route path="list/:queryId" element={<ListView />} />
          <Route path="datarecord/add/:queryId" element={<DataRecordAdd />} />
          <Route path="datarecord/edit/:queryId/:recordId" element={<DataRecordEdit />} />
          <Route path="/admin/*" element={<Dashboard session={session} />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
        <Route path="/search/:queryId" element={<SearchTable />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
