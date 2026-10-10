# nyc_tlc_data

Shared download and access code for NYC raw data: TLC taxi and ride-hail trip records,
NYPD motor vehicle collisions, LION streets and DOT bike routes, and Citi Bike trips.
Used by `5_NYC_bikelanes` and `6_NYC_CC/NYC_CC_analysis`. The data itself lives outside this
repo.

## Data location

`Dropbox/1_research/data_NYC/`, overridable with the `NYC_DATA` environment variable
(in `~/.Renviron`).

```
data_NYC/
  taxi/
    raw/
      yellow/              yellow_tripdata_YYYY-MM.parquet   2012-01 onward
      green/               green_tripdata_YYYY-MM.parquet    2013-08 onward
      fhvhv/               fhvhv_tripdata_YYYY-MM.parquet    2019-02 onward (Uber, Lyft, ...)
      yellow_csv_legacy/   yellow_tripdata_YYYY-MM.csv       2012-01 to 2016-06, with pickup/dropoff
                                                             coordinates; no longer published this way, keep
    manifest.csv, download_log.csv, migration_log.csv
  crashes/
    raw/                   Motor_Vehicle_Collisions_-_{Crashes,Person,Vehicles}_YYYYMMDD.csv (dated snapshots)
                           NYPD_Motor_Vehicle_Collisions_YYYYMMDD.csv (pre-2020 version of the crash table)
    reference/             NYC_vehicle_lookup_table.csv (hand-made vehicle type classification)
  streets/
    lion/                  LION releases: nyc_lion12a.zip ... nyc_lion16d.zip, lion_2012a ... lion_2016d,
                           lion_16d, lion_201911 (probably 19d), nyclion_19d.zip, nyclion_YYYYMMDD.zip (current)
    bike_routes/           DOT bike routes: archived 2019/2020 shapefiles, New York City Bike Routes_YYYYMMDD.geojson
    other/                 street shapefile, Vision Zero speed limits, old bike lane shapefile
  citibike/
    raw/                   YYYY-citibike-tripdata.zip (to 2023), YYYYMM-citibike-tripdata.zip (2024 onward)
    stations/              station lists
    manifest.csv
  migration_log_other.csv
```

Raw files are never edited. Snapshots of updating datasets carry their download date. Files the
publisher replaced are kept as `*.superseded_YYYYMMDD.*`.

## Scripts

Run from the repo root.

| Script | Purpose |
|---|---|
| `scripts/00_migrate_existing.sh` | One-time copy of TLC files previously downloaded inside the project repos |
| `scripts/02_migrate_other.sh` | One-time copy of crash, street, bike-route and station files from the project repos |
| `scripts/01_download_tlc.R` | Download new TLC months (and re-check the most recent ones); writes `taxi/manifest.csv` |
| `scripts/10_download_opendata.R` | New dated snapshots of crashes, persons, bike routes and LION, when NYC Open Data has updated them |
| `scripts/20_download_citibike.R` | Download Citi Bike trip zips not yet present; writes `citibike/manifest.csv` |

```bash
Rscript scripts/01_download_tlc.R yellow,green,fhvhv 3
Rscript scripts/10_download_opendata.R
Rscript scripts/20_download_citibike.R
```

## Use from a project

```r
source("../nyc_tlc_data/R/tlc_open.R")          # path relative to the project root
ds <- tlc_open("yellow", years = 2019:2026)       # lazy arrow dataset
file.path(nyc_data_root(), "crashes", "raw")      # other sources: read directly
```

Each project keeps its own cleaning filters and spatial aggregation.
