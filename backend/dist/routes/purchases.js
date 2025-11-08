import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { purchasesRateLimiter, requireAppKey } from '../middleware/auth.js';
import { validateReceiptQueue } from '../lib/queues.js';
const log = (...args) => console.log('[purchases]', ...args);
const logError = (...args) => console.error('[purchases]', ...args);
const createPurchaseSchema = z.object({
    userId: z.string().min(1),
    userEmail: z.string().email().optional(),
    charityId: z.string().min(1),
    charityName: z.string().min(1).optional(),
    productId: z.literal('mindlock.daypass'),
    transactionId: z.string().min(1),
    transactionJWS: z.string().min(10),
    receiptData: z.string().min(10).optional()
});
export const purchasesRouter = Router();
purchasesRouter.post('/', requireAppKey, purchasesRateLimiter, async (req, res, next) => {
    try {
        const payload = createPurchaseSchema.parse(req.body);
        const { userId, userEmail, charityId, charityName, productId, transactionId, transactionJWS, receiptData } = payload;
        const grossCents = 99;
        const appleFeeCents = Math.round(grossCents * 0.15);
        const netCents = grossCents - appleFeeCents;
        const donationCents = Math.round(netCents * 0.15);
        log('Received purchase submission', {
            userId,
            charityId,
            productId,
            transactionId
        });
        const purchase = await prisma.$transaction(async (tx) => {
            await tx.user.upsert({
                where: { id: userId },
                create: { id: userId, email: userEmail },
                update: userEmail ? { email: userEmail } : {}
            });
            if (charityName) {
                await tx.charity.upsert({
                    where: { id: charityId },
                    create: { id: charityId, name: charityName, description: charityName },
                    update: { name: charityName }
                });
            }
            else {
                const existing = await tx.charity.findUnique({ where: { id: charityId } });
                if (!existing) {
                    throw new Error('Unknown charityId; send charityName to create it.');
                }
            }
            const record = await tx.purchase.create({
                data: {
                    userId,
                    charityId,
                    productId,
                    appleTransactionId: transactionId,
                    receiptData: receiptData ?? null,
                    transactionJws: transactionJWS,
                    grossCents,
                    appleFeeCents,
                    netCents,
                    donationCents
                }
            });
            return record;
        });
        log('Stored purchase', { purchaseId: purchase.id, status: purchase.status });
        await validateReceiptQueue.add('validate-receipt', { purchaseId: purchase.id }, {
            jobId: `validate-${purchase.id}`,
            attempts: 5,
            backoff: {
                type: 'exponential',
                delay: 1000
            },
            removeOnComplete: true,
            removeOnFail: false
        });
        log('Enqueued receipt validation job', { purchaseId: purchase.id });
        res.status(202).json({
            purchaseId: purchase.id,
            status: purchase.status
        });
    }
    catch (err) {
        if (err instanceof z.ZodError) {
            logError('Validation error', err.flatten());
            res.status(400).json({ error: err.flatten() });
            return;
        }
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
            logError('Duplicate purchase submission rejected', { code: err.code, meta: err.meta });
            res.status(409).json({ error: 'Purchase already submitted' });
            return;
        }
        logError('Unhandled purchase error', err);
        next(err);
    }
});
