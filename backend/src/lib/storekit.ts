import { compactVerify, importX509, type CompactVerifyResult } from 'jose';

export interface StoreKitTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  webOrderLineItemId?: string;
  bundleId: string;
  productId: string;
  purchaseDate: string | number;
  type: string;
  appAccountToken?: string;
}

export async function verifyStoreKitTransaction(jws: string): Promise<StoreKitTransactionPayload> {
  const { payload } = await compactVerify(jws, async (header) => {
    const cert = header.x5c?.[0];
    if (!cert) {
      throw new Error('StoreKit JWS missing x5c certificate chain');
    }
    const pem = formatAsPem(cert);
    return importX509(pem, header.alg ?? 'ES256');
  });

  const decoded = JSON.parse(new TextDecoder().decode(payload)) as StoreKitTransactionPayload;

  if (!decoded.transactionId || !decoded.productId) {
    throw new Error('StoreKit JWS missing required fields');
  }

  return decoded;
}

function formatAsPem(derBase64: string): string {
  const wrapped = derBase64.match(/.{1,64}/g)?.join('\n') ?? derBase64;
  return `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----`;
}
