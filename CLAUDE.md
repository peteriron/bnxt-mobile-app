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
`BNXTTests/Support/MockURLProtocol.swift` intercepts network calls (stub by API path with a fixture, fail a path, assert on requests made);
reuse it rather than writing a second mock. `BNXTAPIClient` takes its session, cache and clock in `init`; tests pass `MockURLProtocol.session()`,
a temp-directory `ResponseCache` and a fixed `now`. Models decode leniently (`LenientDecoding.swift`): use `container.text/number/integer/lossyArray`
so one odd field or record never drops a list.

**UI tests:** black-box against the real app, no mocking. `UITestCase` resets on-device state at launch via `--uitest-reset-state`. Query content
by `accessibilityIdentifier`, but query the tab bar by index. Dismiss a focused search field's keyboard before the next tap. Give containers
`.accessibilityElement(children: .contain)` before putting an identifier on them.

## Pitfalls found so far

- The repo sits in iCloud-synced `~/Documents`: anything built *inside* the repo (SwiftPM `.build`) fails codesigning. Xcode's DerivedData is fine. Don't add a local Swift package without solving this first.
- `-destination 'name=iPhone 14 Plus'` resolves to the newest runtime and fails; pin `OS=26.5`.
- Strict concurrency: XCTest base classes that touch `XCUIApplication` must be `@MainActor`.
- A build reads the **published** config, not its bundled copy, so new config fields only work once pushed. UI tests pass
  `--uitest-bundled-config` so they test the build's own config. Ship config changes in the same commit as the code that needs them.
- A "replace" behaviour needs a test that starts from a non-empty state: a deep-link test on an empty stack couldn't tell replace from append.
- A `LazyVGrid` rendered empty (0×0) after `.searchable` filtering shrank its data, so the filtered tile never existed. Small fixed
  sets (16 clubs) use a non-lazy `Grid` (`ClubsScreen`).
- Tests must not reuse the production constant they guard: a privacy test looping over `PrivacyFilter.neverStoredKeys` still passed with the
  filter emptied. Use a fixed expected list in the test. Break the code on purpose once to see a new test fail.

## Data and secrets

- The upstream key is the website's public client key, used by the app for now (§7.15). It lives only in `.env`, `ios/Config/Secrets.xcconfig` (both git-ignored) and the `BNXT_API_KEY` Actions secret. Never commit it, never print it, never hard-code it in Swift; read it through `APIConfiguration`.
- Display type uses the bundled Archivo faces via `Theme.display/score/compactNumber` (§7.10). A new face needs the file, a `UIAppFonts` entry in project.yml and a `DisplayFace` case.
- The GitHub repo is **public** (`peteriron/bnxt-mobile-app`): everything committed is published. BNXT permission covers logos/photos/data (§7.17), not secrets.
- Never decode players' `facebook` / `twitter` / `instagram` or `description`; show age, never the birth date (§7.16).
- No analytics, advertising or tracking SDKs (§7.16).

## Shipping a change

Solo development (§7.23): work directly on `main`, no feature branches or PRs, until a second contributor joins.

1. Run the test command above (or `ios/scripts/ci-local.sh --no-post`) while iterating.
2. Commit and push to `main` when asked, then run `ios/scripts/ci-local.sh`. It posts the `local-tests` status to the pushed commit (§7.22).
   There are no GitHub macOS runners in the normal flow; GitHub only runs `lint`.
3. If `local-tests` or `lint` fails, fix it in the next commit.

## Remote config

`config/v1/config.json` is live for every user once it's on `main` (§7.24). Treat edits like a release: the pre-push hook
(`git config core.hooksPath tools/hooks`) validates it; never raise `minimumVersion` above the live App Store version; never add
`apiKeyOverride` without the user's explicit go-ahead (it publishes a key). Club colours are brand colours and may be dark: use
`TeamSettings.rgb` and lift them to 3:1 for graphics (§5.1, §7.25), never use them for text. Read it through `RemoteConfigClient`; `VersionChecker` is the
`@MainActor @Observable` model for update state (inject a `VersionPolicySource`).

## Releasing

`/release x.y.z` runs [`.claude/commands/release.md`](.claude/commands/release.md). Before staging anything, check App Store Connect for a version
already waiting for review. Never submit for review: that's the human's step.

## Git

Commit and push only when asked. Commits go straight to `main` for now (§7.23); force-pushes to `main` are blocked.
