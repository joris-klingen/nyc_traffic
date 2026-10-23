# nyc_streets — agent signpost

**What this is.** Builds a curated *history* of the NYC street network (segment key, spells,
bike-lane and travel-lane panels) from raw LION + DOT releases. Outputs go to
`../nyc_streets_data/`. Raw inputs are downloaded and read by **`nyc_traffic`**, not here.

**Not to be confused with** `nyc_traffic_data/raw/street_layout/`, which is the *raw* current-state street
layout. This repo produces the *dated history*.

**Read this first.** [`README.md`](README.md) — segment key, street spells, bike-lane
classification, the review page, layout.

**Find an output + how to read it.** [`../nyc_traffic_repo/nyc_data_catalog.md`](../nyc_traffic_repo/nyc_data_catalog.md).

**Big picture.** [`../NYC_DATA.md`](../NYC_DATA.md).

**To use the readers:**
```r
source(Find(file.exists, c("../nyc_streets_repo/R/streets.R", "../nyc_streets/R/streets.R")))
# needs the nyc_traffic repo next to this one for the raw readers
```

**Rules.** Outputs in `nyc_streets_data/` are rebuildable; working files stay in the repo (`out/`).
Work without the store via `sim/` + `profiles/`. Re-run `profiles/build_profiles.R` after rebuilding
outputs.

**R style.** data.table, `dt[, col]` bracket syntax, `# Section ----` headers. Never run R inline —
write a script file and run it with `Rscript`.
