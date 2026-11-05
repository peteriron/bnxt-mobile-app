---
description: Release version $ARGUMENTS (x.y.z) to App Store Connect, staged but not submitted
---

Release BNXT version **$ARGUMENTS**. Follow these steps in order and stop at the first failure.
Background: docs/ios-playbook/04-release-and-app-store.md, REQUIREMENTS.md §7.21.

1. **Check git state.** Be on `main`, up to date with `origin/main`, and have a clean working tree. If there are unrelated changes, stop and ask.
   Confirm `$ARGUMENTS` is `x.y.z` and greater than the latest `v*` tag.
2. **Check App Store Connect's live state.** Query it yourself; don't trust notes or memory. If any version is waiting for review,
   in review or pending release, stop and report it.
3. **Run the full test suite:** `cd ios && bundle exec fastlane test`. Stop on any failure.
4. **Bump:** `bundle exec fastlane bump_version version:$ARGUMENTS`.
5. **Screenshots:** `bundle exec fastlane screenshots`. Open every PNG in `ios/fastlane/screenshots/en-US/` and check for
   clipped text, wrong data, placeholder content or identifiable people in close-up. Stop if anything looks wrong.
6. **What's New:** draft `ios/fastlane/metadata/*/release_notes.txt` from `git log <previous tag>..HEAD`. Include user-facing changes only,
   plain and specific, in the tone of earlier releases. If the last staged version was never submitted, also cover what it added.
   Update `promotional_text.txt` (max 170 characters) only if asked.
7. **Commit** `Bump to $ARGUMENTS` with a sentence on what's included; push.
8. **Tag** `v$ARGUMENTS` (annotated) on that commit, push the tag, and create the GitHub release (Added / Fixed / Also since / Status).
9. **Upload:** `bundle exec fastlane build_and_upload`.
10. **Stage:** `bundle exec fastlane stage_app_store version:$ARGUMENTS`. It refuses while a version is with Apple and verifies the screenshots.
11. **Update the version policy** in `config/v1/config.json` only once this version is **live** in the App Store (after the human's release),
    not at staging: raise `latestVersion` to show the banner; raise `minimumVersion` only if old builds must stop (REQUIREMENTS §3.9, §7.24).
    The pre-push hook validates it; `minimumVersion` must never exceed the live version.
12. **Update REQUIREMENTS.md §8** (release status).
13. **Report back** with links to the GitHub release and App Store Connect, and say plainly that **Submit for Review is your step**. Never submit.
