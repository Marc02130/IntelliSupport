import { Redis } from 'https://deno.land/x/redis@v0.29.0/mod.ts'

const redis = new Redis({
  hostname: Deno.env.get('REDIS_HOST') ?? '',
  port: Deno.env.get('REDIS_PORT') ?? '',
  username: Deno.env.get('REDIS_USER') ?? '',
  password: Deno.env.get('REDIS_PASS') ?? '',
})

interface RateLimitResult {
  allowed: boolean
  retryAfter?: string
}

export async function checkRateLimit(
  userId: string | null,
  maxRequests: number,
  windowSeconds: number
): Promise<RateLimitResult> {
  if (!userId) {
    return { allowed: false }
  }

  const key = `rate_limit:${userId}`
  const now = Date.now()
  const windowMs = windowSeconds * 1000

  // Add the current timestamp and remove old entries
  await redis.zAdd(key, { score: now, member: now.toString() })
  await redis.zRemRangeByScore(key, 0, now - windowMs)

  // Get the number of requests in the current window
  const requestCount = await redis.zCard(key)
  
  // Set the key expiration
  await redis.expire(key, windowSeconds)

  if (requestCount > maxRequests) {
    // Get the oldest request timestamp
    const oldestRequest = await redis.zRange(key, 0, 0)
    if (oldestRequest.length > 0) {
      const resetTime = parseInt(oldestRequest[0]) + windowMs
      const retryAfter = Math.ceil((resetTime - now) / 1000)
      return { allowed: false, retryAfter: retryAfter.toString() }
    }
  }

  return { allowed: true }
} 