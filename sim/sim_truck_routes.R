# Simulated truck routes
#
# Real data: streets/traffic_rules/New_York_City_Truck_Routes_20261014.geojson, read with
# sf::st_read(nyc_latest('truck_routes')); 32,939 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# Designated truck routes: one line per segment with the route type (local, through, limited).
# Columns: truckroute, coun_dist, thrutunl, objectid_1, thrubrg, ltdlocal, streetcode,
# localbrg, borocd, restrictio, shape_leng, st_sen_dis, assem_dist, boroname, thruexwy,
# routetype, localtunl, borocode, street, segmentid, nyc_reg, cong_dist
# (profiles/truck_routes.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_truck_routes(500)

sim_truck_routes <- function(n = 1000, seed = NULL) sim_profile("truck_routes", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_truck_routes(10, seed = 1)))
}
