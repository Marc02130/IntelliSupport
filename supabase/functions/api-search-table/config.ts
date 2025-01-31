export const config = {
  DB_URL: Deno.env.get('DB_URL') ?? '',
  SERVICE_ROLE_KEY: Deno.env.get('SERVICE_ROLE_KEY') ?? ''
} 