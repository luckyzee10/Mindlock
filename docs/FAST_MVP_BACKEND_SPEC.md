# fast-mvp-backend – Lean, Best-Practice Stack

Goal: ship the backend this week without cutting corners on correctness or security. Focus on:
1. Verifying the single in-app purchase SKU (`mindlock.daypass`) and recording donation flows.
2. Generating a trustworthy end-of-month donation report per charity.

We keep scope tight, rely on pay-as-you-go managed services, and follow standard backend practices.

---

## 1. Architecture Overview

| Layer | Stack / Service | Why |
| --- | --- | --- |
| API + Worker | Node 20 + TypeScript (Express) deployed to Render or Fly.io (two services: `api`, `worker`) | Familiar stack, free/cheap tier, HTTPS managed. |
| Database | Supabase (Postgres) | Free tier, automatic backups, Prisma friendly. |
| Queue / Cache | Upstash Redis (serverless) | BullMQ-compatible, billed per request. |
| Jobs / Cron | BullMQ with cron expressions | No extra infra; runs in worker service. |
| Monitoring | Render/Fly logs + (optional) Sentry/Logtail free plan | Basic observability from day one. |

The repo exports two entrypoints: `api.ts` and `worker.ts`. Both read the same `.env`, so no duplicated config.

---

## 2. API Surface & Security

### Authentication
- Each client request must include `X-App-Key: <APP_API_KEY>`.
- Admin routes require `X-Admin-Key`.
- Refuse requests without HTTPS (handled by platform, but also check `x-forwarded-proto`).

### Endpoints
1. `POST /v1/purchases`
   - Validates payload via `zod`.
   - Creates purchase row (`pending_validation`).
   - Enqueues BullMQ job.
   - Returns `{ purchaseId }` with `202 Accepted`.
2. `GET /v1/reports/latest` *(admin)*
   - Returns last generated monthly report JSON.
3. `POST /v1/reports/run` *(admin optional)*
   - Accepts `{ "month": "YYYY-MM" }`.
   - Regenerates report for specified month.
4. `GET /healthz`
   - Liveness check for Render/Fly.

No other endpoints for MVP.

---

## 3. Receipt Validation Workflow

1. **Job creation**: `ValidateReceiptJob` payload = `{ purchaseId }`.
2. **Worker**:
   - Fetch purchase + receipt, call Apple verify endpoint (`APPLE_VERIFY_RECEIPT_URL` from env).
   - Use shared secret (`APPLE_SHARED_SECRET`).
   - Validate `productId` matches `mindlock.daypass`.
   - If success and `apple_transaction_id` not seen:
     - Update purchase to `completed`.
     - Calculate revenue splits.
     - Insert `charity_donation` row.
   - If failure: set purchase `failed`, store `failureReason`.
3. **Retry/backoff**: BullMQ retries up to 5 times (1s, 10s, 1m, 5m, 30m). After last attempt, leave as `failed` for manual review.
4. **Logging**: log each state transition with purchase id + apple status (masking sensitive fields).

Optimistic client unlock is acceptable for now; Apple validation is authoritative for financial reporting. Phase two can include push revocations if needed.

---

## 4. Monthly Reporting

- Worker registers cron `0 5 1 * *` (05:00 UTC on first day of month).
- Job steps:
  1. Determine target month = previous calendar month (e.g., running on 2025-11-01 -> month "2025-10").
  2. Query `charity_donations` aggregated by charity.
  3. Build JSON summary: totals per charity, total revenue, total donation.
  4. Upsert into `monthly_reports` table.
  5. Log summary (can later push to email/Slack).
- Admin can fetch via `GET /v1/reports/latest` or regenerate via `POST /v1/reports/run`.

---

## 5. Donation Math

```
gross = product price ($0.99 default)
appleFee = gross * 0.15  (Small Business Program)
net = gross - appleFee
donation = net * 0.15
platformRevenue = net - donation
```

Save all values as integer cents. Store `grossCents`, `appleFeeCents`, `netCents`, `donationCents` on the purchase row for transparency.

---

## 6. Data Model (Prisma style)

```prisma
model User {
  id        String   @id @default(cuid())
  email     String?  @unique
  createdAt DateTime @default(now())
  purchases Purchase[]
}

model Charity {
  id          String  @id
  name        String
  description String
  isActive    Boolean @default(true)
}

model Purchase {
  id                 String @id @default(cuid())
  userId             String
  charityId          String
  productId          String
  appleTransactionId String? @unique
  receiptData        String
  status             PurchaseStatus @default(pending_validation)
  grossCents         Int
  appleFeeCents      Int
  netCents           Int
  donationCents      Int
  createdAt          DateTime @default(now())
  completedAt        DateTime?
  failureReason      String?

  user    User    @relation(fields: [userId], references: [id])
  charity Charity @relation(fields: [charityId], references: [id])
}

model CharityDonation {
  id            String   @id @default(cuid())
  charityId     String
  purchaseId    String
  donationCents Int
  recordedAt    DateTime @default(now())
}

model MonthlyReport {
  id          String   @id @default(cuid())
  month       String   // "2025-10"
  generatedAt DateTime @default(now())
  payload     Json
}

enum PurchaseStatus {
  pending_validation
  completed
  failed
}
```

---

## 7. Environment Configuration (`.env`)

```
NODE_ENV=production
PORT=8080

DATABASE_URL=postgresql://user:password@db-host:5432/mindlock
REDIS_URL=redis://:password@upstash-host:6379

APPLE_SHARED_SECRET=xxxx
APPLE_VERIFY_RECEIPT_URL=https://buy.itunes.apple.com/verifyReceipt

APP_API_KEY=app-public-key
ADMIN_API_KEY=admin-secret-key

LOG_LEVEL=info
SENTRY_DSN= (optional)
```

Local dev overrides:
```
NODE_ENV=development
PORT=4000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/mindlock_dev
REDIS_URL=redis://localhost:6379
APPLE_VERIFY_RECEIPT_URL=https://sandbox.itunes.apple.com/verifyReceipt
```

Store secrets with Render/Fly secret manager in production; never commit `.env`.

---

## 8. Implementation Checklist

1. **Bootstrapping**
   - `pnpm create` TS project, configure ESLint/Prettier.
   - Setup Express router, `helmet`, `morgan` logging.
   - Initialize Prisma schema + migrations.
2. **Security**
   - Middleware to enforce `X-App-Key` / `X-Admin-Key`.
   - Rate limit `POST /v1/purchases` (e.g., `express-rate-limit` 60 req/min per IP).
   - Sanitize/limit request body size (2 MB max).
3. **Queue + Worker**
   - BullMQ connection to Upstash Redis.
   - Worker handles `ValidateReceiptJob` with retries + logging.
4. **Cron**
   - Register monthly report job via BullMQ `add` with `repeat` option.
5. **Testing**
   - Unit tests for receipt validator (mock Apple responses).
   - Integration test hitting `/v1/purchases` with mocked queue.
6. **Deployment**
   - Two Render services: `mindlock-api` (web) and `mindlock-worker` (background).
   - Supabase + Upstash free tiers.
   - Set up Sentry/Logtail if time permits.

---

## 9. Future Enhancements (post-launch)

- Device/app webhooks to revoke optimistic unlocks instantly.
- Real auth (JWT, Supabase auth) instead of shared keys.
- Automated email/Slack monthly report.
- Stripe or RevenueCat integration for Android/web unlocks.
- Charity admin dashboard + payout automation.

For launch, this spec balances best practices with minimal scope and lean infrastructure costs.
