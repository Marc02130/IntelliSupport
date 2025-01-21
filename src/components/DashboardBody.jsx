import TicketList from './TicketList'

export default function DashboardBody({ userRole, userId }) {
  return (
    <div className="dashboard-body">
      <TicketList 
        userRole={userRole} 
        userId={userId}
      />
    </div>
  )
} 