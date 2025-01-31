import { connect, Redis } from 'https://deno.land/x/redis/mod.ts'
import { getSupabaseClient } from '../preview-message/context.ts'

const MAX_RETRIES = 3
const RETRY_DELAY = 1000 // 1 second
const CACHE_TTL = 60 * 60 // 1 hour in seconds
const CACHE_VERSION = '1' // For cache invalidation

let redisClient: Redis | null = null

async function connectWithRetry(retries = MAX_RETRIES): Promise<Redis> {
  try {
    const client = await connect({
      hostname: Deno.env.get('REDIS_HOST') || 'localhost',
      port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
      password: Deno.env.get('REDIS_PASSWORD'),
      maxRetryCount: 3,
      retryInterval: 1000
    })
    await client.ping() // Verify connection
    return client
  } catch (error) {
    if (retries > 0) {
      console.log(`Redis connection failed, retrying... (${retries} attempts left)`)
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY))
      return connectWithRetry(retries - 1)
    }
    throw new Error(`Failed to connect to Redis after ${MAX_RETRIES} attempts: ${error.message}`)
  }
}

async function getRedis(): Promise<Redis> {
  const connectStartTime = Date.now()
  if (!redisClient) {
    redisClient = await connectWithRetry()
    const connectDuration = Date.now() - connectStartTime
    console.log(`Redis connected in ${connectDuration}ms`)
  }
  return redisClient
}

async function logCacheError(error: Error, operation: string, key: string) {
  console.error(`Redis ${operation} error for key ${key}:`, error)
  const supabase = await getSupabaseClient()
  await supabase
    .from('error_logs')
    .insert({
      service: 'redis',
      operation,
      error: error.message,
      metadata: { key }
    })
}

async function invalidateCache(customerId: string) {
  const client = await getRedis()
  try {
    const pattern = `preview:${customerId}:*`
    const keys = await client.keys(pattern)
    if (keys.length > 0) {
      await client.del(...keys)
      console.log(`Invalidated ${keys.length} cache entries for customer ${customerId}`)
    }
  } catch (error) {
    await logCacheError(error, 'invalidate', `customer:${customerId}`)
  }
}

async function logCacheMetric(
  operation: 'hit' | 'miss' | 'expired' | 'error',
  key: string,
  duration_ms: number,
  metadata?: Record<string, unknown>
) {
  try {
    const supabase = await getSupabaseClient()
    await supabase
      .from('cache_metrics')
      .insert({
        cache_key: key,
        operation,
        duration_ms,
        metadata
      })
  } catch (error) {
    console.error('Failed to log cache metric:', error)
  }
}

function getCacheKey(messageText: string, customerId: string, style?: string): string {
  // Faster hashing for short strings
  const hash = messageText.split('').reduce((h, c) => 
    Math.imul(31, h) + c.charCodeAt(0) | 0, 0x811c9dc5
  ).toString(16)
  
  return `preview:${CACHE_VERSION}:${customerId}:${hash}:${style || 'default'}`
}

export async function getCachedPreview(
  messageText: string,
  customerId: string,
  style?: string
): Promise<string | null> {
  const startTime = Date.now()
  const metrics: Record<string, number> = {}
  const key = getCacheKey(messageText, customerId, style)
  
  try {
    const redisStartTime = Date.now()
    const redis = await getRedis()
    metrics.redis_connect = Date.now() - redisStartTime
    
    try {
      const lookupStartTime = Date.now()
      // Get both value and TTL
      const [value, ttl] = await Promise.all([
        redis.get(key),
        redis.ttl(key)
      ])
      metrics.lookup_duration = Date.now() - lookupStartTime
      metrics.total_duration = Date.now() - startTime
      metrics.request_overhead = Date.now() - startTime - metrics.lookup_duration - metrics.redis_connect
      
      console.log('Cache metrics:', metrics)

      if (!value) {
        await logCacheMetric('miss', key, metrics.total_duration, metrics)
        return null
      }

      // Check if close to expiration
      if (ttl < CACHE_TTL * 0.1) {
        await logCacheMetric('expired', key, metrics.total_duration, { ...metrics, ttl })
        return null
      }

      await logCacheMetric('hit', key, metrics.total_duration, { ...metrics, ttl })
      return value

    } finally {
      // redisPool.release(client)
    }
  } catch (error) {
    metrics.total_duration = Date.now() - startTime
    await logCacheMetric('error', key, metrics.total_duration, { 
      ...metrics, 
      error: error.message 
    })
    return null
  }
}

export async function setCachedPreview(
  messageText: string,
  customerId: string,
  previewText: string,
  style?: string
): Promise<void> {
  const startTime = Date.now()
  const metrics: Record<string, number> = {}
  const key = getCacheKey(messageText, customerId, style)
  
  const redisStartTime = Date.now()
  const redis = await getRedis()
  metrics.redis_connect = Date.now() - redisStartTime
  
  try {
    const writeStartTime = Date.now()
    await redis.set(key, previewText, { ex: CACHE_TTL })
    metrics.write_duration = Date.now() - writeStartTime
    metrics.total_duration = Date.now() - startTime
    
    await logCacheMetric('set', key, metrics.total_duration, metrics)
  } catch (error) {
    metrics.total_duration = Date.now() - startTime
    await logCacheMetric('error', key, metrics.total_duration, { 
      ...metrics,
      error: error.message,
      operation: 'set'
    })
  }
} 