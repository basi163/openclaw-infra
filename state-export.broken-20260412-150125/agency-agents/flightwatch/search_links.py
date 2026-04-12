#!/usr/bin/env python3
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ROUTES = ROOT / "routes.json"


def parse_dates(date_range: str):
    # format: YYYY-MM-DD..YYYY-MM-DD
    start, end = date_range.split("..", 1)
    return datetime.fromisoformat(start).date(), datetime.fromisoformat(end).date()


def aviasales_link(src: str, dst: str, date_from: str):
    # One-way deep link, simple and stable
    return f"https://www.aviasales.ru/search/{src}{date_from}{dst}1"


def trip_link(src: str, dst: str, date_from: str):
    # Generic flight search page with prefilled params
    return (
        "https://www.trip.com/flights/showfarefirst?"
        f"dcity={src}&acity={dst}&ddate={date_from}&triptype=ow&class=y&quantity=1"
    )


def main():
    routes = json.loads(ROUTES.read_text(encoding="utf-8"))
    for r in routes:
        if not r.get("active", True):
            continue

        src = r["from"]
        dst = r["to"]

        if r.get("date_mode") == "flexible":
            date_from, _ = parse_dates(r["date_range"])
            d = date_from.isoformat()
        else:
            d = r.get("date") or r.get("date_range", "").split("..", 1)[0]

        print(f"\nМаршрут: {src} -> {dst}")
        print("Aviasales:", aviasales_link(src, dst, d))
        print("Trip.com:", trip_link(src, dst, d))


if __name__ == "__main__":
    main()
