# Simulated administrative boundaries
#
# Real data: raw/boundaries/*_YYYYMMDD.geojson, read with boundaries_read(name) as sf in EPSG 2263:
#   boroughs             5 polygons: borocode, boroname, ...
#   community_districts  71: borocd (borough digit + district number), ...
#   ntas                 262 Neighborhood Tabulation Areas 2020: nta2020, ntaname, boroname, ...
#   tracts               2,325 census tracts 2020: geoid, boroct2020, ctlabel, ...
#   blocks               37,588 census blocks 2020: geoid, bctcb2020, ...
#   precincts            78 police precincts: precinct, ...
# census_tract_2020_to_nta_cdta (tract_nta) is a lookup table: sim_tract_nta().
#
# Kept: the attribute columns and their value shares, one square per unit with the profiled
# areas, placed where the units are. Not kept: shapes, adjacency, nesting (tracts in NTAs in
# boroughs), ids that match the attributes.
#
# nta <- sim_boundaries("ntas")

sim_boundaries <- function(name = c("boroughs", "community_districts", "ntas", "tracts", "blocks", "precincts"), n = NULL, seed = NULL) {
  name <- match.arg(name)
  src <- paste0("boundaries_", name)
  if (is.null(n)) n <- as.integer(profile_read(src)$meta[, rows_total])
  sim_profile(src, n, seed)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(sim_boundaries("boroughs", seed = 1))
}
