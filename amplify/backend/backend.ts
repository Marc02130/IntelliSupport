import { defineBackend } from '@aws-amplify/backend';
import { auth } from '../auth/resource';
import { ticketProcessor } from './function/ticketProcessor/resource';

export const backend = defineBackend({
  auth,
  api: ticketProcessor
});