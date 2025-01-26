import { defineFunction } from '@aws-amplify/backend';
import { Rule, Schedule } from 'aws-cdk-lib/aws-events';
import { LambdaFunction } from 'aws-cdk-lib/aws-events-targets';
import { secrets } from '../../secrets';

export const ticketProcessor = defineFunction((scope) => {
  const lambda = new Function(scope, 'ticketProcessor', {
    runtime: Runtime.NODEJS_18_X,
    handler: 'index.handler',
    code: Code.fromAsset('./src'),
    timeout: Duration.minutes(5),
    memorySize: 1024,
    environment: {
      PINECONE_INDEX: 'support-tickets',
      AWS_REGION: process.env.AWS_REGION || 'us-west-2'
    }
  });

  // Add EventBridge rule to trigger every 10 minutes
  new Rule(scope, 'TicketProcessorSchedule', {
    schedule: Schedule.rate(Duration.minutes(10)),
    targets: [new LambdaFunction(lambda)]
  });

  return lambda;
});