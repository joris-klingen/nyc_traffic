"""Build a local HTML checklist for the Street View review.

One card per project: claims, aerial window, my aerial note, the photo sheet with the project
segments marked, and three Street View links along the project. Open the file in a browser,
use Street View's date selector ("See more dates") to step back in time, and enter the result
in out/review_checklist.csv (columns protected_from, before_type, confidence, checker_note).
Usage (from repo root): python evidence/aerial_labelling/06_checklist_html.py
"""
import csv, html

rows = list(csv.DictReader(open("evidence/aerial_labelling/out/review_checklist.csv", encoding="utf-8")))

WHAT = {
    "claim_too_early": "Photos show no lane after the claimed date. Check whether protection existed at the claimed date "
                       "(note: unpainted parking-protected lanes are easy to miss from the air).",
    "claim_too_late": "A buffered/protected lane is visible before the claimed date. Find when protection first appeared "
                      "and what was there before (buffered paint vs physical protection).",
    "park_drive_definition": "Park drive: decision taken (2026-10-11) to date protection from the car-free date. "
                             "Only confirm the car-free date for this section.",
}

cards = []
for r in rows:
    links = " ".join(
        f'<a href="{html.escape(r[k])}" target="_blank" rel="noopener">view {i}</a>'
        for i, k in enumerate(["streetview_1", "streetview_2", "streetview_3"], 1) if r.get(k))
    cards.append(f"""
<section class="card p{r['priority']}">
  <h2>{r['proj_id']} &middot; {html.escape(r['street'])} <span class="tag">priority {r['priority']} &middot; {r['category'].replace('_', ' ')}</span></h2>
  <table>
    <tr><th>segments</th><td>{r['n_segments']}</td><th>pipeline date</th><td>{r['prot_pipe'] or '&ndash;'}</td><th>DOT 2026 date</th><td>{r['prot_dot'] or '&ndash;'}</td></tr>
    <tr><th>aerial window</th><td colspan="5">{r['aerial_window'] or 'no protection seen'} &middot; <em>{html.escape(r['note'])}</em></td></tr>
  </table>
  <p class="what">{WHAT.get(r['category'], '')}</p>
  <p class="links">Street View along the project: {links}</p>
  <a href="out/review_sheets/{r['proj_id']}.jpg" target="_blank"><img src="out/review_sheets/{r['proj_id']}.jpg" alt="aerial photos {r['proj_id']}" loading="lazy"></a>
</section>""")

page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bike lane date review</title>
<style>
  :root {{ --bg: #fafaf8; --fg: #1d1d1b; --muted: #6b6b66; --card: #fff; --line: #e3e3de; --p1: #c2410c; --p2: #2563eb; --p3: #6b7280; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg: #161615; --fg: #ececea; --muted: #a3a39e; --card: #1f1f1e; --line: #333331; }} }}
  body {{ background: var(--bg); color: var(--fg); font: 15px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 1000px; padding: 16px; }}
  .card {{ background: var(--card); border: 1px solid var(--line); border-left: 5px solid var(--p3); border-radius: 6px; padding: 12px 16px; margin: 16px 0; }}
  .card.p1 {{ border-left-color: var(--p1); }} .card.p2 {{ border-left-color: var(--p2); }}
  h2 {{ font-size: 1.1rem; margin: 0 0 8px; }} .tag {{ color: var(--muted); font-weight: normal; font-size: .85rem; }}
  table {{ border-collapse: collapse; font-size: .9rem; }} th {{ text-align: left; color: var(--muted); font-weight: normal; padding-right: 6px; }} td {{ padding-right: 18px; }}
  .what {{ margin: 8px 0; }} .links a {{ margin-right: 12px; }}
  img {{ width: 100%; height: auto; border-radius: 4px; margin-top: 6px; }}
</style></head><body>
<h1>Bike lane installation dates: Street View review</h1>
<p>{len(rows)} Manhattan projects where the aerial photos (2008&ndash;2024, every two years, flown in spring) conflict with the
pipeline or DOT date. For each: open the Street View links, use <em>See more dates</em> to step back in time, find the first
panorama with the protected lane, and record <code>protected_from</code> (YYYY-MM), <code>before_type</code> (none / conventional /
buffered), <code>confidence</code> (high / medium / low) and a note in <code>out/review_checklist.csv</code>.
Magenta lines on the photos mark the project segments.</p>
{''.join(cards)}
</body></html>"""

open("evidence/aerial_labelling/review_checklist.html", "w", encoding="utf-8").write(page)
print("wrote aerial_labelling/review_checklist.html with", len(rows), "projects")
