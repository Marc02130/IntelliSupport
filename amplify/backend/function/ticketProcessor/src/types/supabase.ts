export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      embeddings: {
        Row: {
          id: string
          entity_type: string
          entity_id: string
          embedding: number[]
          created_at: string
          updated_at: string
          created_by?: string
          updated_by?: string
        }
        Insert: {
          id?: string
          entity_type: string
          entity_id: string
          embedding: number[]
          created_at?: string
          updated_at?: string
          created_by?: string
          updated_by?: string
        }
        Update: {
          id?: string
          entity_type?: string
          entity_id?: string
          embedding?: number[]
          created_at?: string
          updated_at?: string
          created_by?: string
          updated_by?: string
        }
      }
      tickets: {
        Row: {
          id: string
          subject: string
          description?: string
          status: string
          priority: string
          requester_id?: string
          assignee_id?: string
          team_id?: string
          organization_id?: string
        }
      }
      user_knowledge_domain: {
        Row: {
          id: string
          user_id: string
          knowledge_domain_id: string
          expertise: string
          years_experience: number
          description?: string
          credential?: string
        }
      }
      knowledge_domain: {
        Row: {
          id: string
          name: string
          description?: string
        }
      }
    }
  }
} 