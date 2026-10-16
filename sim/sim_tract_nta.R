# Simulated tract nta
#
# Real data: boundaries/census_tract_2020_to_nta_cdta_20261011.csv, read with
# data.table::fread(nyc_latest('tract_nta')); 2,327 rows, returned as a data.table.
# Census tract 2020 to NTA and CDTA equivalency: one row per tract with its NTA and community
# district tabulation area codes and names.
# Columns: GEOID, CountyFIPS, BoroCode, BoroName, BoroCT2020, CT2020, CTLabel, NTACode,
# NTAType, NTAName, NTAAbbrev, CDTACode, CDTAType, CDTAName (profiles/tract_nta.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_tract_nta(500)

sim_tract_nta <- function(n = 1000, seed = NULL) sim_profile("tract_nta", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_tract_nta(10, seed = 1)))
}
