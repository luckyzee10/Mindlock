import { Redis } from 'ioredis';
import { config } from './config.js';
export function createRedisConnection() {
    const client = new Redis(config.redisUrl);
    client.on('error', (err) => {
        console.error('[redis] error', err);
    });
    return client;
}
export const redis = createRedisConnection();
