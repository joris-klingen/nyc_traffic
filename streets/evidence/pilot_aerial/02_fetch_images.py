"""Aerial imagery pilot: fetch orthophotos per test segment and build one contact sheet each.

Sources (public, Manhattan coverage every other year):
  2008, 2010       NYC DoITT tiles   https://maps.nyc.gov/xyz/1.0.0/photo/{year}/{z}/{x}/{y}.png8
  2012-2024 (even) NYS ITS orthos    https://orthos.its.ny.gov/arcgis/rest/services/wms/{year}/MapServer/export

Each panel is a ~70 m square around the segment midpoint, rotated so the street runs vertically.
Usage (from repo root): python evidence/pilot_aerial/02_fetch_images.py [points.csv] [out_dir]
  points.csv: columns pilot_id or proj_id, lon, lat, bearing (default pilot_aerial/out/pilot_segments.csv)
"""
import csv, io, math, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont

POINTS = sys.argv[1] if len(sys.argv) > 1 else "evidence/pilot_aerial/out/pilot_segments.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "evidence/pilot_aerial/out"
# tile cache outside Dropbox (thousands of small files); override with AERIAL_CACHE
# (not under AppData: the Microsoft Store Python silently redirects writes there)
CACHE = os.environ.get("AERIAL_CACHE", "C:/code/nyc_aerial_cache")
YEARS_NYC = [2008, 2010]
YEARS_NYS = [2012, 2014, 2016, 2018, 2020, 2022, 2024]
FETCH_M = 110      # ground metres fetched (before rotation)
CROP_M = 70        # ground metres shown
PX = 700           # pixels for the fetched square
PANEL = 400        # pixels per panel on the contact sheet
R = 6378137.0

def merc(lon, lat):
    return R * math.radians(lon), R * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))

def get(url, path):
    if os.path.exists(path):
        return open(path, "rb").read()
    req = urllib.request.Request(url, headers={"User-Agent": "research (nyc_streets pilot)"})
    for attempt in range(3):
        try:
            data = urllib.request.urlopen(req, timeout=60).read()
            open(path, "wb").write(data)
            time.sleep(0.05)
            return data
        except Exception as e:
            err = e
            time.sleep(2)
    raise err

def bbox(lon, lat):
    x, y = merc(lon, lat)
    half = FETCH_M / 2 / math.cos(math.radians(lat))   # ground metres -> mercator units
    return x - half, y - half, x + half, y + half

def fetch_nys(pid, lon, lat, year):
    b = bbox(lon, lat)
    url = (f"https://orthos.its.ny.gov/arcgis/rest/services/wms/{year}/MapServer/export"
           f"?bbox={b[0]},{b[1]},{b[2]},{b[3]}&bboxSR=3857&imageSR=3857&size={PX},{PX}&format=png&f=image")
    # pilot (P) and round 1 (M) images are cached by id; later items by location, so that ids can be reassigned
    key = f"{pid}_{year}" if pid[:1] in ("P", "M") else f"nys_{lon:.5f}_{lat:.5f}_{year}"
    return Image.open(io.BytesIO(get(url, os.path.join(CACHE, key + ".png")))).convert("RGB")

def fetch_nyc(pid, lon, lat, year, z=20):
    b = bbox(lon, lat)
    world = 2 * math.pi * R
    tile_m = world / 2 ** z
    tx0, tx1 = int((b[0] + world / 2) // tile_m), int((b[2] + world / 2) // tile_m)
    ty0, ty1 = int((world / 2 - b[3]) // tile_m), int((world / 2 - b[1]) // tile_m)
    mosaic = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
    tiles = [(tx, ty) for tx in range(tx0, tx1 + 1) for ty in range(ty0, ty1 + 1)]
    def one(t):
        tx, ty = t
        url = f"https://maps.nyc.gov/xyz/1.0.0/photo/{year}/{z}/{tx}/{ty}.png8"
        return t, get(url, os.path.join(CACHE, f"tile_{year}_{z}_{tx}_{ty}.png"))
    with ThreadPoolExecutor(max_workers=8) as ex:
        for (tx, ty), data in ex.map(one, tiles):
            mosaic.paste(Image.open(io.BytesIO(data)).convert("RGB"), ((tx - tx0) * 256, (ty - ty0) * 256))
    # crop mosaic to bbox
    ox, oy = tx0 * tile_m - world / 2, world / 2 - ty0 * tile_m
    sc = 256 / tile_m
    box = ((b[0] - ox) * sc, (oy - b[3]) * sc, (b[2] - ox) * sc, (oy - b[1]) * sc)
    return mosaic.crop(tuple(int(round(v)) for v in box)).resize((PX, PX))

def panel(img, bearing):
    rot = ((bearing + 90) % 180) - 90                 # keep orientation within +-90 degrees
    img = img.rotate(rot, resample=Image.BICUBIC)     # counterclockwise: street becomes vertical
    keep = PX * CROP_M / FETCH_M
    c = (PX - keep) / 2
    return img.crop((int(c), int(c), int(c + keep), int(c + keep))).resize((PANEL, PANEL))

def main():
    os.makedirs(CACHE, exist_ok=True)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    os.makedirs(OUT, exist_ok=True)
    rows = list(csv.DictReader(open(POINTS)))
    years = YEARS_NYC + YEARS_NYS
    for r in rows:
        pid = r.get("pilot_id") or r["proj_id"]
        lon, lat, brg = float(r["lon"]), float(r["lat"]), float(r["bearing"])
        if os.path.exists(os.path.join(OUT, f"{pid}.jpg")):
            continue
        sheet = Image.new("RGB", (3 * PANEL + 4 * 6, 3 * PANEL + 4 * 6 + 36), "white")
        d = ImageDraw.Draw(sheet)
        d.text((8, 6), f"{pid}  (street runs vertically, {CROP_M} m square)", fill="black", font=font)
        for i, yr in enumerate(years):
            try:
                img = fetch_nyc(pid, lon, lat, yr) if yr in YEARS_NYC else fetch_nys(pid, lon, lat, yr)
                p = panel(img, brg)
            except Exception as e:
                p = Image.new("RGB", (PANEL, PANEL), "grey")
                print(pid, yr, "failed:", e)
            x, y = 6 + (i % 3) * (PANEL + 6), 42 + (i // 3) * (PANEL + 6)
            sheet.paste(p, (x, y))
            d.rectangle((x, y, x + 70, y + 30), fill="black")
            d.text((x + 6, y + 3), str(yr), fill="yellow", font=font)
        sheet.save(os.path.join(OUT, f"{pid}.jpg"), quality=88)
        print(pid, "done")

if __name__ == "__main__":
    main()
