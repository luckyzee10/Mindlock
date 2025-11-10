import dotenv from 'dotenv';
dotenv.config();
function requireEnv(key) {
    const value = process.env[key];
    if (!value) {
        throw new Error(`Missing required env var ${key}`);
    }
    return value;
}
export const config = {
    nodeEnv: process.env.NODE_ENV ?? 'development',
    port: Number(process.env.PORT ?? 4000),
    databaseUrl: requireEnv('DATABASE_URL'),
    // Redis is optional. If absent, queue-related features are disabled.
    redisUrl: process.env.REDIS_URL,
    appApiKey: requireEnv('APP_API_KEY'),
    adminApiKey: requireEnv('ADMIN_API_KEY'),
    appleSharedSecret: requireEnv('APPLE_SHARED_SECRET'),
    appleVerifyReceiptUrl: process.env.APPLE_VERIFY_RECEIPT_URL ?? 'https://buy.itunes.apple.com/verifyReceipt',
    logLevel: process.env.LOG_LEVEL ?? 'info'
};
