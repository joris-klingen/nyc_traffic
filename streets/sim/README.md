# Simulators

Simulated street network history for code development without the data (`derived/streets`). `source("sim/sim.R")` from `streets/` loads all of them, using the repo-level `R/simulate.R`.

Each script starts with what the real data are and what the simulation keeps and does not keep.
This index is made from those headers.

| Script | Source | Real reader or file | Example |
|---|---|---|---|
| [sim_bike_lane_updates.R](sim_bike_lane_updates.R) | Simulated DOT bike lane updates (Manhattan, 2025) | `derived/streets/bike_lanes/bike_lane_updates.gpkg` | `u <- sim_bike_lane_updates(200)` |
| [sim_bikelane_windows.R](sim_bikelane_windows.R) | Simulated bike lane time windows | `bikelane_windows_read(version)` | `w <- sim_bikelane_windows(500)                     # SegmentIDs drawn` |
| [sim_bikelane_windows_keyed.R](sim_bikelane_windows_keyed.R) | Simulated bike lane windows on the segment key | `bikelane_windows_keyed_read()` | `kw <- sim_bikelane_windows_keyed(keys = sim_key_segments(2000))` |
| [sim_key_segments.R](sim_key_segments.R) | Simulated key segments | `key_segments_read()` | `keys <- sim_key_segments(2000, boro = 1)` |
| [sim_lion_lanes_panel.R](sim_lion_lanes_panel.R) | Simulated LION lane panel | `derived/streets/travel_lanes/lion_lanes_panel.parquet` | `p <- sim_lion_lanes_panel(500)` |
| [sim_lion_lanes_panel_keyed.R](sim_lion_lanes_panel_keyed.R) | Simulated LION lane panel on the segment key | `derived/streets/travel_lanes/lion_lanes_panel_keyed.parquet` | `p <- sim_lion_lanes_panel_keyed(sim_key_segments(500))` |
| [sim_lion_segment_releases.R](sim_lion_segment_releases.R) | Simulated LION records per release | `derived/streets/spine/lion_segment_releases.parquet` | `rows <- sim_lion_segment_releases(sim_segment_key(sim_key_segments(500)))` |
| [sim_manhattan_lanes_monthly.R](sim_manhattan_lanes_monthly.R) | Simulated Manhattan monthly lane panel | `derived/streets/travel_lanes/manhattan_lanes_monthly.parquet` | `m <- sim_manhattan_lanes_monthly(300)` |
| [sim_manhattan_lanes_monthly_keyed.R](sim_manhattan_lanes_monthly_keyed.R) | Simulated Manhattan monthly lane panel on the segment key | `derived/streets/travel_lanes/manhattan_lanes_monthly_keyed.parquet` | `m <- sim_manhattan_lanes_monthly_keyed(sim_key_segments(300, boro = 1))` |
| [sim_segment_key.R](sim_segment_key.R) | Simulated segment key | `segment_key_read()` | `keys <- sim_key_segments(2000); sk <- sim_segment_key(keys)` |
| [sim_segment_links.R](sim_segment_links.R) | Simulated links between segment versions | `derived/streets/spine/segment_links.parquet` | `sk <- sim_segment_key(); links <- sim_segment_links(sk)` |
| [sim_segment_versions.R](sim_segment_versions.R) | Simulated segment versions (lines) | `segment_versions_read(date)` | `v <- sim_segment_versions(sim_segment_key())` |
| [sim_street_spells.R](sim_street_spells.R) | Simulated street spells | `streets_spells_read()` | `keys <- sim_key_segments(2000); sp <- sim_street_spells(keys)` |
| [sim_streets_panel_manhattan.R](sim_streets_panel_manhattan.R) | Simulated street panel (Manhattan, monthly) | `streets_panel` | `panel <- sim_streets_panel_manhattan("2018-01-01", "2019-12-01", n_keys = 2000)` |
