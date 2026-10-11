# Access helpers for the shared NYC data store
#
# source("../nyc_data/R/nyc_data.R")             # path relative to the project root
# ds <- tlc_open("fhvhv", years = 2019:2020)      # lazy arrow dataset
# f  <- nyc_latest("crashes")                     # newest crash snapshot
#
# TLC column names differ between types (e.g. tpep_/lpep_ prefixes, trip_distance
# vs trip_miles) and across years within a type; harmonize after selecting.

# locate this file among (possibly nested) source() calls to find config.R next to it
local({
  ofiles <- unlist(lapply(sys.frames(), function(f) if (is.character(f$ofile)) f$ofile))
  this <- tail(ofiles[grepl("nyc_data\\.R$", ofiles)], 1)
  source(file.path(if (length(this)) dirname(this) else "R", "config.R"), local = FALSE)
})

# TLC trips ----
tlc_files <- function(type, years = NULL) {
  f <- list.files(file.path(tlc_data_dir(), "raw", type),
                  pattern = paste0("^", type, "_tripdata_\\d{4}-\\d{2}\\.parquet$"),
                  full.names = TRUE)
  if (!is.null(years)) f <- f[as.integer(substr(basename(f), nchar(type) + 11, nchar(type) + 14)) %in% years]
  f
}

tlc_open <- function(type, years = NULL) {
  f <- tlc_files(type, years)
  if (length(f) == 0) stop("no files for ", type, " in ", tlc_data_dir())
  # unify_schemas: column types drift across years (e.g. int vs double)
  arrow::open_dataset(f, unify_schemas = TRUE)
}

# Dated snapshots (crashes, bike routes, LION) ----
nyc_snapshots <- list(
  crashes     = c("crashes/raw",         "^Motor_Vehicle_Collisions_-_Crashes_(\\d{8})\\.csv$"),
  persons     = c("crashes/raw",         "^Motor_Vehicle_Collisions_-_Person_(\\d{8})\\.csv$"),
  bike_routes = c("streets/bike_routes", "^New York City Bike Routes_(\\d{8})\\.geojson$"),
  lion        = c("streets/lion",        "^nyclion_(\\d{8})\\.zip$"),
  address_points = c("streets/address_points", "^AddressPoint_(\\d{8})\\.csv$"),
  traffic_counts   = c("traffic_counts/automated", "^Automated_Traffic_Volume_Counts_(\\d{8})\\.csv$"),
  bike_ped_counts  = c("traffic_counts/bicycle",   "^Bicycle_and_Pedestrian_Counts_(\\d{8})\\.csv$"),
  bike_ped_sensors = c("traffic_counts/bicycle",   "^Bicycle_and_Pedestrian_Count_Sensors_(\\d{8})\\.csv$")
)

# all snapshots of a dataset, oldest first, named by snapshot date
nyc_snapshot_files <- function(name) {
  s <- nyc_snapshots[[name]]
  f <- list.files(file.path(nyc_data_root(), s[1]), pattern = s[2])
  d <- sub(s[2], "\\1", f)
  setNames(file.path(nyc_data_root(), s[1], f), d)[order(d)]
}

# newest snapshot, or the newest one on or before `as_of` (YYYYMMDD), for reproducibility
nyc_latest <- function(name, as_of = NULL) {
  f <- nyc_snapshot_files(name)
  if (!is.null(as_of)) f <- f[names(f) <= as_of]
  if (length(f) == 0) stop("no snapshot of ", name, " in ", nyc_data_root())
  unname(f[length(f)])
}

# Crashes ----
# Read a crash snapshot with harmonized columns: snake_case names, squished text, numeric
# coordinates (some 2026 snapshots write "40,717175" and pad text fields), 0/0 coordinates as
# NA, crash_date as IDate. `select` takes the original column names.
crashes_read <- function(file = nyc_latest("crashes"), select = NULL) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  chr <- intersect(c("LATITUDE", "LONGITUDE", "ZIP CODE"), if (is.null(select)) c("LATITUDE", "LONGITUDE", "ZIP CODE") else select)
  cr <- data.table::fread(file, select = select, colClasses = list(character = chr), na.strings = "")
  data.table::setnames(cr, gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(names(cr)))))
  for (v in names(cr)[vapply(cr, is.character, logical(1))])
    data.table::set(cr, j = v, value = gsub(" {2,}", " ", trimws(cr[[v]])))
  for (v in intersect(c("latitude", "longitude"), names(cr)))
    data.table::set(cr, j = v, value = as.numeric(sub(",", ".", cr[[v]], fixed = TRUE)))
  if (all(c("latitude", "longitude") %in% names(cr)))
    cr[latitude == 0 | longitude == 0, `:=`(latitude = NA_real_, longitude = NA_real_)]
  if ("crash_date" %in% names(cr)) cr[, crash_date := data.table::as.IDate(crash_date, format = "%m/%d/%Y")]
  cr[]
}

# Address points ----
borough_codes <- c("1" = "MANHATTAN", "2" = "BRONX", "3" = "BROOKLYN", "4" = "QUEENS", "5" = "STATEN ISLAND")

# Canonical street name, applied to both crash addresses and address points
# ("WEST 86 STREET", "W 86TH ST" and "W  86 ST" all become "W 86 ST")
nyc_street_norm <- function(x) {
  abbr <- c(STREET = "ST", AVENUE = "AVE", AV = "AVE", BOULEVARD = "BLVD", ROAD = "RD", PLACE = "PL",
            DRIVE = "DR", PARKWAY = "PKWY", EXPRESSWAY = "EXPY", EXPWY = "EXPY", LANE = "LN", COURT = "CT",
            TERRACE = "TER", TERR = "TER", SQUARE = "SQ", HIGHWAY = "HWY", TURNPIKE = "TPKE", CONCOURSE = "CONC",
            PLAZA = "PLZ", CRESCENT = "CRES", SAINT = "ST", FORT = "FT", MOUNT = "MT", BEACH = "BCH",
            WEST = "W", EAST = "E", NORTH = "N", SOUTH = "S")
  x <- gsub("[^A-Z0-9 ]", " ", toupper(x))
  x <- gsub("\\b([0-9]+)(ST|ND|RD|TH)\\b", "\\1", x, perl = TRUE)
  w <- strsplit(trimws(gsub(" +", " ", x)), " ", fixed = TRUE)
  vapply(w, function(t) { i <- t %in% names(abbr); t[i] <- abbr[t[i]]; paste(t, collapse = " ") }, character(1))
}

# Matching key: canonical name without spaces, so "MC DONALD AVE" meets "MCDONALD AVE"
nyc_street_key <- function(x) gsub(" ", "", nyc_street_norm(x), fixed = TRUE)

# House number as a number; Queens hyphenated numbers "137-70" become 137070, letter suffixes dropped
nyc_house_num <- function(x) {
  x <- sub("^([0-9]+(-[0-9]+)?).*", "\\1", trimws(x))
  pre <- suppressWarnings(as.numeric(sub("-.*", "", x)))
  suf <- suppressWarnings(as.numeric(ifelse(grepl("-", x), sub(".*-", "", x), NA)))
  ifelse(is.na(suf), pre, pre * 1000 + suf)
}

# DCP/OTI address points: one point per building address, with hn_lo..hn_hi for range addresses.
# b5sc is the borough + 5-digit street code, shared by all names of a street (8 AVE and
# FREDERICK DOUGLASS BLVD are both 110810)
address_points_read <- function(file = nyc_latest("address_points")) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  ap <- data.table::fread(file, select = c("the_geom", "House Number", "House Number Range", "Borough Code",
                                           "Full Street Name", "B7SC_ACTUAL"),
                          colClasses = "character", na.strings = "")
  data.table::setnames(ap, c("geom", "hn", "hn_range", "boro_code", "street", "b7sc"))
  ap[, `:=`(longitude = as.numeric(sub("POINT \\(([-0-9.]+) .*", "\\1", geom)),
            latitude  = as.numeric(sub("POINT \\([-0-9.]+ ([-0-9.]+)\\)", "\\1", geom)),
            borough   = unname(borough_codes[boro_code]),
            b5sc      = substr(b7sc, 1, 6),
            hn_lo     = nyc_house_num(hn))]
  ap[, hn_hi := data.table::fifelse(is.na(hn_range), hn_lo, pmax(hn_lo, nyc_house_num(hn_range), na.rm = TRUE))]
  ap <- ap[!is.na(hn_lo) & !is.na(longitude) & !is.na(b5sc)]
  ap[, parity := hn_lo %% 2]
  ap[, .(borough, b5sc, street, hn_lo, hn_hi, parity, longitude, latitude)]
}

# Street name -> street code dictionary (borough, key, b5sc) from the address point names, LION
# street names and LION alternate names, so a crash on "WEST 110 STREET" finds the address
# points filed under CATHEDRAL PKWY. Without sf or a LION snapshot only address point names are used.
nyc_street_codes <- function(ap = address_points_read(), lion_file = tryCatch(nyc_latest("lion"), error = function(e) NULL)) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  d <- list(unique(ap[, .(borough, street, b5sc)]))
  if (!is.null(lion_file) && requireNamespace("sf", quietly = TRUE)) {
    gdb <- paste0("/vsizip/", lion_file, "/lion/lion.gdb")
    tab <- function(...) { x <- sf::st_read(gdb, quiet = TRUE, ...); data.table::as.data.table(if (inherits(x, "sf")) sf::st_drop_geometry(x) else x) }
    ln <- unique(tab(query = "SELECT Street, LBoro, StreetCode, Join_ID FROM lion"))
    ln <- ln[grepl("^[1-5][0-9]{5}$", StreetCode)]
    ln[, borough := unname(borough_codes[as.character(LBoro)])]
    d <- c(d, list(unique(ln[, .(borough, street = Street, b5sc = StreetCode)])))
    # alternate names (renamed streets: STONE AVE is MOTHER GASTON BLVD). Join_ID groups segments
    # of several streets, so an alternate name is only used when it is not the name of another
    # street in the borough and its segments all belong to one street.
    al <- unique(tab(layer = "altnames")[, .(Street, Join_ID)])
    al <- unique(ln[, .(Join_ID, borough, b5sc = StreetCode)])[al, on = "Join_ID", nomatch = 0L]
    al[, key := nyc_street_key(Street)]
    al <- unique(al[, .(borough, key, b5sc)])
  }
  d <- unique(data.table::rbindlist(d, use.names = TRUE))
  d[, key := nyc_street_key(street)]
  d <- unique(d[, .(borough, key, b5sc)])
  if (exists("al", inherits = FALSE)) {
    al <- al[!d, on = .(borough, key)]
    al <- al[, if (data.table::uniqueN(b5sc) == 1L) .SD, .(borough, key)]
    d <- rbind(d, al)
  }
  d
}

# LION street centerlines (generic and both-roadbed layers, not the separate roadbeds of divided
# streets) with their street code, in NY State Plane feet (EPSG 2263)
nyc_street_lines <- function(lion_file = nyc_latest("lion")) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  # type = 5 linearizes the curved segments, which GEOS cannot handle
  ln <- sf::st_read(paste0("/vsizip/", lion_file, "/lion/lion.gdb"), quiet = TRUE, type = 5, query =
    "SELECT StreetCode FROM lion WHERE FeatureTyp IN ('0','6','A','C') AND RB_Layer IN ('G','B')")
  ln <- sf::st_zm(ln[grepl("^[1-5][0-9]{5}$", ln[["StreetCode"]]), ])
  names(ln)[names(ln) == "StreetCode"] <- "b5sc"
  ln
}

# Orthogonal projection of points onto the nearest centerline of their own street (b5sc).
# Returns longitude/latitude of the snapped points and snap_ft; NA where the street has no line.
nyc_snap_to_street <- function(lon, lat, b5sc, lines = nyc_street_lines()) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  pts <- sf::st_transform(sf::st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326), 2263)
  xy <- matrix(NA_real_, length(lon), 2)
  by_street <- split(seq_along(lon), b5sc)
  by_street <- by_street[names(by_street) %in% lines[["b5sc"]]]
  line_idx <- split(seq_len(nrow(lines)), lines[["b5sc"]])
  for (s in names(by_street)) {
    i <- by_street[[s]]
    l <- sf::st_geometry(lines)[line_idx[[s]]]
    p <- sf::st_geometry(pts)[i]
    np <- sf::st_nearest_points(p, l[sf::st_nearest_feature(p, l)], pairwise = TRUE)
    # each connector runs from the point to its foot on the line
    xy[i, ] <- sf::st_coordinates(np)[c(FALSE, TRUE), 1:2, drop = FALSE]
  }
  snap_ft <- sqrt(rowSums((xy - sf::st_coordinates(pts))^2))
  ok <- !is.na(xy[, 1])
  ll <- matrix(NA_real_, length(lon), 2)
  if (any(ok)) ll[ok, ] <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(data.frame(x = xy[ok, 1], y = xy[ok, 2]), coords = c("x", "y"), crs = 2263), 4326))
  list(longitude = ll[, 1], latitude = ll[, 2], snap_ft = snap_ft)
}

# LION intersection nodes with the street codes of the segments that meet there, and node
# coordinates (longitude, latitude)
nyc_street_nodes <- function(lion_file = nyc_latest("lion")) {
  stopifnot(requireNamespace("sf", quietly = TRUE), requireNamespace("data.table", quietly = TRUE))
  gdb <- paste0("/vsizip/", lion_file, "/lion/lion.gdb")
  seg <- data.table::as.data.table(sf::st_drop_geometry(sf::st_read(gdb, quiet = TRUE, query =
    "SELECT NodeIDFrom, NodeIDTo, LBoro, StreetCode FROM lion WHERE FeatureTyp IN ('0','6','A','C')")))
  seg <- seg[grepl("^[1-5][0-9]{5}$", StreetCode)]
  ns <- unique(data.table::rbindlist(list(seg[, .(node = as.integer(NodeIDFrom), b5sc = StreetCode)],
                                          seg[, .(node = as.integer(NodeIDTo), b5sc = StreetCode)])))
  nd <- sf::st_transform(sf::st_read(gdb, layer = "node", quiet = TRUE), 4326)
  xy <- sf::st_coordinates(nd)
  nd <- data.table::data.table(node = nd[["NODEID"]], longitude = xy[, 1], latitude = xy[, 2])
  nd[ns, on = "node", nomatch = 0L]
}

# Coordinates for intersection crashes (on_street_name and cross_street_name, no address) from the
# LION node where both streets meet. Streets are matched by street code, as in crashes_relocate().
# All candidate nodes must lie within `max_spread_ft` of each other (divided roads have several
# nodes per intersection); the node nearest their centroid is used. Otherwise the crash is left
# out: the two names meet at more than one place (often a crash without a borough).
# Returns collision_id, longitude, latitude, n_nodes.
crashes_intersection_nodes <- function(cr, streets = nyc_street_codes(), nodes = nyc_street_nodes(), max_spread_ft = 500) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  a <- cr[is.na(off_street_name) & !is.na(on_street_name) & !is.na(cross_street_name),
          .(collision_id, borough, k1 = nyc_street_key(on_street_name), k2 = nyc_street_key(cross_street_name))]
  codes <- function(k) {
    x <- streets[a, on = c(key = k), nomatch = 0L, allow.cartesian = TRUE, .(collision_id, cb = i.borough, sb = x.borough, b5sc)]
    unique(x[is.na(cb) | cb == sb, .(collision_id, b5sc)])
  }
  n1 <- unique(nodes[codes("k1"), on = "b5sc", nomatch = 0L, allow.cartesian = TRUE, .(collision_id, node, longitude, latitude)])
  n2 <- unique(nodes[codes("k2"), on = "b5sc", nomatch = 0L, allow.cartesian = TRUE, .(collision_id, node)])
  cand <- unique(n1[n2, on = .(collision_id, node), nomatch = 0L])
  cand[, `:=`(cx = mean(longitude), cy = mean(latitude)), collision_id]
  cand[, d_ft := sqrt(((longitude - cx) * 276500)^2 + ((latitude - cy) * 364000)^2)]
  ok <- cand[, .(spread = 2 * max(d_ft)), collision_id][spread <= max_spread_ft, collision_id]
  cand <- cand[collision_id %in% ok]
  data.table::setorder(cand, collision_id, d_ft)
  cand[, .(longitude = longitude[1], latitude = latitude[1], n_nodes = .N), collision_id]
}

# Relocate crashes geocoded from a house number (off_street_name) to the address point of that
# building. LION interpolation pulls these toward the low-number end of blocks with padded
# address ranges; address points are the building itself. Takes crashes_read() output and adds
#   longitude_ap, latitude_ap  relocated coordinates (original ones for all other crashes)
#   loc_method                 "address point", "nearest address point" (same street and side,
#                              house number within `max_hn_gap`), "intersection node", or "original"
#   snap_ft                    distance from the building to its street centerline
#   moved_ft                   distance between original and relocated point
# With snap = TRUE (default) the building point is projected orthogonally onto the nearest LION
# centerline of the same street, so crashes sit on the street beside the building. Buildings on
# a street without a centerline, or farther than `max_snap_ft` from it (large complexes, streets
# whose LION line lies elsewhere), keep the address point (snap_ft NA).
# Without a borough, the borough of the candidate closest to the original point is used. When
# the crash has an original point, candidates beyond `max_move_ft` are discarded: the original
# geocode is on the right street, so a far candidate means the name matched a different street
# (two "37 AVE" in Queens, an alternate name shared by several streets).
# With fill_intersections = TRUE (default) intersection crashes without coordinates get the LION
# node where the two streets meet (crashes_intersection_nodes()). Tested on crashes that have
# coordinates: with a borough the node is within 150 ft for 99%, without one for 83%.
crashes_relocate <- function(cr, ap = address_points_read(), streets = nyc_street_codes(ap),
                             max_hn_gap = 10, max_move_ft = 1000,
                             snap = TRUE, max_snap_ft = 500, lines = if (snap) nyc_street_lines() else NULL,
                             fill_intersections = TRUE, nodes = if (fill_intersections) nyc_street_nodes() else NULL) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  a <- cr[!is.na(off_street_name) & grepl("^[0-9]", off_street_name),
          .(collision_id, borough, lon0 = longitude, lat0 = latitude,
            hn = nyc_house_num(sub(" .*", "", off_street_name)), key = nyc_street_key(sub("^[^ ]+ ", "", off_street_name)))]
  a <- a[!is.na(hn)]
  a[, `:=`(parity = hn %% 2, hn_from = hn - max_hn_gap, hn_to = hn + max_hn_gap)]

  # street codes the name can refer to (in the crash's borough when it has one)
  sc <- streets[a, on = "key", nomatch = 0L, allow.cartesian = TRUE,
                .(collision_id, crash_boro = i.borough, ap_boro = x.borough, b5sc, lon0, lat0, hn, parity, hn_from, hn_to)]
  sc <- unique(sc[is.na(crash_boro) | crash_boro == ap_boro])

  # address points on those streets and the same side within the house number window
  cand <- ap[sc, on = .(b5sc, parity, hn_hi >= hn_from, hn_lo <= hn_to), nomatch = 0L, allow.cartesian = TRUE,
             .(collision_id, crash_boro, ap_boro, b5sc, lon0, lat0, hn = i.hn, hn_lo = x.hn_lo, hn_hi = x.hn_hi,
               longitude = x.longitude, latitude = x.latitude)]
  cand[, gap := pmax(hn_lo - hn, hn - hn_hi, 0)]
  # feet, equirectangular at NYC's latitude
  cand[, moved_ft := sqrt(((longitude - lon0) * 276500)^2 + ((latitude - lat0) * 364000)^2)]
  cand <- cand[is.na(moved_ft) | moved_ft <= max_move_ft]
  cand[is.na(crash_boro) & !is.na(moved_ft), crash_boro := ap_boro[which.min(moved_ft)], collision_id]
  # no borough and no original point: only accept when all candidates are in one borough
  amb <- cand[is.na(crash_boro), .(n = data.table::uniqueN(ap_boro)), collision_id][n > 1, collision_id]
  cand <- cand[(is.na(crash_boro) | crash_boro == ap_boro) & !collision_id %in% amb]
  data.table::setorder(cand, collision_id, gap, moved_ft, na.last = TRUE)
  best <- cand[, .SD[1], collision_id]

  best[, snap_ft := NA_real_]
  if (snap && nrow(best)) {
    s <- nyc_snap_to_street(best[, longitude], best[, latitude], best[, b5sc], lines)
    ok <- !is.na(s$longitude) & s$snap_ft <= max_snap_ft
    best[ok, `:=`(longitude = s$longitude[ok], latitude = s$latitude[ok], snap_ft = s$snap_ft[ok])]
    best[, moved_ft := sqrt(((longitude - lon0) * 276500)^2 + ((latitude - lat0) * 364000)^2)]
  }

  out <- data.table::copy(cr)
  out[, `:=`(longitude_ap = longitude, latitude_ap = latitude, loc_method = "original", snap_ft = NA_real_, moved_ft = NA_real_)]
  out[best, on = "collision_id", `:=`(longitude_ap = i.longitude, latitude_ap = i.latitude, snap_ft = i.snap_ft, moved_ft = i.moved_ft,
                                      loc_method = data.table::fifelse(i.gap == 0, "address point", "nearest address point"))]
  if (fill_intersections) {
    g <- crashes_intersection_nodes(out[is.na(longitude)], streets, nodes)
    out[g, on = "collision_id", `:=`(longitude_ap = i.longitude, latitude_ap = i.latitude, loc_method = "intersection node")]
  }
  out[]
}

# Citi Bike ----
citibike_files <- function() {
  list.files(file.path(nyc_data_root(), "citibike", "raw"),
             pattern = "citibike-tripdata\\.zip$", full.names = TRUE)
}
