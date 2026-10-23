# nyc_traffic — agent signpost

**What this is.** The hub repo: downloads and reads *all* raw NYC data into `../nyc_traffic_data/`,
and holds the readers for **both** data stores (including `bikelane_windows_read()`, whose data
lives in `nyc_streets_data`).

**Read this first.** [`README.md`](README.md) — sources, joins, CRS, crash geocoding, LION, scripts.

**Find a dataset + how to read it.** [`nyc_data_catalog.md`](nyc_data_catalog.md) — every dataset
across both stores with the exact reader call. Regenerate: `Rscript scripts/50_build_catalog.R`.

**Big picture.** [`../NYC_DATA.md`](../NYC_DATA.md) — how traffic/streets/res fit together.

**To use the readers:**
```r
source(Find(file.exists, c("../nyc_traffic_repo/R/nyc_traffic.R", "../nyc_traffic/R/nyc_traffic.R")))
```

**Rules.** Raw data (everything outside `derived/`) is never edited; snapshots keep their download
date; computed outputs go to `derived/`. Work without the store via `sim/` + `profiles/`. The data
store is local only (not on GitHub).

**R style.** data.table, `dt[, col]` bracket syntax, `# Section ----` headers. Never run R inline
(`Rscript -e`) — write a script file and run it with `Rscript`.
