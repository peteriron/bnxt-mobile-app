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
| Rate limit | `X-RateLimit-Limit: 200`, `X-RateLimit-Remaining` (window not documented; probably per minute). Per key or per IP is unknown: **to test in Phase 0** |
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
| Schedule by month | `schedule/club/{cid}?clubs[0]=1&clubs[1]=2&phase_id=&month=&monthCount=&competition_team_id=` | returned `[]` with every parameter set tried. **Still to figure out** |
| Game | `schedule/find/{gameId}` | competitors + `period_scores`, `period`, `round` (name empty), phase, `arena{name}`, referees (empty) |
| Game overview | `schedule/overview/{gameId}` | `team_totals`, `top_performer`, `game_leaders` |
| Box score | `boxscore/game/{cid}/{gameId}` | per team `{team, is_home, players[], total}` |
| Player game log | `boxscore/player/season-games/{rosterId}` | ⚠️ **roster** id. An unknown id answers HTTP 200 with `{"data":[],"error":"Roster player not found."}`; a player id may silently match some other roster entry (id 1 is a 2021 player). No `plusminus` in these lines |
| Player career | `player/career-averages/{rosterId}` | ⚠️ roster id; per season and competition |
| Player leaders | `player/average-rankings/{cid}?phase_id={phaseId}` | keys `efficiency, points, total_rebound, block, assist, steal, two_point_percent, three_point_percent, free_throw_percent`; entries `{player, team, roster_id, value}`, ~160 each |
| Team leaders | `competition-team/average-rankings/{cid}?phase_id={phaseId}` | same shape |
| Search | `search/find?search={q}` | articles, players, teams |
| News / video / events | `article/list`, `article/find/{slug}`, `video/list`, `event/list`, `award/find/{id}` | not used in v1 |
| Menu / pages | `menu/list`, `page/find/{slug}` | links to the format article and "Where to watch" |
| Config | `server-config` | UI translations, no key needed |
| External | FIBA LiveStats page `https://fibalivestats.dcd.shared.geniussports.com/u/BNXT/{genius_id}/` · BNXT.tv `https://www.bnxt.tv/` · game report `https://bnxtleague.com/en/game-report/{gameId}` | |
| FIBA LiveStats JSON | `https://fibalivestats.dcd.shared.geniussports.com/data/{genius_id}/data.json` (no key) | Genius Sports feed, **third-party and licensed**. Reachable without auth on 4 Nov 2026: `clock`, `period`, `inOT`, `pbp` (537 events for a finished game), `scorers`, `leaddata`, `officials`, `tm` (team/player stats). Research only until licensed (REQUIREMENTS §7.4) |

## Field mapping and quirks

| Field | Meaning / quirk |
|---|---|
| `competitors[].side` | **1 = home, 2 = away** (confirmed against the box score's `is_home`) |
| `status` | `ready` (scheduled), `live` (seen 5 Nov 2026 at tip-off: `period` null, scores 0, box score `[]` for the first minutes), `finished` |
| `game_time` | `"YYYY-MM-DD HH:mm:ss"`, Brussels local time with no zone → `GameTime.parse` |
| `throw_made/all/percent` | **Field goals** (2PT + 3PT) |
| `free_throw_*` · `two_point_*` · `three_point_*` | FT · 2PT · 3PT |
| `value` | VAL / PIR (FIBA efficiency) |
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
- Exponential back-off on 429/5xx. Stop and show cached data when `X-RateLimit-Remaining` < 20.

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
caffeinate -i python3 tools/record_live.py --date 2026-11-05          # → .tmp/live/2026-11-05/
python3 tools/record_live.py --date 2026-11-05 --fiba                 # also the FIBA feed (research only)
python3 tools/record_live.py --summarize .tmp/live/2026-11-05         # rebuild the summary
```

Dry run (4 Nov 2026, finished game 11323): all endpoints answered in ~200–350 ms; `X-RateLimit-Remaining` fell by exactly our own
request count and didn't reset within 40 s, so the window is at least a minute.
