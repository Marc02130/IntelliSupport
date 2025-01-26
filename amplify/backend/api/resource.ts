import { defineBackend } from '@aws-amplify/backend';
import { ticketProcessor } from '../function/ticketProcessor/resource';

const backend = defineBackend({
  api: ticketProcessor
});

export { backend }; 