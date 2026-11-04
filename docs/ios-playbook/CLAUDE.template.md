# Working in this repo

<!-- Template from the Vlaanderen Courtside playbook. Replace <placeholders>, delete what doesn't apply, and add pitfalls as you discover them. -->

<App name> is a native SwiftUI iOS app (`ios/<AppName>/`). See [`REQUIREMENTS.md`](REQUIREMENTS.md) for product scope and decisions and [`ios/SETUP.md`](ios/SETUP.md) for the toolchain and build/test commands.

## Scratch/working directory

Use `.tmp/` (gitignored) at the repo root for temporary files, debugging captures, downloaded reference material and other throwaway work, instead of `/tmp` or a directory outside this repo. Never commit anything under it beyond `.gitkeep`; delete files there once they've served their purpose, especially anything containing credentials or personal data.

## Keep the test suite current

Two test targets: `ios/<AppName>Tests/` (XCTest unit tests: models, persistence, API client, view models) and `ios/<AppName>UITests/` (XCUITest: real on-screen flows against the real app). So:

- **When you add a feature**, add unit tests for its logic and a UI test if it involves an on-screen flow or gesture, in the same change.
- **When you change behaviour**, update the tests that cover it rather than deleting them. Re-read a failing test first: it may be catching a real regression.
- **When you fix a bug, and always when one is reported**, work test-first: write a test that reproduces it, confirm it fails, fix, confirm it passes, and keep it as regression coverage.
- **Before treating a change as done**, run both suites:
  ```bash
  cd ios
  xcodebuild -project <AppName>.xcodeproj -scheme <AppName> \
    -destination 'platform=iOS Simulator,name=<simulator>' \
    -skip-testing:<AppName>UITests/AppStoreScreenshotUITests \
    -collect-test-diagnostics never test
  ```
  `-collect-test-diagnostics never` stops a failing run from spending up to 10 minutes on `simctl diagnose`.
- If you add a source file, regenerate the project (`cd ios && xcodegen generate`); the `.xcodeproj` isn't committed.

## What's in scope for each suite

**Unit tests:** view models and stores take their dependencies (API client, stores, `now`) via injectable initializers. Keep new code following that pattern instead of reaching for `.shared` inside a type you'll want to test. `Support/MockURLProtocol.swift` intercepts network calls; reuse it rather than writing a second mock.

**UI tests:** black-box against the real app, no mocking. `UITestCase` resets on-device state at launch via `--uitest-reset-state`. Query content by `accessibilityIdentifier`, but query the tab bar by index. Dismiss a focused search field's keyboard before the next tap. Give containers `.accessibilityElement(children: .contain)` before putting an identifier on them.

## Releasing

`/release x.y.z` runs [`.claude/commands/release.md`](.claude/commands/release.md). Before staging anything, check App Store Connect for a version already waiting for review. Never submit for review: that's the human's step.

## Privacy rules

<List the fields that must never be decoded, cached or shown, and how people's names are displayed. Link the decisions in REQUIREMENTS.md.>
