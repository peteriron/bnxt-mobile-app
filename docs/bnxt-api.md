# BNXT League API reference

What we found by probing the API that powers bnxtleague.com (a Vue single-page app). Verified 3–4 Nov 2026.
Decisions that depend on this file are in [REQUIREMENTS.md](../REQUIREMENTS.md) §7.

## Basics

| | |
|---|---|
| Base URL | `https://bnxt.sportpress.info/api/v1` |
| Auth | Header `X-Authorization: <client key>`. Without it: `401 {"errors":[{"code":"401","message":"Unauthorized"}]}`. `server-config` works without a key |
| The key | The website's public client key, visible in its JS bundle. Used by the app for now (REQUIREMENTS §7.15): `.env` for scripts, `ios/Config/Secrets.xcconfig` for builds, the `BNXT_API_KEY` Actions secret for CI, all outside git. Never commit or print it |
| Other headers the site sends | `Content-Type: application/json`, `X-Localization: en\|nl\|fr`, and `?lang=en` on every URL |
| Rate limit | `X-RateLimit-Limit: 200`, `X-RateLimit-Remaining`, per **~1-minute window** (resets every 62–65 s) and counted **per client IP, not per key** (game night 5 Nov 2026, below). No 429 seen yet |
| Caching | `Cache-Control: no-cache, private`, no ETag / Last-Modified. Apply our own TTLs |
| CORS | `Access-Control-Allow-Origin: *` |
| Envelope | `{ "data": … }`, except `*/average-rankings`, which return categories at the top level |
| Trailing slash | `schedule/game-slider/` → 301. Call without the slash |
| Usage terms | None published |

## Season IDs (2026-27)

Season `2027` · competition `25` ("BNXT League 2026-2027") · phase `183` ("Regular season 2026-27").
Country "clubs": `1` = Belgium, `2` = Netherlands.
Competition-team IDs (new every season): 537 CHA, 539 OOS, 541 ANT, 543 MON, 545 LIM, 547 GRO, 549 ZWO, 551 RCB,
553 LEI, 555 DBO, 557 AAL, 559 LEU, 561 BRU, 563 MEC, 565 KOR, 567 LIE. `uu_team_id` looks stable across seasons (unverified).

## Endpoints

| Purpose | Request | Notes |
|---|---|---|
| Seasons | `competition-team/club/seasons?clubs[0]=1&clubs[1]=2` | `[{season:2022} … {season:2027}]` |
| Competitions + phases | `phase/season/{season}` | |
| Teams | `competition-team/all?competition_id={cid}` | name, short_name, ticket_url, club (country), team_logo, staffs (empty), statistics |
| Team | `competition-team/find/{teamId}` | `statistics: {average_score_for, average_score_against, field_goal_percent}` |
| Standings | `standings/competition/{cid}/phase/{phaseId}` | win, loss, score, against, score_difference, position, point, percent, `win_loss.home/away`, `last5`, `streak{is_win,count}` |
| Roster | `roster/team-players/{teamId}?competition_id={cid}` | roster `id`, jersey (string), height (cm), weight (often null), `player_position`, `player{…}` |
| Roster entry | `roster/find/{rosterId}` | adds `player.description` |
| Team player averages | `competition-team/player-averages/{teamId}` | per-game averages + `played_games` |
| Team games | `competition-team/statistics-by-game/total/{teamId}` | finished games of one team; each has `total`, **that team's** box-score totals (not the home side's). Feeds the Stats tab's Teams table |
| Game strip | `schedule/game-slider/{cid}` | ~30 games around today; includes `genius_id` |
| Full schedule | `schedule/club/{season}?clubs[0]=1&clubs[1]=2&month=-1` | ⚠️ **season** (`2027`), not the competition id: `25` answers `[]`. The website's calendar call. Verified 5 Nov 2026: all 240 games (16 clubs × 30), ~450 KB, ~1 s. `month=-1` is all months, `month=11` one month (24 games); optional `phase_id=183` and `competition_team_id=537` (30 games). Same game shape as the slider, including `period_scores`, but **no `genius_id`**, so the live feed still needs the slider. One game has a 01:00 tip-off on 31 May 2027 (11749 ANT–GRO), which looks like a placeholder date. Earlier seasons untested |
| Game | `schedule/find/{gameId}` | competitors + `period_scores`, `period`, `round` (name empty), phase, `arena{name}`, referees (empty) |
| Game overview | `schedule/overview/{gameId}` | `team_totals`, `top_performer`, `game_leaders` |
| Box score | `boxscore/game/{cid}/{gameId}` | per team `{team, is_home, players[], total}` |
| Player game log | `boxscore/player/season-games/{rosterId}` | ⚠️ **roster** id. An unknown id answers HTTP 200 with `{"data":[],"error":"Roster player not found."}`; a player id may silently match some other roster entry (id 1 is a 2021 player). No `plusminus` in these lines |
| Player career | `player/career-averages/{rosterId}` | ⚠️ roster id; per season and competition |
| Player leaders | `player/average-rankings/{cid}?phase_id={phaseId}` | keys `efficiency, points, total_rebound, block, assist, steal, two_point_percent, three_point_percent, free_throw_percent`; entries `{player, team, roster_id, value}`, ~160 each |
| Team leaders | `competition-team/average-rankings/{cid}?phase_id={phaseId}` | same shape |
| Search | `search/find?search={q}` | articles, players, teams. Not used: the app searches rosters on device (REQUIREMENTS §7.29) |
| News / video / events | `article/list`, `article/find/{slug}`, `video/list`, `event/list`, `award/find/{id}` | not used in v1 |
| Menu / pages | `menu/list`, `page/find/{slug}` | links to the format article and "Where to watch" |
| Config | `server-config` | UI translations, no key needed |
| External | FIBA LiveStats page `https://fibalivestats.dcd.shared.geniussports.com/u/BNXT/{genius_id}/` · BNXT.tv `https://www.bnxt.tv/` · game report `https://bnxtleague.com/en/game-report/{gameId}` | |
| FIBA LiveStats JSON | `https://fibalivestats.dcd.shared.geniussports.com/data/{genius_id}/data.json` (no key) | Genius Sports feed, **third-party and licensed**. Reachable without auth on 4 Nov 2026: `clock`, `period`, `inOT`, `pbp` (537 events for a finished game), `scorers`, `leaddata`, `officials`, `tm` (team/player stats). Live (5 Nov 2026): publishes about every **30 s**, ~150 ms, ~100 KB in the first quarter; `clock` "MM:SS", `period` 1…, `tm.{1,2}.score` and `tot_s*` team totals, `tm.*.pl` player lines, `pbp` newest first (`clock`, `period`, `s1`/`s2` scores, `tno` team, `player`, `actionType`, `subType`, `qualifier`, `success`, `scoring`). For the app (`LiveFeed`): `tm["1"]` is the **home** side; feed codes differ from BNXT's (ROT vs RCB), so match by order; every shot has `scoring: 1` made or missed, so a score is `success == 1`; `s1`/`s2` are strings; quarter scores are `tm.*.p1_score`, `p2_score`…. Coaches, officials and players' full names also appear (in `tm`, `pbp`, `totallds`, `scorers`): never decoded (§7.16). Used by the live screens (REQUIREMENTS §7.4) |

## Field mapping and quirks

| Field | Meaning / quirk |
|---|---|
| `competitors[].side` | **1 = home, 2 = away** (confirmed against the box score's `is_home`) |
| `status` | `ready` (scheduled), `live` (from tip-off, 5 Nov 2026), `finished`. While live (first 18 min recorded): `period` stays **null**, quarter scores stay empty, only the total score updates, and `boxscore/game` stays `{"data":[]}`. The live clock, period and box score therefore exist only in the FIBA feed. At the final (5 Nov 2026) `finished` comes first, with the score only; quarters, `period` and the box score follow about 5 min later, and the box score is still corrected for a few minutes after that (see "Game night 5 Nov 2026") |
| `game_time` | `"YYYY-MM-DD HH:mm:ss"`, Brussels local time with no zone → `GameTime.parse` |
| `throw_made/all/percent` | **Field goals** (2PT + 3PT) |
| `free_throw_*` · `two_point_*` · `three_point_*` | FT · 2PT · 3PT |
| `value` | VAL: PTS + REB + AST + STL + BLK + fouls drawn (`defensive_foul`) − missed FG − missed FT − TO. Checked against game 11323 (all 24 player lines); personal fouls and `block_against` don't count, so it isn't PIR |
| `minute` | integer in box scores, decimal in averages |
| `starter` | bool in box scores, a count in averages |
| `plusminus` | filled for ~80 % of player lines; show the column only if any line is non-zero |
| `player_position.name` | `point_guard`, `shooting_guard`, `small_forward`, `power_forward`, `center`, or combos joined with `-`; can be null |
| `nationality_code` | IOC-style (`NED`, `SUI`, `ANG`…), can be empty |
| `jersey` | a string in rosters (and often `""` there, e.g. all of Spirou's), an int in box scores and game logs: take the number from those |
| Team names | include sponsors ("Partena Professional Okapi Aalst"). We use display names from config. The website strips "playoff" from names and appends `*` |
| `round.name` | always empty: group by date |
| `staffs`, `referees` | always empty |
| `team_logo` | transparent PNG; thumbnails `small`/`medium` (~100 KB). Some are dark navy/black (BRU, MEC, OOS) and need a light plate on dark UI |
| `profile_image` | 400×500 transparent cut-out (~200 KB); missing for 49 of 233 players |
| Club colours | not in the API → curated in `config/v1/config.json` (REQUIREMENTS §7.25, `tools/club_colours.py`) |

## Personal data exposed, and what we decode

All people in the API are professional players and staff with public league profiles.

| Field | Where | Decision (REQUIREMENTS §7.16) |
|---|---|---|
| first/last name, jersey, position, height, weight, nationality, photo | roster, box scores, rankings | decoded and shown |
| `birthdate` | `player` | decoded **only to compute age**; the date itself is never shown or cached separately |
| `facebook`, `twitter`, `instagram` | `player` | **never decoded** |
| `description` | `roster/find` → `player` | **never decoded** |
| staff entries | `staffs` (empty today) | never decoded until a decision says otherwise |

## Polling policy (self-imposed)

- Never more than **1 request per second** per device overall; bursts (opening a club page) are capped at 4 concurrent requests.
- TTLs: standings / leaders 5 min (60 s on game days) · finished game + box score: immutable 3 h after tip-off, cache-first ·
  rosters 6 h · schedule 15 min · team list 24 h.
- Live: one request per live screen every **10 s** (5 s minimum if the cadence turns out higher), only while the screen is visible, paused in the background.
  Measured 5 Nov 2026: FIBA publishes every ~30 s and BNXT's live score every 1–3 min, so 10 s for the FIBA feed and 30 s for
  `schedule/find` lose nothing (to settle in Phase 4).
- Exponential back-off on 429/5xx. Stop and show cached data when `X-RateLimit-Remaining` < 20. Enforced by `RateLimitGuard`
  (9 Nov 2026): below 20, cached copies until the ~65 s window resets (still one request if nothing is cached); a 429 holds
  off for its `Retry-After`, a 5xx for 5 s doubling to 60 s, during which nothing-cached requests fail fast; a success resets it.

## Research tooling

`tools/record_live.py` records game nights (below), `tools/api.sh <path>` (reads `BNXT_API_KEY` from `.env`), `tools/fetch.py` (snapshot the season into `raw/`), `tools/build_data.py`
(prototype `data.js`), `tools/quant.py` (shrink PNGs). Run them from `.tmp/` so outputs stay out of git:

```bash
mkdir -p .tmp/data && cd .tmp/data && python3 ../../tools/fetch.py && python3 ../../tools/build_data.py
```

### Recording a game night

`tools/record_live.py` polls `schedule/find`, `boxscore/game` (every 10 s) and `schedule/overview` (every 30 s) for each game from 20 min
before tip-off until 30 min after the final, plus `schedule/game-slider` every minute. It saves a snapshot only when a response changes,
logs every poll with its rate-limit headers to `log.jsonl`, and writes `summary.md`: status values seen, update cadence per endpoint
while live, and whether `X-RateLimit-Remaining` falls faster than our own requests (which would mean the limit is shared per key, §7.15).

```bash
caffeinate -is python3 tools/record_live.py --date 2026-11-05         # → .tmp/live/2026-11-05/
python3 tools/record_live.py --date 2026-11-05 --fiba                 # also the FIBA feed (research only)
python3 tools/record_live.py --summarize .tmp/live/2026-11-05         # rebuild the summary
```

**Keep the Mac on power with the lid open.** `caffeinate` doesn't stop sleep when the lid closes: on 6 Nov 2026 that cut polling to a few
seconds every 15 min or so (`-s` also only works on mains power). Polling gaps look like a stalled feed or a late status, so before
trusting any timing, check `log.jsonl` for gaps and `pmset -g log` for `Clamshell Sleep`.

Dry run (4 Nov 2026, finished game 11323): all endpoints answered in ~200–350 ms; `X-RateLimit-Remaining` fell by exactly our own
request count and didn't reset within 40 s, so the window is at least a minute.

#### Game night 5 Nov 2026 (CHA–RCB, game 11351, genius 2873634)

Recorded in parts: tip-off (20:30) to 20:48 (Q1 1:44 left, 18–11), then from Q4 3:45 left through the final. The middle wasn't
recorded, so this doesn't count as a start-to-finish night (Phase 4 needs two).

- **BNXT API while live:** `schedule/find` and `schedule/overview` change only when the BNXT side copies the score over: 8 times in
  18 min, 1–3 min apart (median 172 s), sometimes skipping baskets (FIBA showed 10–7, 10–8 and 13–8; BNXT went 8–5 → 15–8).
  `period` null, quarters empty, `boxscore/game` empty throughout. Responses ~220–280 ms.
- **FIBA feed while live:** polled every 10 s, it changed every ~31–33 s, so it publishes on a ~30 s cycle. Neither source is
  always first: BNXT trailed FIBA by up to ~60 s (8–5, 18–11) but twice showed a score up to 25 s before FIBA's next cycle. FIBA
  showed every basket; BNXT skipped some. 0 errors.
- **Rate limit:** the window resets every 62–65 s. `summary.md` counted 433 "extra" decrements (Remaining falling faster than our
  own requests) and read that as a shared key. They come from this Mac's own app: every extra decrement falls inside a test run
  (Xcode test run 20:31:20–20:37:35, `ci-local.sh` until 20:45:11), and from 20:45:16 Remaining fell by exactly our own requests
  while the game was still live and the website was serving it. Conclusion: **per client IP**. Run no tests during a recording,
  so the reading stays clean.
- **The final whistle** (one game, polled every 10 s):

  | Time | What changed |
  |---|---|
  | 22:29:25 | BNXT's score reaches the final 77–74, still `live` (FIBA: ~0:13 left) |
  | 22:32:20 | FIBA's last change: clock `00:00`, `period` 4, `pbp` starts with `game`/`end` and `period`/`end`. The feed has no status field |
  | 22:32:23 | `schedule/find`: `finished`, score 77–74, `period` null, quarters and box score still empty |
  | 22:32:47 | The game slider's first change after the final |
  | 22:37:19 | `schedule/find`: `period` Q4 and quarters, matching FIBA's |
  | 22:37:22 | `boxscore/game` first has lines, **but not all**: 11 for CHA, without its #1 |
  | 22:38:25 | Box score: CHA's #1 added, two players' minutes change |
  | 22:39:28 | Box score: four players' minutes change. No later change by 22:51 |

  So BNXT's `finished` follows FIBA within seconds, but `finished` doesn't mean complete: for ~5 min only the feed has quarters and
  player lines, and BNXT's first box score is provisional. The feed stayed unchanged and available after the final.

#### Game night 6 Nov 2026 (LIE–ZWO, game 11353, genius 2873638)

Recorded from 21:06, mid-game. The lid closed at 21:53, so the Mac slept through most of the end of the game and **timings after that are
only bounds**: how long BNXT took to say `finished`, and whether quarters and box score lagged, can't be read from this night.

- **At the first wake-up after the final:** at 22:20:10 FIBA had `game`/`end` at 88–84, and at 22:20:13 BNXT had the same score, still `live`.
  By 22:35:24 BNXT had `finished` with quarters, and its box score had lines by 22:35:19.
- **Late box-score corrections:** unchanged at 22:53:04, but by 23:03:52 `plusminus` had gone from 0 to a real value on 17 of 22 lines and
  minutes had changed on four. So corrections can come **at least 33 min after the final**, well inside the 3 h rule.
