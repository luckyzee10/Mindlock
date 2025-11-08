import { Queue, QueueEvents } from 'bullmq';
import { createRedisConnection } from './redis.js';

const queueConnection = {
  connection: createRedisConnection()
};

export const validateReceiptQueue = new Queue('validate-receipt', queueConnection);
export const reportQueue = new Queue('generate-report', queueConnection);

export const validateReceiptEvents = new QueueEvents('validate-receipt', {
  connection: createRedisConnection()
});
export const reportEvents = new QueueEvents('generate-report', {
  connection: createRedisConnection()
});
