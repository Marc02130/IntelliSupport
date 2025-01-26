import { TicketRoutingService } from '../../services/routing';
import { ChatOpenAI } from "@langchain/openai";
import { RunnableSequence } from "@langchain/core/runnables";

jest.mock('@langchain/openai');
jest.mock('@langchain/core/runnables');

describe('TicketRoutingService', () => {
  let routingService: TicketRoutingService;
  
  beforeEach(() => {
    jest.clearAllMocks();
    
    const mockInvoke = jest.fn().mockResolvedValue(JSON.stringify({
      assignTo: { type: 'team', id: 'team1' },
      confidence: 0.85,
      reasoning: 'Backend expertise required',
      priority: 'high',
      required_skills: ['nodejs', 'aws']
    }));

    (RunnableSequence.from as jest.Mock).mockReturnValue({
      invoke: mockInvoke
    });

    ((ChatOpenAI as unknown) as jest.Mock).mockImplementation(() => ({
      pipe: jest.fn().mockReturnThis(),
      invoke: jest.fn().mockResolvedValue([{
        content: JSON.stringify({
          assignTo: { type: 'team', id: 'team1' },
          confidence: 0.85,
          reasoning: 'Backend expertise required',
          priority: 'high',
          required_skills: ['nodejs', 'aws']
        })
      }])
    }));
    
    routingService = new TicketRoutingService();
  });

  it('should route ticket based on content and metadata', async () => {
    const result = await routingService.routeTicket(
      'Backend API issue with AWS Lambda',
      {
        organization_id: 'org123',
        teams: [{
          id: 'team1',
          tags: ['backend', 'infrastructure']
        }],
        users: [{
          id: 'user1',
          knowledgeDomains: ['API Integration'],
          yearsExperience: 5,
          expertise: ['Technical Support']
        }]
      }
    );
    
    expect(result).toEqual({
      assignTo: { type: 'team', id: 'team1' },
      confidence: 0.85,
      reasoning: 'Backend expertise required',
      priority: 'high',
      required_skills: ['nodejs', 'aws']
    });
  });
});
