# nyc_traffic

Shared download and access code for NYC data: TLC taxi and ride-hail trips, NYPD motor vehicle
collisions, LION streets, address points, DOT bike routes, traffic and bicycle counts, Citi Bike
trips, and boundary layers (boroughs, community districts, NTAs, census tracts and blocks,
precincts, taxi zones). The data itself lives outside this repo, in `nyc_traffic_data/`.

## Setup

Copy `config.example` to `config.local` (not tracked) and set `NYC_TRAFFIC_DATA` to the root of
the data store. An `NYC_TRAFFIC_DATA` environment variable takes precedence (the old name
`NYC_DATA` still works as a fallback). In R:

```r
source("path/to/nyc_traffic/R/nyc_traffic.R")   # all helpers below; needs data.table, arrow, sf
```

## Sources

| Source | Coverage | Location / join key | CRS | Read with | Known issues |
|---|---|---|---|---|---|
| Yellow taxi | 2012-01 to latest month | `PULocationID`, `DOLocationID` (taxi zones) | - | `tlc_open("yellow")` | `airport_fee` is `Airport_fee` from 2023-02; `cbd_congestion_fee` from 2025-01, `request_source` from 2026-06; column types drift across years |
| Green taxi | 2014-01 to latest | zone ids | - | `tlc_open("green")` | 2013-08..12 not published as parquet |
| FHVHV (Uber, Lyft, ...) | 2019-02 to latest | zone ids | - | `tlc_open("fhvhv")` | `trip_miles`, not `trip_distance`; `cbd_congestion_fee` from 2025-01 |
| Yellow legacy CSV | 2012-01 to 2016-06 | pickup/dropoff lon/lat | 4326 | `fread` | ~2.4% of pickups at 0,0 or outside NYC: filter with `nyc_in_bbox()` |
| Crashes | 2012-07 to latest | lon/lat; `crashes_relocate()` adds LION `segment_id`, `node_id` | 4326 | `crashes_read()`, `crashes_relocate()` | see [Crash locations](#crash-locations) |
| Crash persons, vehicles | 2012 to latest | `collision_id` | - | `fread(nyc_latest("persons"))` | |
| LION | 57 quarterly releases 2012a-2026c (12d, 22d not archived) + current snapshot | `SegmentID`, `NODEID`, `StreetCode` | 2263 | `lion_read()`, `nyc_lion_for_date()` | see [LION](#lion) |
| Address points | current | building point; `b5sc` street code | 4326 | `address_points_read()` | |
| DOT bike routes | snapshots 2025-10, 2026-10; archives 2017-2020 | `segmentid` = LION `SegmentID` (99%) | 4326 | `bike_routes_read()` | 13 empty geometries (dropped by the reader) |
| Automated traffic counts | 2000 to latest, 15 min | `SegmentID` (85% in current LION, rest in older releases) | 2263 (`WktGeom`) | `traffic_counts_read()` | |
| Bicycle/pedestrian counts | DOT counters | sensor `id` | 4326 | `fread(nyc_latest("bike_ped_counts"))` | 10 of 66 counters in the 2020 version sit at 0,0 |
| Citi Bike | 2013-06 to latest month | station lon/lat | 4326 | `citibike_read("2016-07")` | rider demographics only to 2019-12 (see below); 3 archive layouts |
| Street layout (parking signs and meters, bus lanes, speed limits, slow zones, truck routes, speed humps and SRTS, LPI and Barnes dance signals, open streets, plazas, bike parking, pavement ratings, construction closures) | current state, dated snapshots from 2026-10-14 (SRTS, closures also 2020-02) | mostly LION `segmentid` or street + from/to street; signs and meters as points | 4326 | `nyc_latest("bus_lanes")` etc., names in `nyc_opendata` (`R/config.R`) | published as current state only: history exists only from the first snapshot, except fields with install dates (speed humps, LPI, bike racks, bus lane `year1`, signs `order_completed_on_date`) and `street_network_changes` (one-way conversions) |
| Citi Bike stations | GBFS snapshots from 2026-10-14; 2019 snapshots | station lon/lat | 4326 | `jsonlite::fromJSON(nyc_latest("citibike_stations"))` | before 2026: first and last trip per station in the trip data |
| Boundaries | 2020 census geographies, current admin areas | polygons | 4326 on disk | `boundaries_read("tracts")` | 4 census blocks have invalid geometry (repaired by the reader) |
| Taxi zones | current | `LocationID` | 2263 | `taxi_zones_read()` | zones 264/265 are "unknown", no polygon |

Coverage is checked by `checks/store.R`.

## Joining sources

- **CRS.** Join and measure in NY State Plane Long Island feet, `nyc_crs` (EPSG 2263). All
  `*_read()` helpers that return sf use it; `nyc_points_sf(dt, "longitude", "latitude")` turns any
  lon/lat table into points in it (dropping rows without coordinates in NYC).
- **Streets.** LION `SegmentID` links LION, bike routes, traffic counts and relocated crashes;
  LION `NODEID` links intersection crashes. LION changes over time: use the release in force at
  the date (`nyc_lion_for_date()`), especially for older count stations.
- **Street names.** Match by street code (`b5sc`, borough + 5 digits), not by name:
  `nyc_street_codes()` maps normalized names, alternate and former names to codes.
- **Areas.** `sf::st_join(points, boundaries_read("ntas"))`; trips join to `taxi_zones_read()` by
  `LocationID`. Boundary keys: `borocode`, `boro_cd`, `nta2020`, `geoid`/`boroct2020` (tracts),
  `bctcb2020` (blocks), `precinct`. Tracts also carry `nta2020` and `cdta2020`.

```r
library(data.table); library(sf)
source("path/to/nyc_traffic/R/nyc_traffic.R")

cr  <- crashes_relocate(crashes_read())                   # best location per crash
pts <- nyc_points_sf(cr, "longitude_ap", "latitude_ap")   # sf points, EPSG 2263
pts <- st_join(pts, boundaries_read("ntas")["nta2020"])   # crashes by neighborhood

lion <- lion_read(nyc_lion_for_date("2019-06-01"), boro = 1)   # Manhattan streets in mid-2019
tc   <- traffic_counts_read()
tc   <- merge(tc, st_drop_geometry(lion)[, c("SegmentID", "Number_Travel_Lanes")], by = "SegmentID")

trips <- tlc_open("yellow", 2024) |> dplyr::count(PULocationID) |> dplyr::collect()
zones <- merge(taxi_zones_read(), trips, by.x = "LocationID", by.y = "PULocationID")
```

## Crash locations

`crashes_read()` harmonizes the snapshots: snake_case names, squished text, numeric coordinates
(the 2026-02 to 2026-05 snapshots write `40,717175` and pad text fields), coordinates at 0,0 or
outside NYC as NA, `crash_date` as IDate. It reads a parquet copy when
`scripts/30_crashes_parquet.R` has made one.

`crashes_relocate()` returns the best available location in `longitude_ap`, `latitude_ap`, with
`loc_method` saying where it comes from:

- `address point`, `nearest address point`: crashes reported at a house number (`off_street_name`,
  about 18% of crashes). Until October 2024 these were geocoded by interpolating along LION's
  address range; where LION pads a block's range to xx98 they pile toward the low-number end of the
  block, and about 10% land on another block. From November 2024 the published coordinates are
  already the building's address point. They are moved to the building's address point (about 95%
  match), projected orthogonally onto the LION centerline of the same street (`snap_ft`, median
  about 50 ft, `segment_id` of that centerline); median total move about 50 ft.
- `intersection node`: intersection crashes without coordinates (about 10% of them) get the LION
  node where the two streets meet, when that is unambiguous. Against crashes with coordinates:
  median error 2 ft with a borough, 99% within 150 ft (83% without a borough).
- `original`: everything else, including street-only crashes (mostly highways, placed along the
  highway; on surface streets at a node of the named street).

`node_id` is set for intersection crashes (the node filled in, or the one within 10 ft of the
original point). Coordinates are missing for 11.0% of crashes in the data and 6.1% after
`crashes_relocate()`.

## LION

`lion_read(file, boro, what = "centerline")` handles what reading LION by hand gets wrong: the
geodatabase sits at `lion/lion.gdb` inside the zip (`lion.gdb` in 2015b), curved segments must be
linearized (`type = 5`) for GEOS, `RW_TYPE` is stored with a leading space (`" 1"`), and
`what = "centerline"` keeps the street features (`FeatureTyp` 0, 6, A, C; not rail, shoreline or
boundaries) on the generic and both-roadbed layers (`RB_Layer` G, B), so a divided street is one line. `RW_TYPE` 1 is
a street, 2 a highway, 3 a bridge, 4 a tunnel, 9 a ramp. `lion_releases()` lists the quarterly
releases with their dates (a in February, b May, c August, d November).

## Citi Bike

`citibike_read("2016-07")` returns one month in one schema: `started_at`, `ended_at`,
`start/end_station_id`, `_name`, `_lat`, `_lng`, `member`, plus `bikeid`, `birth_year`, `gender`
up to 2019-12 and `ride_id`, `rideable_type` from 2020. Citi Bike published the old format with
rider demographics until 2021-01, but its 2024 repackaging converted all of 2020 to the new
format; the original 2020-01 to 2021-01 files are not in the store. The 2013 archive holds each
month twice (whole and split); the reader uses one copy.

## Data layout

```
nyc_traffic_data/
  taxi/
    yellow/                yellow_tripdata_YYYY-MM.parquet   2012-01 onward
    green/                 green_tripdata_YYYY-MM.parquet    2014-01 onward
    fhvhv/                 fhvhv_tripdata_YYYY-MM.parquet    2019-02 onward
    yellow_csv_legacy/     yellow_tripdata_YYYY-MM.csv       2012-01 to 2016-06, with pickup/dropoff
                                                             coordinates; no longer published this way, keep
    zones/                 taxi_zones_YYYYMMDD.zip (shapefile), taxi_zone_lookup_YYYYMMDD.csv;
                           taxi_zones_20250923.zip is the 2025 version used by 5_NYC_bikelanes (other
                           Manhattan LocationIDs, 3 duplicate ids)
    manifest.csv, download_log.csv
  crashes/                 Motor_Vehicle_Collisions_-_{Crashes,Person,Vehicles}_YYYYMMDD.csv (dated snapshots)
                           NYPD_Motor_Vehicle_Collisions_YYYYMMDD.csv (pre-2020 version of the crash table)
    reference/             NYC_vehicle_lookup_table.csv (hand-made vehicle type classification)
  streets/
    lion/                  quarterly releases nyc_lion12a.zip ... nyc_lion16d.zip, nyclion_17a.zip ...
                           nyclion_26c.zip; current snapshot nyclion_YYYYMMDD.zip; older extracted
                           copies lion_2012a ... lion_2016d, lion_16d, lion_201911 (probably 19d);
                           nyc_lion15b.corrupt_20200630.zip (a damaged download, kept)
    address_points/        AddressPoint_YYYYMMDD.csv (one point per building address)
    bike_routes/           New York City Bike Routes_YYYYMMDD.geojson; archived 2019/2020 shapefiles;
                           2017 route tables and earlier DOT exports
    bus_lanes/             Bus_Lanes_Local_Streets_YYYYMMDD.geojson
    parking/               Parking_Regulation_Locations_and_Signs, Parking_Meters_Locations_and_Status (csv);
                           Parking_Meters_ParkNYC_Block_Faces, Parking_Meters_Citywide_Rate_Zones (geojson)
    traffic_rules/         VZV_Speed_Limits, VZV_Arterial_Slow_Zones, VZV_Neighborhood_Slow_Zones,
                           New_York_City_Truck_Routes (geojson); Street_Network_Changes_Historical.csv;
                           dot_VZV_Speed_Limits (2020-06 shapefile and csv)
    calming/               VZV_Speed_Humps.geojson; Speed_Reducer_Tracking_System__SRTS_.csv (from 2020-02)
    signals/               VZV_Leading_Pedestrian_Interval_Signals, Exclusive_Pedestrian_Signal_Locations (csv)
    public_space/          Open_Streets_Locations, NYC_DOT_Pedestrian_Plazas (geojson); Pedestrian_Space_Added.csv
    bike_parking/          Bicycle_Parking, Bicycle_Parking_Shelters (csv)
    pavement/              Street_Pavement_Ratings.csv (geometry as WKT)
    closures/              Street_Closures_due_to_construction_activities_by_Block.csv (from 2020-02)
    other/                 NYC_streets shapefile and csv, NYC_bikelanes shapefile
  boundaries/              borough_boundaries, community_districts, nta_2020, census_tracts_2020,
                           census_blocks_2020, police_precincts (_YYYYMMDD.geojson);
                           census_tract_2020_to_nta_cdta_YYYYMMDD.csv
  traffic_counts/
    automated/             Automated_Traffic_Volume_Counts_YYYYMMDD.csv (DOT ATR counts)
    legacy/                DOT volume and vehicle classification counts 2011-2018, Midtown 2018
    bicycle/               Bicycle_and_Pedestrian_Counts(_Sensors)_YYYYMMDD.csv (DOT counters),
                           Bicycle_Count(er)s_20200204.csv (historical version), DCP Manhattan and
                           East River bridge counts
  citibike/
    trips/                 YYYY-citibike-tripdata.zip (2013-2023), YYYYMM-citibike-tripdata.zip (2024 onward);
                           old format with rider demographics to 2019-12, new format from 2020
    trips_monthly_original/ YYYYMM-citibike-tripdata(.csv).zip, 2014-01 to 2019-12: original monthly releases,
                           before Citi Bike repackaged them into yearly zips in 2024. Keep: original record
                           for the gender paper.
    stations/              station_information_YYYYMMDD.json (GBFS, from 2026-10-14);
                           citibikestationsNYC_YYYYMMDD_HHMM.json (2019)
    manifest.csv
  documents/
    dot_presentations/     DOT project presentations and street design checklists (PDF), downloaded by
                           nyc_bikelane_history/dot_projects/03_fetch_extract.py
  derived/                 made from the raw data, can be rebuilt:
    crashes_parquet/       parquet copies of the crash snapshots (scripts/30_crashes_parquet.R)
    lion_panel/            LION lane panels (nyc_bikelane_history/lanes/)
    bikelane_history/      Manhattan bike lane time windows (nyc_bikelane_history/scripts/03_time_windows.R),
                           read with bikelane_windows_read()
  opendata_download_log.csv
```

Everything outside `derived/` is raw data as published, and never edited. Snapshots of updating
datasets carry their download date. Files the
publisher replaced are kept as `*.superseded_YYYYMMDD.*`, damaged downloads as
`*.corrupt_YYYYMMDD.*`. Anything computed from the raw data goes to `derived/`.

## Scripts

Run from the repo root.

| Script | Purpose |
|---|---|
| `scripts/01_download_tlc.R` | New TLC months (and re-check the most recent ones), taxi zones; writes `taxi/manifest.csv` |
| `scripts/10_download_opendata.R` | New dated snapshots of the NYC Open Data sets listed in `nyc_opendata` (`R/config.R`: crashes, LION, bike routes, street layout sets, counts, boundaries, ...) when they were updated; a download identical to the latest snapshot is dropped; logs to `opendata_download_log.csv` |
| `scripts/21_snapshot_citibike_stations.R` | Citi Bike station list (GBFS) when it changed |
| `scripts/11_download_lion_releases.R` | Quarterly LION releases from the DCP archive |
| `scripts/20_download_citibike.R` | Citi Bike trip zips not yet present; writes `citibike/manifest.csv` |
| `scripts/30_crashes_parquet.R` | Parquet copies of the crash snapshots in `derived/crashes_parquet/` |

```bash
Rscript scripts/01_download_tlc.R yellow,green,fhvhv 3
Rscript scripts/10_download_opendata.R
Rscript scripts/20_download_citibike.R
Rscript scripts/21_snapshot_citibike_stations.R
Rscript scripts/30_crashes_parquet.R
```

## Checks

| Script | Checks |
|---|---|
| `checks/store.R` | every dataset present and its age, failed downloads, TLC missing months and trip-count drops, zone ids, Citi Bike months, traffic count years, boundary feature counts and geometry validity |
| `checks/crash_geocoding.R <borough>` | position of house-number crashes along their block, original vs relocated (padded LION ranges: 25% of Brooklyn segments, 64% of Queens) |
| `checks/crash_locations.R` | missing crash coordinates, placement of intersection and street-only crashes, accuracy of the intersection nodes |

Each project keeps its own cleaning filters and spatial aggregation.
