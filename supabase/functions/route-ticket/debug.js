import { createClient } from "@supabase/supabase-js";
import * as dotenv from "dotenv";
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '.env') });

// Add debugging before creating client
console.log('Environment check:');
console.log('DB_URL:', process.env.DB_URL ? 'Set' : 'Not set');
console.log('SERVICE_ROLE_KEY:', process.env.SERVICE_ROLE_KEY ? 'Set' : 'Not set');

// Add auth override with explicit headers
const supabaseClient = createClient(
  process.env.DB_URL || '',
  process.env.SERVICE_ROLE_KEY || '',
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false
    },
    global: {
      headers: {
        Authorization: `Bearer ${process.env.SERVICE_ROLE_KEY}`
      }
    }
  }
);

// Add more detailed debugging
console.log('\nSupabase client config:');
console.log('URL:', supabaseClient.supabaseUrl);
console.log('Auth header present:', Boolean(supabaseClient.supabaseKey));
console.log('Authorization header:', Boolean(supabaseClient.headers?.Authorization));
console.log('Using service role:', process.env.SERVICE_ROLE_KEY?.startsWith('eyJ'));

async function debugTeamQuery() {
  const { data: teams, error } = await supabaseClient
    .from('teams')
    .select(`
      id,
      name,
      tags:team_tags!team_tags_team_id_fkey(
        tag:tags!team_tags_tag_id_fkey(name)
      ),
      knowledge_domains:team_members!team_members_team_id_fkey(
        user:users!fk_team_members_user(
          user_knowledge_domain:user_knowledge_domain!fk_user_knowledge_domain_user(
            domain:knowledge_domain!fk_user_knowledge_domain_knowledge(name),
            expertise
          )
        )
      )
    `)
    .limit(1);

  if (error) {
    console.error('Query error:', error);
    return;
  }

  console.log('Full response:', JSON.stringify(teams, null, 2));
  
  if (teams?.[0]) {
    const team = teams[0];
    console.log('\nTeam structure analysis:');
    console.log('- Has knowledge_domains:', Boolean(team.knowledge_domains));
    console.log('- First member:', team.knowledge_domains?.[0]);
    console.log('- User structure:', team.knowledge_domains?.[0]?.user);
    console.log('- Knowledge domains:', team.knowledge_domains?.[0]?.user?.user_knowledge_domain);
  }
}

debugTeamQuery().catch(console.error); 