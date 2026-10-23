# Simulated barnes dance
#
# Real data: street_layout/signals/Exclusive_Pedestrian_Signal_Locations_20261014.csv, read with
# data.table::fread(nyc_latest('barnes_dance')); 737 rows, returned as a data.table with POINT
# geometry as WKT text in the_geom.
# Exclusive pedestrian signal phases (Barnes dance): one point per intersection (WKT column
# the_geom).
# Columns: BoroCode, BoroName, BoroCD, CounDist, AssemDist, StSenDist, CongDist, Main Street,
# Cross Street, Barnes Dance, Modified Barnes Dance, Mid-Block Crossing, T- Oneway Away- 24
# hour Walk, T- Oneway Away- All Walk in Phase B, Installation Date, NTAName, FEMAFldz,
# FEMAFldT, HrcEvac (profiles/barnes_dance.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_barnes_dance(500)

sim_barnes_dance <- function(n = 1000, seed = NULL) sim_profile("barnes_dance", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_barnes_dance(10, seed = 1)))
}
