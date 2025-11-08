import { compactVerify, importX509 } from 'jose';
export async function verifyStoreKitTransaction(jws) {
    const { payload } = await compactVerify(jws, async (header) => {
        const cert = header.x5c?.[0];
        if (!cert) {
            throw new Error('StoreKit JWS missing x5c certificate chain');
        }
        const pem = formatAsPem(cert);
        return importX509(pem, header.alg ?? 'ES256');
    });
    const decoded = JSON.parse(new TextDecoder().decode(payload));
    if (!decoded.transactionId || !decoded.productId) {
        throw new Error('StoreKit JWS missing required fields');
    }
    return decoded;
}
function formatAsPem(derBase64) {
    const wrapped = derBase64.match(/.{1,64}/g)?.join('\n') ?? derBase64;
    return `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----`;
}
