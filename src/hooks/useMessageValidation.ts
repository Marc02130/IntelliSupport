import { useState, useEffect } from 'react'
import { MessagePreview } from '../types/message-editor'

export function useMessageValidation(message: MessagePreview | null) {
  const [isValid, setIsValid] = useState(false)
  const [errors, setErrors] = useState<string[]>([])

  useEffect(() => {
    if (!message) {
      setIsValid(false)
      setErrors(['No message to validate'])
      return
    }

    const newErrors: string[] = []
    
    if (!message.content?.trim()) {
      newErrors.push('Message content is required')
    }
    
    if (message.content?.length > 5000) {
      newErrors.push('Message is too long (max 5000 characters)')
    }

    setErrors(newErrors)
    setIsValid(newErrors.length === 0)
  }, [message])

  return { isValid, errors }
} 