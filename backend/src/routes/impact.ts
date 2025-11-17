import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAppKey } from '../middleware/auth.js';

const impactRouter = Router();

const summaryQuerySchema = z.object({
  userId: z.string().min(1)
});

const monthlyBudgets = {
  'mindlock.plus.monthly': 255, // cents
  'mindlock.plus.annual': 204 // monthly allocation of annual donation
} as const;

const impactReportSchema = z.object({
  userId: z.string().min(1),
  userEmail: z.string().email().optional(),
  subscriptionTier: z.enum(['mindlock.plus.monthly', 'mindlock.plus.annual']),
  month: z.string().regex(/^[0-9]{4}-[0-9]{2}$/),
  impactPoints: z.number().int().min(0),
  streakDays: z.number().int().min(0).optional(),
  multiplier: z.number().int().min(1).optional()
});

impactRouter.get('/summary', requireAppKey, async (req, res, next) => {
  try {
    const { userId } = summaryQuerySchema.parse(req.query);

    const donations = await prisma.charityDonation.findMany({
      where: {
        purchase: {
          userId,
          status: 'completed'
        }
      },
      include: {
        charity: {
          select: {
            id: true,
            name: true
          }
        }
      },
      orderBy: {
        recordedAt: 'desc'
      }
    });

    const totalDonationCents = donations.reduce((sum, donation) => sum + donation.donationCents, 0);
    const startOfMonth = firstDayOfCurrentMonth();
    const monthDonationCents = donations
      .filter((donation) => donation.recordedAt >= startOfMonth)
      .reduce((sum, donation) => sum + donation.donationCents, 0);

    const charityTotals = new Map<
      string,
      { charityId: string; charityName: string; donationCents: number }
    >();

    for (const donation of donations) {
      const id = donation.charityId;
      const existing = charityTotals.get(id);
      if (existing) {
        existing.donationCents += donation.donationCents;
      } else {
        charityTotals.set(id, {
          charityId: id,
          charityName: donation.charity?.name ?? 'Unknown',
          donationCents: donation.donationCents
        });
      }
    }

    const charities = Array.from(charityTotals.values()).sort(
      (a, b) => b.donationCents - a.donationCents
    );

    res.json({
      totalDonationCents,
      monthDonationCents,
      totalDonations: donations.length,
      charities
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      res.status(400).json({ error: err.flatten() });
      return;
    }
    next(err);
  }
});

impactRouter.post('/report', requireAppKey, async (req, res, next) => {
  try {
    const payload = impactReportSchema.parse(req.body);
    const { userId, userEmail, subscriptionTier, month, impactPoints, streakDays, multiplier } =
      payload;

    const budgetCents = monthlyBudgets[subscriptionTier];
    if (budgetCents == null) {
      throw new Error(`Unsupported tier: ${subscriptionTier}`);
    }

    const cappedPoints = Math.max(0, Math.min(impactPoints, 60));
    const projectedDonationCents = Math.round((budgetCents * cappedPoints) / 60);

    await prisma.$transaction(async (tx) => {
      await tx.user.upsert({
        where: { id: userId },
        create: { id: userId, email: userEmail },
        update: userEmail ? { email: userEmail } : {}
      });

      await tx.impactLedger.upsert({
        where: { userId_month: { userId, month } },
        update: {
          subscriptionTier,
          impactPoints,
          cappedPoints,
          streakDays: streakDays ?? null,
          multiplier: multiplier ?? null,
          budgetCents,
          projectedDonationCents
        },
        create: {
          userId,
          month,
          subscriptionTier,
          impactPoints,
          cappedPoints,
          streakDays: streakDays ?? null,
          multiplier: multiplier ?? null,
          budgetCents,
          projectedDonationCents
        }
      });
    });

    res.json({
      month,
      impactPoints,
      cappedPoints,
      projectedDonationCents
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      res.status(400).json({ error: err.flatten() });
      return;
    }
    next(err);
  }
});

function firstDayOfCurrentMonth(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0, 0, 0, 0));
}

export { impactRouter };
