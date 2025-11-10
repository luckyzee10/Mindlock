# Referral Program – Development Checklist

This document outlines a lean, end‑to‑end referral program for MindLock. Users share a link; a friend installs/opens via that link and completes their “first contribution” (first Day Pass). We record an additional donation in the referrer’s name.

## Goals
- Frictionless share → open app via Universal Link → claim referral → award donation on first completed purchase.
- Keep the solution simple, observable, and App Review friendly.

## Data Model (Prisma)
- **Referral**
  - `id` (cuid, PK)
  - `code` (string, unique)
  - `referrerUserId` (string, FK → User)
  - `referredUserId` (string, FK → User, nullable)
  - `status` (enum/string: `pending` | `claimed` | `completed` | `rejected`)
  - `charityId` (string, nullable)
  - `createdAt`, `claimedAt`, `completedAt` (DateTime)
- **CharityDonation** (existing)
  - Add `donationType` enum = `purchase` | `referral` (default `purchase`)
  - Add `referrerUserId` (string, FK → User, nullable)
- **Indexes**
  - `code` unique; `(referrerUserId, createdAt)`; `(referredUserId)`

## Backend API
- `POST /v1/referrals` (App Key)
  - Body: `{ userId, charityId? }`
  - Generates unique short `code` (8–10 URL-safe chars), returns `{ code, shareUrl }`.
- `POST /v1/referrals/claim` (App Key)
  - Body: `{ code, referredUserId, deviceId? }`
  - Validates and marks referral `claimed` (sets `referredUserId`, `claimedAt`).
  - Basic fraud checks (see below).
- `GET /v1/purchases/:id` (App Key) — optional
  - Returns `{ status, failureReason }` for client polling to gate unlock on server confirmation.
- (Optional) Admin `GET /v1/referrals/:code` for debugging.

## Worker Logic
- On purchase `completed` (existing validate‑receipt flow):
  1. Check if `purchase.userId` has a `Referral` with `status='claimed'` and `completedAt IS NULL`.
  2. Verify it’s the user’s first `Purchase.completed`.
  3. If both true:
     - Create `CharityDonation` with `donationType='referral'`, set `referrerUserId`, choose `charityId` (priority: `referral.charityId` > referred user’s current charity > default).
     - Mark `Referral.completed` and set `completedAt`.
- Log success/fail paths for observability.

## Fraud / Abuse Controls
- One referral per referred user/device (persist hashed device GUID at claim).
- Block self‑referrals (same `userId`).
- Rate‑limit both endpoints via existing middleware.
- Only award on first completed purchase for the referred user.
- Admin override to reject/refund suspicious referrals (optional endpoint).

## Website (Marketing Site)
- Host Universal Links association file (AASA): `/.well-known/apple-app-site-association`.
  - Include your `TEAMID.bundleID` and path `"/r/*"`.
- Add a lightweight `/r/:code` page to:
  - Open the app via Universal Links if installed.
  - Fallback with a “Get the app” page otherwise.
- Update `website/privacy.html` to mention referral attribution data (code, referrer, claim metadata).

## iOS App
- Entitlements: Associated Domains → `applinks:<your-domain>`.
- URL Handling: on open with `/r/<code>`, call `/v1/referrals/claim` and store “claimed”.
- Invite/Share UI: call `POST /v1/referrals`, present native share sheet with the returned link.
- Purchase UX (optional tightening): treat HTTP 202 as `pending` and poll `/v1/purchases/:id` until `completed` before final unlock and `transaction.finish()`.

## Donation Rules
- Amount: flat (e.g., $0.25) or percentage of referred’s first purchase net.
- Charity precedence: `referral.charityId` > referred user’s selected charity > default.

## Config & Secrets
- API/Worker ENV
  - `REFERRALS_ENABLED=true`
  - `REFERRAL_BASE_URL=https://your-domain/r`
- Website
  - AASA JSON must be served with correct headers (application/json), no redirects.

## QA / Testing
- Unit tests: referral create/claim; first‑purchase award logic.
- Integration: end‑to‑end purchase triggers referral donation; repeated claims blocked.
- Manual: Universal Link flows (installed vs not), self‑referral, duplicate device claim.
- Observability: confirm queue counts; worker logs for validate/award lifecycle.

## Rollout Plan
1. Schema + migrations; deploy API/Worker with feature flag off.
2. Enable `/v1/referrals` + claim; verify DB writes.
3. Turn on worker award path; monitor referrals/donations.
4. Add iOS invite + link handling; ship behind a remote flag if desired.

## Implementation Order
1. Prisma schema + migration (Referral; donationType; referrerUserId).
2. API: `POST /v1/referrals`, `POST /v1/referrals/claim`.
3. Worker: award referral donation on first completed purchase.
4. Website: add AASA + `/r/:code` minimal page.
5. iOS: Associated Domains; URL handler; invite UI.
6. Rate limits + fraud checks.
7. Optional: `GET /v1/purchases/:id` + client polling.
8. Docs: privacy update; short README for referral config.

## Notes & Alternatives
- You can host the AASA and `/r/:code` on the API domain instead of the marketing site; point Associated Domains to that host.
- If you skip Universal Links, add a simple “Enter referral code” field in onboarding (with more friction).

