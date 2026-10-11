# nyc_data

Shared download and access code for NYC raw data: TLC taxi and ride-hail trip records, traffic and bicycle counts,
NYPD motor vehicle collisions, LION streets and DOT bike routes, and Citi Bike trips.
The data itself lives outside this repo.

## Data location

Copy `config.example` to `config.local` (not tracked) and set `NYC_DATA` to the root of the data
store. An `NYC_DATA` environment variable takes precedence. The one-time migration scripts also
need `NYC_RESEARCH`, the folder holding the project repos the data was first downloaded into, and
write their logs to `migration_logs/` in this repo (not tracked).

```
data_NYC/
  taxi/
    raw/
      yellow/              yellow_tripdata_YYYY-MM.parquet   2012-01 onward
      green/               green_tripdata_YYYY-MM.parquet    2013-08 onward
      fhvhv/               fhvhv_tripdata_YYYY-MM.parquet    2019-02 onward (Uber, Lyft, ...)
      yellow_csv_legacy/   yellow_tripdata_YYYY-MM.csv       2012-01 to 2016-06, with pickup/dropoff
                                                             coordinates; no longer published this way, keep
    manifest.csv, download_log.csv
  crashes/
    raw/                   Motor_Vehicle_Collisions_-_{Crashes,Person,Vehicles}_YYYYMMDD.csv (dated snapshots)
                           NYPD_Motor_Vehicle_Collisions_YYYYMMDD.csv (pre-2020 version of the crash table)
    reference/             NYC_vehicle_lookup_table.csv (hand-made vehicle type classification)
  streets/
    lion/                  LION releases: nyc_lion12a.zip ... nyc_lion16d.zip, lion_2012a ... lion_2016d,
                           lion_16d, lion_201911 (probably 19d), nyclion_19d.zip, nyclion_YYYYMMDD.zip (current);
                           quarterly releases nyc_lion12a.zip ... nyc_lion16d.zip and nyclion_17a.zip ... nyclion_26c.zip
                           (57 releases; 12d and 22d are not in the DCP archive)
    address_points/        AddressPoint_YYYYMMDD.csv (DCP/OTI address points: one point per building address)
    bike_routes/           DOT bike routes: archived 2019/2020 shapefiles, New York City Bike Routes_YYYYMMDD.geojson
    other/                 street shapefile, Vision Zero speed limits, old bike lane shapefile
  traffic_counts/
    automated/             Automated_Traffic_Volume_Counts_YYYYMMDD.csv (DOT ATR counts, dated snapshots)
    legacy/                older DOT volume and vehicle classification counts (2011-2018), Midtown 2018
    bicycle/               Bicycle_and_Pedestrian_Counts(_Sensors)_YYYYMMDD.csv (current DOT counters),
                           Bicycle_Count(er)s_20200204.csv (historical version), DCP Manhattan and
                           East River bridge counts
  citibike/
    raw/                   YYYY-citibike-tripdata.zip (to 2023), YYYYMM-citibike-tripdata.zip (2024 onward)
                           Format up to 2021-01: bikeid, usertype, birth year, gender (only source for these).
                           From 2021-02: ride_id, rideable_type, member_casual; no rider demographics.
    raw_monthly_original/  YYYYMM-citibike-tripdata(.csv).zip, 2014-01 to 2019-12: original monthly releases as
                           downloaded at the time, before Citi Bike repackaged them into yearly
                           zips in 2024. Keep: original record for the gender paper.
    stations/              station snapshots, citibikestationsNYC_YYYYMMDD_HHMM.json
    manifest.csv
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
| `scripts/03_migrate_traffic.sh` | One-time copy of traffic and bicycle counts from the bike lanes repo |
| `scripts/10_download_opendata.R` | New dated snapshots of crashes, persons, bike routes, LION, address points, traffic counts and bicycle/pedestrian counts, when NYC Open Data has updated them |
| `scripts/11_download_lion_releases.R` | Quarterly LION releases from the DCP archive (`nyclion_<release>.zip`; 2017a onward, earlier ones as `nyc_lion<release>.zip`) |
| `scripts/20_download_citibike.R` | Download Citi Bike trip zips not yet present; writes `citibike/manifest.csv` |

```bash
Rscript scripts/01_download_tlc.R yellow,green,fhvhv 3
Rscript scripts/10_download_opendata.R
Rscript scripts/20_download_citibike.R
```

## Use from a project

```r
source("path/to/nyc_data/R/nyc_data.R")
ds <- tlc_open("yellow", years = 2019:2026)       # lazy arrow dataset
crashes <- crashes_read()                         # or crashes_read(nyc_latest("crashes", as_of = "20250924"))
crashes <- crashes_relocate(crashes)              # adds longitude_ap, latitude_ap, loc_method, snap_ft, moved_ft
```

`crashes_read()` harmonizes the snapshots: snake_case names, squished text, numeric coordinates
(the 2026-02 to 2026-05 snapshots write `40,717175` and pad text fields), 0/0 coordinates as NA,
`crash_date` as IDate.

Crashes reported at a house number (`off_street_name`, about 18% of all crashes) were
geocoded by interpolating along LION's address range until October 2024; from November 2024 the
published coordinates are the building's address point, about 45 ft beside the centerline.
Before that, where LION pads a block's range to xx98, points pile toward the low-number end of the
block, and about 10% land on another block of the same street. `crashes_relocate()` moves them to the building's address point, matching the street by
street code so alternate names work (8 AVENUE / FREDERICK DOUGLASS BLVD). About 95% are
relocated. The building point is then projected orthogonally onto the LION centerline of the same
street (`snap_ft`, median about 50 ft), so the crash sits on the street beside the building; the
median total move is about 50 ft. `Rscript checks/crash_geocoding.R <borough>` shows the problem
and the fix (padded ranges: 25% of Brooklyn segments, 64% of Queens).

Each project keeps its own cleaning filters and spatial aggregation.
