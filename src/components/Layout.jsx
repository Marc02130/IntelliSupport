import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import Header from './Header'
import { supabase } from '../lib/supabaseClient'

export default function Layout({ session }) {
  // Get full name from user metadata
  const fullName = session.user.user_metadata?.full_name || session.user.email
  const [firstName, lastName] = fullName.split(' ')

  const handleSignOut = async () => {
    await supabase.auth.signOut()
  }

  return (
    <div className="app-layout">
      <Sidebar session={session} />
      <div className="main-container">
        <Header 
          firstName={firstName}
          lastName={lastName}
          handleSignOut={handleSignOut}
        />
        <main className="main-content">
          <Outlet context={session} />
        </main>
      </div>

      <style jsx>{`
        .app-layout {
          display: flex;
          height: 100vh;
          width: 100vw;
          overflow: hidden;
        }

        .main-container {
          flex: 1;
          display: flex;
          flex-direction: column;
          overflow: hidden;
          min-width: 0; /* Important: prevents flex items from overflowing */
        }

        .main-content {
          flex: 1;
          overflow: auto;
          padding: 20px;
          background: #f5f5f5;
          width: 100%;
          min-width: 0; /* Important: prevents flex items from overflowing */
        }
      `}</style>
    </div>
  )
} 