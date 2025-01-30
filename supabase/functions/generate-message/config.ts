export const MODELS = {
  GPT4: "gpt-4",
  GPT35: "gpt-3.5-turbo"
}

export const PROMPT_TEMPLATES = {
  CUSTOMER_SERVICE: {
    role: "You are a helpful customer service agent.",
    style: {
      FORMAL: "Maintain a professional and formal tone",
      FRIENDLY: "Be warm and approachable while remaining professional",
      TECHNICAL: "Use precise technical language when appropriate"
    }
  },
  TECHNICAL_SUPPORT: {
    role: "You are a technical support specialist.",
    style: {
      DETAILED: "Provide step-by-step technical instructions",
      SIMPLIFIED: "Explain technical concepts in simple terms",
      DIAGNOSTIC: "Focus on troubleshooting and problem diagnosis"
    }
  },
  SALES: `You are an AI assistant specializing in sales communications...`
}

// Rate limiting configuration
export const RATE_LIMITS = {
  MAX_REQUESTS_PER_MINUTE: 60,
  MAX_TOKENS_PER_REQUEST: 1000,
  COOLDOWN_PERIOD: 1000 // milliseconds
}

// Request validation schema
export const REQUEST_SCHEMA = {
  required: ['customer_context', 'context_type'],
  properties: {
    customer_context: {
      type: 'object',
      required: ['customer_id', 'customer_name'],
      properties: {
        customer_id: { type: 'string' },
        customer_name: { type: 'string' },
        preferred_style: { type: 'string' }
      }
    },
    context_type: {
      type: 'string',
      enum: ['CUSTOMER_SERVICE', 'TECHNICAL_SUPPORT', 'SALES']
    }
  }
} 