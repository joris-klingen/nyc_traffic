"""Build the review page: embed the checklist rows in template.html and copy the sheets.

Writes review_app/index.html and review_app/sheets/*.jpg (published as the artifact's files).
Usage (from repo root): python evidence/aerial_labelling/review_app/build.py
"""
import csv, json, os, shutil

APP = "evidence/aerial_labelling/review_app"
KEEP = ["priority", "category", "proj_id", "street", "n_segments", "prot_pipe", "prot_dot",
        "aerial_window", "note", "streetview_1", "streetview_2", "streetview_3"]

rows = [{k: r[k] for k in KEEP} for r in csv.DictReader(open("evidence/aerial_labelling/out/review_checklist.csv", encoding="utf-8"))]
data = json.dumps(rows, ensure_ascii=False).replace("</", "<\\/")
ev_path = "evidence/dot_projects/review_evidence.json"
evidence = json.load(open(ev_path, encoding="utf-8")) if os.path.exists(ev_path) else {}
evidence = {k: v for k, v in evidence.items() if k in {r["proj_id"] for r in rows}}
ev_data = json.dumps(evidence, ensure_ascii=False).replace("</", "<\\/")
html = (open(os.path.join(APP, "template.html"), encoding="utf-8").read()
        .replace("/*DATA*/", data).replace("/*EVIDENCE*/", ev_data))
open(os.path.join(APP, "index.html"), "w", encoding="utf-8").write(html)

os.makedirs(os.path.join(APP, "sheets"), exist_ok=True)
for r in rows:
    shutil.copy2(f"evidence/aerial_labelling/out/review_sheets/{r['proj_id']}.jpg", os.path.join(APP, "sheets", f"{r['proj_id']}.jpg"))
print(len(rows), "projects;", round(sum(os.path.getsize(os.path.join(APP, "sheets", f)) for f in os.listdir(os.path.join(APP, "sheets"))) / 1e6, 1), "MB of sheets")
