# Simulated street panel (Manhattan, monthly)
#
# Real data: streets_panel(from, to, boro = 1), built from the spells (not stored). Wide: one row
# per key segment and date with in_lion, bike_lane_tf, bike_lane_ft (Protected, Standard,
# Sharrows, none), travel_lanes, parking_lanes, total_lanes, street_width (numeric) and
# traffic_dir (W with, A against, T two-way, P pedestrian). Profiled for 2018-01 to 2019-12
# (529,692 rows on 22,302 key segments): profiles/streets_panel_manhattan.csv.
#
# Runs the real streets_panel() on simulated spells and key segments, so the panel logic (overlap
# of sources by priority, in_lion filter, wide reshape) is the production code.
#
# panel <- sim_streets_panel_manhattan("2018-01-01", "2019-12-01", n_keys = 2000)

sim_streets_panel_manhattan <- function(from = "2018-01-01", to = "2019-12-01", n_keys = 2000, seed = NULL,
                                        keys = sim_key_segments(n_keys, seed, boro = 1), spells = sim_street_spells(keys), ...) {
  streets_panel(from, to, boro = 1, spells = spells, keys = keys, ...)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  p <- sim_streets_panel_manhattan(n_keys = 300, seed = 1)
  print(p)
  print(p[, .N, bike_lane_tf])
}
