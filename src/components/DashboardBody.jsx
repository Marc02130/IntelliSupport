import { useState, useEffect } from 'react'
import ListView from './ListView'
import DataRecord from './DataRecord'

export default function DashboardBody({ userRole, userId, queryId, mode, recordId }) {
  console.log('DashboardBody render:', { userRole, userId, queryId, mode, recordId })

  if (mode === 'record') {
    return (
      <div className="dashboard-body">
        <DataRecord
          queryId={queryId}
          recordId={recordId}
          mode={recordId === 'add' ? 'add' : 'edit'}
        />
      </div>
    )
  }

  if (mode === 'list') {
    return (
      <div className="dashboard-body">
        <ListView queryId={queryId} />
      </div>
    )
  }

  return (
    <div className="dashboard-body">
      <div className="welcome-message">
        <h2>Welcome to Dashboard</h2>
        <p>Select an item from the sidebar to get started</p>
      </div>
    </div>
  )
} 