import OpenAI from 'openai';
import { ChatCompletionMessageParam } from 'openai/resources/chat/completions';
import { RoutingDecision } from '../types';

export class OpenAIService {
  private client: OpenAI;
  private embeddingModel: string;
  private chatModel: string;

  constructor() {
    this.client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });
    // Use environment variables with fallbacks
    this.embeddingModel = process.env.OPENAI_EMBEDDING_MODEL || 'text-embedding-3-large';
    this.chatModel = process.env.OPENAI_MODEL || 'gpt-4-turbo-preview';
  }

  async generateEmbedding(text: string): Promise<number[]> {
    try {
      const response = await this.client.embeddings.create({
        model: this.embeddingModel,
        input: text,
        encoding_format: 'float'
      });
      return response.data[0].embedding;
    } catch (error) {
      throw new Error('Failed to generate embedding');
    }
  }
  

  async analyzeTicket(text: string): Promise<RoutingDecision> {
    try {
      const completion = await this.client.chat.completions.create({
        model: this.chatModel,
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant that analyzes support tickets.'
          },
          { role: 'user', content: text }
        ],
        temperature: 0.7
      });

      const response = completion.choices[0]?.message?.content;
      if (!response) {
        throw new Error('Empty response from OpenAI');
      }

      return JSON.parse(response) as RoutingDecision;
    } catch (error) {
      if (error instanceof Error) {
        if (error.message === 'Empty response from OpenAI') {
          throw error;  // Re-throw the empty response error
        }
      }
      throw new Error('Failed to analyze ticket');
    }
  }

  async generateSummary(text: string): Promise<string> {
    try {
      const completion = await this.client.chat.completions.create({
        model: this.chatModel,
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant that summarizes text.'
          },
          { role: 'user', content: text }
        ],
        temperature: 0.7
      });

      return completion.choices[0]?.message?.content || '';
    } catch (error) {
      throw new Error('Failed to generate summary');
    }
  }

  async suggestResponse(
    text: string,
    similarTickets: { content: string }[] = [],
    tags: string[] = []
  ): Promise<string> {
    try {
      const messages: ChatCompletionMessageParam[] = [
        {
          role: 'system',
          content: `You are a helpful assistant that suggests responses to support tickets. ${
            tags.length > 0 ? `The ticket involves ${tags.join(', ')}.` : ''
          }`
        },
        {
          role: 'user',
          content: `Ticket: ${text}\n\n${
            similarTickets.length > 0
              ? `Similar Tickets: ${similarTickets.map(t => t.content).join('\n')}`
              : ''
          }`
        }
      ];

      const completion = await this.client.chat.completions.create({
        model: this.chatModel,
        messages,
        temperature: 0.7
      });

      return completion.choices[0]?.message?.content || '';
    } catch (error) {
      throw new Error('Failed to suggest response');
    }
  }
}

// Initialize function for the service
export function initOpenAI(): OpenAIService {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY is not set');
  }

  return new OpenAIService();
} 