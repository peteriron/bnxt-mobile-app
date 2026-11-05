#!/usr/bin/env python3
"""Propose club colours from logos and render a review sheet (REQUIREMENTS.md §7.25).

The largest colour cluster isn't always the club colour (black outlines, a cartoon face), so this only proposes
candidates. Pick each club's colour by eye and write it to config/v1/config.json `teams[id].color` by hand.

  python3 tools/club_colours.py                  # candidates for the clubs in the teams fixture
  python3 tools/club_colours.py --check          # the config's current picks as hero gradients, with contrast on ink

Needs Pillow (`pip3 install pillow`). Logos download into .tmp/club-colours/; the sheet is .tmp/club-colours/sheet.png.
"""
import argparse
import colorsys
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / ".tmp" / "club-colours"
INK = (7, 6, 11)
FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)


def clubs():
    teams = json.loads((ROOT / "ios/BNXTTests/Fixtures/teams.json").read_text())["data"]
    WORK.mkdir(parents=True, exist_ok=True)
    for t in teams:
        path = WORK / f"{t['id']}.png"
        if not path.exists():
            url = (t["team_logo"].get("thumbnails") or {}).get("medium") or t["team_logo"]["public_url"]
            subprocess.run(["curl", "-sfL", "-o", str(path), url], check=True)
        yield t["id"], t["short_name"], Image.open(path).convert("RGBA")


def candidates(logo, count=3):
    buckets = {}
    small = logo.resize((80, 80))
    pixels = small.get_flattened_data() if hasattr(small, "get_flattened_data") else small.getdata()
    for r, g, b, a in pixels:
        if a < 200:
            continue
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        key = "white" if l > 0.92 else (f"grey{int(l * 4)}" if s < 0.18 or l < 0.08 else f"hue{int(h * 18)}")
        bucket = buckets.setdefault(key, [0, 0, 0, 0])
        bucket[0] += 1
        bucket[1] += r
        bucket[2] += g
        bucket[3] += b
    ranked = [(k, v) for k, v in sorted(buckets.items(), key=lambda kv: -kv[1][0]) if k != "white"]
    return ["#%02X%02X%02X" % (r // n, g // n, b // n) for _, (n, r, g, b) in ranked[:count]]


def luminance(hex_colour):
    channels = [int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    channels = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast_on_ink(hex_colour):
    a, b = luminance(hex_colour), luminance("#%02X%02X%02X" % INK)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="render the config's current colours instead of candidates")
    args = parser.parse_args()
    config = json.loads((ROOT / "config/v1/config.json").read_text())
    rows = list(clubs())
    sheet = Image.new("RGB", (760, 92 * len(rows)), INK)
    draw = ImageDraw.Draw(sheet)
    for row, (club_id, short, logo) in enumerate(rows):
        y = row * 92
        sheet.paste(logo.resize((76, 76)), (8, y + 8), logo.resize((76, 76)))
        draw.text((96, y + 34), short, fill=(245, 243, 251), font=FONT)
        colours = [config["teams"].get(str(club_id), {}).get("color")] if args.check else candidates(logo)
        for k, colour in enumerate(c for c in colours if c):
            x = 160 + k * 200
            draw.rectangle((x, y + 14, x + 70, y + 78), fill=colour)
            ratio = contrast_on_ink(colour)
            draw.text((x + 78, y + 30), f"{colour}\n{ratio:.1f}:1 on ink", fill=(226, 255, 0) if ratio < 3 else (169, 164, 189), font=FONT)
        print(short, club_id, colours)
    sheet.save(WORK / "sheet.png")
    print(f"Review sheet: {WORK / 'sheet.png'}")


if __name__ == "__main__":
    main()
