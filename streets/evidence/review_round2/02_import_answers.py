"""Turn the round 2 review answers into layers/bike_lanes/manual/round2_answers.csv.

Export first (Claude does this with the ArtifactData tool, action "list", collection "round2",
out_dir layers/bike_lanes/manual/review_export), which writes one JSON file per item to
layers/bike_lanes/manual/review_export/round2/. Each answer is joined to the item's segments, so
the CSV has one row per item and SegmentID. Reviewer ids are kept (opaque), names are not stored.

An answer holds a verdict (confirmed: the proposed timeline; confirmed_ours / confirmed_dot for date
conflicts; corrected: the reviewer tagged photos and Street View panoramas), and for corrected answers
the observations: per photo or panorama the travel lanes for cars, a bus lane, and the bike lane as
seen (none / sharrows / conventional / buffered / protected). Changes are derived here from the
observations, as on the page: a change lies between two observations; the earliest DOT or pipeline
day inside that window dates it (precision verified), else the first observation showing it (window).
Buffered and protected are both class I, so buffered -> protected is an upgrade within class I.
Confirmed answers take the proposal; their lane counts are the reviewer's from lanes_counted (from
2026-10-14), else LION's (lanes_source "LION"), which is often off.
Usage (from repo root): python evidence/review_round2/02_import_answers.py
"""
import csv, glob, json
from collections import defaultdict
from datetime import date, timedelta

PHOTOS = {"2008": ("2008-06-01", "2008-06-30"), "2010": ("2010-06-15", "2010-06-15"), "2012": ("2012-06-15", "2012-06-20"),
          "2014": ("2014-06-01", "2014-06-01"), "2016": ("2016-03-26", "2016-04-05"), "2018": ("2018-04-14", "2018-05-02"),
          "2020": ("2020-03-21", "2020-04-11"), "2022": ("2022-03-18", "2022-03-18"), "2024": ("2024-03-14", "2024-03-24")}
CLASS = {"none": "none", "sharrows": "Sharrows", "conventional": "Standard", "buffered": "Protected", "protected": "Protected"}
FIELDS = ["item_id", "kind", "street", "SegmentID", "verdict",
          "protected_date", "protected_precision", "protected_last_without", "protected_first_with", "before_type",
          "upgrade_date", "upgrade_precision", "upgrade_last_without", "upgrade_first_with",
          "lanes_before", "lanes_after", "lanes_source", "lanes_date", "lanes_precision", "lanes_last_before", "lanes_first_after",
          "bus_change", "bus_date", "bus_last_without", "bus_first_with",
          "lanes_before_project", "n_bike_changes", "n_lane_changes", "note", "by", "saved_at"]


def merged(evs):
    """the same change recorded on nearby days (block by block) is one change, dated by its first day"""
    out = []
    for e in sorted(evs, key=lambda e: e["date"]):
        m = next((o for o in out if o["from"] == e["from"] and o["to"] == e["to"]
                  and (date.fromisoformat(e["date"]) - date.fromisoformat(o["last"])).days <= 122), None)
        if m:
            m["last"] = e["date"]
        else:
            out.append(dict(e, last=e["date"]))
    return out


def window_of(o):
    if o["source"] == "aerial":
        lo, hi = PHOTOS[o["photo"]]
        return lo, hi, o["photo"] + " photo"
    y, m = int(o["date"][:4]), int(o["date"][5:7])
    end = (date(y + (m == 12), m % 12 + 1, 1) - timedelta(days=1)).isoformat()
    return o["date"] + "-01", end, "Street View " + o["date"]


def derive(a, cands):
    obs = []
    for o in a.get("observations") or []:
        lo, hi, label = window_of(o)
        obs.append(dict(o, lo=lo, hi=hi, label=label))
    obs.sort(key=lambda o: o["lo"])
    bike, lanes, bus = [], [], []
    wb = [o for o in obs if o.get("bike")]
    for x, y in zip(wb, wb[1:]):
        if x["bike"] == y["bike"]:
            continue
        cy = CLASS[y["bike"]]
        hit = sorted((e for e in cands if e["to"] == cy and x["hi"] < e["date"] <= y["hi"]), key=lambda e: e["date"])
        bike.append({"from": CLASS[x["bike"]], "to": cy, "from_type": x["bike"], "to_type": y["bike"], "last_without": x["label"],
                     "first_with": y["label"], "lo": x["hi"], "hi": y["lo"], "date": hit[0]["date"] if hit else y["lo"],
                     "precision": "verified" if hit else "window"})
    wl = [o for o in obs if o.get("lanes") is not None]
    for x, y in zip(wl, wl[1:]):
        if x["lanes"] == y["lanes"]:
            continue
        bc = next((c for c in bike if c["lo"] < y["hi"] and c["hi"] > x["lo"]), None)
        lanes.append({"before": x["lanes"], "after": y["lanes"], "last_before": x["label"], "first_after": y["label"],
                      "date": bc["date"] if bc else y["lo"], "precision": bc["precision"] if bc else "window"})
    wbus = [o for o in obs if o.get("bus") is not None]
    for x, y in zip(wbus, wbus[1:]):
        if x["bus"] != y["bus"]:
            bus.append({"to": "bus lane" if y["bus"] else "no bus lane", "last_without": x["label"], "first_with": y["label"], "date": y["lo"]})
    return bike, lanes, bus, wl


items = {r["item_id"]: r for r in csv.DictReader(open("evidence/review_round2/out/items.csv", encoding="utf-8"))}
segs = defaultdict(list)
for r in csv.DictReader(open("evidence/review_round2/out/item_segments.csv", encoding="utf-8")):
    segs[r["item_id"]].append(r["SegmentID"])

rows = []
for f in sorted(glob.glob("layers/bike_lanes/manual/review_export/round2/*.json")):
    a = json.load(open(f, encoding="utf-8"))
    it = items[a["item_id"]]
    cands = merged(json.loads(it["bike_events"] or "[]")) + merged(json.loads(it["dot_events"] or "[]"))
    lanes_source = ""
    if a["verdict"] == "corrected":
        bike, lane_ch, bus, wl = derive(a, cands)
        lb = wl[0]["lanes"] if wl else ""
        la = wl[-1]["lanes"] if wl else ""
        lanes_source = "observed" if wl else ""
    else:
        bike, bus = a.get("bike_changes") or [], []
        lane_ch = a.get("lane_changes") or []
        lc = a.get("lanes_counted")
        if lc:
            lb, la, lanes_source = lc["before"], lc["after"], "reviewer" if lc.get("edited") else "LION, confirmed"
        elif lane_ch:
            lb, la, lanes_source = lane_ch[0]["before"], lane_ch[0]["after"], "LION"
        else:
            lb = la = ""
    prot = next((c for c in bike if c.get("to") == "Protected" and c.get("from") != "Protected"), {})
    upg = next((c for c in bike if c.get("from_type") == "buffered" and c.get("to_type") == "protected"), {})
    lane = lane_ch[0] if lane_ch else {}
    b = bus[0] if bus else {}
    row = {k: a.get(k, "") for k in ("item_id", "kind", "street", "verdict", "lanes_before_project", "note", "by", "saved_at")}
    row.update(protected_date=prot.get("date", ""), protected_precision=prot.get("precision", ""),
               protected_last_without=prot.get("last_without", ""), protected_first_with=prot.get("first_with", ""),
               before_type=prot.get("from_type", prot.get("from", "")),
               upgrade_date=upg.get("date", ""), upgrade_precision=upg.get("precision", ""),
               upgrade_last_without=upg.get("last_without", ""), upgrade_first_with=upg.get("first_with", ""),
               lanes_before=lb, lanes_after=la, lanes_source=lanes_source, lanes_date=lane.get("date", ""),
               lanes_precision=lane.get("precision", ""), lanes_last_before=lane.get("last_before", ""),
               lanes_first_after=lane.get("first_after", ""),
               bus_change=("added" if b.get("to") == "bus lane" else "removed") if b else "", bus_date=b.get("date", ""),
               bus_last_without=b.get("last_without", ""), bus_first_with=b.get("first_with", ""),
               n_bike_changes=len(bike), n_lane_changes=len(lane_ch))
    rows += [dict(row, SegmentID=s) for s in segs.get(a["item_id"], [])]

with open("layers/bike_lanes/manual/round2_answers.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
print(len({r["item_id"] for r in rows}), "answers,", len(rows), "segment rows -> layers/bike_lanes/manual/round2_answers.csv")
