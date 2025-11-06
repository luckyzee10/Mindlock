# Re-Enabling Device Activity Monitoring

When Apple's FamilyControls/Device Activity entitlement is approved, use this checklist to bring the MindLock monitor extension back online and wire it into the build.

---

## 1. Restore the Extension Target in `project.yml`
1. Open `ios/project.yml`.
2. Under `targets:`, reintroduce the `MindLockMonitor` block:
   ```yaml
   MindLockMonitor:
     type: app-extension
     platform: iOS
     deploymentTarget: "17.0"
     sources:
       - path: MindLockMonitor
     settings:
       base:
         PRODUCT_BUNDLE_IDENTIFIER: com.lucaszambranonavia.mindlock.monitor
         CODE_SIGN_STYLE: Automatic
         INFOPLIST_FILE: MindLockMonitor/Info.plist
     info:
       path: MindLockMonitor/Info.plist
       properties:
         NSExtension:
           NSExtensionPointIdentifier: com.apple.deviceactivity-monitor
           NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).MindLockActivityMonitor
     entitlements:
       path: MindLockMonitor/MindLockMonitor.entitlements
       properties:
         com.apple.developer.deviceactivity: true
     dependencies:
       - sdk: DeviceActivity.framework
       - sdk: ManagedSettings.framework
   ```
3. Reattach the extension dependency to the main app target:
   ```yaml
   MindLock:
     # ...
     dependencies:
       - target: MindLockMonitor
       - sdk: FamilyControls.framework
       - sdk: ManagedSettings.framework
       - sdk: DeviceActivity.framework
   ```

## 2. Regenerate the Xcode Project
```bash
cd ios
xcodegen
```
This rebuilds `MindLock.xcodeproj` with the restored extension target.

## 3. Refresh Signing
1. In Apple Developer Portal, enable the Device Activity entitlement for both the app and extension App IDs.
2. Regenerate provisioning profiles for both targets and download them.
3. In Xcode > Settings > Accounts, refresh profiles for your Apple ID.
4. Open the regenerated project and ensure each target lists the refreshed team/profile under **Signing & Capabilities**.

## 4. Rebuild and Install
- Clean and build (`Cmd+Shift+K`, then `Cmd+B`).
- Deploy to a device. Installation should succeed now that the entitlement is active.
- Check logs: `MindLockActivityMonitor` should log interval/event callbacks, and shared defaults notifications should drive the unlock flow in the host app.

## 5. Swap From Mock Analytics (Optional)
If real Screen Time data is ready:
1. Replace the mock provider in `AnalyticsViewModel` with the actual Screen Time data source.
2. Remove or guard `AnalyticsMockDataProvider` so the production build pulls live usage information.

## 6. Restore Device Activity Debug Utilities (Optional)
Re-enable any `#if ENABLE_DEVICE_ACTIVITY` code or diagnostic logging you previously disabled while the monitor was off.

Following these steps will return the project to its full Device Activity configuration once Apple has granted the required authorization.
