# Simulated meter blockfaces
#
# Real data: raw/street_layout/parking/Parking_Meters_ParkNYC_Block_Faces_20261014.geojson, read with
# sf::st_read(nyc_latest('meter_blockfaces')); 11,185 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# ParkNYC metered block faces: one line per block face with its rate zone, rates and hours.
# Columns: on_street, from_stree, meter_rate, all_vehi_3, commerci_3, all_vehi_1, vehicle_ty,
# side_of_st, commerci_2, all_vehicl, shape_leng, pay_by_cel, commercial, commerci_1, borough,
# to_street, all_vehi_2 (profiles/meter_blockfaces.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_meter_blockfaces(500)

sim_meter_blockfaces <- function(n = 1000, seed = NULL) sim_profile("meter_blockfaces", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_meter_blockfaces(10, seed = 1)))
}
