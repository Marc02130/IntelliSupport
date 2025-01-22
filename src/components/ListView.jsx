import { useState } from 'react'
import SearchTable from './SearchTable'
import DataRecord from './DataRecord'

export default function ListView({ queryId, onRecordSelect }) {
  const [selectedRecord, setSelectedRecord] = useState(null)

  const handleRowDoubleClick = (row) => {
    setSelectedRecord(row)
  }

  const handleSave = async (updatedRecord) => {
    setSelectedRecord(null)
  }

  const handleCancel = () => {
    setSelectedRecord(null)
  }

  const handleAdd = () => {
    setSelectedRecord({})
  }

  return (
    <div className="list-view">
      {selectedRecord ? (
        <DataRecord
          record={selectedRecord}
          onSave={handleSave}
          onCancel={handleCancel}
        />
      ) : (
        <SearchTable
          queryId={queryId}
          onRowDoubleClick={handleRowDoubleClick}
          onAdd={handleAdd}
        />
      )}
    </div>
  )
} 