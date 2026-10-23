# Simulated open streets
#
# Real data: raw/street_layout/public_space/Open_Streets_Locations_20261014.geojson, read with
# sf::st_read(nyc_latest('open_streets')); 391 rows, returned as sf with MULTILINESTRING
# geometry (EPSG 4326).
# Open Streets: streets closed to through traffic on given days and hours, one line per segment
# with the program type and schedule.
# Columns: apprmonclo, segmentidf, apprsatope, apprsunope, shape_stle, boroughname, apprthuclo,
# apprdayswe, apprenddat, apprmonope, apprwedclo, apprtueclo, segmentidt, apprfromst,
# apprsatclo, reviewstat, apprwedope, orgname, lionversion, appronstre, apprstartd, apprtostre,
# apprsunclo, apprthuope, apprfriope, apprfriclo, object_id, apprtueope
# (profiles/open_streets.csv).
#
# Kept: column types, NA shares and value shares; geometry of the profiled sizes placed where
# the features are (lines as straight segments, polygons as squares). Not kept: relations
# between columns (streets that match the location, dates in order).
#
# x <- sim_open_streets(500)

sim_open_streets <- function(n = 1000, seed = NULL) sim_profile("open_streets", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_open_streets(10, seed = 1)))
}
