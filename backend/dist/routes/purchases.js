import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../lib/prisma.js';
import { purchasesRateLimiter, requireAppKey } from '../middleware/auth.js';
import { verifyStoreKitTransaction } from '../lib/storekit.js';
const log = (...args) => console.log('[purchases]', ...args);
const logError = (...args) => console.error('[purchases]', ...args);
const allowedProducts = {
    'mindlock.plus.monthly': { grossCents: 999 },
    'mindlock.plus.annual': { grossCents: 5999 }
};
const createPurchaseSchema = z.object({
    userId: z.string().min(1),
    userEmail: z.string().email().optional(),
    charityId: z.string().min(1),
    charityName: z.string().min(1).optional(),
    productId: z.enum(['mindlock.plus.monthly', 'mindlock.plus.annual']),
    transactionId: z.string().min(1),
    transactionJWS: z.string().min(10),
    receiptData: z.string().min(10).optional(),
    subscriptionTier: z.string().optional()
});
export const purchasesRouter = Router();
purchasesRouter.post('/', requireAppKey, purchasesRateLimiter, async (req, res, next) => {
    try {
        const payload = createPurchaseSchema.parse(req.body);
        const { userId, userEmail, charityId, charityName, productId, transactionId, transactionJWS, receiptData } = payload;
        const pricing = allowedProducts[productId];
        if (!pricing) {
            throw new Error(`Unsupported product: ${productId}`);
        }
        const grossCents = pricing.grossCents;
        const appleFeeCents = Math.round(grossCents * 0.15);
        const netCents = grossCents - appleFeeCents;
        const donationCents = Math.round(netCents * 0.20);
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
        // Inline validation using StoreKit 2 JWS
        try {
            const txn = await verifyStoreKitTransaction(transactionJWS);
            if (txn.transactionId !== transactionId) {
                throw new Error('Transaction ID mismatch');
            }
            if (txn.productId !== productId) {
                throw new Error('Product ID mismatch');
            }
            const dateMs = typeof txn.purchaseDate === 'string' ? Number(txn.purchaseDate) : txn.purchaseDate;
            const completedAt = Number.isFinite(dateMs) ? new Date(Number(dateMs)) : new Date();
            await prisma.$transaction(async (tx) => {
                await tx.purchase.update({
                    where: { id: purchase.id },
                    data: { status: 'completed', completedAt, failureReason: null }
                });
                await tx.charityDonation.upsert({
                    where: { purchaseId: purchase.id },
                    create: {
                        purchaseId: purchase.id,
                        charityId,
                        donationCents
                    },
                    update: {}
                });
            });
            res.status(200).json({ purchaseId: purchase.id, status: 'completed' });
        }
        catch (e) {
            const reason = e.message ?? 'Unknown validation error';
            logError('Inline validation failed', reason);
            await prisma.purchase.update({
                where: { id: purchase.id },
                data: { status: 'failed', failureReason: reason }
            });
            res.status(400).json({ error: reason, purchaseId: purchase.id, status: 'failed' });
        }
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
