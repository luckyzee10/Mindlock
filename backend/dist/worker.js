import { Worker } from 'bullmq';
import { redisConnection } from './lib/queues.js';
import { handleValidateReceipt } from './jobs/validateReceipt.js';
import { handleMonthlyReport } from './jobs/monthlyReport.js';
import { reportQueue } from './lib/queues.js';
async function bootstrap() {
    await ensureMonthlyJob();
    const validateWorker = new Worker('validate-receipt', handleValidateReceipt, {
        connection: redisConnection,
        prefix: 'mindlock'
    });
    const reportWorker = new Worker('generate-report', handleMonthlyReport, {
        connection: redisConnection,
        prefix: 'mindlock'
    });
    validateWorker.on('ready', () => {
        console.log('[worker] validate-receipt ready');
    });
    validateWorker.on('active', (job) => {
        console.log(`[worker] validate active ${job.id}`);
    });
    validateWorker.on('completed', (job) => {
        console.log(`[worker] validate completed ${job?.id}`);
    });
    validateWorker.on('failed', (job, err) => {
        console.error(`[worker] validate job ${job?.id} failed`, err);
    });
    reportWorker.on('ready', () => {
        console.log('[worker] generate-report ready');
    });
    reportWorker.on('active', (job) => {
        console.log(`[worker] report active ${job.id}`);
    });
    reportWorker.on('completed', (job) => {
        console.log(`[worker] report completed ${job?.id}`);
    });
    reportWorker.on('failed', (job, err) => {
        console.error(`[worker] report job ${job?.id} failed`, err);
    });
    const shutdown = async () => {
        console.log('[worker] shutting down');
        await Promise.allSettled([validateWorker.close(), reportWorker.close()]);
        process.exit(0);
    };
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
}
bootstrap().catch((err) => {
    console.error('[worker] bootstrap error', err);
    process.exit(1);
});
async function ensureMonthlyJob() {
    await reportQueue.add('monthly-report', {}, {
        jobId: 'monthly-report-cron',
        repeat: {
            pattern: '0 5 1 * *',
            tz: 'UTC'
        },
        removeOnComplete: true
    });
}
