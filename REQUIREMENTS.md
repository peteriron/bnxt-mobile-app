# BNXT League fan app: requirements

The working spec. When a decision changes, rewrite it here in place; git keeps the old wording.
Decisions are numbered (§7.x) so code comments and commits can refer to them.

Related documents:
[docs/bnxt-api.md](docs/bnxt-api.md) (data source reference) ·
[ios/SETUP.md](ios/SETUP.md) (toolchain, build, test, release) ·
[docs/ios-playbook/](docs/ios-playbook/README.md) (how we work) ·
[prototype](prototype/index.html) ([hosted](https://claude.ai/artifact/BTCCtu4TkY31ohTfxLtjUv))

---

## 1. Overview & goals

A native iPhone app for fans of the BNXT League, the joint Belgian–Dutch top basketball league,
built on public league data. It should be the fastest way for a supporter to answer: *when does my
club play, what's the score, where do we stand, and who's playing well?*

**Goals**
- A club-centric Home that shows a supporter's club at a glance (live/next game, last result, standing, leaders).
- Complete, accurate league data: standings, all games, box scores, players, stat leaders.
- Live games with score, clock and play-by-play (subject to data availability, §7.4).
- Feels native: SwiftUI, Liquid Glass, Dynamic Type, VoiceOver, fast and offline-tolerant.

**Non-goals (v1)**
- Push notifications, Live Activities and widgets (§7.3).
- News, video and podcasts (§7.3).
- Dutch and French (strings are localisable from day one; §7.11).
- Accounts, social features, comments, betting or fantasy.
- Following more than one club (§7.8).
- iPad and Mac layouts (deferred, not dropped).
- Season archive and player career history.

## 2. Users & scope

| | |
|---|---|
| Primary user | A **club supporter** of one of the 16 BNXT clubs (§7.1) |
| Secondary user | Neutral league followers and stats fans (served by Games, Standings, Stats) |
| Platform | iPhone, iOS 26+ (§7.13) |
| Distribution | App Store, free, Belgium + Netherlands first |
| Languages | English in v1; Dutch and French later (§7.11) |
| Accounts | None. Favourite club is stored on device (§7.16) |
| Branding | Independent fan app, built with BNXT League's permission to use its data, logos, photos and name (§7.17) |

## 3. Feature requirements

Prototype references: `prototype/app.js` implements every screen below with real data; port its derivation rules
(and their edge cases) rather than reinventing them.

### 3.1 Onboarding
- On first launch: a splash screen, then **Pick your club**: a 3-column logo grid of all clubs of the current season,
  grouped 🇧🇪 Belgium / 🇳🇱 Netherlands, sorted by display name.
- The continue button is disabled until a club is picked and then reads "Follow <club>".
- The choice is stored on device. It can be changed from Settings and from any club page ("Make my club").

### 3.2 Home (club-centric)
In this order:
1. **Live card** when the favourite club is playing: logos, live score, period + clock, the last play.
   Tapping it opens Game detail (§3.4).
2. **Next game** (opponent, vs/@, "In N days" or "Today", date and time) and **Last result** (W/L, score), side by side.
3. **Standing**: league position, W–L, current streak, national rank ("3rd of the Belgian clubs"), whether
   the club is in a playoff place, and a 5-row snippet of the table centred on the club.
4. **Club leaders**: the club's top player in PTS, REB, AST and VAL (per-game averages).
5. **Around the league**: results from the most recent round of games (the last 4 days with results), as a horizontal carousel.
6. **League leaders**: VAL top 3.
- Header: club logo and name, plus Search and Settings buttons.

### 3.3 Games
- Segmented **Upcoming / Results**; filter chips **All clubs / <my club>**.
- Grouped by day with headers "Today", "Tomorrow", "Yesterday", or the full weekday and date.
- Live games are pinned in a **Live now** section at the top of Upcoming.
- Row: both clubs (logo, display name, score when started), status column (time / LIVE + clock / Final). The winner is shown
  in full colour and the loser dimmed. A dot marks the favourite club.
- Results newest first, upcoming soonest first.

### 3.4 Game detail
- Header: competition and phase, status (date/time and arena, LIVE + clock, or Final), both clubs (tappable to the club page)
  with records, and a big score or tip-off time.
- **Quarter table** (Q1–Q4, OT columns when played, total).
- Tabs depend on state:
  - **Live:** Play-by-play (newest first, with the score after each scoring play and a 3PT marker) · Box score · Summary · Info.
  - **Final:** Summary · Box score · Info.
  - **Upcoming:** Preview · Info.
- **Summary:** top performer per club (highest VAL), team comparison bars (FG, 3P, FT with made/attempted, REB, AST, STL, BLK,
  TOV, where the lower value wins), game leaders (PTS, REB, AST).
- **Box score:** club switch. Columns MIN PTS REB AST STL BLK FG 3P FT OR TO PF (+/- if any non-zero) VAL. Starters marked,
  team totals row, sticky player column, horizontal scroll. Tapping a row opens the player.
- **Preview:** record, position, PPG, points allowed, REB, AST, FG%, 3P%, last-5 form for both clubs, a "player to watch" per club
  (highest VAL), earlier meetings this season, **Tickets** (the home club's ticket URL) and **Add to Calendar**.
- **Info:** date and tip-off (CET/CEST), arena and city, where to watch (BNXT.tv), tickets (not for finished games), and
  the official game report on bnxtleague.com.

### 3.5 Standings
- Segmented **League / Belgium / Netherlands / Playoffs** (§7.5).
- Table: rank, club, W, L, point difference, streak. A colour stripe marks the zone, the favourite club's row is tinted,
  and tapping a row opens the club.
- Belgium and Netherlands show national ranks with a dashed **cut line** after the last playoff place.
- **Playoffs:** projected brackets "if the season ended today", labelled *Projected*. BE quarter-finals 1v8, 4v5, 2v7, 3v6 → semi-finals → final;
  NL semi-finals 1v4, 2v3 → final. Series lengths are shown.
- A legend and a "How the season works" explainer, both driven by config (`zones`, `playoffs`, `seasonExplainer`).

### 3.6 Stats
- Segmented **Players / Teams**.
- Players: category chips VAL, PTS, REB, AST, STL, BLK, 2P%, 3P%, FT%. A hero card for #1 (photo, value, club), then ranks 2–20
  with bars. Source: league rankings (minimum-attempt rules are the league's).
- Teams: PPG, points allowed, RPG, APG, FG%, 3P%, SPG, TPG (lower is better for points allowed and turnovers), computed from box scores.
- A **Compare** button opens §3.7.

### 3.7 Compare players
- Two slots (A violet, B orange). Defaults: A = the favourite club's top player by VAL; B = the league VAL leader (or the next leader if that's A).
- Tapping a slot opens a sheet with a search field (player or club) listing players by VAL.
- 12 mirrored bars: PTS, REB, AST, STL, BLK, TOV (lower wins), FG%, 3P%, FT%, VAL, MIN, GP. The better value is highlighted;
  equal values highlight neither.
- Reachable from Stats and from any player page ("Compare with another player" pre-fills A).

### 3.8 Clubs, club page, player page, search, settings
- **Clubs:** a search field, then 3-column grids per country (logo, display name, W–L and position, a star on the favourite).
- **Club page:** a hero in the club colour (logo watermark), display name, country, city, arena, official name, facts (record,
  position, PPG, points allowed), **Make my club**, **Tickets**. Tabs Roster (by jersey number: photo, name, position, height, flag, PPG) ·
  Games (upcoming, then results with form) · Player stats (sortable per-game table).
- **Player page:** a cut-out photo hero with a jersey-number watermark, first name and SURNAME, club. Bio: position, height, age,
  nationality. Season averages (PTS REB AST VAL / STL BLK TO PF) with "#N in league" badges for top-10 ranks; shooting
  rings (FG, 2PT, 3PT, FT with made/attempted per game); points-per-game chart with the average line; game log (opponent, W/L,
  score, MIN PTS REB AST) linking to games. Players without games yet show bio only.
- **Search:** players and clubs, from the first character, with suggestions when empty.
- **Settings:** my club, language (English; NL/FR "coming later"), show onboarding again, data source and date.

### 3.9 Version checker
Keeps every user on a build that works (§7.18).
- States: **up to date** · **update available** (a dismissible Home banner, shown once per latest version, plus a Settings row) ·
  **update required** (a full-screen blocking view with an Update button, which can't be dismissed) · **unknown** (behaves as up to date).
- Inputs: installed `CFBundleShortVersionString` and the **version policy** in the remote config (§7.24): `latestVersion`, `minimumVersion`,
  `blockedVersions[]`, `storeURL` (optional until the app has a store page), localised `message`, `minimumDataSchema`.
- An unsound policy (unparsable version, `minimumVersion` above `latestVersion`, non-https `storeURL`) is ignored, so a typo can't lock users out.
- Rules, in order:
  1. Installed version unparsable or no policy → unknown.
  2. Installed version in `blockedVersions` → required.
  3. Installed version below `minimumVersion` → required.
  4. App data schema below `minimumDataSchema` → required.
  5. Installed version below `latestVersion` → available.
  6. Otherwise → up to date.
- Versions compare as SemVer `MAJOR.MINOR.PATCH` (missing parts = 0, numeric not lexical, pre-release suffix ignored).
- Checked on launch and when returning to the foreground, at most once per 6 hours. The config is cached on device.
- **A network failure never blocks the app:** a failed check keeps the previous status; the config falls back to the cached copy, then to
  the copy bundled into the build (which by construction never blocks that build).
- A policy change must pass a validation test before it's published: `minimumVersion ≤ latestVersion`, `storeURL` is https,
  and `minimumVersion` is not above the version live in the App Store.

## 4. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Cold launch to cached Home < 1.5 s on a recent iPhone; lists scroll at full frame rate; box score opens < 300 ms from cache |
| Offline | The last successful response per request is cached; on failure the cache is served with a "last updated" time; first launch offline shows a clear empty state |
| Network etiquette | Requests stay well inside the API's rate limit; live polling only while the live screen is visible (docs/bnxt-api.md, "Polling policy") |
| Accessibility | Dynamic Type up to AX sizes (stacked layouts, tables scroll); VoiceOver labels on logos, scores and live state; text tokens ≥ 4.5:1 (tested); Reduce Motion respected |
| Localization | String Catalogs; `LocalizedStringKey` for UI text, `Text(verbatim:)` for data; plurals for counts |
| Privacy | §7.16: no accounts, no analytics or tracking SDKs, no personal data beyond public player profiles |
| Reliability | Lenient decoding: one bad record never drops a list. Crash-free sessions ≥ 99.5 % |
| Legal | BNXT permission for data, logos, photos and name: granted (§7.17). Live feed and app API key still to confirm |
| Quality | Every feature ships with tests; every bug fix starts with a failing test (§7.19) |

## 5. Technical architecture

SwiftUI + MVVM on iOS 26, Swift 6 with strict concurrency, no third-party runtime dependencies (§7.13). The Xcode project is generated
from `ios/project.yml` (§7.12). Code lives in the app target under `App/ Models/ Networking/ Persistence/ Services/
ViewModels/ Views/ Theme/ Resources/`; tests in `BNXTTests` (XCTest) and `BNXTUITests` (XCUITest). Details and commands are in
[ios/SETUP.md](ios/SETUP.md).

### 5.1 Design tokens (from the prototype, `Theme.swift`)

| Token | Value | Use |
|---|---|---|
| ink / surface / surface2 / surface3 | `#07060B` / `#14121C` / `#1D1A28` / `#29253A` | Backgrounds, cards, controls |
| textPrimary / textSecondary / textTertiary | `#F5F3FB` / `#A9A4BD` / `#8A84A3` | Text levels (tertiary raised, §7.20) |
| violet / violetHigh | `#6441FF` / `#A08CFF` | Brand, league-leader zone, compare A |
| lime | `#E2FF00` | Highlight, my club, BE playoff zone, selected tab |
| orange | `#FF6A13` | NL playoff zone, compare B |
| live / win / loss | `#FF3B52` / `#3DDC97` / `#FF5C74` | Semantic |

Display type: wide, heavy italic (the brand uses Druk Wide; see §7.10) for titles and numbers, with tabular digits. SF Pro for text.
Club colours (config `teams[id].color`, §7.25) drive hero gradients, bars and rings. Graphics lift a club colour that's below **3:1**
against the background (WCAG non-text contrast) by mixing it towards white until it reaches 3:1; text never uses club colours.
Dark logos get a light plate (prototype: `DARK` detection).

## 6. Data & API integration

Source: the BNXT League's JSON API behind bnxtleague.com (`bnxt.sportpress.info/api/v1`). Full reference, quirks,
personal-data inventory and polling policy are in [docs/bnxt-api.md](docs/bnxt-api.md).

| Screen | Endpoints |
|---|---|
| Onboarding, Clubs | `competition-team/all`, `standings/…` |
| Home | `standings/…`, `schedule/game-slider`, `competition-team/player-averages/{team}`, `player/average-rankings` |
| Games | `schedule/game-slider` (+ full schedule, still to find: §8 Phase 0) |
| Game detail | `schedule/find/{game}`, `schedule/overview/{game}`, `boxscore/game/{cid}/{game}`, live: still to find (§7.4) |
| Standings | `standings/competition/{cid}/phase/{phase}` + season config |
| Stats | `player/average-rankings/{cid}`, team aggregates from box scores |
| Club page | `competition-team/find/{team}`, `roster/team-players/{team}`, `competition-team/player-averages/{team}`, `competition-team/statistics-by-game/total/{team}` |
| Player page | `roster/find/{roster}`, `boxscore/player/season-games/{roster}`, rankings |

Usage terms: none published; the API requires a client key that the website ships publicly. Using it for
research is fine; a public release needs BNXT's permission (§7.17).

## 7. Decisions

**§7.1 Primary persona: club supporter.** Home is built around one favourite club picked at onboarding.
*Why:* most fans follow one club; league-wide views remain one tab away. *Trade-off:* neutral fans get a club-centric Home.

**§7.2 Tabs: Home · Games · Standings · Stats · Clubs.** Players are reached via Clubs, Stats, game detail and search.
*Why:* matches how fans navigate (by club and by game). Five tabs is the iPhone maximum without "More".

**§7.3 v1 scope = core + live + stat leaders/compare.** Push, news/video, widgets and Live Activities come after v1.
*Why:* push needs a backend (§7.15) and news duplicates the website; live and stats are the differentiators.

**§7.4 Live games are in v1, using the FIBA LiveStats feed for now.** *Decided 4 Nov 2026:* live clock, period and play-by-play
come from the public Genius Sports / FIBA LiveStats JSON (`…/data/{genius_id}/data.json`, no key), the feed the website's
"live stats" link uses; scores and box scores also keep coming from the BNXT API. *Why:* it's the only live play-by-play source found,
and it works today. *Risks accepted:* the feed belongs to Genius Sports, not BNXT, and may change or be blocked without notice, so the app
treats it as optional (live screens fall back to BNXT scores refreshed on the polling schedule) and remote config can switch it off.
*To do:* confirm with BNXT whether their agreement covers it (§7.17), and measure its update cadence on a game night (Phase 0).
*Note:* the prototype's live game is simulated and labelled so.

**§7.5 Standings: phase switcher with zones from config.** League / Belgium / Netherlands / projected Playoffs. Zones are
league leader (violet), Belgian top 8 (lime) and Dutch top 4 (orange), with no relegation in 2026-27.
*Why:* the format changes from season to season, so the rules are data, not code.

**§7.6 Game detail is full depth.** Quarters, team comparison, full box scores, top performers, game leaders, info, tickets.
*Why:* box scores are the most-requested stats content; the data is complete for finished games.

**§7.7 Compare = season averages side by side.** No game-log trend in v1.

**§7.8 One favourite club in v1.** Multiple favourites come later. *Why:* keeps Home simple and decisive.

**§7.9 Dark mode only in v1.** `UIUserInterfaceStyle = Dark`. *Why:* the brand identity is dark-first; a light theme
needs its own design pass, not an inversion.

**§7.10 Brand font: Archivo.** *Decided 4 Nov 2026.* The website's face, Druk Wide (Commercial Type), is commercial. Archivo is free
(SIL OFL 1.1), close in character, and already used by the prototype. Bundled faces (`Resources/Fonts/`, `UIAppFonts`, `DisplayFace`):
Archivo Expanded Black Italic for headlines (`Theme.display`), Archivo Expanded ExtraBold Italic for scores and big numbers (`Theme.score`),
Archivo SemiExpanded ExtraBold Italic for dense numbers (`Theme.compactNumber`). All scale with Dynamic Type; body text stays SF Pro.
The OFL text ships with the fonts. *Alternatives considered:* a Druk Wide app licence, Hubot/Mona Sans, Anybody, Saira, SF Pro Expanded.

**§7.11 English is the development language.** String keys are English source text; NL and FR are added later via the
String Catalog. *Why:* serves both countries equally until both translations exist. (The playbook's previous project used
Dutch; this one deliberately doesn't.)

**§7.12 Generated Xcode project.** XcodeGen from `ios/project.yml`; `.xcodeproj` and Info.plist are git-ignored.

**§7.13 Architecture: SwiftUI + MVVM with `@Observable`, iOS 26+, no third-party runtime dependencies.**
View models are `@MainActor @Observable final class`es with dependencies injected through initializers (API client, stores,
`now`, debounce intervals); no singletons inside tested types. One hand-written `URLSession` client with one method per endpoint.
*Why `@Observable` instead of the playbook's `ObservableObject`:* iOS 26 is the minimum, and Observation tracks nested
observable objects, which removes the playbook's "nested ObservableObject doesn't re-render" pitfall.
*Why iOS 26:* Liquid Glass and the current SwiftUI APIs; the audience is on recent iPhones.

**§7.14 Season, competition and phase IDs are configuration.** They change every summer (2026-27: season 2027, competition 25, phase 183).
Bundled fallback in `Season.current`, overridable by remote config.

**§7.15 No backend; the app uses the website's API key for now.** *Decided 4 Nov 2026:* the app talks straight to the BNXT API with
the bnxtleague.com client key, with a file cache, and remote config (version policy, season IDs, zones, display names, club colours) is a
static JSON file. The key reaches the app at build time (`ios/Config/Secrets.xcconfig`, git-ignored → Info.plist `BNXTAPIKey` →
`APIConfiguration`); locally from `.env`, in CI from the `BNXT_API_KEY` Actions secret. It's never committed, because the repo is public.
*Risks accepted:* anyone can extract a key from an app binary (it's already public on the website); if the website rotates its key, every
installed app breaks until a new key arrives, so remote config will be able to override the key, and the version checker (§3.9) is the last resort.
*Revisit (a proxy or an app-specific key from BNXT) if:* the game-night recording shows the 200-request limit is shared per key; BNXT asks
us to stop using the website key; or push notifications move into scope (§7.3).

**§7.16 Privacy.** No accounts, no analytics, advertising or tracking SDKs; nothing about the user leaves the device except the
data requests themselves. Crash data only via Apple's opt-in reporting (Xcode Organizer / MetricKit).
Player data shown is the league's public profile: name, photo, jersey, position, height, nationality, **age** (computed from
birth date; the date itself is never shown). **Never decoded:** players' `facebook` / `twitter` / `instagram` fields and the free-text
`description`; staff personal fields if they ever appear. Enforced by `Decodable` types without those properties and a `Mirror` test.
The response cache stores raw JSON only after `PrivacyFilter` has removed those keys, so they never reach disk either (tested).
The favourite club is stored in `UserDefaults` only.

**§7.17 Permission and branding.** *Granted 4 Nov 2026:* BNXT League gave permission to use its data, club logos, player photos and the
"BNXT" name. Keep the written confirmation (outside the repo) and re-check its scope when features grow.
*Consequences:* the logos and photos in `prototype/data.js` may live in the public GitHub repo; the app still presents itself as an
independent fan app built with the league's permission, not as the official app, unless BNXT says otherwise.
*Still open:* (a) whether the permission covers an **app API key** and the expected request volume (§7.15); (b) whether it covers the
**Genius Sports / FIBA LiveStats feed** (§7.4); that feed belongs to Genius Sports, so it likely needs their licence or BNXT's sublicence.
Bundle ID / App ID: `com.pjproductions.bnxt` (confirmed 4 Nov 2026, registered in the developer account).

**§7.18 Version checker with soft and hard updates** (§3.9). The policy lives in the remote config (§7.24).
*Why:* the data source is unversioned and outside our control; if it changes we must be able to move users onto a fixed build.
A network failure never blocks.

**§7.19 Testing: XCTest unit tests + XCUITest UI tests** per the playbook. Golden fixtures from real finished games, one shared
`MockURLProtocol`, test-first bug fixes, UI tests by identifier and the tab bar by index.
*(The earlier plan used Swift Testing in a Swift package; dropped in favour of the playbook's two app test targets.)*

**§7.20 Tertiary text colour raised from `#716B88` to `#8A84A3`.** *Why:* the prototype value measured 4.0:1 on ink and 3.67:1
on surface, which fails WCAG AA. The new value measures 5.7:1 and 5.2:1. Pinned by `ThemeTests.testTextTokensClearAAContrast`.

**§7.21 Releases: one command minus the last click.** fastlane + App Store Connect API key, metadata in git, and screenshots captured by
`AppStoreScreenshotUITests`; a human presses Submit for Review (playbook 04).

**§7.22 Tests run on the developer's Mac, not GitHub's macOS runners.** *Decided 4 Nov 2026:* `ios/scripts/ci-local.sh` runs lint and
both test suites on the Mac against the pushed commit and posts a `local-tests` commit status, next to GitHub's `lint` job (a SwiftLint
container on Linux). *Why:* GitHub's macOS runners queued 5–15 minutes per run, while the local
run takes about a minute. *Why not a self-hosted runner:* the repo is public, and a fork's pull request could run code on the Mac.
*Trade-off:* checks only run when someone runs the script; the GitHub macOS job stays available as a manual fallback.

**§7.23 Solo development: commit straight to `main`, no branches or PRs.** *Decided 4 Nov 2026.* *Why:* one developer, so a PR per
change adds ceremony without review value. `main` still blocks force-pushes and deletion. Checks aren't required for merging, because
there's nothing to merge; `ci-local.sh` runs after every push instead. *Revisit when* a second contributor joins or the project changes:
then go back to the playbook's branch + PR flow and require `local-tests` and `lint` on `main` again. (The PR template stays for that.)

**§7.24 Remote config is a static file in this repo.** *Decided 5 Nov 2026:* `config/v1/config.json` (season IDs, standings zones,
playoff format and season explainer, display names and cities, feature flags, version policy, an emergency API-key override) is served from
`https://raw.githubusercontent.com/peteriron/bnxt-mobile-app/main/config/v1/config.json` and bundled into every build as the offline
fallback. *Why:* no backend (§7.15), reviewed in git like code, one source for the remote and bundled copies.
*Consequences:* pushing a change to `main` publishes it within minutes (GitHub's CDN caches ~5 min), so the `tools/hooks/pre-push` hook
runs the config tests before any push that touches `config/`; the app ignores unsound policies and newer-schema sections it doesn't
understand. The path carries a version (`v1`): a breaking schema change gets `v2/` while old apps keep reading `v1/`.

**§7.25 Club colours are curated brand colours in the remote config.** *Decided 5 Nov 2026:* one `#RRGGBB` per club, picked by eye from
the candidates `tools/club_colours.py` extracts from each logo (the largest cluster is often black outline or a mascot's face, so it's
never automatic). Stored as the true brand colour, even when dark: 7 of 16 are below 3:1 on ink (Brussels 1.1:1, Mons 1.2:1, Liège 1.4:1,
Oostende 1.7:1, Hammers 2.0:1, Antwerp 2.3:1, Mechelen 2.8:1), so graphics apply the 3:1 lift in §5.1. *Why in config, not code:*
clubs rebrand between seasons. *Re-check* each summer with `tools/club_colours.py --check`.

**§7.26 Logo plates and club countries are config.** *Decided 6 Nov 2026:* six logos are too dark for the UI (Brussels, Kortrijk,
Den Bosch, Aalst, Oostende, Mechelen) and sit on a light circular plate (`teams[id].logoPlate`). They were chosen by eye on the card
background; a brightness threshold alone misjudged Mechelen. Each club's `country` is in the config too, so onboarding can group clubs
before the API answers. The favourite club is stored with its short name and re-linked by it when ids change at a new season.

**§7.27 Deep links: `bnxt://club/{id}`, `bnxt://game/{id}`, `bnxt://player/{rosterId}`.** *Decided 6 Nov 2026:* a custom URL scheme
(universal links need a website we don't run). A link selects its tab (club and player: Clubs; game: Games) and replaces that tab's
stack, so Back returns to the tab's root. Tapping the selected tab pops to its root. Each tab has its own navigation stack (`Router`).

## 8. Release status & roadmap

**Live:** nothing yet. **On `main`:** app shell 0.1.0 (5 placeholder tabs, Archivo display type, theme tokens, API key plumbing, test targets, local CI), live recorder.
**Prototype:** v0.1 (HTML, data snapshot 3 Nov 2026).

### Phase 0: foundations & permission (in progress)
- [x] Repo, generated Xcode project, unit and UI test targets, CI, lint config, scratch dir, release scaffolding
- [x] Contact BNXT League: permission for data, logos, photos and name granted 4 Nov 2026 (§7.17)
- [x] Use the website key and the FIBA LiveStats feed for now (§7.15, §7.4); key plumbing via `Secrets.xcconfig` + CI secret
- [ ] Ask BNXT: is using the website key at app volume OK, and does the agreement cover the FIBA LiveStats feed (§7.15, §7.4)
- [ ] Record a live game night with `tools/record_live.py` (first chance: Thu 5 Nov, CHA–RCB 20:30): what `status` and live endpoints return, update cadence (§7.4)
- [ ] Find the full-season schedule call (the website's calendar page)
- [ ] Determine whether the rate limit is per key or per IP (game-night recording) → revisit §7.15 if shared
- [x] Set `DEVELOPMENT_TEAM` (92HC396B37)
- [x] Brand font: Archivo, bundled (§7.10); App ID `com.pjproductions.bnxt` confirmed (§7.17)

### Phase 1: data layer (in progress)
- [x] API client `BNXTAPIClient`: one method per endpoint (11), lenient models, `Fetched` values with source and time
- [x] File cache with offline fallback, cache-first for finished box scores (empty ones refetched), privacy-filtered (§7.16)
- [x] Golden fixtures from game 11323 / team 537 (`tools/make_fixtures.py`), shared `MockURLProtocol`, privacy `Mirror` tests
- [ ] FIBA LiveStats client for live play-by-play (§7.4), once the game-night recording shows the feed's shape and cadence
- [ ] Full-season schedule endpoint (still unknown; `gameSlider` + `teamGames` cover today's needs)
- [x] Remote config `config/v1/config.json` (§7.24): season, zones, display names, cities, features, version policy, key override; network → cache → bundled; pre-push validation hook
- [x] **Version checker** (§3.9): rules, 6 h throttle, blocking screen, dismissable Home banner, UI tests via `--uitest-version-policy`
- [x] Club colours in the config (§7.25), curated from logos with `tools/club_colours.py`

### Phase 2: design system & shell (done, 6 Nov 2026)
- [x] Components: `ClubLogo` (plate, initials fallback), `GameRow`, `LiveCard`, `StatusPill`, `FormStrip`, `ChipBar`, `SectionHeader`,
  `StatRing`, `Sparkline` (Swift Charts), `BoxScoreTable` (pinned player column); colour lift to 3:1 for graphics (§5.1)
- [x] `Club` (API team + config), `AppModel` (config + clubs, config-only fallback), `FavoriteClubStore` (re-links after season change)
- [x] Onboarding (§3.1), Settings (§3.8), Home header with my club, version-checker banner and blocking screen
- [x] `Router`: tab selection, one stack per tab, deep links (§7.27); destination placeholders for club / game / player
- [x] Debug component gallery (`bnxt://debug/gallery`) for on-screen review
- [x] Native segmented control styling: the system segmented `Picker` (first used by Standings, Phase 3)

### Phase 3: core screens (in progress)
One slice per commit, each with its unit and UI tests. Standings comes first because Clubs, the club page and Home use its ranks and zones.
- [x] Standings (§3.5): League / Belgium / Netherlands tables, config zones, cut line, projected brackets; playoff format and
  "How the season works" text in the config (`playoffs`, `seasonExplainer`)
- [x] Clubs tab and club page (§3.8): searchable 3-column grid with record and position; hero, facts, Make my club, Tickets;
  Roster (jersey numbers from the latest box score, since rosters often send none) · Games (upcoming from the game slider) · Player stats
- [ ] Player page (§3.8)
- [ ] Games and game detail, final + upcoming (§3.3, §3.4)
- [ ] Stats and compare (§3.6, §3.7)
- [ ] Home (§3.2)
- [ ] Search (§3.8)

### Phase 4: live
Live polling (visible-only), live card, live game detail; verified on two real game nights.

### Phase 5: hardening & beta
Accessibility and performance passes, Dynamic Type, offline, a TestFlight beta with fans of 2–3 clubs.

### Phase 6: launch
App Store metadata and screenshots, version policy set to 1.0.0, phased release.

### After v1 (stretch)
Push notifications and Live Activities (needs §7.15 revisited) · widgets · NL/FR · news & video · multiple favourites ·
season archive · player careers · iPad.
