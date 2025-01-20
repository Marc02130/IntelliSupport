import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function Auth({ recoveryMode = false }) {
  const [loading, setLoading] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isSignUp, setIsSignUp] = useState(false)
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [isResetPassword, setIsResetPassword] = useState(recoveryMode)
  const [newPassword, setNewPassword] = useState('')

  useEffect(() => {
    // Check if we're in a password reset flow
    const hashParams = new URLSearchParams(window.location.hash.substring(1))
    if (hashParams.get('type') === 'recovery') {
      setIsResetPassword(true)
    }
  }, [])

  const handleAuth = async (e) => {
    e.preventDefault()
    setLoading(true)

    try {
      if (recoveryMode || isResetPassword) {
        if (recoveryMode) {
          // We're setting a new password after clicking the recovery link
          const { error } = await supabase.auth.updateUser({
            password: password
          })
          if (error) throw error
          alert('Password updated successfully! Please sign in with your new password.')
          window.location.href = '/' // Redirect to home/login page
        } else {
          // We're requesting a password reset email
          const { error } = await supabase.auth.resetPasswordForEmail(email, {
            redirectTo: `${window.location.origin}`
          })
          if (error) throw error
          alert('Check your email for the password reset link!')
          setIsResetPassword(false)
        }
      } else if (isSignUp) {
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: `${firstName} ${lastName}`,
              role: 'customer'
            }
          }
        })
        if (error) throw error
        alert('Check your email for the confirmation link!')
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        })
        if (error) throw error
      }
    } catch (error) {
      alert(error.message)
    } finally {
      setLoading(false)
    }
  }

  const toggleView = () => {
    setIsSignUp(!isSignUp)
    setIsResetPassword(false)
  }

  // Get the hash parameters to check if we're in a recovery flow
  const hashParams = new URLSearchParams(window.location.hash.substring(1))
  const isRecovery = hashParams.get('type') === 'recovery'

  return (
    <div className="auth-container">
      <form onSubmit={handleAuth} className="auth-form">
        <h1>
          {recoveryMode 
            ? 'Set New Password'
            : (isResetPassword 
                ? 'Reset Password' 
                : (isSignUp ? 'Sign Up' : 'Sign In'))}
        </h1>
        
        {!recoveryMode && (
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        )}

        {(recoveryMode || !isResetPassword) && (
          <input
            type="password"
            placeholder={recoveryMode ? "New Password" : "Password"}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        )}

        {isSignUp && !recoveryMode && (
          <>
            <input
              type="text"
              placeholder="First Name"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              required
            />
            <input
              type="text"
              placeholder="Last Name"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              required
            />
          </>
        )}

        <button type="submit" disabled={loading}>
          {loading 
            ? 'Loading...' 
            : (recoveryMode 
                ? 'Update Password'
                : (isResetPassword 
                    ? 'Send Reset Link'
                    : (isSignUp ? 'Sign Up' : 'Sign In')))}
        </button>

        {!recoveryMode && (
          <div className="auth-links">
            {!isResetPassword && (
              <p>
                {isSignUp ? 'Already have an account? ' : "Don't have an account? "}
                <button 
                  type="button" 
                  className="link-button"
                  onClick={() => {
                    setIsSignUp(!isSignUp)
                    setIsResetPassword(false)
                  }}
                >
                  {isSignUp ? 'Sign In' : 'Sign Up'}
                </button>
              </p>
            )}
            {!isSignUp && !isResetPassword && (
              <p>
                <button 
                  type="button" 
                  className="link-button"
                  onClick={() => setIsResetPassword(true)}
                >
                  Forgot Password?
                </button>
              </p>
            )}
            {isResetPassword && (
              <p>
                <button 
                  type="button" 
                  className="link-button"
                  onClick={() => setIsResetPassword(false)}
                >
                  Back to Sign In
                </button>
              </p>
            )}
          </div>
        )}
      </form>
    </div>
  )
} 