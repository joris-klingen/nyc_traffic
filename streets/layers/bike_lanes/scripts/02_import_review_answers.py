"""Turn the review page's exported answers into manual/streetview_review_answers.csv.

Export first (Claude does this with the ArtifactData tool, action "list", collection "reviews",
out_dir manual/review_export), which writes one JSON file per project to
manual/review_export/reviews/. Reviewer ids are kept (opaque), names are not stored.
Usage (from repo root): python layers/bike_lanes/scripts/02_import_review_answers.py
"""
import csv, glob, json

FIELDS = ["proj_id", "street", "protected_from", "before_type", "note", "by", "saved_at"]
rows = [json.load(open(f, encoding="utf-8")) for f in sorted(glob.glob("layers/bike_lanes/manual/review_export/reviews/*.json"))]
with open("layers/bike_lanes/manual/streetview_review_answers.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
print(len(rows), "answers -> manual/streetview_review_answers.csv")
