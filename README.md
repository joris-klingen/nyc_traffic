# nyc_tlc_data

Shared download and access code for NYC Taxi & Limousine Commission (TLC) trip records,
used by `5_NYC_bikelanes` and `6_NYC_CC/NYC_CC_analysis`. The data itself lives outside
this repo.

## Data location

`Dropbox/1_research/data_NYC/taxi/`, overridable with the `NYC_TLC_DATA` environment
variable (in `~/.Renviron`).

```
data_NYC/taxi/
  raw/
    yellow/              yellow_tripdata_YYYY-MM.parquet   2012-01 onward
    green/               green_tripdata_YYYY-MM.parquet    2013-08 onward
    fhvhv/               fhvhv_tripdata_YYYY-MM.parquet    2019-02 onward (Uber, Lyft, ...)
    yellow_csv_legacy/   yellow_tripdata_YYYY-MM.csv       2012-01 to 2016-06, with pickup/dropoff
                                                           coordinates; no longer published this way, keep
  manifest.csv           every raw file with size and modification time
  download_log.csv       history of download attempts
  migration_log.csv      one-time copy from the project repos (2026-10)
```

Raw files keep TLC's own file names and are never edited. Files TLC republishes are kept as
`*.superseded_YYYYMMDD.parquet`.

## Scripts

Run from the repo root.

| Script | Purpose |
|---|---|
| `scripts/00_migrate_existing.sh` | One-time copy of files previously downloaded inside the project repos |
| `scripts/01_download_tlc.R` | Download new months (and re-check the most recent ones); writes `manifest.csv` |

```bash
Rscript scripts/01_download_tlc.R yellow,green,fhvhv 3
```

## Use from a project

```r
source("../nyc_tlc_data/R/tlc_open.R")          # path relative to the project root
ds <- tlc_open("yellow", years = 2019:2026)       # lazy arrow dataset
```

Each project keeps its own cleaning filters and spatial aggregation.
