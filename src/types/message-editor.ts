export interface MessagePreview {
  id: string
  ticket_id: string
  content: string
  context: {
    customer: {
      preferences: any
      history: any[]
    }
    ticket: {
      subject: string
      description: string
      tags: string[]
      comments: any[]
    }
  }
  style_feedback?: {
    tone_match: number
    style_suggestions: string[]
  }
  metadata: {
    model_used: string
    generation_time: number
    template_id?: string
    edited?: boolean
  }
  status: 'draft' | 'sending' | 'sent' | 'failed'
}

export interface Template {
  id: string
  template_text: string
  context_type: string
  metadata: Record<string, any>
} 