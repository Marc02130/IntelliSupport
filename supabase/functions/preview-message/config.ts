export const MODELS = {
  GPT4: "gpt-4",
  GPT35: "gpt-3.5-turbo"
}

export const PROMPT_TEMPLATES = {
  IMPROVEMENT: `Review and suggest improvements for this draft message:
    {draft}
    
    Consider:
    1. Tone and style matching
    2. Clarity and effectiveness
    3. Previous communication patterns
    4. Customer preferences`,

  SYSTEM_CONTEXT: `You are a helpful assistant providing real-time suggestions for customer communications.
    Focus on:
    - Maintaining consistent style
    - Personalizing based on history
    - Improving clarity and impact
    - Matching communication preferences`
} 