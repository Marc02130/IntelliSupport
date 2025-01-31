import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

interface AnalysisRequest {
  time_window?: string // '24h', '7d', '30d'
  min_feedback_count?: number
  min_effectiveness_score?: number
}

interface MessageAnalysis {
  message_id: string
  message_text: string
  effectiveness_score: number
  feedback_count: number
  helpful_count: number
  not_helpful_count: number
  common_themes: string[]
  improvement_suggestions: string[]
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const client = await getSupabaseClient()
    const metrics: Record<string, number> = {}
    const startTime = Date.now()

    // Get analysis parameters
    const { time_window = '7d', min_feedback_count = 5, min_effectiveness_score = 0.7 } = 
      await req.json() as AnalysisRequest

    // Calculate time threshold
    const timeThreshold = new Date()
    switch (time_window) {
      case '24h': timeThreshold.setHours(timeThreshold.getHours() - 24); break
      case '7d': timeThreshold.setDate(timeThreshold.getDate() - 7); break
      case '30d': timeThreshold.setDate(timeThreshold.getDate() - 30); break
      default: throw new Error('Invalid time window')
    }

    // Get messages with sufficient feedback
    const { data: messages } = await client
      .from('message_previews')
      .select(`
        id,
        message_text,
        metadata->'effectiveness'->>'score' as effectiveness_score,
        metadata->'effectiveness'->>'feedback_count' as feedback_count,
        metadata->'effectiveness'->>'helpful_count' as helpful_count,
        metadata->'effectiveness'->>'not_helpful_count' as not_helpful_count
      `)
      .gte('created_at', timeThreshold.toISOString())
      // First get all messages with feedback
      .not('metadata->>\'effectiveness\'', 'is', null)
      .filter('metadata->>\'effectiveness\'', 'neq', '{}')

    console.log('Found messages:', messages)

    if (!messages?.length) {
      return new Response(
        JSON.stringify({ 
          message: 'No messages found matching criteria',
          criteria: { time_window, min_feedback_count, min_effectiveness_score },
          debug: {
            timeThreshold: timeThreshold.toISOString(),
            query: 'SELECT id, message_text, metadata->\'effectiveness\'->>\'score\' as effectiveness_score FROM message_previews WHERE created_at >= $1 AND metadata->>\'effectiveness\' IS NOT NULL'
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
      )
    }

    // Filter messages in memory for more accurate numeric comparisons
    const filteredMessages = messages.filter(msg => {
      const feedbackCount = parseInt(msg.feedback_count) || 0
      const score = parseFloat(msg.effectiveness_score) || 0
      return feedbackCount >= min_feedback_count && score >= min_effectiveness_score
    })

    if (!filteredMessages.length) {
      return new Response(
        JSON.stringify({ 
          message: 'No messages meet effectiveness criteria',
          criteria: { time_window, min_feedback_count, min_effectiveness_score },
          debug: {
            total_messages: messages.length,
            messages_with_feedback: messages.filter(m => m.feedback_count).length,
            messages_with_score: messages.filter(m => m.effectiveness_score).length
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
      )
    }

    // Get feedback for analysis
    const { data: feedback } = await client
      .from('message_feedback')
      .select('message_id, feedback_type, feedback_text')
      .in('message_id', filteredMessages.map(m => m.id))
      .not('feedback_text', 'is', null)
      .order('created_at', { ascending: false })

    // Analyze feedback with GPT
    const analysisPromises = filteredMessages.map(async (message) => {
      const messageFeedback = feedback?.filter(f => f.message_id === message.id) || []
      const feedbackText = messageFeedback
        .filter(f => f.feedback_text)
        .map(f => f.feedback_text)
        .join('\n')

      if (!feedbackText) {
        return {
          message_id: message.id,
          message_text: message.message_text,
          effectiveness_score: parseFloat(message.effectiveness_score),
          feedback_count: parseInt(message.feedback_count),
          helpful_count: parseInt(message.helpful_count),
          not_helpful_count: parseInt(message.not_helpful_count),
          common_themes: [],
          improvement_suggestions: []
        }
      }

      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: `Analyze message feedback and identify common themes and improvement suggestions.
              Focus on:
              - Writing style and tone
              - Message clarity and effectiveness
              - Technical accuracy
              - Areas for improvement
              Format response as JSON with:
              - "themes": array of common feedback themes
              - "suggestions": array of specific improvement suggestions
              - "style_notes": array of writing style observations
              Keep responses concise and actionable.`
          },
          {
            role: 'user',
            content: `
              Message: "${message.message_text}"
              
              Feedback Summary:
              - Total feedback: ${message.feedback_count}
              - Helpful: ${message.helpful_count}
              - Not helpful: ${message.not_helpful_count}
              - Effectiveness score: ${message.effectiveness_score}
              
              Detailed Feedback:
              ${feedbackText}
              
              Analyze the message and feedback, focusing on what worked well and what could be improved.`
          }
        ],
        response_format: { type: 'json_object' }
      })

      const analysis = JSON.parse(completion.choices[0].message.content)
      
      return {
        message_id: message.id,
        message_text: message.message_text,
        effectiveness_score: parseFloat(message.effectiveness_score),
        feedback_count: parseInt(message.feedback_count),
        helpful_count: parseInt(message.helpful_count),
        not_helpful_count: parseInt(message.not_helpful_count),
        common_themes: analysis.themes,
        improvement_suggestions: analysis.suggestions
      }
    })

    const analyses = await Promise.all(analysisPromises)
    metrics.total_duration = Date.now() - startTime

    return new Response(
      JSON.stringify({
        message_count: filteredMessages.length,
        feedback_count: feedback?.length || 0,
        analyses,
        duration_ms: metrics.total_duration
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
}) 