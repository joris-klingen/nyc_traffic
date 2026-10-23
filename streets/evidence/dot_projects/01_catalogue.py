"""Catalogue NYC DOT's project archive (nyc.gov/html/dot/html/about/projects-YYYY.shtml).

One row per presentation PDF: archive year, project title, description, PDF url, link text and
the presentation month parsed from the link text or file name. The pages are downloaded to
dot_projects/html/ (kept out of git) so the catalogue can be rebuilt.
Usage (from repo root): python evidence/dot_projects/01_catalogue.py
"""
import csv, html, os, re, time, urllib.request

OUT = "evidence/dot_projects"
HTML = os.path.join(OUT, "html")
PAGES = {y: f"https://www.nyc.gov/html/dot/html/about/projects-{y}.shtml" for y in range(2007, 2026)}
PAGES["current"] = "https://www.nyc.gov/html/dot/html/about/current-projects.shtml"
MONTHS = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}


def fetch(key, url):
    path = os.path.join(HTML, f"projects-{key}.shtml")
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research; nyc_streets)"})
        open(path, "wb").write(urllib.request.urlopen(req, timeout=60).read())
        time.sleep(0.5)
    return open(path, encoding="utf-8", errors="replace").read()


def clean(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s))).strip()


def month_of(text):
    """(year, month) from 'presented ... in March 2019' or a file name like 'cb1-feb2020', 'spring2019'."""
    t = text.lower()
    m = re.search(r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?[\s_-]*(19|20)(\d\d)", t)
    if m:
        return int(m.group(2) + m.group(3)), MONTHS[m.group(1)]
    m = re.search(r"(20\d\d)-(\d\d)-", t)            # 2012-12-columbus-... style
    if m and 1 <= int(m.group(2)) <= 12:
        return int(m.group(1)), int(m.group(2))
    m = re.search(r"(spring|summer|fall|autumn|winter)[\s_-]*(20\d\d)", t)
    if m:
        return int(m.group(2)), {"spring": 4, "summer": 7, "fall": 10, "autumn": 10, "winter": 1}[m.group(1)]
    return None, None


def main():
    os.makedirs(HTML, exist_ok=True)
    rows = []
    for key, url in PAGES.items():
        page = fetch(key, url)
        # projects are <article> (older pages) or <div class='cproject'> (newer pages)
        blocks = re.split(r"<article\b|<div class=['\"]cproject['\"]", page)[1:]
        for b in blocks:
            t = re.search(r"<h3[^>]*>(.*?)</h3>", b, re.S)
            if not t:
                continue
            title = clean(t.group(1))
            desc = " ".join(clean(p) for p in re.findall(r"<p(?![^>]*tag-lists)[^>]*>(.*?)</p>", b, re.S))
            links = re.findall(r"<a href=['\"]([^'\"]+\.pdf)['\"][^>]*>(.*?)</a>([^<]*)", b, re.S)
            for href, text in ((h, clean(x) + " " + clean(after)) for h, x, after in links):
                y, m = month_of(text)
                if y is None:
                    y, m = month_of(os.path.basename(href))
                href = re.sub(r"^http://", "https://", href)
                if href.startswith("/"):
                    href = "https://www.nyc.gov" + href
                rows.append({"archive_page": key, "title": title, "pdf_url": href, "link_text": text,
                             "presented_year": y or "", "presented_month": m or "", "description": desc[:1500]})
    with open(os.path.join(OUT, "dot_project_catalogue.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print(len(rows), "presentations;", len({r["title"] for r in rows}), "projects;",
          sum(1 for r in rows if r["presented_year"]), "with a presentation month")


if __name__ == "__main__":
    main()
