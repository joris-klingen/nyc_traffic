# To do

State on 2026-10-11: repo renamed to `nyc_traffic` (GitHub `joris-klingen/nyc_traffic`), data store
renamed to `Dropbox/1_research/nyc_traffic_data` with the flat layout, all three repos pushed
(`nyc_traffic` 3982288, `nyc_bikelane_history` 96717c8, `5_NYC_bikelanes` a2cd41f).

## After the rename

- [ ] Verify the local folder rename: `git status` clean, `git remote -v` shows
      `github.com/joris-klingen/nyc_traffic.git`, and a temp script sourcing `R/nyc_traffic.R`
      prints `.../nyc_traffic_data` for `nyc_data_root()` and 176 for `length(tlc_files("yellow"))`
      (never `Rscript -e` on this machine).
- [ ] Run one script in each project against the new paths: `5_NYC_bikelanes/scripts/000_project_init.R`
      and e.g. `nyc_bikelane_history/checks/01_dot_release_quality.R` (both from their repo root).
- [ ] Run `Rscript checks/store.R` on the new layout and fix what it flags.

## Bicycle and pedestrian counts

- [ ] Test `bike_count_sensors()` and `bike_counts_read()` on the full files
      (`traffic_counts/bicycle/Bicycle_and_Pedestrian_Counts_20261011.csv`, 1.9 GB, ~21.4M rows).
      The last sample test was cut off right after fixing sensors without coordinates. Check:
  - every count gets a sensor name; `counter_id` (device in place) is filled where devices have dates
  - the duplicate sensor-flow-time rows (40 in a 3M sample) are the repeated 01:00 hour on
    fall-back days; decide whether to keep both
  - time is NYC local time (the 02:00 hour is missing on spring-forward days; morning peak at 8
    in January and July), even though the source says EST
  - `segment_ft` for bridge paths (nearest LION centerline may be far)
- [ ] Add the counts to the README source table and `checks/store.R` (sensors still reporting,
      gaps per sensor, level shifts at device swaps).

## Smaller items

- [ ] `nyc_bikelane_history` writes `derived/lion_panel`; re-run `lanes/01_lion_panel.R` once to
      confirm it works through `nyc_data_root()`.
- [ ] `5_NYC_bikelanes/notes/*.md` still mention `data_NYC` and `nyc_data` (dated planning notes,
      left as they were; update if wanted).
- [ ] Optionally drop the `NYC_DATA` fallback in `R/config.R` once nothing uses it.
- [ ] Citi Bike: the original 2020-01 to 2021-01 releases with rider demographics are not in the
      store (the 2024 repackaging converted 2020 to the new format). Check whether they can still be
      found anywhere if the gender work needs them.
- [ ] `output/` and `migration_logs/` in the repo folder are untracked leftovers; delete if not needed.
