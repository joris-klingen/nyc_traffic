# To do

State on 2026-10-11: repo renamed to `nyc_traffic` (GitHub `joris-klingen/nyc_traffic`), data store
renamed to `Dropbox/1_research/nyc_traffic_data` with the flat layout, all three repos pushed
(`nyc_traffic` 3982288, `nyc_bikelane_history` 96717c8, `nyc_res_bikelanes` a2cd41f).

## After the rename

- [x] Folder rename verified 2026-10-13 (`nyc_data_root()` and 176 yellow months; `NYC_DATA` unset).
- [x] `nyc_res_bikelanes/scripts/000_project_init.R` and `nyc_bikelane_history/checks/01_dot_release_quality.R`
      run against the new paths.
- [x] `checks/store.R` run on the new layout 2026-10-13: only flags the real COVID drops (2020-04 to
      2020-06); the IDate warning is fixed. 85% of traffic count SegmentIDs are in current LION.

## Bicycle and pedestrian counts

- [x] Readers tested on the full file 2026-10-13 (17 min, 21.4M rows, 41 sensors with counts):
  - every count has a sensor name; no unparsed times
  - no duplicate sensor-flow-time keys once deleted rows are dropped: the duplicates of the sample
    were 216 deleted + modified pairs, not daylight saving
  - local time confirmed: 02:00 missing on spring-forward Sundays, fall-back Sundays have a single
    01:00 hour, weekday morning peak at 8 in summer
- [ ] `counter_id` is empty for 10% of rows, mostly two sensors whose device dates do not cover their
      data: Comprehensive Brooklyn Bridge Counter (2013-12 to 2022-03, 543k rows) and 1st Avenue -
      26th St N - Interference testing (2013-09 to 2018-04, 321k rows).
- [ ] Off-street sensors snap to a far LION centerline: Concrete Plant Park (165 ft), High Bridge
      (136 ft), Hunts Point Ave (89 ft). Set `segment_id` to NA beyond some distance, or flag
      off-street paths. One sensor has no coordinates (Manhattan Bridge Interference Calibration 2018).
- [ ] Add the counts to the README source table and `checks/store.R` (sensors still reporting,
      gaps per sensor, level shifts at device swaps).

## Smaller items

- [x] `lanes/01_lion_panel.R` re-run through `nyc_data_root()` 2026-10-13; output identical.
- [x] `nyc_res_bikelanes/notes/*.md` point to the current repos and data store (2026-10-16; a
      header line in each note says the paths were updated).
- [ ] Optionally drop the `NYC_DATA` fallback in `R/config.R` once nothing uses it.
- [ ] Citi Bike: the original 2020-01 to 2021-01 releases with rider demographics are not in the
      store (the 2024 repackaging converted 2020 to the new format). Check whether they can still be
      found anywhere if the gender work needs them.
- [x] `output/` and `migration_logs/` deleted 2026-10-13.
