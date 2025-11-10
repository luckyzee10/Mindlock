import { Router } from 'express';
import { requireAdminKey } from '../middleware/auth.js';
import { validateReceiptQueue, reportQueue } from '../lib/queues.js';
export const debugRouter = Router();
debugRouter.get('/debug/queues', requireAdminKey, async (_req, res, next) => {
    try {
        if (!validateReceiptQueue || !reportQueue) {
            res.status(200).json({ queues: 'disabled' });
            return;
        }
        const [vr, rep] = await Promise.all([
            validateReceiptQueue.getJobCounts(),
            reportQueue.getJobCounts()
        ]);
        res.json({ validateReceipt: vr, generateReport: rep });
    }
    catch (err) {
        next(err);
    }
});
