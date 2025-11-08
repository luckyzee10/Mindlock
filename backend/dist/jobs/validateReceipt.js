import fetch from 'node-fetch';
import { prisma } from '../lib/prisma.js';
import { config } from '../lib/config.js';
import { verifyStoreKitTransaction } from '../lib/storekit.js';
const retryableStatuses = new Set([21002, 21005, 21009]);
export async function handleValidateReceipt(job) {
    const { purchaseId } = job.data;
    const purchase = await prisma.purchase.findUnique({
        where: { id: purchaseId }
    });
    if (!purchase) {
        await job.log(`Purchase ${purchaseId} missing; skipping`);
        return;
    }
    if (purchase.status !== 'pending_validation') {
        await job.log(`Purchase ${purchaseId} already processed (${purchase.status})`);
        return;
    }
    try {
        if (purchase.receiptData) {
            await validateViaReceipt(job, purchase);
        }
        else {
            await validateViaTransactionJws(job, purchase);
        }
        await job.log(`Purchase ${purchaseId} validated successfully`);
    }
    catch (err) {
        if (err instanceof RetryableError) {
            await job.log(`Retryable Apple error: ${err.message}`);
            throw err;
        }
        await markFailed(purchaseId, err instanceof Error ? err.message : 'Unknown error');
    }
}
class RetryableError extends Error {
}
async function validateWithApple(job, receiptData) {
    const payload = {
        'receipt-data': receiptData,
        password: config.appleSharedSecret,
        'exclude-old-transactions': true
    };
    const json = await postReceipt(config.appleVerifyReceiptUrl, payload);
    if (json.status === 21007 && config.appleVerifyReceiptUrl.includes('buy.itunes.apple.com')) {
        await job.log('Received 21007, retrying against sandbox endpoint');
        const sandboxJson = await postReceipt('https://sandbox.itunes.apple.com/verifyReceipt', payload);
        return interpretAppleResponse(sandboxJson);
    }
    return interpretAppleResponse(json);
}
async function postReceipt(url, payload) {
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        return (await response.json());
    }
    catch (error) {
        throw new RetryableError(`Failed to reach Apple: ${error.message}`);
    }
}
function interpretAppleResponse(json) {
    if (json.status === 0) {
        return json;
    }
    if (retryableStatuses.has(json.status)) {
        throw new RetryableError(`Apple returned retryable status ${json.status}`);
    }
    throw new Error(`Apple returned status ${json.status}`);
}
function findTransaction(json, appleTransactionId) {
    if (!appleTransactionId) {
        return undefined;
    }
    const candidates = [
        ...(json.latest_receipt_info ?? []),
        ...(json.receipt?.in_app ?? [])
    ];
    return candidates.find((entry) => entry.transaction_id === appleTransactionId);
}
async function markFailed(purchaseId, reason) {
    await prisma.purchase.update({
        where: { id: purchaseId },
        data: {
            status: 'failed',
            failureReason: reason
        }
    });
}
async function validateViaReceipt(job, purchase) {
    const result = await validateWithApple(job, purchase.receiptData);
    const match = findTransaction(result, purchase.appleTransactionId);
    if (!match) {
        await markFailed(purchase.id, `Transaction ${purchase.appleTransactionId ?? 'unknown'} not present in receipt`);
        return;
    }
    const completedAt = match.purchase_date_ms
        ? new Date(Number(match.purchase_date_ms))
        : new Date();
    await markCompleted(purchase, completedAt);
}
async function validateViaTransactionJws(job, purchase) {
    if (!purchase.transactionJws) {
        await markFailed(purchase.id, 'Transaction JWS missing');
        return;
    }
    const payload = await verifyStoreKitTransaction(purchase.transactionJws);
    if (payload.transactionId !== purchase.appleTransactionId) {
        await markFailed(purchase.id, 'Transaction ID mismatch');
        return;
    }
    if (payload.productId !== purchase.productId) {
        await markFailed(purchase.id, 'Product ID mismatch');
        return;
    }
    const completedAt = new Date(payload.purchaseDate);
    await markCompleted(purchase, completedAt);
    await job.log('Validated via StoreKit JWS payload');
}
async function markCompleted(purchase, completedAt) {
    await prisma.$transaction(async (tx) => {
        await tx.purchase.update({
            where: { id: purchase.id },
            data: {
                status: 'completed',
                completedAt,
                failureReason: null
            }
        });
        await tx.charityDonation.upsert({
            where: { purchaseId: purchase.id },
            create: {
                purchaseId: purchase.id,
                charityId: purchase.charityId,
                donationCents: purchase.donationCents
            },
            update: {}
        });
    });
}
