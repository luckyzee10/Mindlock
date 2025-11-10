import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { generateMonthlyReport } from '../jobs/monthlyReport.js';
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
    const report = await generateMonthlyReport(month);
    res.status(200).json(report);
  } catch (err) {
    if (err instanceof z.ZodError) {
      res.status(400).json({ error: err.flatten() });
      return;
    }
    next(err);
  }
});

// GET /v1/reports/export?month=YYYY-MM&recompute=1
// Streams a CSV with per-charity donation totals for the requested month.
reportsRouter.get('/export', requireAdminKey, async (req, res, next) => {
  const querySchema = z.object({
    month: z.string().regex(/^\d{4}-\d{2}$/).optional(),
    recompute: z.string().optional()
  });

  try {
    const q = querySchema.parse(req.query);
    const doRecompute = q.recompute === '1' || q.recompute === 'true';

    // Choose month: if provided, use it. Otherwise, use the latest saved report if any; else previous month.
    let month = q.month;
    if (!month) {
      const latest = await prisma.monthlyReport.findFirst({ orderBy: { month: 'desc' } });
      month = latest?.month ?? previousMonth();
    }

    // Load or compute the report payload for the month
    let payload: any;
    if (doRecompute) {
      const r = await generateMonthlyReport(month);
      payload = r.payload;
    } else {
      const existing = await prisma.monthlyReport.findUnique({ where: { month } });
      if (existing) {
        payload = existing.payload as any;
      } else {
        const r = await generateMonthlyReport(month);
        payload = r.payload;
      }
    }

    const charities: Array<{ charityId: string; charityName: string; donationCents: number }>
      = Array.isArray(payload?.charities) ? payload.charities : [];

    // Build CSV
    const header = 'month,charity_id,charity_name,donation_cents,donation_usd';
    const rows = charities.map((c) => {
      const cents = Number(c.donationCents) || 0;
      const usd = (cents / 100).toFixed(2);
      const name = (c.charityName ?? '').toString().replace(/"/g, '""');
      return `${month},${c.charityId},"${name}",${cents},${usd}`;
    });
    const totalCents = charities.reduce((sum, c) => sum + (Number(c.donationCents) || 0), 0);
    const totalUsd = (totalCents / 100).toFixed(2);
    rows.push(`TOTALS,,,${totalCents},${totalUsd}`);

    const csv = [header, ...rows].join('\n');
    const filename = `mindlock_report_${month}.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.status(200).send(csv);
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
