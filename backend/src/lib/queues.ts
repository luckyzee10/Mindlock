import { Queue } from 'bullmq';
import { createRedisConnection } from './redis.js';

// Create a single shared connection and fixed prefix so API and worker
// definitely talk to the same Bull keyspace.
export const redisConnection = createRedisConnection();
const bullOptions = { connection: redisConnection, prefix: 'mindlock' } as const;

export const validateReceiptQueue = new Queue('validate-receipt', bullOptions);
export const reportQueue = new Queue('generate-report', bullOptions);
