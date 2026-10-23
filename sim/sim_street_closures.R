# Simulated street closures
#
# Real data:
# street_layout/closures/Street_Closures_due_to_construction_activities_by_Block_20261014.csv, read
# with data.table::fread(nyc_latest('street_closures')); 3,895 rows, returned as a data.table.
# Street closures for construction, by block: on / from / to street, start and end dates and
# purpose.
# Columns: SEGMENTID, OFT, ONSTREETNAME, FROMSTREETNAME, TOSTREETNAME, BOROUGH_CODE,
# WORK_START_DATE, WORK_END_DATE, UNIQUEID, PURPOSE, geometry (profiles/street_closures.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_street_closures(500)

sim_street_closures <- function(n = 1000, seed = NULL) sim_profile("street_closures", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_street_closures(10, seed = 1)))
}
