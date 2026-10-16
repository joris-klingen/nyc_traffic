# Simulated Citi Bike station list (GBFS)
#
# Real data: citibike/stations/station_information_YYYYMMDD.json, read with
# jsonlite::fromJSON(nyc_latest("citibike_stations"))[["data"]][["stations"]]; 2,519 stations in
# 2026-10. Columns: station_id (UUID), name, short_name (the id used in the trip data, e.g.
# "5329.03"), lon, lat, region_id, capacity, rental_uris, has_kiosk, station_type, external_id,
# electric_bike_surcharge_waiver, eightd_has_key_dispenser (list columns left out).
#
# Kept: the real station names and locations of the 2020-on trips (short_name matches the trip
# station ids of sim_citibike_trips()); capacity and flags from the profile. Not kept: UUIDs.
#
# st <- sim_citibike_stations()

sim_citibike_stations <- function(n = NULL, seed = NULL) {
  st <- sim_ref("citibike_trips_2020_on_stations.csv", colClasses = c(station_id = "character"))
  if (!is.null(n)) st <- st[seq_len(min(n, .N))]
  x <- sim_profile("citibike_stations", nrow(st), seed)
  uuid <- function(k) sprintf("%s-%s-%s-%s-%s", sim_ids(k, "hex", 8, 8), sim_ids(k, "hex", 4, 4), sim_ids(k, "hex", 4, 4),
                              sim_ids(k, "hex", 4, 4), sim_ids(k, "hex", 12, 12))
  x[, `:=`(station_id = uuid(.N), external_id = uuid(.N), name = st[, name], short_name = st[, station_id],
           lon = st[, lng], lat = st[, lat])]
  x[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_citibike_stations(seed = 1)))
}
