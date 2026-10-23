# Simulated bus lanes
#
# Real data: street_layout/bus_lanes/Bus_Lanes_Local_Streets_20261014.geojson, read with
# sf::st_read(nyc_latest('bus_lanes')); 4,068 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# DOT bus lanes on local streets: one line per bus lane segment with street, from / to street,
# hours and days of operation, lane type (curbside, offset, ...) and the year it was installed
# (year1). Published as current state only.
# Columns: rw_type, year3, sbs_route3, days_code, direction, year2, chron_id_1, shape_leng,
# lane_color, last_updat, streetwidt, hours, lane_type1, year1, open_dates, lane_type,
# sbs_route1, boro, lane_type2, street, mid_block, shape_le_1, bltrafdir, facility, segmentid,
# days, sbs_route2, lane_width (profiles/bus_lanes.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_bus_lanes(500)

sim_bus_lanes <- function(n = 1000, seed = NULL) sim_profile("bus_lanes", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_bus_lanes(10, seed = 1)))
}
