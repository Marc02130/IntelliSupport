import { useState, useEffect } from 'react'
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

  return <Dashboard session={session} />
}

export default App
