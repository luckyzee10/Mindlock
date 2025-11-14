import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { requireAppKey } from '../middleware/auth.js';
const impactRouter = Router();
const summaryQuerySchema = z.object({
    userId: z.string().min(1)
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
        const charityTotals = new Map();
        for (const donation of donations) {
            const id = donation.charityId;
            const existing = charityTotals.get(id);
            if (existing) {
                existing.donationCents += donation.donationCents;
            }
            else {
                charityTotals.set(id, {
                    charityId: id,
                    charityName: donation.charity?.name ?? 'Unknown',
                    donationCents: donation.donationCents
                });
            }
        }
        const charities = Array.from(charityTotals.values()).sort((a, b) => b.donationCents - a.donationCents);
        res.json({
            totalDonationCents,
            monthDonationCents,
            totalDonations: donations.length,
            charities
        });
    }
    catch (err) {
        if (err instanceof z.ZodError) {
            res.status(400).json({ error: err.flatten() });
            return;
        }
        next(err);
    }
});
function firstDayOfCurrentMonth() {
    const now = new Date();
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0, 0, 0, 0));
}
export { impactRouter };
