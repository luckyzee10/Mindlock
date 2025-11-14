# MindLock+ Subscription & Impact Plan

This document supersedes the legacy Day Pass specs. Keep the older plans for context, but treat this doc as the source of truth for the subscription rollout.

## Product Pillars

1. **MindLock+ Subscription**
   - Auto-renewing tiers: `mindlock.plus.monthly`, `mindlock.plus.annual`.
   - Unlocks: unlimited time blocks, enhanced analytics, charity impact tracking, priority roadmap features.
   - Pricing targets: $9.99/month, $59.99/year (subject to localized tiers).

2. **Impact Engine**
   - Reuse existing unlock-free streak counters as “Impact Points” (1 point per unlock-free day).
   - Multiplier ladder:  
     `0-6 days → 1×`, `7-13 → 2×`, `14-20 → 3×`, `21-27 → 4×`, `28+ → 5× (cap)`.
   - Donation budget: up to 20% of the subscriber’s net fee per billing cycle; convert points → dollars on the backend and surface recaps in-app.

3. **Mindful Breaks**
   - Free wait unlock remains (30-second countdown unlocks 1–15 minutes chosen by the user).
   - Messaging nudges toward MindLock+ for longer unlock flexibility and impact boosts, but no pay-to-fail penalties.

## Implementation Track

### 1. StoreKit / Client

- Replace Day Pass consumable logic with the two MindLock+ auto-renewables.
- PaymentManager responsibilities:
  - Load both products, expose lowest-priced offer for UI.
  - Handle subscription status refresh via `Transaction.currentEntitlements`.
  - Post receipts to `/v1/purchases` with `subscriptionTier`.
- UnlockPromptView becomes the MindLock+ paywall:
  - Shows current streak / impact multiplier.
  - Requires a selected charity prior to purchase.
  - Hides CTA when already subscribed.
- Setup/Limit cards now route to MindLock+ paywall rather than Day Pass sheet.

### 2. Backend

- Update purchase schema to allow `mindlock.plus.monthly` / `mindlock.plus.annual`.
- Record subscription receipts, donation caps (20% of net revenue) per billing period, and per-user impact points sent from client or recomputed nightly.
- Provide endpoints for:
  - Receipt validation + subscription status.
  - **Impact recap** (`GET /v1/impact/summary` via app key) returning lifetime + monthly donation totals and per-charity breakdowns for the requesting user. The profile screen consumes this payload.

### 3. Charity / Impact UI

- Dashboard streak card displays current multiplier + days until next boost.
- Unlock flow and Setup view share the same impact summary component.
- Charity selection acts as a funnel for non-subscribers (“Unlock Impact” CTA).
- Profile screen highlights cumulative donations from MindLock+ instead of Day Pass purchases.

### 4. Migration Notes

- Archive prior Day Pass copy but leave it unchanged for historical context.
- Remove Day Pass-specific analytics (minutes/unlocks) once subscription metrics are live.
- Coordinate App Store metadata, screenshots, and privacy descriptions to reflect the new model.
*** End Patch*** to=functions.apply_patchistí
