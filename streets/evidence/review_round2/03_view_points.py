"""Sheet centres at the three Street View points of each item (25 / 50 / 75 % along it).

The round 2 sheets show one 70 m square at the middle of an item; on long avenues shadows and trees
differ block by block. This writes the Street View points as extra sheet centres, ids x<item>_<k>
(not starting with M or P, so their state orthophotos are cached by location), with the item's
segment lines, for evidence/aerial_labelling/05_review_sheets.py:
  out/view_points.csv, out/view_segment_lines.csv
Usage (from repo root): python evidence/review_round2/03_view_points.py
Then: python evidence/aerial_labelling/05_review_sheets.py out/view_points.csv out/view_segment_lines.csv out/sheets_views
"""
import csv, re

OUT = "evidence/review_round2/out"
pts, ids = [], set()
for r in csv.DictReader(open(f"{OUT}/items.csv", encoding="utf-8")):
    for k in (1, 2, 3):
        u = r.get(f"streetview_{k}") or ""
        m = re.search(r"viewpoint=([-\d.]+),([-\d.]+)&heading=([-\d.]+)", u)
        if m:
            pid = f"x{r['item_id']}_{k}"
            pts.append({"proj_id": pid, "lon": m.group(2), "lat": m.group(1), "bearing": m.group(3)})
            ids.add((r["item_id"], pid))
with open(f"{OUT}/view_points.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["proj_id", "lon", "lat", "bearing"]); w.writeheader(); w.writerows(pts)
lines = list(csv.DictReader(open(f"{OUT}/segment_lines.csv", encoding="utf-8")))
by_item = {}
for l in lines:
    by_item.setdefault(l["proj_id"], []).append(l)
with open(f"{OUT}/view_segment_lines.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(lines[0].keys())); w.writeheader()
    for item, pid in sorted(ids):
        for l in by_item.get(item, []):
            w.writerow(dict(l, proj_id=pid))
print(len(pts), "view points for", len({i for i, _ in ids}), "items")
