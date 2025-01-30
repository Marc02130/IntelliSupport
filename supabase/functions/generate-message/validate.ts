import { REQUEST_SCHEMA } from './config.ts'

// Custom error types
export class ValidationError extends Error {
  code: string
  details?: any
  
  constructor(message: string, details?: any, code = 'VALIDATION_ERROR') {
    super(message)
    this.code = code
    this.details = details
  }
}

export class RateLimitError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'RateLimitError'
  }
}

// Validation helper functions
function validateCustomerContext(context: any): void {
  if (!context?.customer_id) {
    throw new ValidationError('Missing customer ID', 'customer_id')
  }
  
  if (!context?.customer_name) {
    throw new ValidationError('Missing customer name', 'customer_name')
  }

  if (context?.preferred_style && 
      !Object.values(REQUEST_SCHEMA.properties.customer_context.properties.preferred_style.enum).includes(context.preferred_style)) {
    throw new ValidationError('Invalid preferred style', 'preferred_style')
  }
}

function validateContextType(type: string): void {
  if (!REQUEST_SCHEMA.properties.context_type.enum.includes(type)) {
    throw new ValidationError(
      `Invalid context type. Must be one of: ${REQUEST_SCHEMA.properties.context_type.enum.join(', ')}`,
      'context_type'
    )
  }
}

export function validateRequest(body: any) {
  if (!body.customer_context) {
    throw new ValidationError('Missing customer context')
  }
  if (!body.context_type) {
    throw new ValidationError('Missing context type')
  }
  if (!body.customer_context.customer_id) {
    throw new ValidationError('Missing customer ID')
  }
}

// Error response helper
export function createErrorResponse(error: any) {
  const status = error instanceof ValidationError ? 400 :
                 error instanceof RateLimitError ? 429 : 500
                 
  return new Response(
    JSON.stringify({
      error: error.message,
      code: error instanceof ValidationError ? error.code : 'INTERNAL_ERROR',
      details: error instanceof ValidationError ? error.details : undefined
    }),
    { 
      status,
      headers: { 'Content-Type': 'application/json' }
    }
  )
} 