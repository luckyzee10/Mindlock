import { prisma } from '../lib/prisma.js';
export async function handleMonthlyReport(job) {
    const month = job.data.month ?? previousMonth();
    const { start, end } = monthRange(month);
    const purchases = await prisma.purchase.findMany({
        where: {
            status: 'completed',
            completedAt: {
                gte: start,
                lt: end
            }
        }
    });
    const donations = await prisma.charityDonation.findMany({
        where: {
            recordedAt: {
                gte: start,
                lt: end
            }
        },
        include: {
            charity: true
        }
    });
    let totalGrossCents = 0;
    let totalNetCents = 0;
    let totalDonationCents = 0;
    for (const purchase of purchases) {
        totalGrossCents += purchase.grossCents;
        totalNetCents += purchase.netCents;
        totalDonationCents += purchase.donationCents;
    }
    const charityMap = new Map();
    for (const donation of donations) {
        const aggregate = charityMap.get(donation.charityId) ?? {
            charityId: donation.charityId,
            charityName: donation.charity?.name ?? 'Unknown',
            donationCents: 0
        };
        aggregate.donationCents += donation.donationCents;
        charityMap.set(donation.charityId, aggregate);
    }
    const charitySummaries = Array.from(charityMap.values()).map((aggregate) => ({
        charityId: aggregate.charityId,
        charityName: aggregate.charityName,
        donationCents: aggregate.donationCents
    }));
    const payload = {
        month,
        totals: {
            purchases: purchases.length,
            grossCents: totalGrossCents,
            netCents: totalNetCents,
            donationCents: totalDonationCents
        },
        charities: charitySummaries
    };
    await prisma.monthlyReport.upsert({
        where: { month },
        update: { payload, generatedAt: new Date() },
        create: { month, payload }
    });
    await job.log(`Monthly report generated for ${month}`);
}
function previousMonth() {
    const date = new Date();
    date.setUTCDate(1);
    date.setUTCHours(0, 0, 0, 0);
    date.setUTCMonth(date.getUTCMonth() - 1);
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}
function monthRange(month) {
    const [year, monthPart] = month.split('-').map((part) => Number(part));
    if (!year || !monthPart) {
        throw new Error(`Invalid month format: ${month}`);
    }
    const start = new Date(Date.UTC(year, monthPart - 1, 1, 0, 0, 0, 0));
    const end = new Date(Date.UTC(year, monthPart, 1, 0, 0, 0, 0));
    return { start, end };
}
