export const MODELS = {
  GPT4: "gpt-4",
  GPT35: "gpt-3.5-turbo"
}

export const PROMPT_TEMPLATES = {
  SYSTEM_CONTEXT: `You are a helpful assistant providing real-time suggestions for customer communications.
    Keep responses under 100 words.
    Focus on clarity and professionalism.
    Use technical language appropriately.`,

  IMPROVEMENT: `Review and suggest improvements for this draft message:
    {draft}
    
    Improve while keeping core message brief and clear.`
}

export const config = {
  DB_URL: Deno.env.get('DB_URL') ?? '',
  SERVICE_ROLE_KEY: Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  OPENAI_API_KEY: Deno.env.get('OPENAI_API_KEY') ?? '',
  OPENAI_MODEL: Deno.env.get('OPENAI_MODEL') ?? ''
} 