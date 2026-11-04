#!/usr/bin/env python3
"""Record what the BNXT API serves during live games (REQUIREMENTS.md §7.4, §7.15; Phase 0).

Polls the game endpoints from shortly before tip-off until shortly after the final, saves a snapshot
whenever a response changes, logs every poll (with rate-limit headers), and writes summary.md that answers:

  * which `status` values appear (the live value is unknown so far), and when
  * how often each endpoint actually changes during play (the update cadence)
  * whether box scores / overview update live or only after the game
  * whether X-RateLimit-Remaining drops faster than our own requests (=> the limit is shared per key, §7.15)

Usage (from the repo root; needs BNXT_API_KEY in .env):
  python3 tools/record_live.py --date 2026-11-05          # every game on that date
  python3 tools/record_live.py --game 11351               # one game
  python3 tools/record_live.py --game 11323 --now --duration 60   # dry run against any game, right now
  python3 tools/record_live.py --summarize .tmp/live/2026-11-05   # re-build summary.md from a recording

Keep the Mac awake for a long session:  caffeinate -i python3 tools/record_live.py --date 2026-11-05
Ctrl-C stops cleanly and still writes the summary.

Polling stays inside docs/bnxt-api.md "Polling policy": at most one request per second overall,
game endpoints every --interval seconds (default 10, minimum 5).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
import statistics
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
BASE = "https://bnxt.sportpress.info/api/v1/"
FIBA = "https://fibalivestats.dcd.shared.geniussports.com/data/{gid}/data.json"
LEAGUE_TZ = ZoneInfo("Europe/Brussels")
MIN_GAP = 1.0  # seconds between any two requests (polling policy)
RL_HEADERS = ("x-ratelimit-limit", "x-ratelimit-remaining", "retry-after")

STOP = False


def _on_sigint(*_):
    global STOP
    STOP = True
    print("\nStopping after the current request…", flush=True)


# ---------------------------------------------------------------- HTTP

def load_key() -> str:
    key = os.environ.get("BNXT_API_KEY")
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("BNXT_API_KEY="):
                key = line.split("=", 1)[1].strip()
    if not key:
        sys.exit("Set BNXT_API_KEY in .env (see .env.example).")
    return key


class Client:
    """Paced HTTP client. Never prints the key."""

    def __init__(self, key: str):
        self.key = key
        self.last = 0.0
        self.count = 0  # requests we made to the BNXT API (for the rate-limit analysis)

    def get(self, url: str, upstream: bool = True) -> dict:
        wait = self.last + MIN_GAP - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        headers = {"User-Agent": "Mozilla/5.0 (bnxt-app research)", "Accept": "application/json"}
        if upstream:
            headers["X-Authorization"] = self.key
        t0 = time.monotonic()
        status, body, hdrs, error = 0, b"", {}, None
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=20) as r:
                status, body, hdrs = r.status, r.read(), {k.lower(): v for k, v in r.headers.items()}
        except urllib.error.HTTPError as e:
            status, body, hdrs = e.code, e.read(), {k.lower(): v for k, v in e.headers.items()}
        except Exception as e:  # network error: logged, never fatal
            error = f"{type(e).__name__}: {e}"
        self.last = time.monotonic()
        if upstream:
            self.count += 1
        return {"status": status, "body": body, "headers": hdrs, "ms": round((self.last - t0) * 1000), "error": error}


# ---------------------------------------------------------------- game model

def parse_game_time(s: str) -> datetime:
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=LEAGUE_TZ)


def now() -> datetime:
    return datetime.now(LEAGUE_TZ)


@dataclass
class Game:
    id: int
    tip: datetime
    home: str
    away: str
    genius_id: int | None
    finished_at: datetime | None = None
    last_hash: dict = field(default_factory=dict)
    next_due: dict = field(default_factory=dict)

    @property
    def label(self) -> str:
        return f"{self.home}-{self.away}"


def extract(endpoint: str, data) -> dict:
    """Small, comparable facts from a response, for the log and the summary."""
    try:
        d = data.get("data", data) if isinstance(data, dict) else data
        if endpoint == "find":
            comps = sorted(d.get("competitors", []), key=lambda c: c.get("side", 0))
            return {
                "status": d.get("status"),
                "period": (d.get("period") or {}).get("name"),
                "score": [c.get("finalScore") for c in comps],
                "quarters": [[p.get("score") for p in c.get("period_scores") or []] for c in comps],
                "keys": sorted(d.keys()),
            }
        if endpoint == "box":
            return {"teams": len(d), "points": [(t.get("total") or {}).get("points") for t in d],
                    "players": [len(t.get("players") or []) for t in d]}
        if endpoint == "overview":
            return {"team_totals": len(d.get("team_totals") or []), "leaders": len(d.get("game_leaders") or [])}
        if endpoint == "fiba":
            return {"keys": sorted(d.keys())[:20], "clock": d.get("clock"), "period": d.get("period"),
                    "pbp": len(d.get("pbp") or [])}
    except Exception as e:
        return {"extract_error": str(e)}
    return {}


# ---------------------------------------------------------------- recorder

class Recorder:
    def __init__(self, args, client: Client):
        self.a = args
        self.c = client
        self.out = Path(args.out)
        self.out.mkdir(parents=True, exist_ok=True)
        self.log = (self.out / "log.jsonl").open("a")
        self.games: list[Game] = []
        self.slider_due = 0.0
        self.slider_hash = None

    def write_log(self, rec: dict):
        self.log.write(json.dumps(rec, ensure_ascii=False) + "\n")
        self.log.flush()

    def fetch(self, endpoint: str, url: str, game: Game | None, upstream=True):
        r = self.c.get(url, upstream)
        ts = now()
        body = r["body"]
        digest = hashlib.sha256(body).hexdigest()[:16] if body else None
        key = endpoint
        prev = (game.last_hash.get(key) if game else self.slider_hash)
        changed = digest is not None and digest != prev
        parsed = None
        if body:
            try:
                parsed = json.loads(body)
            except ValueError:
                parsed = None
        facts = extract(endpoint, parsed) if parsed is not None and r["status"] == 200 else {}
        if changed and r["status"] == 200:
            folder = self.out / (f"{game.id}_{game.label}" if game else "_league") / endpoint
            folder.mkdir(parents=True, exist_ok=True)
            (folder / f"{ts:%H%M%S}.json").write_bytes(body)
            if game:
                game.last_hash[key] = digest
            else:
                self.slider_hash = digest
        rec = {
            "t": ts.isoformat(timespec="seconds"), "game": game.id if game else None, "endpoint": endpoint,
            "http": r["status"], "ms": r["ms"], "bytes": len(body), "hash": digest, "changed": changed,
            "our_requests": self.c.count if upstream else None, "error": r["error"], "facts": facts,
            **{h.replace("x-ratelimit-", "rl_"): r["headers"].get(h) for h in RL_HEADERS if upstream},
        }
        self.write_log(rec)
        if r["status"] == 429:
            retry = int(r["headers"].get("retry-after") or 60)
            print(f"  429 rate limited; backing off {retry}s", flush=True)
            time.sleep(min(retry, 300))
        return rec

    def resolve_games(self):
        rec = self.fetch("slider", f"{BASE}schedule/game-slider/{self.a.competition}", None)
        path = sorted((self.out / "_league" / "slider").glob("*.json"))
        data = json.loads(path[-1].read_bytes())["data"] if path else []
        if rec["http"] != 200 or not data:
            sys.exit(f"Could not load the game slider (HTTP {rec['http']}).")
        for g in data:
            comps = sorted(g["competitors"], key=lambda c: c["side"])
            game = Game(g["id"], parse_game_time(g["game_time"]), comps[0]["competition_team"]["short_name"],
                        comps[1]["competition_team"]["short_name"], g.get("genius_id"))
            if (self.a.game and game.id in self.a.game) or (self.a.date and game.tip.date().isoformat() == self.a.date):
                self.games.append(game)
        if self.a.game and len(self.games) < len(self.a.game):
            # Not in the slider window: look the game up directly.
            for gid in set(self.a.game) - {g.id for g in self.games}:
                r = self.c.get(f"{BASE}schedule/find/{gid}")
                if r["status"] != 200:
                    sys.exit(f"Game {gid} not found (HTTP {r['status']}).")
                d = json.loads(r["body"])["data"]
                comps = sorted(d["competitors"], key=lambda c: c["side"])
                self.games.append(Game(gid, parse_game_time(d["game_time"]), comps[0]["competition_team"]["short_name"],
                                       comps[1]["competition_team"]["short_name"], None))
        if not self.games:
            sys.exit("No games match. Check --date (YYYY-MM-DD, league time) or --game.")
        if self.a.now:
            for g in self.games:
                g.tip = now() + timedelta(minutes=self.a.lead)
        self.games.sort(key=lambda g: g.tip)
        meta = [{"id": g.id, "game": g.label, "tip": g.tip.isoformat(), "genius_id": g.genius_id} for g in self.games]
        (self.out / "games.json").write_text(json.dumps(meta, indent=2))
        for g in self.games:
            print(f"  {g.id}  {g.label:<9} tip-off {g.tip:%a %d %b %H:%M}  genius {g.genius_id}")

    def window(self, g: Game) -> tuple[datetime, datetime]:
        start = g.tip - timedelta(minutes=self.a.lead)
        hard_end = g.tip + timedelta(hours=self.a.max_hours)
        end = min(hard_end, g.finished_at + timedelta(minutes=self.a.tail)) if g.finished_at else hard_end
        return start, end

    def endpoints(self, g: Game):
        iv = self.a.interval
        eps = [("find", f"{BASE}schedule/find/{g.id}", iv, True),
               ("box", f"{BASE}boxscore/game/{self.a.competition}/{g.id}", iv, True),
               ("overview", f"{BASE}schedule/overview/{g.id}", iv * 3, True)]
        if self.a.fiba and g.genius_id:
            eps.append(("fiba", FIBA.format(gid=g.genius_id), iv, False))
        return eps

    def run(self):
        deadline = time.monotonic() + self.a.duration if self.a.duration else None
        last_wait_msg = 0.0
        while not STOP:
            t = now()
            active = [g for g in self.games if self.window(g)[0] <= t <= self.window(g)[1]]
            pending = [g for g in self.games if t < self.window(g)[0]]
            if not active and not pending:
                print("All games done.", flush=True)
                break
            if deadline and time.monotonic() > deadline:
                print("Duration reached.", flush=True)
                break
            if not active:
                start = min(self.window(g)[0] for g in pending)
                if time.monotonic() - last_wait_msg > 300:
                    print(f"Waiting until {start:%H:%M} ({(start - t).seconds // 60} min)…", flush=True)
                    last_wait_msg = time.monotonic()
                time.sleep(min(30, max(1, (start - t).total_seconds())))
                continue
            mono = time.monotonic()
            if mono >= self.slider_due:
                self.fetch("slider", f"{BASE}schedule/game-slider/{self.a.competition}", None)
                self.slider_due = mono + self.a.slider_interval
            for g in active:
                for name, url, every, upstream in self.endpoints(g):
                    if STOP or time.monotonic() < g.next_due.get(name, 0):
                        continue
                    rec = self.fetch(name, url, g, upstream)
                    g.next_due[name] = time.monotonic() + every
                    f = rec["facts"]
                    if name == "find" and rec["http"] == 200:
                        if f.get("status") == "finished" and not g.finished_at:
                            g.finished_at = now()
                            print(f"  {g.label}: finished; recording {self.a.tail} more minutes", flush=True)
                        if rec["changed"]:
                            print(f"  {now():%H:%M:%S} {g.label:<9} status={f.get('status')} period={f.get('period')} "
                                  f"score={f.get('score')} rl={rec.get('rl_remaining')}", flush=True)
                    elif rec["changed"] and rec["http"] == 200:
                        print(f"  {now():%H:%M:%S} {g.label:<9} {name} changed {f}", flush=True)
                    elif rec["http"] != 200:
                        print(f"  {now():%H:%M:%S} {g.label:<9} {name} HTTP {rec['http']} {rec['error'] or ''}", flush=True)
            time.sleep(0.5)
        self.log.close()


# ---------------------------------------------------------------- summary

def summarize(out: Path) -> str:
    log = [json.loads(line) for line in (out / "log.jsonl").read_text().splitlines() if line.strip()]
    games = json.loads((out / "games.json").read_text()) if (out / "games.json").exists() else []
    lines = [f"# Live recording summary: {out.name}", "",
             f"{len(log)} polls between {log[0]['t'] if log else '-'} and {log[-1]['t'] if log else '-'}.", ""]

    # Rate limit: does Remaining fall faster than our own requests? (=> shared per key)
    up = [r for r in log if r.get("rl_remaining") not in (None, "") and r.get("our_requests") is not None]
    limits = sorted({r.get("rl_limit") for r in up if r.get("rl_limit")})
    excess, pairs = [], 0
    for a, b in zip(up, up[1:]):
        ours = b["our_requests"] - a["our_requests"]
        drop = int(a["rl_remaining"]) - int(b["rl_remaining"])
        secs = (datetime.fromisoformat(b["t"]) - datetime.fromisoformat(a["t"])).total_seconds()
        if drop >= 0 and secs <= 30:  # same window, no reset in between
            pairs += 1
            excess.append(drop - ours)
    foreign = [x for x in excess if x > 0]
    lines += ["## Rate limit (REQUIREMENTS §7.15)", "",
              f"- Limit header: {', '.join(limits) or 'not seen'}; lowest Remaining seen: "
              f"{min((int(r['rl_remaining']) for r in up), default='-')}",
              f"- Comparable request pairs: {pairs}; pairs where Remaining fell by more than our own requests: "
              f"{len(foreign)} (total extra decrements: {sum(foreign)})",
              "- Reading: many extra decrements while the website had live traffic means the limit is **shared per key**; "
              "~none means per client/IP. HTTP 429s seen: " + str(sum(1 for r in log if r["http"] == 429)), ""]

    for g in games:
        gl = [r for r in log if r["game"] == g["id"]]
        lines += [f"## {g['game']} (game {g['id']}, tip-off {g['tip'][11:16]}, genius {g.get('genius_id')})", ""]
        find = [r for r in gl if r["endpoint"] == "find" and r["http"] == 200]
        seen, order = {}, []
        for r in find:
            s = r["facts"].get("status")
            if s not in seen:
                seen[s] = r["t"][11:19]
                order.append(s)
        lines.append("- Status values (first seen): " + (", ".join(f"`{s}` {seen[s]}" for s in order) or "none"))
        periods = []
        for r in find:
            p = r["facts"].get("period")
            if p and (not periods or periods[-1] != p):
                periods.append(p)
        lines.append("- Period values in order: " + (" → ".join(periods) or "none"))
        live_start = next((r["t"] for r in find if r["facts"].get("status") not in ("ready", None)), None)
        fin = next((r["t"] for r in find if r["facts"].get("status") == "finished"), None)
        lines += ["", "| Endpoint | Polls | Changes | Changes while live | Median gap between changes (live) | Errors | Median ms |",
                  "|---|---|---|---|---|---|---|"]
        for ep in ("find", "box", "overview", "fiba"):
            rows = [r for r in gl if r["endpoint"] == ep]
            if not rows:
                continue
            ch = [r for r in rows if r["changed"]]
            live = [r for r in ch if live_start and r["t"] >= live_start and (not fin or r["t"] <= fin)]
            gaps = [(datetime.fromisoformat(b["t"]) - datetime.fromisoformat(a["t"])).total_seconds()
                    for a, b in zip(live, live[1:])]
            med = f"{statistics.median(gaps):.0f} s" if gaps else "-"
            errs = sum(1 for r in rows if r["http"] != 200)
            ms = statistics.median([r["ms"] for r in rows])
            lines.append(f"| {ep} | {len(rows)} | {len(ch)} | {len(live)} | {med} | {errs} | {ms:.0f} |")
        scores = []
        for r in find:
            sc = r["facts"].get("score")
            if r["changed"] and (not scores or scores[-1][1] != sc):
                scores.append((r["t"][11:19], sc, r["facts"].get("period")))
        lines += ["", f"Score changes recorded: {len(scores)}"]
        lines += [f"- {t} {p or ''} {s}" for t, s, p in scores[:15]]
        if len(scores) > 15:
            lines.append(f"- … {len(scores) - 15} more (see log.jsonl)")
        lines.append("")

    lines += ["## Next steps", "",
              "- Copy the findings into docs/bnxt-api.md (status values, live cadence) and settle REQUIREMENTS §7.4 / §7.15.",
              "- Keep one finished-game snapshot as a test fixture; delete the rest of this folder when done."]
    text = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(text)
    return text


# ---------------------------------------------------------------- main

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--date", help="record every game on this date (YYYY-MM-DD, league time)")
    p.add_argument("--game", type=int, action="append", help="game id (repeatable)")
    p.add_argument("--competition", type=int, default=25, help="competition id (default 25 = 2026-27)")
    p.add_argument("--interval", type=int, default=10, help="seconds between polls of find/box (min 5, default 10)")
    p.add_argument("--slider-interval", type=int, default=60, help="seconds between game-slider polls (default 60)")
    p.add_argument("--lead", type=int, default=20, help="start this many minutes before tip-off (default 20)")
    p.add_argument("--tail", type=int, default=30, help="keep recording this many minutes after the final (default 30)")
    p.add_argument("--max-hours", type=float, default=3.5, help="hard stop per game after tip-off (default 3.5)")
    p.add_argument("--duration", type=int, help="stop after this many seconds (dry runs)")
    p.add_argument("--now", action="store_true", help="treat the game(s) as starting now (dry runs)")
    p.add_argument("--fiba", action="store_true",
                   help="also poll the FIBA LiveStats JSON feed (third-party, licensed; research only)")
    p.add_argument("--out", help="output folder (default .tmp/live/<date or game ids>)")
    p.add_argument("--summarize", metavar="DIR", help="only (re)build summary.md for an existing recording")
    a = p.parse_args()

    if a.summarize:
        print(summarize(Path(a.summarize)))
        return
    if not a.date and not a.game:
        p.error("pass --date or --game")
    a.interval = max(5, a.interval)
    a.out = a.out or str(ROOT / ".tmp" / "live" / (a.date or "game-" + "-".join(map(str, a.game))))

    signal.signal(signal.SIGINT, _on_sigint)
    rec = Recorder(a, Client(load_key()))
    print(f"Recording into {a.out}", flush=True)
    rec.resolve_games()
    try:
        rec.run()
    finally:
        print("\n" + summarize(Path(a.out)))


if __name__ == "__main__":
    main()
