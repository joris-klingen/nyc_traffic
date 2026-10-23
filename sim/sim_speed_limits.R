# Simulated speed limits
#
# Real data: street_layout/traffic_rules/VZV_Speed_Limits_20261014.geojson, read with
# sf::st_read(nyc_latest('speed_limits')); 141,444 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# Vision Zero speed limits: one line per street segment with its posted speed limit (postvz_sl)
# and street name.
# Columns: street, postvz_sl, postvz_sg, shape_leng (profiles/speed_limits.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_speed_limits(500)

sim_speed_limits <- function(n = 1000, seed = NULL) sim_profile("speed_limits", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_speed_limits(10, seed = 1)))
}
