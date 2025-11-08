import { Queue, QueueEvents } from 'bullmq';
import { createRedisConnection } from './redis.js';
// Create a single shared connection and fixed prefix so API and worker
// definitely talk to the same Bull keyspace.
export const redisConnection = createRedisConnection();
const bullOptions = { connection: redisConnection, prefix: 'mindlock' };
export const validateReceiptQueue = new Queue('validate-receipt', bullOptions);
export const reportQueue = new Queue('generate-report', bullOptions);
export const validateReceiptEvents = new QueueEvents('validate-receipt', bullOptions);
export const reportEvents = new QueueEvents('generate-report', bullOptions);
