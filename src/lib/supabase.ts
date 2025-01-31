import { createClient } from '@supabase/supabase-js'
import { useEffect, useState } from 'react'

const supabaseUrl = process.env.VITE_SUPABASE_URL as string
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY as string

const supabase = createClient(supabaseUrl, supabaseKey)

export function useSupabase() {
  return { supabase }
} 