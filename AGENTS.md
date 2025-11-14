# Repository Guidelines

## Project Structure & Module Organization
MindLock's iOS sources live in `ios/`. The `MindLock` target uses `Design/`, `Views/`, `Models/`, and `Services/` folders, while `MindLockMonitor` handles DeviceActivity tracking. Regenerate the project after touching `project.yml` so the `.xcodeproj` stays in sync. Architecture, roadmap, and flow docs sit in `docs/`. The static marketing site in `website/` supplies demo collateral; treat build outputs under `ios/build/` as disposable.

## Build, Test, and Development Commands
Open the app with `open ios/MindLock.xcodeproj` (or `xed -b ios/MindLock.xcodeproj`) when iterating locally. Run XcodeGen whenever the spec changes: `xcodegen generate --spec ios/project.yml`. For headless builds use `xcodebuild -scheme MindLock -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`. Once tests exist, execute `xcodebuild -scheme MindLock -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test`. Serve the marketing site via `python3 -m http.server --directory website 4173` before capturing screenshots or copy edits.

## Coding Style & Naming Conventions
Target Swift 5.9, four-space indentation, and a trailing newline. Use `UpperCamelCase` for types, `lowerCamelCase` for functions and properties, and keep view files under 300 lines by extracting helpers into extensions. Group related declarations with `// MARK:` as shown in `ios/MindLock/Design/DesignSystem.swift`. Maintain semantic asset names aligned with the Opal-inspired color and spacing tokens, and rely on environment objects for dependency injection.

## Testing Guidelines
Add XCTest coverage with every feature. Create a `MindLockTests` target if missing and mirror production folders (for example, place dashboard specs in `MindLockTests/Views/Dashboard/`). Name methods `test_<Scenario>_<Expectation>()`, favor deterministic mocks for Screen Time interactions, and note simulator destinations in the PR when reproducing device-specific issues.

## Commit & Pull Request Guidelines
Use conventional commits such as `feat(screen-time): add usage ring animation`; scopes should match top-level directories (`ios`, `docs`, `website`). Pull requests need a concise summary, manual test notes or simulator targets, and refreshed screenshots for UI-visible changes. Link roadmap items from `docs/ROADMAP.md` and flag entitlement or provisioning updates so reviewers can adjust signing assets promptly.

## Security & Configuration Tips
Never commit real Firebase or StoreKit credentials—use sanitized `GoogleService-Info.plist` placeholders and keep secrets in local `.xcconfig` files. Review `MindLock/MindLock.entitlements` and `MindLockMonitor/MindLockMonitor.entitlements` after capability changes to avoid shipping unused permissions. Document new background modes or Screen Time touchpoints in `docs/ARCHITECTURE.md` before merge.

##Style Guidelines
In chat keep it informative but brief. Like a coder talking to their boss, be mindful of the user's time.