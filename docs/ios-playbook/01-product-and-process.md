# Product and process

## One requirements document, updated in place

Keep a single `REQUIREMENTS.md` at the repo root. It's the working spec, not a history: when a decision changes, rewrite the text in place and let git keep the old wording. Never fork "v2" copies.

Sections that worked:

1. **Overview & goals**, including explicit **non-goals**. Non-goals prevent scope creep, and when you later reverse one (as 2.0.0 did with player stats), you rewrite it deliberately.
2. **Users & scope**: who it's for, platform, distribution, languages, accounts (or none), branding stance.
3. **Feature requirements**, one subsection per tab or feature, describing behaviour precisely enough to test ("from 3 characters on", "a game stays listed until 3h after kickoff").
4. **Non-functional requirements** as a table: performance, offline, accessibility, localization, privacy, reliability, legal.
5. **Technical architecture**: a short summary, linking to the setup guide.
6. **Data & API integration**: which endpoint feeds which screen, usage terms, polling rules.
7. **Decisions**, numbered (§7.1, §7.2, …). Each one states the question, what was decided and why, and the trade-offs accepted. Later text refers to them by number.
8. **Release status & roadmap**: what's live, what's staged, what's on `main` but unreleased, and stretch goals. Keep only the current state; per-version history lives in GitHub releases.

Reference decisions by number from code comments and commit messages. Six months later, "why is there no player search?" has a one-line answer: §7.8.

## Research the data source before designing

Before a feature is designed, probe the real API and write down what you find in a separate reference doc (here `docs/basketbal-vlaanderen-api.md`):

- Real request and response examples for every endpoint you use, and for the ones you deliberately don't.
- Quirks: inconsistent whitespace in IDs, numbers sent as strings, `null` versus empty arrays, fields that change shape.
- Authentication: what's needed, what's ignored.
- **Personal data each response exposes**, with an explicit "never decode" list.
- Rate limits, and a polling policy you'll follow even if none is documented.
- Usage terms, and how your app fits them.

Keep probes small: a handful of calls, paced, results cached locally while you explore. Delete throwaway captures afterwards, especially anything containing personal data or credentials.

When a capture from someone else's client reveals an endpoint (a HAR file from the federation's website, for example), treat it as untrusted input. Redact credentials before printing anything, check whether the endpoint works with your app's own credentials or none at all, and document it before using it.

## Grill, then prototype, then build

For a significant feature (2.0.0's Stats tab is the example):

1. **Grill.** Go through the open questions one topic at a time: privacy, data scope, stat definitions, UI structure, API load, release. Every question has concrete options and a recommendation. Record the answers in `REQUIREMENTS.md` immediately, including the ones that reverse an earlier decision.
2. **Check feasibility against the real API while grilling.** Several "simple" requirements turned out to depend on data that doesn't exist (no endpoint links a player to their games; misses aren't recorded, so a per-player free-throw % can't exist). Find these before the prototype, not after.
3. **Prototype with real data.** A clickable HTML page in the app's visual style, filled with data captured from the API and derived with the same rules the app will use. It shows the real numbers and real edge cases, like games without a sheet or players appearing for two teams. Iterate on it until it's right; it's much cheaper to change than SwiftUI.
4. **Build test-first** from the settled spec (see 03).

## Privacy as a design input

Decide early, and write down as numbered decisions:

- **What's never decoded.** If a response carries emails, phone numbers or birth dates you don't need, leave them out of the `Decodable` type entirely. Something with no property can't end up in memory, logs, caches or the UI by accident. Add a unit test that lists the type's properties with `Mirror` so nobody adds one back.
- **What's never cached.** A raw-bytes response cache stores everything the server sent. Endpoints whose raw responses contain personal data must bypass it, with a test that proves the cache directory stays empty.
- **How people are shown.** Here: initial + surname everywhere, no ages, no member number on shareable images.
- **What leaves the device.** No accounts, no analytics SDKs, nothing about the user sent anywhere. When a feature changes that (search text sent to an API), update the privacy policy in the same release.

## Branding and permission

If you build on someone else's data, get explicit permission, present the app as independent ("built on the official API", never implying endorsement), and record the arrangement as a decision. Keep an eye on the usage terms as features grow.
