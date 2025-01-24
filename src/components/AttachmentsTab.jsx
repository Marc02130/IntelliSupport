import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function AttachmentsTab({ recordId, type = 'ticket' }) {
  const [attachments, setAttachments] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (recordId) {
      loadAttachments()
    }
  }, [recordId])

  async function loadAttachments() {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('attachments')
        .select('*')
        .eq('entity_type', type)
        .eq('entity_id', recordId)

      if (error) throw error
      setAttachments(data || [])
    } catch (err) {
      console.error('Error loading attachments:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function handleUpload(event) {
    try {
      const file = event.target.files[0]
      if (!file) return

      // Get current user from supabase
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('No user found')

      // Upload file to storage using the correct user ID
      const filePath = `${user.id}/${type}/${recordId}/${file.name}`
      const { error: uploadError } = await supabase.storage
        .from('attachments')
        .upload(filePath, file)

      if (uploadError) throw uploadError

      // Create attachment record
      const { error: dbError } = await supabase
        .from('attachments')
        .insert({
          entity_type: type,
          entity_id: recordId,
          storage_path: filePath,
          filename: file.name,
          size: file.size,
          mime_type: file.type
        })

      if (dbError) throw dbError

      // Reload attachments
      loadAttachments()
    } catch (err) {
      console.error('Upload error:', err)
      setError(err.message)
    }
  }

  async function handleDelete(attachmentId) {
    try {
      const attachment = attachments.find(a => a.id === attachmentId)
      if (!attachment) return

      // Delete from storage
      const { error: storageError } = await supabase.storage
        .from('attachments')
        .remove([attachment.storage_path])

      if (storageError) throw storageError

      // Delete from database
      const { error: dbError } = await supabase
        .from('attachments')
        .delete()
        .eq('id', attachmentId)

      if (dbError) throw dbError

      // Reload attachments
      loadAttachments()
    } catch (err) {
      console.error('Delete error:', err)
      setError(err.message)
    }
  }

  if (loading) return <div>Loading attachments...</div>
  if (error) return <div className="error-message">{error}</div>

  return (
    <div className="attachments-container">
      <div className="upload-section">
        <input 
          type="file"
          onChange={handleUpload}
          className="file-input"
        />
      </div>

      {attachments.length === 0 ? (
        <div>No attachments found</div>
      ) : (
        <div className="attachments-list">
          {attachments.map(attachment => (
            <div key={attachment.id} className="attachment-item">
              <span className="filename">{attachment.filename}</span>
              <span className="filesize">({Math.round(attachment.size / 1024)} KB)</span>
              <button 
                onClick={() => handleDelete(attachment.id)}
                className="delete-btn"
              >
                Delete
              </button>
            </div>
          ))}
        </div>
      )}

      <style jsx>{`
        .attachments-container {
          padding: 1rem;
        }
        .upload-section {
          margin-bottom: 1rem;
        }
        .attachments-list {
          display: flex;
          flex-direction: column;
          gap: 0.5rem;
        }
        .attachment-item {
          display: flex;
          align-items: center;
          gap: 1rem;
          padding: 0.5rem;
          border: 1px solid #ddd;
          border-radius: 4px;
        }
        .filename {
          flex: 1;
          font-weight: 500;
        }
        .filesize {
          color: #666;
        }
        .delete-btn {
          padding: 0.25rem 0.5rem;
          border: 1px solid #ddd;
          border-radius: 4px;
          background: #fff;
          cursor: pointer;
        }
        .delete-btn:hover {
          background: #f5f5f5;
        }
        .error-message {
          color: red;
          margin: 1rem 0;
        }
      `}</style>
    </div>
  )
} 