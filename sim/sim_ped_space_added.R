# Simulated ped space added
#
# Real data: streets/public_space/Pedestrian_Space_Added_20261014.csv, read with
# data.table::fread(nyc_latest('ped_space_added')); 757 rows, returned as a data.table.
# Pedestrian space added by DOT per year (a short table).
# Columns: Project Title, City FY, Total Former Roadbed Space (profiles/ped_space_added.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_ped_space_added(500)

sim_ped_space_added <- function(n = 1000, seed = NULL) sim_profile("ped_space_added", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_ped_space_added(10, seed = 1)))
}
