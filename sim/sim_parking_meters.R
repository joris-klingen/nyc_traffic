# Simulated parking meters
#
# Real data: street_layout/parking/Parking_Meters_Locations_and_Status_20261014.csv, read with
# data.table::fread(nyc_latest('parking_meters')); 15,598 rows, returned as a data.table with
# POINT geometry as WKT text in Location.
# Parking meters: one row per meter with meter number, status, pay-by-cell zone, borough, on
# street, side, from / to streets, meter hours and the point location (WKT column Location).
# Columns: ObjectID, Meter Number, Status, Pay By Cell Number, Meter_Hours,
# Parking_Facility_Name, Facility, Borough, On_Street, Side_of_Street, From_Street, To_Street,
# Latitude, Longitude, X, Y (profiles/parking_meters.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_parking_meters(500)

sim_parking_meters <- function(n = 1000, seed = NULL) sim_profile("parking_meters", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_parking_meters(10, seed = 1)))
}
