# Simulated pavement ratings
#
# Real data: raw/street_layout/pavement/Street_Pavement_Ratings_20261014.csv, read with
# data.table::fread(nyc_latest('pavement_ratings')); 524,928 rows, returned as a data.table.
# Street pavement ratings: one row per rated segment with the rating and inspection date
# (geometry as WKT).
# Columns: OFTCode, BoroughName, OnStreetName, FromStreetName, ToStreetName, IsMultiPass,
# Direction, Road_Type, SystemRating, NonRatingReason, InspectionTime,
# LocationGeometry.STLength, geometry (profiles/pavement_ratings.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_pavement_ratings(500)

sim_pavement_ratings <- function(n = 1000, seed = NULL) sim_profile("pavement_ratings", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_pavement_ratings(10, seed = 1)))
}
