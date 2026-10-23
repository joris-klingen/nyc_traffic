"""Redraw the photo sheets of the review projects with the project's street segments marked.

Reuses the fetching code (and tile cache) of pilot_aerial/02_fetch_images.py. The segment
centre lines are drawn semi-transparently on each panel, so it is clear which carriageway is
being judged; the lane itself sits at the curb and stays visible.
Usage (from repo root): python evidence/aerial_labelling/05_review_sheets.py [points.csv lines.csv out_dir [ids]]
  default: the round 1 review projects; ids: comma-separated subset (e.g. only items without a sheet)
"""
import csv, importlib.util, math, os, sys
from collections import defaultdict
from PIL import Image, ImageDraw, ImageFont

spec = importlib.util.spec_from_file_location("fetch", "evidence/pilot_aerial/02_fetch_images.py")
F = importlib.util.module_from_spec(spec)
spec.loader.exec_module(F)

POINTS = sys.argv[1] if len(sys.argv) > 1 else "evidence/aerial_labelling/out/projects.csv"
LINES = sys.argv[2] if len(sys.argv) > 2 else "evidence/aerial_labelling/out/review_segment_lines.csv"
OUT = sys.argv[3] if len(sys.argv) > 3 else "evidence/aerial_labelling/out/review_sheets"
ONLY = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
LINE = (255, 0, 255, 110)   # magenta, semi-transparent


def to_px(lon, lat, cx, cy):
    """lon/lat -> pixel in the fetched (unrotated) square centred on (cx, cy)."""
    b = F.bbox(cx, cy)
    x, y = F.merc(lon, lat)
    return (x - b[0]) / (b[2] - b[0]) * F.PX, (b[3] - y) / (b[3] - b[1]) * F.PX


def main():
    os.makedirs(OUT, exist_ok=True)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    pts = {r["proj_id"]: r for r in csv.DictReader(open(POINTS))}
    lines = defaultdict(list)
    for r in csv.DictReader(open(LINES)):
        if ONLY is None or r["proj_id"] in ONLY:
            lines[r["proj_id"]].append(r)
    years = F.YEARS_NYC + F.YEARS_NYS
    cap = {int(r["year"]): r["label"] for r in csv.DictReader(open("layers/bike_lanes/manual/aerial_capture_dates_manhattan.csv"))}
    for pid, segs in sorted(lines.items()):
        p = pts[pid]
        lon, lat, brg = float(p["lon"]), float(p["lat"]), float(p["bearing"])
        sheet = Image.new("RGB", (3 * F.PANEL + 4 * 6, 3 * F.PANEL + 4 * 6 + 36), "white")
        d = ImageDraw.Draw(sheet)
        d.text((8, 6), f"{pid}  (street runs vertically, {F.CROP_M} m square; magenta = project segments)", fill="black", font=font)
        for i, yr in enumerate(years):
            try:
                # the NYC tile service for 2008 / 2010 has moved (it now returns a placeholder): round 1
                # (M) and pilot (P) items use their cached NYC tiles, later items the NYS service's 2008 / 2010
                use_nyc = yr in F.YEARS_NYC and pid[:1] in ("M", "P")
                img = F.fetch_nyc(pid, lon, lat, yr) if use_nyc else F.fetch_nys(pid, lon, lat, yr)
                over = Image.new("RGBA", img.size, (0, 0, 0, 0))
                od = ImageDraw.Draw(over)
                for s in segs:
                    a = to_px(float(s["lon_start"]), float(s["lat_start"]), lon, lat)
                    b = to_px(float(s["lon_end"]), float(s["lat_end"]), lon, lat)
                    od.line([a, b], fill=LINE, width=4)
                img = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")
                panel = F.panel(img, brg)
            except Exception as e:
                panel = Image.new("RGB", (F.PANEL, F.PANEL), "grey")
                print(pid, yr, "failed:", e)
            x, y = 6 + (i % 3) * (F.PANEL + 6), 42 + (i // 3) * (F.PANEL + 6)
            sheet.paste(panel, (x, y))
            label = cap.get(yr, str(yr))
            w = d.textlength(label, font=font) if hasattr(d, "textlength") else 12 * len(label)
            d.rectangle((x, y, x + w + 12, y + 30), fill="black")
            d.text((x + 6, y + 3), label, fill="yellow", font=font)
        sheet.save(os.path.join(OUT, f"{pid}.jpg"), quality=88)
        print(pid, "done")


if __name__ == "__main__":
    main()
