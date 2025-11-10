import { Queue } from 'bullmq';
import { createRedisConnection } from './redis.js';

// Create a single shared connection; if absent, queues are disabled.
export const redisConnection = createRedisConnection();
const bullOptions = redisConnection ? { connection: redisConnection, prefix: 'mindlock' } : null;

export const validateReceiptQueue = bullOptions
  ? new Queue('validate-receipt', bullOptions)
  : null;
export const reportQueue = bullOptions ? new Queue('generate-report', bullOptions) : null;
