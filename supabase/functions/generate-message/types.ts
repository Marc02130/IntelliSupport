export interface RateLimitInfo {
  remaining: number
  reset: number
  total: number
}

export interface CustomerContext {
  customer_id: string
  customer_name: string
  preferred_style: string
  preferred_times: Record<string, any>
  communication_frequency: string
  recommendations: Record<string, any>
  recent_communications: Array<{
    message: string
    sent_at: string
    effectiveness: Record<string, any>
  }>
  organization_id: string
  additional_context: Record<string, any>
} 