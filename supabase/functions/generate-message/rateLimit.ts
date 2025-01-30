import { connect } from 'https://deno.land/x/redis@v0.29.0/mod.ts'
import { RATE_LIMITS } from './config.ts'

const RATE_LIMIT = 100 // requests per hour
const WINDOW = 3600 // 1 hour in seconds

interface RateLimitInfo {
  remaining: number
  reset: number
  total: number
}

export async function checkRateLimit(customerId: string): Promise<RateLimitInfo> {
  const redis = await connect({
    hostname: Deno.env.get('REDIS_HOST') || 'localhost',
    port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
    password: Deno.env.get('REDIS_PASSWORD'),
  })

  const key = `rate_limit:${customerId}`
  const count = await redis.incr(key)
  
  if (count === 1) {
    await redis.expire(key, WINDOW)
  }

  const ttl = await redis.ttl(key)
  
  if (count > RATE_LIMIT) {
    throw new Error('Rate limit exceeded')
  }

  return {
    remaining: RATE_LIMIT - count,
    reset: Date.now() + (ttl * 1000),
    total: RATE_LIMIT
  }
}

// Add rate limit headers to response
export function addRateLimitHeaders(headers: Headers, info: RateLimitInfo) {
  headers.set('X-RateLimit-Limit', info.total.toString())
  headers.set('X-RateLimit-Remaining', info.remaining.toString())
  headers.set('X-RateLimit-Reset', info.reset.toString())
} 