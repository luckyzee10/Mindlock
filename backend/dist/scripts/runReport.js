import { reportQueue } from '../lib/queues.js';
async function main() {
    const [, , monthArg] = process.argv;
    const month = monthArg ?? undefined;
    await reportQueue.add('monthly-report', { month }, {
        jobId: `manual-report-${month ?? 'latest'}-${Date.now()}`,
        removeOnComplete: true,
        removeOnFail: false
    });
    console.log(`[reports] enqueued job for month ${month ?? 'previous'}`);
    process.exit(0);
}
main().catch((err) => {
    console.error('[reports] failed to enqueue report job', err);
    process.exit(1);
});
