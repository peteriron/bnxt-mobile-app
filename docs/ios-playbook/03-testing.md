# Testing

## Two targets with different jobs

| | Unit tests (XCTest) | UI tests (XCUITest) |
|---|---|---|
| **Covers** | Models and their decoding quirks, derived values, persistence, the API client, view models, localization, design tokens | Real on-screen flows: navigation, search, follow/pin, gestures, sheets, drill-downs |
| **Data** | Mocked network and fixtures | The real app, real bundled data, real API. No mocking at this layer |
| **Speed** | ~1 s for 350+ tests | Minutes; network-bound |

Run both before calling anything done:

```bash
cd ios
xcodebuild -project App.xcodeproj -scheme App \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skip-testing:AppUITests/AppStoreScreenshotUITests \
  -collect-test-diagnostics never test
```

`-collect-test-diagnostics never` matters: without it, any failure triggers `simctl diagnose`, which can add 10 minutes before the run reports. The `.xcresult` bundle still contains failure messages, screenshots and UI hierarchies.

## Rules

- **Every feature ships with its tests** in the same change: unit tests for the logic, plus a UI test if the feature has a flow or gesture a unit test can't reach.
- **Every bug fix starts with a failing test.** Write the test that reproduces the bug, run it and watch it fail with the real error, fix the code, watch it pass, and keep it as permanent regression coverage. Name it after the bug and explain it in a comment (when it was found, what broke).
- **A changed behaviour means an updated test, not a deleted one.** When a test fails after a deliberate change, re-read it first: it might be catching a real regression. If it isn't, update its expectation (e.g. "3 tabs" → "4 tabs").
- **Add a new source file, regenerate the project** (`xcodegen generate`), or the file silently isn't compiled.

## Unit-test techniques

- **Golden tests on real data.** Pick a real, finished record whose data will never change (here, one finished game) and commit its real API responses as fixtures, with personal fields stripped. Validate derived numbers against an independent source once, then pin them in tests. Every aggregate (season averages, team quarters) can be checked against the same fixture.
- **One URL-protocol mock** (`MockURLProtocol`) intercepts all requests made through an injected `URLSession`. Reuse it; never write a second mock. For multi-endpoint flows, add a small **router** that answers by path (and by an ID in the request body), records every request thread-safely, and can be told to fail a given endpoint. Tests then assert on *calls made*: "the second open costs exactly 2 requests", "no participants fetch when there's no sheet".
- **Read PUT bodies from `httpBodyStream`.** Inside `URLProtocol`, `httpBody` is usually nil.
- **Privacy assertions:** `Mirror` over a decoded type's properties proves fields you must never hold don't exist; an empty temp cache directory proves a response wasn't cached.
- **Inject time and debounce intervals** so tests are deterministic and instant. Expose an in-flight `Task` (e.g. `pendingSearch`) so a test can `await` it.

## UI-test techniques and pitfalls

- **A shared base class** (`UITestCase`) launches the app with a reset argument so every test starts from known-empty state, and provides helpers (tab accessors, waits, scrolling, keyboard dismissal).
- **Query by `accessibilityIdentifier`**, never by on-screen text: the simulator's language decides which text appears.
- **Query the tab bar by index**, not identifier. SwiftUI sometimes leaves a tab item's identifier unset on its first render.
- **An identifier on a container is copied onto every element inside it.** Give such containers `.accessibilityElement(children: .contain)` first.
- **A focused search field swallows the next tap** as focus resignation. Dismiss the keyboard explicitly before tapping elsewhere. Tap the keyboard's Search key by coordinate: `element.tap()` on a key can fail its scroll-to-visible step on new simulators.
- **Make predicates exact.** `label CONTAINS 'A. Jans'` also matched "A. Janssen".
- **Don't let two screens share a property or identifier name.** Several pin stars on one screen needed different identifiers; a subclass property named like the base class's broke the build.
- **Debug-only launch arguments** that open a screen directly (e.g. `--uitest-open-match <id>`) keep UI tests short and also help with manual checks and screenshot capture.

## Look at the screens

Passing tests don't show untranslated strings, clipped text or wrong numbers. After building UI, capture screenshots: a throwaway UI test that calls `XCTAttachment(screenshot:)` with `.keepAlways`, then `xcresulttool export attachments`. Look at every screen in both languages. This is how a decoding bug (two games silently missing from a team's stats) and a batch of untranslated strings were caught here. Delete the throwaway test afterwards.

## Manual QA

Keep a short list in the setup guide of what automation can't reach: live-network behaviour, offline after a successful load, sharing and printing on a real device.
