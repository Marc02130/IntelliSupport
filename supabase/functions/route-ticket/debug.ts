const { createClient } = require("@supabase/supabase-js");
const dotenv = require("dotenv");

dotenv.config();

const supabaseClient = createClient(
  process.env.DB_URL!,
  process.env.SERVICE_ROLE_KEY!
);

async function debugTeamQuery() {
  // Get full team data including tags and knowledge domains
  const { data: teams, error } = await supabaseClient
    .from('teams')
    .select(`
      id,
      name,
      tags:team_tags(
        tag:tags(name)
      ),
      knowledge_domains:team_members(
        user:users(
          user_knowledge_domain(
            domain:knowledge_domain(name),
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