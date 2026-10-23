"""Assemble the DOT evidence per review project, for the review page.

For each review project: its bike-related DOT presentations (date presented, title, link) with
up to three timing sentences each, ranked so that sentences naming an installation and a
season or month come first; plus rows of DOT's 2014 protected-lane report on the same corridor.
Writes dot_projects/review_evidence.json, keyed by proj_id.
Usage (from repo root): python evidence/dot_projects/04_review_evidence.py [matches.csv timing.csv out.json]
  presentations kept: bike-related or with the street in the title; up to three lane statements each
"""
import csv, json, re, sys

MATCHES = sys.argv[1] if len(sys.argv) > 1 else "evidence/dot_projects/review_matches.csv"
TIMING = sys.argv[2] if len(sys.argv) > 2 else "evidence/dot_projects/presentation_timing.csv"
OUT = sys.argv[3] if len(sys.argv) > 3 else "evidence/dot_projects/review_evidence.json"
NUM = re.compile(r"\b(one|two|three|four|five|six|\d)\b", re.I)
from collections import defaultdict

SEASON = re.compile(r"\b(spring|summer|fall|autumn|winter|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(19|20)\d\d", re.I)
STRONG = re.compile(r"install|implement|complet|construct|post[- ]implementation", re.I)


def score(s):
    return 2 * bool(STRONG.search(s)) + bool(SEASON.search(s)) - len(s) / 1000


def main():
    matches = [r for r in csv.DictReader(open(MATCHES, encoding="utf-8")) if r["bike_related"] == "1" or int(r["relevance"]) >= 2]
    snips, lanes = defaultdict(list), defaultdict(list)
    for r in csv.DictReader(open(TIMING, encoding="utf-8")):
        if r["snippet"]:
            # PDF bullets and quotes that did not decode come through as U+FFFD
            text = re.sub(r"\s+", " ", r["snippet"].replace("�", " ")).strip(" -•")
            (lanes if r.get("kind") == "lanes" else snips)[r["pdf_url"]].append({"page": r["page"], "text": text})
    report = list(csv.DictReader(open("evidence/dot_projects/dot_2014_report_install_years.csv", encoding="utf-8")))

    ev = defaultdict(lambda: {"presentations": [], "report2014": []})
    for m in matches:
        best = sorted(snips.get(m["pdf_url"], []), key=lambda s: -score(s["text"]))[:3]
        ev[m["proj_id"]]["presentations"].append({
            "presented": m["presented"], "title": m["title"], "link_text": m["link_text"],
            "url": m["pdf_url"], "snippets": best, "relevance": int(m["relevance"]),
            # lane statements, those with a number first ("from four to three lanes")
            "lanes": sorted(lanes.get(m["pdf_url"], []), key=lambda s: (not NUM.search(s["text"]), len(s["text"])))[:3]})
    streets = {m["proj_id"]: m["street"] for m in matches}
    for pid, street in streets.items():
        ev[pid]["report2014"] = [r for r in report if r["corridor"] == street]
    for pid in ev:
        # keep the 8 most relevant (street in the project title, bike project, has timing sentences),
        # then show them chronologically: early decks bracket the plan, post-implementation decks completion
        ps = sorted(ev[pid]["presentations"], key=lambda p: (-p["relevance"], -len(p["snippets"]) - len(p["lanes"]), p["presented"]))[:8]
        ev[pid]["presentations"] = sorted(ps, key=lambda p: p["presented"] or "0")
    json.dump(ev, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(ev), "projects with DOT evidence;",
          sum(len(v["presentations"]) for v in ev.values()), "presentations;",
          sum(len(p["snippets"]) for v in ev.values() for p in v["presentations"]), "timing sentences;",
          sum(1 for v in ev.values() if v["report2014"]), "with 2014 report rows")


if __name__ == "__main__":
    main()
