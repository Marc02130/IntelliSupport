import { connect } from 'https://deno.land/x/redis@v0.29.0/mod.ts'

const RATE_LIMIT = 60 // requests per minute
const WINDOW = 60 // 1 minute in seconds

export async function checkRateLimit(customerId: string) {
  const redis = await connect({
    hostname: Deno.env.get('REDIS_HOST') || 'localhost',
    port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
    password: Deno.env.get('REDIS_PASSWORD'),
  })

  const key = `preview_rate_limit:${customerId}`
  const count = await redis.incr(key)
  
  if (count === 1) {
    await redis.expire(key, WINDOW)
  }

  const ttl = await redis.ttl(key)
  
  if (count > RATE_LIMIT) {
    throw new Error('Rate limit exceeded for preview requests')
  }

  return {
    remaining: RATE_LIMIT - count,
    reset: Date.now() + (ttl * 1000),
    limit: RATE_LIMIT
  }
} 