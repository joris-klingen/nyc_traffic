# Simulated 2020 census block groups and their population
#
# Real data: raw/boundaries/census_block_groups_2020/tl_2020_36_bg.shp (TIGER/Line 2020, New York
# State, 16,070 block groups), read with census_block_groups_read(): sf in EPSG 4269 with STATEFP,
# COUNTYFP, TRACTCE, BLKGRPCE, GEOID (12 digits: state, county, tract, block group), NAMELSAD,
# MTFCC, FUNCSTAT, ALAND, AWATER, INTPTLAT, INTPTLON. NYC are COUNTYFP 005 (Bronx), 047
# (Brooklyn), 061 (Manhattan), 081 (Queens), 085 (Staten Island).
# Population: raw/boundaries/census_block_groups_2020/nyc_bg_population_2020_YYYYMMDD.json, read with
# jsonlite::fromJSON(nyc_latest("bg_population")): a text matrix whose first row holds the names
# P1_001N (population), state, county, tract, block group (6,807 NYC block groups).
#
# Kept: GEOID built from its parts and unique; squares of the profiled areas where block groups
# are; sim_bg_population() gives the population of the simulated NYC block groups in the JSON
# layout (first row = names). Not kept: shapes, adjacency, tracts nesting in space.
#
# bg <- sim_census_block_groups(500); pop <- sim_bg_population(bg)

sim_census_block_groups <- function(n = 1000, seed = NULL) {
  x <- sim_profile("census_block_groups", n, seed)
  x[["STATEFP"]] <- "36"
  x[["TRACTCE"]] <- sprintf("%06d", sample(100:999999, nrow(x)))
  x[["BLKGRPCE"]] <- as.character(sample(1:6, nrow(x), replace = TRUE))
  x[["GEOID"]] <- paste0(x[["STATEFP"]], x[["COUNTYFP"]], x[["TRACTCE"]], x[["BLKGRPCE"]])
  x[["NAMELSAD"]] <- paste("Block Group", x[["BLKGRPCE"]])
  x
}

sim_bg_population <- function(block_groups = sim_census_block_groups(), seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  bg <- data.table::as.data.table(sf::st_drop_geometry(block_groups))[COUNTYFP %in% c("005", "047", "061", "081", "085")]
  p <- sim_profile("bg_population", nrow(bg))
  rbind(c("P1_001N", "state", "county", "tract", "block group"),
        cbind(p[, P1_001N], bg[, STATEFP], bg[, COUNTYFP], bg[, TRACTCE], bg[, BLKGRPCE]))
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  bg <- sim_census_block_groups(200, seed = 1)
  print(head(bg[, c("GEOID", "COUNTYFP", "ALAND")]))
  print(head(sim_bg_population(bg)))
}
