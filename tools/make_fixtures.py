#!/usr/bin/env python3
"""Capture golden test fixtures for BNXTTests from the real API (playbook 03, "Golden tests on real data").

Picks one finished game whose data won't change (CHA–OOS, 23 Oct 2026, game 11323) plus its context, strips
the fields we never decode (REQUIREMENTS.md §7.16), trims big lists, and writes ios/BNXTTests/Fixtures/*.json.

Run from the repo root with BNXT_API_KEY in .env:   python3 tools/make_fixtures.py
Re-running overwrites the fixtures; pinned numbers in the tests are for game 11323 and team 537 and must still hold.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ios" / "BNXTTests" / "Fixtures"
API = ROOT / "tools" / "api.sh"
NEVER_DECODE = {"facebook", "twitter", "instagram", "description"}   # REQUIREMENTS §7.16

COMPETITION, PHASE, TEAM, GAME, UPCOMING = 25, 183, 537, 11323, 11351


def get(path):
    out = subprocess.run([str(API), path], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def strip(node):
    if isinstance(node, dict):
        return {k: strip(v) for k, v in node.items() if k not in NEVER_DECODE}
    if isinstance(node, list):
        return [strip(v) for v in node]
    return node


def save(name, data):
    (OUT / f"{name}.json").write_text(json.dumps(strip(data), ensure_ascii=False, indent=1) + "\n")
    print(f"  {name}.json")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    roster = get(f"roster/team-players/{TEAM}?competition_id={COMPETITION}")
    # A roster player who played in game 11323, for the game-log fixture.
    box = get(f"boxscore/game/{COMPETITION}/{GAME}")
    played = {p["roster_id"] for side in box["data"] for p in side["players"]}
    roster_id = next(r["id"] for r in roster["data"] if r["id"] in played)

    save("teams", get(f"competition-team/all?competition_id={COMPETITION}"))
    save("team_537", get(f"competition-team/find/{TEAM}"))
    save("standings", get(f"standings/competition/{COMPETITION}/phase/{PHASE}"))
    save("roster_537", roster)
    save("player_averages_537", get(f"competition-team/player-averages/{TEAM}"))
    save("team_games_537", get(f"competition-team/statistics-by-game/total/{TEAM}"))
    slider = get(f"schedule/game-slider/{COMPETITION}")
    finished = [g for g in slider["data"] if g["status"] == "finished"][:3]
    ready = [g for g in slider["data"] if g["status"] != "finished"][:3]
    save("game_slider", {"data": finished + ready})
    save("game_11323", get(f"schedule/find/{GAME}"))
    save("game_11351_upcoming", get(f"schedule/find/{UPCOMING}"))
    save("box_score_11323", box)
    save(f"player_game_log_{roster_id}", get(f"boxscore/player/season-games/{roster_id}"))
    save(f"roster_entry_{roster_id}", get(f"roster/find/{roster_id}"))
    save("player_game_log_unknown", get("boxscore/player/season-games/999999999"))   # the API's "not found" shape
    leaders = get(f"player/average-rankings/{COMPETITION}?phase_id={PHASE}")
    save("player_leaders", {k: v[:5] for k, v in leaders.items()})
    print(f"roster id used for the game log: {roster_id}")


if __name__ == "__main__":
    if not os.environ.get("BNXT_API_KEY") and not (ROOT / ".env").exists():
        sys.exit("Set BNXT_API_KEY in .env")
    main()
