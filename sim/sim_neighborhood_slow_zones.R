# Simulated neighborhood slow zones
#
# Real data: street_layout/traffic_rules/VZV_Neighborhood_Slow_Zones_20261014.geojson, read with
# sf::st_read(nyc_latest('neighborhood_slow_zones')); 28 rows, returned as sf with MULTIPOLYGON
# geometry (EPSG 4326).
# Vision Zero neighborhood slow zones: 20 mph zones as polygons, with the year they were set
# up.
# Columns: name, year, shape_leng, shape_area (profiles/neighborhood_slow_zones.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_neighborhood_slow_zones(500)

sim_neighborhood_slow_zones <- function(n = 1000, seed = NULL) sim_profile("neighborhood_slow_zones", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_neighborhood_slow_zones(10, seed = 1)))
}
