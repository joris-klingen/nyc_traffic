# Simulated street network changes
#
# Real data: street_layout/traffic_rules/Street_Network_Changes_Historical_20261014.csv, read with
# data.table::fread(nyc_latest('street_network_changes')); 281 rows, returned as a data.table.
# Historical street network changes: renamed, opened and closed streets with their dates.
# Columns: On Street, From St, To Street, Completion Date, Type of Change, New Direction, Boro,
# Notes (profiles/street_network_changes.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_street_network_changes(500)

sim_street_network_changes <- function(n = 1000, seed = NULL) sim_profile("street_network_changes", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_street_network_changes(10, seed = 1)))
}
