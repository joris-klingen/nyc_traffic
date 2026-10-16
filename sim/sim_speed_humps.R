# Simulated speed humps
#
# Real data: streets/calming/VZV_Speed_Humps_20261014.geojson, read with
# sf::st_read(nyc_latest('speed_humps')); 4,383 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# Vision Zero speed humps: one line per hump segment with street and install date.
# Columns: on_street, humps, shape_stle, from_stree, date_insta, objectid, to_street
# (profiles/speed_humps.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_speed_humps(500)

sim_speed_humps <- function(n = 1000, seed = NULL) sim_profile("speed_humps", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_speed_humps(10, seed = 1)))
}
