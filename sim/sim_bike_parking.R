# Simulated bike parking
#
# Real data: raw/street_layout/bike_parking/Bicycle_Parking_20261014.csv, read with
# data.table::fread(nyc_latest('bike_parking')); 38,107 rows, returned as a data.table.
# Bicycle parking racks: one row per site with rack type, number of racks, install date and
# location.
# Columns: BoroCode, BoroName, BoroCD, CounDist, AssemDist, StSenDist, CongDist, Program,
# Site_ID, Group_ID, Borough, IFOAddress, OnStreet, FromStreet, ToStreet, Side_of_St, RackType,
# Date_Inst, Latitude, Longitude, NTAName, FEMAFldz, FEMAFldT, HrcEvac, geometry
# (profiles/bike_parking.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_bike_parking(500)

sim_bike_parking <- function(n = 1000, seed = NULL) sim_profile("bike_parking", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_bike_parking(10, seed = 1)))
}
