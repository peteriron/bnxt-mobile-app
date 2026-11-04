# iOS app playbook

How Vlaanderen Courtside was designed, built, tested and shipped, written as principles that carry over to a new iOS project. Each file covers one area. The examples come from this project; replace them with your own as you go.

| File | What it covers |
|---|---|
| [01-product-and-process.md](01-product-and-process.md) | Requirements as a living decisions log, researching the data source, "grill, then prototype, then build", privacy decisions |
| [02-architecture.md](02-architecture.md) | SwiftUI + MVVM, dependency injection, networking and caching, persistence, generated Xcode project, design tokens, localization, accessibility |
| [03-testing.md](03-testing.md) | Two test targets, test-first bug fixes, real-data fixtures, mocking the network, UI-test pitfalls |
| [04-release-and-app-store.md](04-release-and-app-store.md) | Versioning, the scripted release pipeline (fastlane + API key), screenshots, metadata in git, stopping before Submit for Review |
| [05-working-with-claude.md](05-working-with-claude.md) | Repo conventions that make an AI pair productive: `CLAUDE.md`, scratch directory, release runbook, memory |
| [CLAUDE.template.md](CLAUDE.template.md) | A starting `CLAUDE.md` for the new project |

## Using this in a new project

1. Copy this folder into the new repo, e.g. as `docs/playbook/`.
2. Copy `CLAUDE.template.md` to the repo root as `CLAUDE.md` and fill in the placeholders.
3. Start a `REQUIREMENTS.md` using the structure in 01, before writing code.
4. Set up `project.yml`, the two test targets and the release tooling from 02–04 in the first week, while the app is small. Retrofitting them later costs much more.

## The principles in one page

- **Decide in writing.** One requirements document, updated in place, with a numbered decisions section that records *why*. Git history holds the old versions.
- **Verify the data source before designing around it.** Probe the real API, write down what it returns, what it costs and what it exposes, then design.
- **Grill, prototype, build.** Settle open questions one topic at a time, click through a prototype filled with real data, and only then write production code.
- **Privacy is a design input.** Decide what personal data is never decoded, stored or shown, and enforce that in the type system, not with good intentions.
- **Plain, testable architecture.** SwiftUI + MVVM, dependencies injected through initializers, no singletons inside types you test, no backend unless one is unavoidable.
- **Nothing generated is committed.** The Xcode project comes from `project.yml`; screenshots come from a UI test; build output stays out of git.
- **Every feature ships with tests, and every bug starts with one.** A failing test that reproduces the bug comes before the fix.
- **Releases are one command, minus the last click.** Bump, test, screenshot, upload and stage are scripted; a human reviews and presses Submit for Review.
- **Check the live state before acting on it.** Never trust notes about what's in App Store Connect; query it.
