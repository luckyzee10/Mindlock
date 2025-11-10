import { Redis } from 'ioredis';
import { config } from './config.js';

/**
 * Creates a Redis connection if REDIS_URL is set; otherwise returns null.
 * This lets the API run without Redis for environments where queues are disabled.
 */
export function createRedisConnection(): Redis | null {
  if (!config.redisUrl) {
    return null;
  }
  const client = new Redis(config.redisUrl, {
    // BullMQ requires this to be null to avoid crashing future releases.
    maxRetriesPerRequest: null,
  });
  client.on('error', (err) => {
    console.error('[redis] error', err);
  });
  return client;
}

// Do NOT create a global connection at import time; keep optional.
export const redis: Redis | null = null;
