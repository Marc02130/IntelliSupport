import { defineFunction } from '@aws-amplify/backend';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';

export const api = defineFunction((scope) => {
  return new Function(scope, 'ticketProcessor', {
    runtime: Runtime.NODEJS_18_X,
    handler: 'index.handler',
    code: Code.fromAsset('./function/ticketProcessor'),
    environment: {
      // Add environment variables if needed
    },
  });
});

// Define API routes
export const routes = {
  '/process': {
    POST: {
      function: api,
      authorizer: 'userPool',
    },
  },
};