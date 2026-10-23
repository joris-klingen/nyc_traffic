"""Match DOT project presentations to the review projects.

A presentation matches a review project when its title, description or link text names the
project's street (with spelling aliases), it is not explicitly in another borough, and it is
presented within 4 years before to 2 years after the earliest claimed date. Bike-related
presentations are flagged; others (e.g. pure pedestrian work on the same avenue) are kept but
ranked lower.
Writes dot_projects/review_matches.csv.
Usage (from repo root): python evidence/dot_projects/02_match_review.py [items.csv out.csv]
  default: the round 1 review checklist; items.csv needs proj_id or item_id, street, prot_pipe, prot_dot
"""
import csv, re, sys

ITEMS = sys.argv[1] if len(sys.argv) > 1 else "evidence/aerial_labelling/out/review_checklist.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "evidence/dot_projects/review_matches.csv"

ALIASES = {
    "AVENUE OF THE AMERICAS": r"avenue of the americas|\b(6th|sixth) ave",
    "1 AVENUE": r"\b(1st|first) ave",
    "2 AVENUE": r"\b(2nd|second) ave",
    "3 AVENUE": r"\b(3rd|third) ave",
    "4 AVENUE": r"\b(4th|fourth) ave",
    "8 AVENUE": r"\b(8th|eighth) ave",
    "11 AVENUE": r"\b(11th|eleventh) ave",
    "12 AVENUE": r"\b(12th|twelfth) ave",
    "AMSTERDAM AVENUE": r"amsterdam ave",
    "COLUMBUS AVENUE": r"columbus ave",
    "CENTRAL PARK WEST": r"central park west",
    "HUDSON STREET": r"hudson st",
    "LAFAYETTE STREET": r"lafayette st",
    "ST NICHOLAS AVENUE": r"st\.? nicholas|saint nicholas",
    "UNION SQUARE WEST": r"union square",
    "VARICK STREET": r"varick",
    "BROADWAY": r"\bbroadway\b",
    "CLEVELAND PLACE": r"cleveland pl",
    "DYCKMAN STREET": r"dyckman",
    "WILLIS AVENUE BRIDGE APPROACH": r"willis ave(nue)? bridge",
}
PARK = r"central park|car[- ]free|park drive|loop drive"   # all park-drive projects
OTHER_BORO = r"\b(bronx|brooklyn|queens|staten island)\b"
BIKE = r"bike|bicycl|cycl|protected path|greenway"


def alias(street):
    if street in ALIASES:
        return ALIASES[street]
    if re.search(r"DRIVE|APPR|CPW", street):
        return PARK
    # numbered streets and avenues: "10 AVENUE" -> 10th Ave, "W 55 ST" / "EAST 13 STREET" -> 55th St
    m = re.match(r"^(?:(?:E|EAST|W|WEST)\.?\s+)?(\d+)\s+(ST|STREET|AV|AVE|AVENUE)$", street)
    if m:
        kind = r"st(reet)?\b" if m.group(2).startswith("ST") else r"ave(nue)?\b"
        return r"\b" + m.group(1) + r"(st|nd|rd|th)\s+" + kind
    words = street.lower().split()
    words = [r"ave(nue)?" if w in ("ave", "av", "avenue") else r"st(reet)?" if w in ("st", "street") else re.escape(w) for w in words]
    return r"\b" + r"\s+".join(words) + r"\b"


def main():
    cat = list(csv.DictReader(open("evidence/dot_projects/dot_project_catalogue.csv", encoding="utf-8")))
    rev = list(csv.DictReader(open(ITEMS, encoding="utf-8")))
    for r in rev:
        r["proj_id"] = r.get("proj_id") or r["item_id"]
    out = []
    for r in rev:
        pat = re.compile(alias(r["street"]), re.I)
        claims = [int(c[:4]) for c in (r.get("prot_pipe", ""), r.get("prot_dot", "")) if c and c[:4].isdigit() and int(c[:4]) >= 2000]
        lo, hi = (min(claims) - 4, max(claims) + 2) if claims else (2007, 2026)
        for c in cat:
            text = " ".join([c["title"], c["description"], c["link_text"]])
            if not pat.search(text):
                continue
            boro_txt = (c["link_text"] + " " + c["title"]).lower()
            if re.search(OTHER_BORO, boro_txt) and "manhattan" not in boro_txt:
                continue
            y = int(c["presented_year"]) if c["presented_year"] else None
            if y is not None and not (lo <= y <= hi):
                continue
            out.append({"proj_id": r["proj_id"], "street": r["street"], "prot_pipe": r.get("prot_pipe", ""), "prot_dot": r.get("prot_dot", ""),
                        "bike_related": int(bool(re.search(BIKE, text, re.I))),
                        # relevance: the street is in the project's own title, and the title is about bikes
                        "relevance": 2 * int(bool(pat.search(c["title"]))) + int(bool(re.search(BIKE, c["title"], re.I))),
                        "presented": f"{c['presented_year']}-{int(c['presented_month']):02d}" if c["presented_month"] else c["presented_year"],
                        "title": c["title"], "link_text": c["link_text"], "pdf_url": c["pdf_url"]})
    out.sort(key=lambda x: (x["proj_id"], -x["bike_related"], x["presented"]))
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
        w.writeheader(); w.writerows(out)
    by = {}
    for o in out:
        by.setdefault(o["proj_id"], [0, 0]); by[o["proj_id"]][0] += 1; by[o["proj_id"]][1] += o["bike_related"]
    print(len(out), "matches;", len(by), "of", len(rev), "review projects matched;",
          sum(1 for v in by.values() if v[1]), "with a bike-related presentation")
    for r in rev:
        v = by.get(r["proj_id"], [0, 0])
        print(f"{r['proj_id']} {r['street'][:28]:28s} matches {v[0]:3d}  bike {v[1]:3d}")


if __name__ == "__main__":
    main()
