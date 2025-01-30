export interface Database {
  public: {
    Tables: {
      message_generation_logs: {
        Row: {
          id: string
          customer_id: string
          context_type: string
          input_context: Record<string, any>
          generated_message?: string
          model_used?: string
          usage_metrics?: Record<string, any>
          status: 'processing' | 'completed' | 'failed'
          error_message?: string
          error_code?: string
          success: boolean
          generation_time?: number
          started_at: string
          completed_at?: string
        }
        Insert: {
          id?: string
          customer_id: string
          context_type: string
          input_context: Record<string, any>
          generated_message?: string
          model_used?: string
          usage_metrics?: Record<string, any>
          status: 'processing' | 'completed' | 'failed'
          error_message?: string
          error_code?: string
          success?: boolean
          generation_time?: number
          started_at?: string
          completed_at?: string
        }
        Update: {
          id?: string
          customer_id?: string
          context_type?: string
          input_context?: Record<string, any>
          generated_message?: string
          model_used?: string
          usage_metrics?: Record<string, any>
          status?: 'processing' | 'completed' | 'failed'
          error_message?: string
          error_code?: string
          success?: boolean
          generation_time?: number
          started_at?: string
          completed_at?: string
        }
      }
      // Add other table types as needed
    }
  }
} 