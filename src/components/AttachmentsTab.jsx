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

      // Sanitize the filename - remove special characters and spaces
      const sanitizedFileName = file.name
        .replace(/[^a-zA-Z0-9.-]/g, '_')  // Replace special chars with underscore
        .toLowerCase()                     // Convert to lowercase
      
      // Upload file to storage using the correct user ID and sanitized filename
      const filePath = `${user.id}/${type}/${recordId}/${sanitizedFileName}`
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
          filename: file.name,  // Store original filename in database
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

  async function handleDownload(attachment) {
    try {
      const { data, error } = await supabase.storage
        .from('attachments')
        .download(attachment.storage_path)

      if (error) throw error

      // Create a blob URL and trigger download
      const blob = new Blob([data], { type: attachment.mime_type })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = attachment.filename // Use original filename
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } catch (err) {
      console.error('Download error:', err)
      setError(err.message)
    }
  }

  async function handlePreview(attachment) {
    try {
      // Get signed URL that expires in 1 hour
      const { data: { signedUrl }, error } = await supabase.storage
        .from('attachments')
        .createSignedUrl(attachment.storage_path, 3600)

      if (error) throw error

      // Open in new tab
      window.open(signedUrl, '_blank')
    } catch (err) {
      console.error('Preview error:', err)
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
              <div className="action-buttons">
                <button 
                  onClick={() => handlePreview(attachment)}
                  className="preview-btn"
                >
                  Preview
                </button>
                <button 
                  onClick={() => handleDownload(attachment)}
                  className="download-btn"
                >
                  Download
                </button>
                <button 
                  onClick={() => handleDelete(attachment.id)}
                  className="delete-button"
                >
                  Delete
                </button>
              </div>
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
        .action-buttons {
          display: flex;
          gap: 8px;
          align-items: center;
        }
        .download-btn {
          padding: 8px 16px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 14px;
          background: #4CAF50;
          color: white;
          border: none;
        }
        .download-btn:hover {
          background: #45a049;
        }
        .preview-btn {
          padding: 8px 16px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 14px;
          background: #2196F3;
          color: white;
          border: none;
        }
        .preview-btn:hover {
          background: #1976D2;
        }
      `}</style>
    </div>
  )
} 