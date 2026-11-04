# BNXT League fan app

A native iPhone app for BNXT League (Belgium + Netherlands) basketball fans: a club-centric Home, live games, standings with the
playoff picture, stat leaders, player compare, clubs and players.

| Start here | |
|---|---|
| [REQUIREMENTS.md](REQUIREMENTS.md) | Scope, feature requirements, numbered decisions, roadmap |
| [docs/bnxt-api.md](docs/bnxt-api.md) | The data source: endpoints, quirks, personal data, polling policy |
| [ios/SETUP.md](ios/SETUP.md) | Toolchain, build, test, release |
| [docs/ios-playbook/](docs/ios-playbook/README.md) | How we work |
| [prototype/index.html](prototype/index.html) | Clickable HTML prototype with real data ([hosted](https://claude.ai/artifact/BTCCtu4TkY31ohTfxLtjUv)) |

## Quick start

```bash
brew install xcodegen swiftlint
cd ios && xcodegen generate && open BNXT.xcodeproj
```

## Repo layout

```
ios/
  project.yml        XcodeGen spec (the .xcodeproj is generated, not committed)
  BNXT/              app target: App/ Models/ Theme/ Views/ Resources/ …
  BNXTTests/         XCTest unit tests
  BNXTUITests/       XCUITest UI tests (+ App Store screenshot capture)
  fastlane/          release lanes and App Store metadata
  scripts/           release.sh (archive + upload)
docs/                API reference, iOS playbook
prototype/           HTML prototype + data snapshot
tools/               research scripts for the upstream API (need .env)
.claude/commands/    /release runbook
.tmp/                scratch space (git-ignored)
```

## Content notice

Club logos, player photos, league data and the BNXT name are used with BNXT League's permission (REQUIREMENTS §7.17).
They remain the property of BNXT League and the clubs; they're not covered by any licence for this repository's code.
