import { ChatOpenAI } from "@langchain/openai";
import { ChatPromptTemplate, PromptTemplate } from "@langchain/core/prompts";
import { StringOutputParser } from "@langchain/core/output_parsers";
import { RunnableSequence } from "@langchain/core/runnables";

interface TeamMetadata {
  id: string;
  tags: string[];
}

interface UserMetadata {
  id: string;
  knowledgeDomains: string[];
  yearsExperience: number;
  expertise: string[];
}

interface RoutingMetadata {
  organization_id: string;
  teams: TeamMetadata[];
  users: UserMetadata[];
}

export class TicketRoutingService {
  private model: ChatOpenAI;
  private routingChain: RunnableSequence;

  constructor() {
    this.model = new ChatOpenAI({
      modelName: process.env.OPENAI_MODEL || "gpt-4o-mini",
      temperature: 0
    });

    const prompt = ChatPromptTemplate.fromTemplate(`
      Route this ticket based on the content and available teams/users.
      
      Ticket: {ticket}
      
      Available teams and users: {metadata}
      
      Provide your response in the following JSON format:
      {format_instructions}
    `);

    this.routingChain = RunnableSequence.from([
      prompt,
      this.model,
      new StringOutputParser()
    ]);
  }

  async routeTicket(content: string, metadata: RoutingMetadata) {
    console.log('Metadata:', JSON.stringify(metadata, null, 2));
    const response = await this.routingChain.invoke({
      ticket: content,
      metadata: JSON.stringify(metadata),
      format_instructions: `{
        "assignTo": { "type": "team|user", "id": "string" },
        "confidence": "number between 0-1",
        "reasoning": "string",
        "priority": "low|medium|high",
        "required_skills": ["array of strings"]
      }`
    });
    
    return JSON.parse(response);
  }
} 