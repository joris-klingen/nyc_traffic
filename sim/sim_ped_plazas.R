# Simulated ped plazas
#
# Real data: raw/street_layout/public_space/NYC_DOT_Pedestrian_Plazas_20261014.geojson, read with
# sf::st_read(nyc_latest('ped_plazas')); 93 rows, returned as sf with MULTIPOLYGON geometry
# (EPSG 4326).
# DOT pedestrian plazas: polygons with plaza name, partner and status.
# Columns: stsendist, onstreet, shape_area, fromstreet, coundist, assemdist, tostreet, borocd,
# femafldz, partner, objectid, shape_leng, boroname, plazaname, hrcevac, borocode, congdist,
# femafldt (profiles/ped_plazas.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_ped_plazas(500)

sim_ped_plazas <- function(n = 1000, seed = NULL) sim_profile("ped_plazas", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_ped_plazas(10, seed = 1)))
}
