# Simulated arterial slow zones
#
# Real data: street_layout/traffic_rules/VZV_Arterial_Slow_Zones_20261014.geojson, read with
# sf::st_read(nyc_latest('arterial_slow_zones')); 28 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# Vision Zero arterial slow zones: corridors whose speed limit was lowered to 25 mph, with the
# date it was done.
# Columns: from_stree, to_street, enforcemen, shape_leng (profiles/arterial_slow_zones.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_arterial_slow_zones(500)

sim_arterial_slow_zones <- function(n = 1000, seed = NULL) sim_profile("arterial_slow_zones", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_arterial_slow_zones(10, seed = 1)))
}
