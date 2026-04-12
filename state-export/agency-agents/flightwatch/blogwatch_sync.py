#!/usr/bin/env python3
import json
import subprocess
from datetime import datetime, UTC
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ROUTES = ROOT / "routes.json"
PREFIX = "fw-"


def run(cmd):
    return subprocess.run(cmd, text=True, capture_output=True)


def parse_dates(date_range: str):
    if date_range == "any":
        now = datetime.now(UTC).date().isoformat()
        return now, now
    start, end = date_range.split("..", 1)
    return start, end


def aviasales_link(src: str, dst: str, date_from: str):
    return f"https://www.aviasales.ru/search/{src}{date_from}{dst}1"


def trip_link(src: str, dst: str, date_from: str):
    return (
        "https://www.trip.com/flights/showfarefirst?"
        f"dcity={src}&acity={dst}&ddate={date_from}&triptype=ow&class=y&quantity=1"
    )


def desired_entries(routes):
    out = {}
    for r in routes:
        if not r.get("active", True):
            continue
        src = r["from"]
        dst = r["to"]

        if r.get("date_mode") == "flexible":
            d, _ = parse_dates(r.get("date_range", "any"))
        else:
            d = r.get("date") or r.get("date_range", "any").split("..", 1)[0]

        sources = r.get("sources", ["aviasales", "trip.com"])
        if "aviasales" in sources:
            name = f"{PREFIX}{src}-{dst}-aviasales".lower()
            out[name] = aviasales_link(src, dst, d)
        if "trip.com" in sources:
            name = f"{PREFIX}{src}-{dst}-trip".lower()
            out[name] = trip_link(src, dst, d)
    return out


def current_fw_names():
    p = run(["blogwatcher", "blogs"])
    if p.returncode != 0:
        return []
    names = []
    for line in p.stdout.splitlines():
        if line.startswith("  ") and not line.startswith("    "):
            n = line.strip()
            if n.startswith(PREFIX):
                names.append(n)
    return names


def add_blog(name, url):
    # body selector as a generic fallback for dynamic pages
    run(["blogwatcher", "add", name, url, "--scrape-selector", "body"])


def remove_blog(name):
    run(["blogwatcher", "remove", name, "--yes"])


def main():
    routes = json.loads(ROUTES.read_text(encoding="utf-8"))
    want = desired_entries(routes)
    have = set(current_fw_names())

    for name in sorted(have - set(want.keys())):
        remove_blog(name)
        print(f"removed: {name}")

    for name, url in want.items():
        add_blog(name, url)
        print(f"ensured: {name} -> {url}")


if __name__ == "__main__":
    main()
