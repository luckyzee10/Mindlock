# Analytics

MindLock uses `AnalyticsService` as the single app analytics entry point. UI and service code should call `AnalyticsService.shared.track(...)`; product analytics providers should be wired behind that wrapper so event naming stays consistent.

## Provider

The app is wired for PostHog through the official iOS SDK.

- Swift package: `https://github.com/PostHog/posthog-ios.git`
- Minimum package version: `3.0.0`
- Default host: `https://us.i.posthog.com`

PostHog event sending is disabled unless `MindLockPostHogAPIKey` resolves to a real value in the app bundle.

## Configuration

Set these build settings before shipping analytics-enabled builds:

- `POSTHOG_API_KEY`: PostHog project token
- `POSTHOG_HOST`: PostHog client API host for the project

`ios/project.yml` maps those build settings into `MindLock/Info.plist`:

- `MindLockPostHogAPIKey`
- `MindLockPostHogHost`

After editing `ios/project.yml`, run:

```sh
xcodegen generate --spec ios/project.yml
```

## Current Event Coverage

The app already tracks:

- app open and foreground
- user identification
- onboarding start, page views, choices, completion
- Screen Time permission request / grant / failure
- app selection
- limit creation
- time block creation
- paywall view
- purchase start / complete / fail / pending / cancel
- restore tapped / complete / fail
- unlock flow start
- unlock minutes granted
- language challenge start / complete

## Privacy Notes

Do not send raw Screen Time usage data, selected app names, selected app tokens, or shielded app identifiers to product analytics. Screen Time usage data should remain on-device through Apple's DeviceActivity reporting flow.

Allowed analytics properties should describe product behavior, not private app usage content. Examples:

- selected app count
- selected language
- unlock method
- lesson ID
- question count
- XP earned
- subscription active state
- generic paywall/purchase state

Before shipping with PostHog enabled, update App Store Connect privacy nutrition labels and the privacy policy to disclose first-party product analytics collection. Do not use PostHog data for cross-app tracking or advertising attribution unless the app also implements Apple's tracking permission flow.
