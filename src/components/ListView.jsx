import { useParams } from 'react-router-dom'
import SearchTable from './SearchTable'

export default function ListView() {
  const { queryId } = useParams()

  return (
    <div className="list-view">
      <SearchTable 
        queryId={queryId}
        onAdd={true} // Enable add functionality
      />
      
      <style jsx>{`
        .list-view {
          padding: 20px;
          height: 100%;
        }
      `}</style>
    </div>
  )
} 