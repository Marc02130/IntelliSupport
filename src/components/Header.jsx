export default function Header({ firstName, lastName, handleSignOut }) {
  return (
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
  )
} 