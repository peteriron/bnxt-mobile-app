# Working in this repo

BNXT is a native SwiftUI iOS app (`ios/BNXT/`) for BNXT League basketball fans. See [`REQUIREMENTS.md`](REQUIREMENTS.md) for product scope and
numbered decisions (§7.x), [`docs/bnxt-api.md`](docs/bnxt-api.md) for the data source, and [`ios/SETUP.md`](ios/SETUP.md) for the toolchain
and build/test commands. How we work: [`docs/ios-playbook/`](docs/ios-playbook/README.md). Follow it unless a decision in REQUIREMENTS.md says otherwise.

## Scratch/working directory

Use `.tmp/` (gitignored) at the repo root for temporary files, debugging captures, API probes, downloaded reference material and other
throwaway work, instead of `/tmp` or a directory outside this repo. Never commit anything under it beyond `.gitkeep`. Delete files there
once they've served their purpose, especially anything containing credentials. Data tooling runs from `.tmp/data/` (docs/bnxt-api.md).

## Keep the test suite current

Two test targets: `ios/BNXTTests/` (XCTest unit tests: models, persistence, API client, view models, theme) and `ios/BNXTUITests/`
(XCUITest: real on-screen flows against the real app). So:

- **When you add a feature**, add unit tests for its logic and a UI test if it involves an on-screen flow or gesture, in the same change.
- **When you change behaviour**, update the tests that cover it rather than deleting them. Re-read a failing test first: it may be catching a real regression.
- **When you fix a bug, and always when one is reported**, work test-first: write a test that reproduces it, confirm it fails, fix, confirm it passes,
  and keep it as regression coverage, named after the bug.
- **Before treating a change as done**, run both suites:
  ```bash
  cd ios
  xcodebuild -project BNXT.xcodeproj -scheme BNXT \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    -skip-testing:BNXTUITests/AppStoreScreenshotUITests \
    -collect-test-diagnostics never test
  ```
  `-collect-test-diagnostics never` stops a failing run from spending up to 10 minutes on `simctl diagnose`.
- If you add a source file, regenerate the project (`cd ios && xcodegen generate`); the `.xcodeproj` isn't committed.

## What's in scope for each suite

**Unit tests:** view models and stores take their dependencies (API client, stores, `now`) via injectable initializers. Keep new code following
that pattern instead of reaching for `.shared` inside a type you'll want to test. View models are `@MainActor @Observable final class` (§7.13).
`BNXTTests/Support/MockURLProtocol.swift` (arrives with the API client) intercepts network calls; reuse it rather than writing a second mock.

**UI tests:** black-box against the real app, no mocking. `UITestCase` resets on-device state at launch via `--uitest-reset-state`. Query content
by `accessibilityIdentifier`, but query the tab bar by index. Dismiss a focused search field's keyboard before the next tap. Give containers
`.accessibilityElement(children: .contain)` before putting an identifier on them.

## Pitfalls found so far

- The repo sits in iCloud-synced `~/Documents`: anything built *inside* the repo (SwiftPM `.build`) fails codesigning. Xcode's DerivedData is fine. Don't add a local Swift package without solving this first.
- `-destination 'name=iPhone 14 Plus'` resolves to the newest runtime and fails; pin `OS=26.5`.
- Strict concurrency: XCTest base classes that touch `XCUIApplication` must be `@MainActor`.

## Data and secrets

- The upstream key is the website's public client key, used by the app for now (§7.15). It lives only in `.env`, `ios/Config/Secrets.xcconfig` (both git-ignored) and the `BNXT_API_KEY` Actions secret. Never commit it, never print it, never hard-code it in Swift; read it through `APIConfiguration`.
- Display type uses the bundled Archivo faces via `Theme.display/score/compactNumber` (§7.10). A new face needs the file, a `UIAppFonts` entry in project.yml and a `DisplayFace` case.
- The GitHub repo is **public** (`peteriron/bnxt-mobile-app`): everything committed is published. BNXT permission covers logos/photos/data (§7.17), not secrets.
- Never decode players' `facebook` / `twitter` / `instagram` or `description`; show age, never the birth date (§7.16).
- No analytics, advertising or tracking SDKs (§7.16).

## Shipping a change

1. Work on a branch; run the test command above while iterating.
2. Commit and push the branch, then run `ios/scripts/ci-local.sh`. It posts the `local-tests` status that `main` requires (§7.22).
   Don't wait for GitHub macOS runners: there are none in the normal flow.
3. Open the PR; merge once `local-tests` and `lint` are green, and only when asked.

## Releasing

`/release x.y.z` runs [`.claude/commands/release.md`](.claude/commands/release.md). Before staging anything, check App Store Connect for a version
already waiting for review. Never submit for review: that's the human's step.

## Git

Commit and push only when asked. Feature work happens on a branch, merged when asked.
