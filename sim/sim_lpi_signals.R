# Simulated lpi signals
#
# Real data: raw/street_layout/signals/VZV_Leading_Pedestrian_Interval_Signals_20261014.csv, read with
# data.table::fread(nyc_latest('lpi_signals')); 6,803 rows, returned as a data.table with POINT
# geometry as WKT text in the_geom.
# Leading pedestrian interval signals: one point per intersection with the install date (WKT
# column the_geom).
# Columns: MainStreet, CrossStree, Install_Da, LONG, LAT, X, Y (profiles/lpi_signals.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_lpi_signals(500)

sim_lpi_signals <- function(n = 1000, seed = NULL) sim_profile("lpi_signals", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_lpi_signals(10, seed = 1)))
}
