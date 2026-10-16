# Simulated DOT bike routes
#
# Real data: streets/bike_routes/New York City Bike Routes_YYYYMMDD.geojson (29,682 rows in 2026),
# read with bike_routes_read(): sf in EPSG 2263, one row per bike route segment version since the
# 2025 release (status Current or Retired, ret_date, bikeid, prevbikeid): segmentid (LION
# SegmentID, integer), street, fromstreet, tostreet, boro, facilitycl (I protected, II
# conventional, III shared, L link), allclasses, tf_facilit / ft_facilit (Protected,
# Conventional, Shared, Curbside, Sidewalk, ...; NA = none that way), tf2facilit, ft2facilit,
# bikedir (2 two-way, R / L one way), lanecount, onoffst, instdate, greenway columns (grnwy,
# gwsystem, gwyjuris, gwsys2), spur. Archived releases (2017-2020) have other columns.
#
# lion = NULL: rows drawn from the profile, lines placed where bike routes are.
# lion = sim_lion(): bike routes on that network: the segments with a LION bike lane code, with
# their SegmentID, street and geometry, facility class and direction from the profile shares,
# one-way facilities on one-way streets; instdate from the profile. Not kept: from / to streets
# that match the network, version chains of Retired rows.
#
# br <- sim_bike_routes(lion = sim_lion())

sim_bike_routes <- function(n = 500, lion = NULL, seed = NULL) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  if (!is.null(seed)) set.seed(seed)
  if (is.null(lion)) {
    x <- sim_profile("bike_routes", n)
    x[["segmentid"]] <- sort(sample.int(330000L, nrow(x)))
    return(x)
  }
  l <- lion[trimws(lion[["BikeLane"]]) != "", ]
  x <- sim_profile("bike_routes", nrow(l))
  x <- data.table::as.data.table(sf::st_drop_geometry(x))
  ld <- data.table::as.data.table(sf::st_drop_geometry(l))
  x[, `:=`(segmentid = ld[, SegmentID], street = ld[, Street], boro = "Manhattan", status = "Current", ret_date = as.POSIXct(NA),
           prevbikeid = NA_character_, bikeid = sprintf("%d", 700000L + seq_len(.N)))]
  cls <- sample(c("I", "II", "III"), nrow(x), replace = TRUE, prob = c(0.35, 0.42, 0.23))
  fac <- c(I = "Protected", II = "Conventional", III = "Shared")[cls]
  oneway <- ld[, TrafDir != "T"]
  x[, `:=`(facilitycl = cls, allclasses = cls, tf_facilit = fac, ft_facilit = fifelse(oneway, NA_character_, fac),
           bikedir = fifelse(oneway, "R", "2"), lanecount = fifelse(oneway, "1", "2"), onoffst = "ON")]
  sf::st_sf(x, geometry = sf::st_geometry(l))
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  br <- sim_bike_routes(lion = sim_lion(seed = 1), seed = 1)
  print(br[, c("segmentid", "street", "facilitycl", "tf_facilit", "ft_facilit", "bikedir")])
}
