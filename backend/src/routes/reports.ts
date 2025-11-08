import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { reportQueue } from '../lib/queues.js';
import { requireAdminKey } from '../middleware/auth.js';

const runSchema = z.object({
  month: z
    .string()
    .regex(/^\d{4}-\d{2}$/, 'Month must be formatted YYYY-MM')
    .optional()
});

export const reportsRouter = Router();

reportsRouter.get('/latest', requireAdminKey, async (_req, res, next) => {
  try {
    const report = await prisma.monthlyReport.findFirst({
      orderBy: { month: 'desc' }
    });
    if (!report) {
      res.status(404).json({ error: 'No reports generated yet' });
      return;
    }
    res.json(report);
  } catch (err) {
    next(err);
  }
});

reportsRouter.post('/run', requireAdminKey, async (req, res, next) => {
  try {
    const parsed = runSchema.parse(req.body ?? {});
    const month = parsed.month ?? previousMonth();
    await reportQueue.add(
      'monthly-report',
      { month },
      {
        jobId: `monthly-report-${month}-${Date.now()}`,
        removeOnComplete: true,
        removeOnFail: false
      }
    );
    res.status(202).json({ month });
  } catch (err) {
    if (err instanceof z.ZodError) {
      res.status(400).json({ error: err.flatten() });
      return;
    }
    next(err);
  }
});

function previousMonth(): string {
  const now = new Date();
  now.setUTCDate(1);
  now.setUTCHours(0, 0, 0, 0);
  now.setUTCMonth(now.getUTCMonth() - 1);
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}
