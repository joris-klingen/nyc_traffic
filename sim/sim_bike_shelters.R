# Simulated bike shelters
#
# Real data: street_layout/bike_parking/Bicycle_Parking_Shelters_20261014.csv, read with
# data.table::fread(nyc_latest('bike_shelters')); 17 rows, returned as a data.table.
# Bicycle parking shelters (a short list with locations).
# Columns: BoroCode, BoroName, BoroCD, CounDist, AssemDist, StSenDist, CongDist, location,
# shelter_id, street, Build_date, NTAName, FEMAFldz, FEMAFldT, HrcEvac, geometry
# (profiles/bike_shelters.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_bike_shelters(500)

sim_bike_shelters <- function(n = 1000, seed = NULL) sim_profile("bike_shelters", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_bike_shelters(10, seed = 1)))
}
