# iOS setup

Toolchain, build, test and release for the BNXT app. Product scope and decisions are in [REQUIREMENTS.md](../REQUIREMENTS.md);
how we work is in [docs/ios-playbook/](../docs/ios-playbook/README.md).

## Toolchain

| Tool | Version | Install |
|---|---|---|
| Xcode | 27 (iOS 27 SDK; deployment target iOS 26) | App Store |
| XcodeGen | 2.46+ | `brew install xcodegen` |
| SwiftLint | latest | `brew install swiftlint` |
| Ruby + fastlane (release only) | Homebrew Ruby, fastlane 2.228+ | `brew install ruby`, put its `bin` dirs on `PATH`, then `cd ios && bundle install` |

Simulators: **iPhone 18 Pro (iOS 27)** for tests and **iPhone 14 Plus (iOS 26.5)** for App Store screenshots
(1284×2778, a size App Store Connect accepts).

> ⚠️ **iCloud Drive:** this repo currently lives in `~/Documents`, which is synced to iCloud. iCloud tags build output with
> metadata mid-build, which breaks codesigning for anything built inside the repo (`swift build` failed with "resource fork,
> Finder information, or similar detritus not allowed"), and syncing `.git` is risky. Xcode builds go to `~/Library/Developer`
> and are unaffected. Moving the repo to an unsynced folder (e.g. `~/Developer/bnxt-mobile-app`) is recommended.

## Project

The Xcode project is generated from `project.yml` and is not committed (REQUIREMENTS §7.12).

```bash
cd ios && xcodegen generate && open BNXT.xcodeproj
```

**Regenerate after adding, removing or renaming a file**, or after editing `project.yml`. Otherwise the file silently isn't compiled.

Layout of the app target (`ios/BNXT/`):

```
App/          entry point, launch arguments (Info.plist is generated here)
Models/       Decodable API types and pure derived values
Networking/   the API client, response cache
Persistence/  on-device stores (favourite club)
Services/     multi-step work that isn't UI state (calendar export)
ViewModels/   one per screen: @MainActor @Observable final class, dependencies via init
Views/        one folder per tab or feature; Shared/ for components
Theme/        design tokens (Theme.swift)
Resources/    assets, fonts, String Catalog
```

Folders appear as they get their first file.

## API key (once per machine)

The app uses the bnxtleague.com client key for now (REQUIREMENTS §7.15). Put it in the git-ignored build config:

```bash
cp ios/Config/Secrets.example.xcconfig ios/Config/Secrets.xcconfig   # then paste the key (same value as BNXT_API_KEY in .env)
```

Without it the app builds, but `APIConfiguration.main` is nil and data calls can't authenticate. CI writes the file from the
`BNXT_API_KEY` Actions secret (`gh secret set BNXT_API_KEY`).

## Signing

Team ID `92HC396B37` (Peter Jans, paid Apple Developer Program) is set as `DEVELOPMENT_TEAM` in `project.yml`; automatic signing.
To look it up: developer.apple.com/account → Membership details → Team ID; or Xcode → Settings → Accounts → the team;
or `security find-identity -v -p codesigning` (the 10 characters in brackets after "Apple Distribution").
The bundle ID `com.pjproductions.bnxt` is provisional (REQUIREMENTS §7.17).

## Tests

Two targets: `BNXTTests` (XCTest unit tests) and `BNXTUITests` (XCUITest against the real app). Run both before calling anything done:

```bash
cd ios
xcodebuild -project BNXT.xcodeproj -scheme BNXT \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -skip-testing:BNXTUITests/AppStoreScreenshotUITests \
  -collect-test-diagnostics never test
```

- `-skip-testing:…AppStoreScreenshotUITests` keeps screenshot capture out of routine runs (skip it here, not in the scheme, or `-only-testing` breaks).
- `-collect-test-diagnostics never` stops a failing run from spending up to 10 minutes in `simctl diagnose`. The `.xcresult` still has the failures.
- Or `cd ios && bundle exec fastlane test`.

**Unit tests:** dependencies (API client, stores, `now`, debounce intervals) are injected through initializers. Network tests use one shared
`MockURLProtocol` (in `BNXTTests/Support/`, added with the API client in Phase 1). Reuse it and never write a second one.
Golden fixtures are real responses of finished games, in `BNXTTests/Fixtures/`, with never-decode fields stripped (REQUIREMENTS §7.16).

**UI tests:** subclass `UITestCase`, which launches with `--uitest-reset-state` (stores skip loading for that launch).
- Query content by `accessibilityIdentifier`, never by visible text. Query **the tab bar by index** (`tab(0)` … `tab(4)`).
- Put `.accessibilityElement(children: .contain)` on a container before giving it an identifier, or the identifier is copied onto every child.
- Dismiss a focused search field's keyboard before the next tap.

**Look at the screens** after building UI: run `AppStoreScreenshotUITests` (or `bundle exec fastlane screenshots`) and open every image.

## Local CI (required before merging)

Tests don't run on GitHub's macOS runners (REQUIREMENTS §7.22). After pushing to `main` (solo flow, §7.23), run:

```bash
ios/scripts/ci-local.sh            # lint + unit + UI tests on HEAD, posts the `local-tests` status to GitHub
ios/scripts/ci-local.sh --no-post  # same checks on uncommitted work, nothing posted
SIM="iPhone 17 Pro" ios/scripts/ci-local.sh   # another simulator
```

It refuses to post for a dirty tree or an unpushed commit, so the status always matches the tested commit. Pending → success/failure
shows on the commit in GitHub; logs land in `.tmp/ci-local/<sha>/`. Checks aren't required for merging while there's one developer
(§7.23); when that changes, require `local-tests` and `lint` on `main` again.
Fallback when the Mac isn't available: `gh workflow run CI --ref <branch> -f macos_tests=true` (GitHub macOS runner, slow queue).
Every pushed commit needs its own run: statuses belong to commits.

## Lint

```bash
swiftlint --strict
```

## Manual QA (what automation can't reach)

- A real live game night: score, clock and play-by-play against the official site; battery over 2 hours.
- Offline after a successful load, and first launch offline.
- Dynamic Type at AX sizes and VoiceOver on each new screen, on a device.
- Tickets / BNXT.tv / game report links open correctly; Add to Calendar.

## Releasing

`/release x.y.z` runs [`.claude/commands/release.md`](../.claude/commands/release.md). It never submits for review.

One-time setup:
1. A paid Apple Developer Program membership; the app record in App Store Connect with bundle ID `com.pjproductions.bnxt` (once confirmed).
2. An App Store Connect API key (Users and Access → Integrations → App Store Connect API, role App Manager). Save the `.p8` once at
   `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`. Never commit it.
3. `ios/fastlane/.env` (git-ignored): `ASC_KEY_ID=…` and `ASC_ISSUER_ID=…`.
4. `cd ios && bundle install`.
5. Privacy policy and support URLs (currently placeholders in `ios/fastlane/metadata/en-US/*_url.txt`).

Lanes (`ios/fastlane/Fastfile`, not yet exercised against App Store Connect): `test`, `bump_version version:x.y.z`, `screenshots`,
`build_and_upload` (`ios/scripts/release.sh`), `stage_app_store version:x.y.z`. The last refuses while any version is with Apple, and verifies the screenshots landed.
