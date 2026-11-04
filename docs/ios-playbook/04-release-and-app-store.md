# Release and App Store

## Principles

- **A release is one command**, `/release x.y.z`, plus one human click: Submit for Review.
- **Everything about the listing lives in git**: description, keywords, promotional text, What's New, URLs, screenshot captions. App Store Connect is a deployment target, not the source of truth.
- **Nothing is ever submitted automatically.** Once a version is in review, pulling it back is clumsy, and a human should look at the generated screenshots and copy first.
- **Check App Store Connect's live state before changing it.** Never rely on notes about what's staged or submitted.

## Versioning

- `MARKETING_VERSION` (x.y.z) and `CURRENT_PROJECT_VERSION` (build number) live in `project.yml`. A bump lane sets the version and increments the build number, which never goes down.
- Every release gets an annotated git tag `vX.Y.Z` on its bump commit and a GitHub release.
- Bump commits are titled `Bump to x.y.z`, with a sentence or two on what's included since the last version.
- If a staged version is never submitted, the next version replaces it and its What's New must also cover what the replaced version added. Users go from the *live* version to the new one.

## One-time setup

1. **Paid Apple Developer Program** membership (a free Apple ID can run on your own device for 7-day stretches, but can't publish).
2. **App Store Connect API key** (Users and Access → Integrations → App Store Connect API, role App Manager). Download the `.p8` once to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`. Record the Key ID and Issuer ID in the setup guide; never commit the `.p8` (gitignore `*.p8` as a backstop). This means no Apple ID, 2FA or Xcode Organizer in the loop.
3. **Homebrew Ruby + fastlane** (system Ruby is too old): `brew install ruby`, put its `bin` dirs on `PATH`, then `gem install fastlane`.
4. **XcodeGen** (`brew install xcodegen`).
5. A privacy policy and support page. Here they're static HTML in `docs/`, published with GitHub Pages, which is why the repo is public.

## The pipeline

`ios/scripts/release.sh` archives and uploads with `xcodebuild` using the API key (`-allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …` and an `ExportOptions.plist` with `method: app-store-connect`, `destination: upload`, automatic signing). fastlane wraps it in lanes:

| Lane | Does |
|---|---|
| `test` | Regenerates the project, runs both test targets |
| `bump_version version:x.y.z` | Sets the version, increments the build, regenerates |
| `screenshots` | Runs the screenshot UI test via `snapshot` in every locale, then composites marketing images |
| `build_and_upload` | Runs `release.sh` |
| `stage_app_store version:x.y.z` | Uploads metadata and screenshots with `deliver` (no binary, `submit_for_review(false)`), waits for the build to finish processing, attaches it, then **verifies** in App Store Connect that the screenshots actually landed |

The runbook that ties it together, `.claude/commands/release.md`:

1. Check git state; nothing unrelated gets swept into the release.
2. Run the full test suite. Stop on failure.
3. Bump the version.
4. Capture fresh screenshots.
5. Draft What's New in every locale from `git log <previous tag>..HEAD`: user-facing changes only, plain and specific, in the tone of previous releases.
6. Commit "Bump to x.y.z", push.
7. Tag, push the tag, create the GitHub release (Added / Fixed / Also since / Status; this may mention developer-facing changes).
8. Upload the build.
9. Stage in App Store Connect.
10. Update the release status in `REQUIREMENTS.md`.
11. Report back with links, and say plainly that Submit for Review is the human's step.

## Screenshots

- **Captured by a UI test** (`AppStoreScreenshotUITests`) driving the real app against real data, one `snapshot("NN-Name")` per screen. It's excluded from routine test runs with `-skip-testing`, not at the scheme level (that would also break `snapshot`'s `only_testing`).
- **Use a simulator whose native resolution App Store Connect accepts.** It only takes a fixed set of sizes (e.g. 1284×2778 for 6.7"); the newest flagship simulators render larger and get rejected. `iPhone 14 Plus` works. Verify with one test screenshot before a full run.
- **Composite marketing images** (device frame, background, caption per screen) with a script: HTML/CSS rendered by headless Chrome, captions in a JSON file keyed by `NN-Name`, per locale.
- **Clear the output directory before compositing.** `deliver` uploads every PNG it finds, so a renamed screen would otherwise be uploaded twice.
- **Don't show identifiable real people** in marketing images. Prefer team-level screens over a single player's stats.
- Compositing occasionally fails transiently; re-running just the compositor is enough when the raw captures exist.

## Metadata

`fastlane/metadata/<locale>/`: `name`, `subtitle`, `description`, `keywords`, `promotional_text` (max 170 characters, so count them), `release_notes` (What's New, rewritten every release), and the support/marketing/privacy URLs. When a feature changes what the app does with data, update the privacy policy in the same release.

## Lessons that cost something

- **`deliver` edits whichever version is in progress, whatever its number.** App Store Connect allows one in-progress version. If an earlier version was submitted by hand after staging, `deliver` renames *that* in-review version and overwrites its listing. The staging lane now refuses to run while any version is waiting for review, in review or pending release. Also query the states yourself at the start of a release.
- **Uploads to a version that's already submitted can silently do nothing.** `deliver` reports success, so verify against the API afterwards; the lane checks the screenshot file names it expects.
- **A freshly uploaded build needs minutes of processing** before it can be attached; the lane polls for it.
- **Removing a submission from review** returns the version to an editable state (`DEVELOPER_REJECTED`). It can be done through the API with explicit permission, and then restaged.
