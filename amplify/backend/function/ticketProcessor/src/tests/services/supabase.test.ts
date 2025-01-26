import { SupabaseService } from '../../services/supabase';
import dotenv from 'dotenv';

dotenv.config({ path: '.env.test' });

describe('SupabaseService', () => {
  let supabase: SupabaseService;

  beforeEach(() => {
    supabase = new SupabaseService();
  });

  it('should connect to Supabase', async () => {
    const data = await supabase.testConnection();
    expect(Array.isArray(data)).toBe(true);
  });
}); 