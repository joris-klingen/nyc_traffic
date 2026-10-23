# Simulated meter rate zones
#
# Real data: street_layout/parking/Parking_Meters_Citywide_Rate_Zones_20261014.geojson, read with
# sf::st_read(nyc_latest('meter_rate_zones')); 52 rows, returned as sf with MULTIPOLYGON
# geometry (EPSG 4326).
# Citywide parking meter rate zones: polygons with the hourly rates.
# Columns: shape_area, shape_leng, boro_name, zone_name, rate_zone, boro_code, shape_le_1, zone
# (profiles/meter_rate_zones.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_meter_rate_zones(500)

sim_meter_rate_zones <- function(n = 1000, seed = NULL) sim_profile("meter_rate_zones", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_meter_rate_zones(10, seed = 1)))
}
