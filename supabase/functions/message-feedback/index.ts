import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'

interface FeedbackRequest {
  message_id: string
  feedback_type: 'helpful' | 'not_helpful' | 'suggestion'
  feedback_text?: string
  effectiveness_score?: number
}

function validateFeedback(feedback: FeedbackRequest) {
  const errors: string[] = []

  // Validate message_id
  const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!UUID_REGEX.test(feedback.message_id)) {
    errors.push('Invalid message ID format')
  }

  // Validate feedback_type
  const VALID_TYPES = ['helpful', 'not_helpful', 'suggestion']
  if (!VALID_TYPES.includes(feedback.feedback_type)) {
    errors.push('Invalid feedback type. Must be one of: ' + VALID_TYPES.join(', '))
  }

  // Validate feedback_text
  if (feedback.feedback_text) {
    if (feedback.feedback_text.length < 3) {
      errors.push('Feedback text must be at least 3 characters')
    }
    if (feedback.feedback_text.length > 1000) {
      errors.push('Feedback text cannot exceed 1000 characters')
    }
  }

  // Validate effectiveness_score
  if (feedback.effectiveness_score !== undefined) {
    if (feedback.effectiveness_score < 0 || feedback.effectiveness_score > 1) {
      errors.push('Effectiveness score must be between 0 and 1')
    }
  }

  return errors
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const client = await getSupabaseClient()
    const metrics: Record<string, number> = {}
    const startTime = Date.now()

    // Get user ID and request data
    const [{ message_id, feedback_type, feedback_text, effectiveness_score }, userId] = await Promise.all([
      req.json() as Promise<FeedbackRequest>,
      (async () => {
        const id = req.headers.get('x-user-id')
        if (!id) throw new Error('Missing user ID')
        return id
      })()
    ])

    // Validate request
    const validationErrors = validateFeedback({ 
      message_id, 
      feedback_type, 
      feedback_text, 
      effectiveness_score 
    })
    if (validationErrors.length > 0) {
      return new Response(
        JSON.stringify({ 
          error: 'Validation failed', 
          details: validationErrors 
        }),
        { 
          status: 400, 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json'
          }
        }
      )
    }

    // Validate message exists and belongs to user
    const { data: message } = await client
      .from('message_previews')
      .select('id')
      .eq('id', message_id)
      .eq('user_id', userId)
      .single()

    if (!message) {
      throw new Error('Message not found or access denied')
    }

    // Check for duplicate feedback
    const { data: existingFeedback } = await client
      .from('message_feedback')
      .select('id')
      .eq('message_id', message_id)
      .eq('user_id', userId)
      .single()

    console.log('Existing feedback:', existingFeedback)

    if (existingFeedback) {
      console.log('Updating feedback:', {
        id: existingFeedback.id,
        feedback_type,
        feedback_text,
        effectiveness_score
      })

      // Update existing feedback
      const { data: feedback, error } = await client
        .from('message_feedback')
        .update({
          feedback_type,
          feedback_text,
          effectiveness_score,
        })
        .eq('id', existingFeedback.id)
        .select()
        .single()

      if (error) {
        console.error('Update error:', error)
        throw error
      }

      // Update message effectiveness metrics
      await client.rpc('update_message_effectiveness', {
        p_message_id: message_id,
        p_feedback_type: feedback_type,
        p_effectiveness_score: effectiveness_score
      })

      metrics.total_duration = Date.now() - startTime

      return new Response(
        JSON.stringify({
          feedback_id: feedback.id,
          message: 'Feedback updated successfully',
          duration_ms: metrics.total_duration
        }),
        { 
          headers: { 
            ...corsHeaders, 
            'Content-Type': 'application/json'
          }
        }
      )
    }

    // Try to insert new feedback
    const { data, error } = await client
      .from('message_feedback')
      .insert({
        message_id,
        user_id: userId,
        feedback_type,
        feedback_text,
        effectiveness_score,
      })
      .select()
      .single()

    let feedback;
    if (error) {
      // Check if duplicate
      if (error.code === '23505') { // Unique violation
        const { data: existing, error: updateError } = await client
          .from('message_feedback')
          .update({
            feedback_type,
            feedback_text,
            effectiveness_score,
          })
          .eq('message_id', message_id)
          .eq('user_id', userId)
          .select()
          .single()
          
        if (updateError) throw updateError
        feedback = existing
      } else {
        throw error
      }
    } else {
      feedback = data
    }

    // Update message effectiveness metrics
    await client.rpc('update_message_effectiveness', {
      p_message_id: message_id,
      p_feedback_type: feedback_type,
      p_effectiveness_score: effectiveness_score
    })

    metrics.total_duration = Date.now() - startTime

    return new Response(
      JSON.stringify({
        feedback_id: feedback.id,
        message: data ? 'Feedback recorded successfully' : 'Feedback updated successfully',
        duration_ms: metrics.total_duration
      }),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json'
        }
      }
    )

  } catch (error) {
    const status = error.message.includes('not found') ? 404 : 500
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json'
        }
      }
    )
  }
}) 