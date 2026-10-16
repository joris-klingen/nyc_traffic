# Data profiles and simulated data
#
# A profile describes a table column by column, so that code can be developed against simulated
# data with the same names, types and rough distributions, without access to the data store (for
# example in a cloud session). Profiles sit in profiles/ (one <source>.csv with a row per column,
# <source>_values.csv with the most common values and their shares, and index.csv with one row per
# source); profiles/build_profiles.R makes them from the real data. sim/sim_<source>.R wraps
# sim_profile() per source with a description and the rules that tie columns together.
#
# source("R/simulate.R")
# dt <- sim_profile("crashes", n = 5000)
#
# Only data.table is needed to simulate; sf for spatial sources. Each column is drawn on its own
# (from its quantiles or its value shares), so relations between columns are lost unless a
# sim_<source>() restores them. Coordinates are the exception: lon/lat or x/y pairs are drawn
# together from a grid of cells (.cell rows in the profile), so points fall where the data is.

sim_probs <- c(0, 0.001, 0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99, 0.999, 1)
sim_qnames <- c("min", "q001", "q01", "q05", "q10", "q25", "median", "q75", "q90", "q95", "q99", "q999", "max")

# profiles/ next to R/, found from the location of this file (works from any working directory)
sim_profiles_dir <- local({
  ofiles <- unlist(lapply(sys.frames(), function(f) if (is.character(f$ofile)) f$ofile))
  this <- tail(ofiles[grepl("simulate\\.R$", ofiles)], 1)
  d <- normalizePath(file.path(if (length(this)) dirname(dirname(this)) else ".", "profiles"),
                     winslash = "/", mustWork = FALSE)
  function() d
})

# Profiling ----

# kind of a column: what the simulator has to produce
sim_kind <- function(x) {
  if (inherits(x, "POSIXct")) return("POSIXct")
  if (inherits(x, "Date")) return("Date")
  if (inherits(x, "ITime")) return("ITime")
  if (inherits(x, "integer64")) return("numeric")
  if (inherits(x, "difftime")) return("numeric")
  if (is.logical(x)) return("logical")
  if (is.integer(x)) return("integer")
  if (is.numeric(x)) return("numeric")
  if (is.factor(x) || is.character(x)) return("character")
  "other"
}

# shape of a character id, so that simulated ids look alike
sim_id_pattern <- function(x) {
  x <- x[!is.na(x)][seq_len(min(1000, sum(!is.na(x))))]
  if (!length(x)) return(NA_character_)
  if (all(grepl("^[0-9]+$", x))) return("digits")
  if (all(grepl("^[0-9A-F]+$", x))) return("HEX")
  if (all(grepl("^[0-9a-f]+$", x))) return("hex")
  "alnum"
}

# One profile row per column, plus the value shares of discrete columns.
#   xy      named pairs of coordinate columns, e.g. list(c("longitude", "latitude")), drawn
#           together in sim_profile() from cells of size `cell` (in the units of the columns)
#   max_values  number of values kept for discrete columns (numeric columns are discrete with at
#           most 25 values, character columns when they repeat: fewer distinct values than half the rows)
# sf input: the geometry is replaced by .geom_x/.geom_y (centroid) and .geom_length or .geom_area
# in the layer's CRS, with .geom_x/.geom_y as an xy pair; the CRS and geometry type go in attr "geom".
#   formats named formats of date/time columns stored as text (see profile_detect_formats()): the
#           column is profiled as a date or time and simulated back as text in that format
#   wkt     a column with WKT geometry (e.g. "the_geom"): profiled as the geometry and simulated
#           back as WKT text
profile_dt <- function(x, xy = NULL, cell = NULL, max_values = 400, formats = NULL, wkt = NULL) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  geom <- NULL
  if (!is.null(wkt)) {
    stopifnot(requireNamespace("sf", quietly = TRUE))
    x <- data.table::as.data.table(x)
    w <- x[[wkt]]
    ok <- !is.na(w) & nzchar(w)
    g <- sf::st_sfc(rep(list(sf::st_point()), length(w)), crs = 4326)
    g[ok] <- sf::st_as_sfc(w[ok], crs = 4326)
    x <- sf::st_sf(x[, setdiff(names(x), wkt), with = FALSE], geometry = g)
  }
  if (length(formats)) {
    x <- data.table::copy(data.table::as.data.table(x))
    for (v in names(formats)) {
      f <- formats[[v]]
      y <- x[[v]]
      data.table::set(x, j = v, value =
        if (!grepl("%[dY]", f)) data.table::as.ITime(y, format = f)
        else if (grepl("%H|%I", f)) as.POSIXct(y, format = f, tz = "America/New_York")
        else as.Date(y, format = f))
    }
  }
  if (inherits(x, "sf")) {
    stopifnot(requireNamespace("sf", quietly = TRUE))
    g <- sf::st_geometry(x)
    type <- names(sort(table(as.character(sf::st_geometry_type(g))), decreasing = TRUE))[1]
    crs <- sf::st_crs(g)$epsg
    ok <- !sf::st_is_empty(g)
    cen <- matrix(NA_real_, length(g), 2)
    cen[ok, ] <- suppressWarnings(sf::st_coordinates(sf::st_centroid(g[ok])))[, 1:2]
    x <- data.table::as.data.table(sf::st_drop_geometry(x))
    data.table::set(x, j = ".geom_x", value = cen[, 1])
    data.table::set(x, j = ".geom_y", value = cen[, 2])
    if (grepl("LINE", type)) data.table::set(x, j = ".geom_length", value = as.numeric(sf::st_length(g)))
    if (grepl("POLYGON", type)) data.table::set(x, j = ".geom_area", value = as.numeric(sf::st_area(g)))
    geom <- list(type = type, crs = crs)
    xy <- c(xy, list(c(".geom_x", ".geom_y")))
    if (is.null(cell)) cell <- if (isTRUE(sf::st_is_longlat(g))) 0.01 else 2000
  }
  x <- data.table::as.data.table(x)
  if (is.null(cell)) cell <- 0.01
  n <- nrow(x)
  rows <- list(); vals <- list()
  for (v in names(x)) {
    y <- x[[v]]
    kind <- sim_kind(y)
    if (kind == "other") {
      rows[[v]] <- data.table::data.table(column = v, kind = "other", class = class(y)[1], n = n)
      next
    }
    if (is.factor(y)) y <- as.character(y)
    nn <- sum(!is.na(y))
    nd <- data.table::uniqueN(y, na.rm = TRUE)
    r <- data.table::data.table(column = v, kind = kind, class = class(y)[1], n = n,
                                na_share = if (n) 1 - nn / n else NA_real_, n_distinct = nd)
    if (kind == "POSIXct") r[, tz := { tz <- attr(y, "tzone"); if (is.null(tz) || tz == "") "UTC" else tz[1] }]
    # text in the source: class is what the reader returns, kind what the text holds
    if (v %in% names(formats)) r[, `:=`(format = formats[[v]], class = "character")]
    discrete <- nd > 0 && (nd <= 25 || (kind == "character" && nd / max(nn, 1) < 0.5))
    if (kind %in% c("integer", "numeric", "Date", "POSIXct", "ITime") && nn > 0) {
      z <- as.numeric(y[!is.na(y)])
      q <- stats::quantile(z, sim_probs, names = FALSE, type = 1)
      fmt <- switch(kind,
        Date = function(t) format(as.Date(t, origin = "1970-01-01")),
        POSIXct = function(t) format(as.POSIXct(t, origin = "1970-01-01", tz = r[, tz]), "%Y-%m-%d %H:%M:%S"),
        ITime = function(t) format(data.table::as.ITime(t)),
        function(t) format(signif(t, 10), scientific = FALSE, trim = TRUE))
      r[, (sim_qnames) := as.list(fmt(q))]
      r[, `:=`(mean = fmt(mean(z)), sd = signif(stats::sd(z), 6),
               whole = all(abs(z - round(z)) < 1e-9))]
    }
    if (kind == "logical" && nn > 0) r[, mean := as.character(signif(mean(y, na.rm = TRUE), 6))]
    if (kind == "character" && nn > 0) {
      nc <- nchar(y[!is.na(y)])
      r[, `:=`(nchar_min = min(nc), nchar_max = max(nc), id_pattern = sim_id_pattern(y),
               example = y[!is.na(y)][1])]
    }
    is_cell <- FALSE
    if (discrete && kind != "logical") {
      t <- data.table::data.table(value = y[!is.na(y)])[, .N, by = value][order(-N)]
      k <- min(nrow(t), max_values)
      t <- t[seq_len(k)]
      vals[[v]] <- data.table::data.table(column = v, rank = seq_len(k), value = as.character(t[, value]),
                                          share = signif(t[, N] / nn, 6))
      r[, `:=`(values_kept = k, values_share = signif(sum(t[, N]) / nn, 6))]
    }
    rows[[v]] <- r
  }
  # coordinate pairs: shares of grid cells
  for (p in xy) {
    if (!all(p %in% names(x))) next
    ok <- !is.na(x[[p[1]]]) & !is.na(x[[p[2]]])
    if (!any(ok)) next
    cx <- floor(x[[p[1]]][ok] / cell); cy <- floor(x[[p[2]]][ok] / cell)
    t <- data.table::data.table(value = paste(cx, cy))[, .N, by = value][order(-N)]
    k <- min(nrow(t), 2000)
    nm <- paste0(".cell:", p[1], ":", p[2])
    rows[[nm]] <- data.table::data.table(column = nm, kind = "cell", class = "cell", n = n,
                                         na_share = 1 - sum(ok) / n, n_distinct = nrow(t),
                                         cell = cell, values_kept = k, values_share = signif(sum(t[1:k, N]) / sum(ok), 6))
    vals[[nm]] <- data.table::data.table(column = nm, rank = seq_len(k), value = t[1:k, value], share = signif(t[1:k, N] / sum(ok), 6))
  }
  prof <- data.table::rbindlist(rows, fill = TRUE)
  out <- list(columns = prof, values = data.table::rbindlist(vals))
  if (!is.null(geom)) geom$wkt <- if (is.null(wkt)) NA_character_ else wkt
  attr(out, "geom") <- geom
  out
}

# Formats of character columns that hold dates or times, from the first 1,000 values: a named
# vector for profile_dt(formats =)
profile_detect_formats <- function(x) {
  pats <- c("%m/%d/%Y %I:%M:%S %p" = "^\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}:\\d{2} [AP]M$",
            "%m/%d/%Y %H:%M:%S" = "^\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}:\\d{2}$",
            "%m/%d/%Y" = "^\\d{2}/\\d{2}/\\d{4}$",
            "%Y-%m-%dT%H:%M:%OS" = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?$",
            "%Y-%m-%d %H:%M:%OS" = "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}(\\.\\d+)?$",
            "%Y/%m/%d %H:%M:%OS" = "^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}(\\+00)?$",
            "%Y-%m-%d" = "^\\d{4}-\\d{2}-\\d{2}$",
            "%H:%M" = "^\\d{1,2}:\\d{2}$")
  out <- character()
  for (v in names(x)) {
    y <- x[[v]]
    if (!is.character(y)) next
    y <- utils::head(y[!is.na(y) & nzchar(y)], 1000)
    if (!length(y)) next
    hit <- names(pats)[vapply(pats, function(p) all(grepl(p, y, perl = TRUE)), logical(1))]
    if (length(hit)) out[v] <- hit[1]
  }
  out
}

# Name of a WKT geometry column (values like "POINT (-73.9 40.7)"), or NULL
profile_detect_wkt <- function(x) {
  for (v in names(x)) {
    y <- x[[v]]
    if (!is.character(y)) next
    y <- utils::head(y[!is.na(y) & nzchar(y)], 200)
    if (length(y) && all(grepl("^(MULTI)?(POINT|LINESTRING|POLYGON) ?\\(", y))) return(v)
  }
  NULL
}

# write a profile to profiles/<source>.csv and <source>_values.csv, and its row in index.csv
profile_write <- function(p, source, meta = list(), dir = sim_profiles_dir()) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  data.table::fwrite(p$columns, file.path(dir, paste0(source, ".csv")))
  data.table::fwrite(if (nrow(p$values)) p$values else data.table::data.table(column = character(), rank = integer(), value = character(), share = numeric()),
                     file.path(dir, paste0(source, "_values.csv")))
  g <- attr(p, "geom")
  row <- data.table::as.data.table(c(list(source = source), meta,
                                     list(columns = sum(!grepl("^\\.", p$columns[, column])),
                                          geometry = if (is.null(g)) NA_character_ else g$type,
                                          crs = if (is.null(g)) NA_integer_ else g$crs,
                                          wkt = if (is.null(g)) NA_character_ else g$wkt,
                                          profiled_on = format(Sys.Date()))))
  f <- file.path(dir, "index.csv")
  idx <- if (file.exists(f)) data.table::fread(f, colClasses = "character") else NULL
  row <- row[, lapply(.SD, as.character)]
  if (!is.null(idx)) idx <- idx[source != row[, source]]
  idx <- data.table::rbindlist(list(idx, row), fill = TRUE)
  data.table::fwrite(idx[order(source)], f)
  invisible(row)
}

# Simulation ----

profile_read <- function(source, dir = sim_profiles_dir()) {
  f <- file.path(dir, paste0(source, ".csv"))
  if (!file.exists(f)) stop("no profile ", f, "; available: ",
                            paste(sub("\\.csv$", "", setdiff(list.files(dir, "\\.csv$"), c("index.csv", list.files(dir, "_values\\.csv$")))), collapse = ", "))
  cols <- data.table::fread(f, colClasses = "character", na.strings = "")
  vf <- file.path(dir, paste0(source, "_values.csv"))
  # the values file never holds NA, and "" is a real value
  vals <- data.table::fread(vf, colClasses = c(column = "character", rank = "integer", value = "character", share = "numeric"),
                            na.strings = NULL)
  idx <- data.table::fread(file.path(dir, "index.csv"), colClasses = "character", na.strings = "")
  src <- source
  list(columns = cols, values = vals, meta = idx[source == src])
}

# synthetic ids shaped like the real ones
sim_ids <- function(n, pattern, nchar_min, nchar_max) {
  len <- if (nchar_min == nchar_max) rep(nchar_min, n) else sample(nchar_min:nchar_max, n, replace = TRUE)
  chars <- switch(pattern, digits = 0:9, HEX = c(0:9, LETTERS[1:6]), hex = c(0:9, letters[1:6]),
                  c(0:9, LETTERS, letters))
  vapply(len, function(l) paste(sample(chars, l, replace = TRUE), collapse = ""), character(1))
}

# draw n values for one profile row
sim_column <- function(r, vals, n) {
  kind <- r[, kind]
  num <- function(s) suppressWarnings(as.numeric(s))
  to_num <- switch(kind,
    Date = function(s) as.numeric(as.Date(s)),
    POSIXct = function(s) as.numeric(as.POSIXct(s, tz = r[, tz])),
    ITime = function(s) as.numeric(data.table::as.ITime(s)),
    num)
  from_num <- switch(kind,
    Date = if (r[, class] == "IDate") function(z) data.table::as.IDate(as.Date(round(z), origin = "1970-01-01"))
           else function(z) as.Date(round(z), origin = "1970-01-01"),
    POSIXct = function(z) as.POSIXct(round(z), origin = "1970-01-01", tz = r[, tz]),
    ITime = function(z) data.table::as.ITime(round(z)),
    integer = function(z) as.integer(round(z)),
    numeric = function(z) if (isTRUE(as.logical(r[, whole]))) round(z) else z,
    function(z) z)
  v <- vals[column == r[, column]]
  if (kind == "logical") {
    out <- stats::runif(n) < num(r[, mean])
  } else if (nrow(v) && kind != "character") {
    out <- from_num(to_num(sample(v[, value], n, replace = TRUE, prob = v[, share])))
  } else if (kind == "character") {
    cover <- if (nrow(v)) sum(v[, share]) else 0
    from_top <- stats::runif(n) < cover
    out <- character(n)
    if (any(from_top)) out[from_top] <- sample(v[, value], sum(from_top), replace = TRUE, prob = v[, share])
    if (any(!from_top)) {
      pat <- r[, id_pattern]
      lo <- as.integer(r[, nchar_min]); hi <- as.integer(r[, nchar_max])
      out[!from_top] <- if (nrow(v) && cover > 0.5) {
        # long tail of a categorical column: generic labels
        sprintf("%s_%04d", r[, column], sample(max(1, as.integer(r[, n_distinct]) - nrow(v)), sum(!from_top), replace = TRUE))
      } else if (!is.na(pat)) sim_ids(sum(!from_top), pat, lo, hi) else NA_character_
    }
  } else if (kind %in% c("integer", "numeric", "Date", "POSIXct", "ITime")) {
    q <- to_num(unlist(r[, sim_qnames, with = FALSE]))
    if (all(is.na(q))) return(from_num(rep(NA_real_, n)))
    u <- stats::runif(n)
    z <- stats::approx(sim_probs, q, xout = u, ties = "ordered")[["y"]]
    # the outer 0.1% on each side: on a log scale when the extreme is far out (data errors such
    # as a 100,000-mile taxi trip), so that few draws land near it
    k <- length(q)
    if (q[k] > 0 && q[k - 1] > 0 && q[k] / q[k - 1] > 10) {
      hi <- u > sim_probs[k - 1]
      t <- (u[hi] - sim_probs[k - 1]) / (1 - sim_probs[k - 1])
      z[hi] <- exp(log(q[k - 1]) + t^3 * (log(q[k]) - log(q[k - 1])))
    }
    if (q[1] < 0 && q[2] < 0 && q[1] / q[2] > 10) {
      lo <- u < sim_probs[2]
      t <- (sim_probs[2] - u[lo]) / sim_probs[2]
      z[lo] <- -exp(log(-q[2]) + t^3 * (log(-q[1]) - log(-q[2])))
    }
    out <- from_num(z)
  } else {
    return(rep(NA, n))
  }
  na <- num(r[, na_share])
  if (!is.na(na) && na > 0) out[stats::runif(n) < na] <- NA
  # dates and times that the source stores as text
  f <- if ("format" %in% names(r)) r[, format] else NA_character_
  if (!is.na(f) && nzchar(f)) {
    out <- if (kind == "ITime") ifelse(is.na(out), NA_character_, sprintf("%d:%02d", as.integer(out) %/% 3600L, as.integer(out) %% 3600L %/% 60L))
           else ifelse(is.na(out), NA_character_, format(out, sub("%OS", "%S", f, fixed = TRUE)))
  }
  out
}

# Simulate n rows of a source from its profile: a data.table with the profiled columns in their
# types, or an sf object for spatial sources (points at the centroids; lines as straight segments
# of the profiled length in a random direction; polygons as squares of the profiled area).
sim_profile <- function(source, n = 1000, seed = NULL, dir = sim_profiles_dir()) {
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  if (!is.null(seed)) set.seed(seed)
  p <- profile_read(source, dir)
  cols <- p$columns
  out <- data.table::data.table(.row = seq_len(n))
  for (i in which(!cols[, kind] %in% c("cell", "other")))
    data.table::set(out, j = cols[i, column], value = sim_column(cols[i], p$values, n))
  out[, .row := NULL]
  # coordinate pairs drawn together: a cell by its share, then a point inside it
  for (i in which(cols[, kind] == "cell")) {
    nm <- strsplit(cols[i, column], ":", fixed = TRUE)[[1]][2:3]
    v <- p$values[column == cols[i, column]]
    size <- as.numeric(cols[i, cell])
    k <- sample(nrow(v), n, replace = TRUE, prob = v[, share])
    cxy <- do.call(rbind, lapply(strsplit(v[k, value], " ", fixed = TRUE), as.numeric))
    miss <- !stats::complete.cases(out[, nm, with = FALSE])
    data.table::set(out, j = nm[1], value = ifelse(miss, NA_real_, (cxy[, 1] + stats::runif(n)) * size))
    data.table::set(out, j = nm[2], value = ifelse(miss, NA_real_, (cxy[, 2] + stats::runif(n)) * size))
  }
  geom <- p$meta[, geometry]
  if (length(geom) && !is.na(geom) && ".geom_x" %in% names(out)) {
    out <- sim_geometry(out, geom, as.integer(p$meta[, crs]))
    wkt <- if ("wkt" %in% names(p$meta)) p$meta[, wkt] else NA_character_
    if (!is.na(wkt) && nzchar(wkt)) {
      w <- sf::st_as_text(sf::st_geometry(out))
      out <- data.table::as.data.table(sf::st_drop_geometry(out))
      data.table::set(out, j = wkt, value = w)
    }
  }
  out
}

# turn .geom_* columns into an sf geometry column
sim_geometry <- function(x, type, crs) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  ok <- !is.na(x[, .geom_x]) & !is.na(x[, .geom_y])
  x <- x[ok]
  cx <- x[, .geom_x]; cy <- x[, .geom_y]
  # lengths and areas are in metres for lon/lat layers: draw them in degrees at NYC's latitude
  ll <- isTRUE(sf::st_is_longlat(sf::st_crs(crs)))
  sx <- if (ll) 1 / 84000 else 1; sy <- if (ll) 1 / 111000 else 1
  if (grepl("POINT", type)) {
    g <- sf::st_geometry(sf::st_as_sf(data.frame(x = cx, y = cy), coords = c("x", "y"), crs = crs))
  } else if (grepl("LINE", type)) {
    len <- if (".geom_length" %in% names(x)) x[, .geom_length] else 300
    len[is.na(len)] <- stats::median(len, na.rm = TRUE)
    a <- stats::runif(nrow(x), 0, pi)
    g <- sf::st_sfc(lapply(seq_len(nrow(x)), function(i) sf::st_linestring(rbind(
      c(cx[i] - cos(a[i]) * len[i] / 2 * sx, cy[i] - sin(a[i]) * len[i] / 2 * sy),
      c(cx[i] + cos(a[i]) * len[i] / 2 * sx, cy[i] + sin(a[i]) * len[i] / 2 * sy)))), crs = crs)
    if (grepl("MULTI", type)) g <- sf::st_cast(g, "MULTILINESTRING")
  } else {
    area <- if (".geom_area" %in% names(x)) x[, .geom_area] else 1e5
    area[is.na(area)] <- stats::median(area, na.rm = TRUE)
    h <- sqrt(pmax(area, 1)) / 2
    hx <- h * sx; hy <- h * sy
    g <- sf::st_sfc(lapply(seq_len(nrow(x)), function(i) sf::st_polygon(list(rbind(
      c(cx[i] - hx[i], cy[i] - hy[i]), c(cx[i] + hx[i], cy[i] - hy[i]), c(cx[i] + hx[i], cy[i] + hy[i]),
      c(cx[i] - hx[i], cy[i] + hy[i]), c(cx[i] - hx[i], cy[i] - hy[i]))))), crs = crs)
    if (grepl("MULTI", type)) g <- sf::st_cast(g, "MULTIPOLYGON")
  }
  x[, intersect(c(".geom_x", ".geom_y", ".geom_length", ".geom_area"), names(x)) := NULL]
  sf::st_sf(x, geometry = g)
}

# Check a simulated table against its profile: same columns, same kinds
sim_check <- function(x, source, dir = sim_profiles_dir()) {
  p <- profile_read(source, dir)$columns[!kind %in% c("cell", "other") & !grepl("^\\.geom", column)]
  if ("format" %in% names(p)) p[!is.na(format) & nzchar(format), kind := "character"]
  if (inherits(x, "sf")) x <- sf::st_drop_geometry(x)
  have <- vapply(names(x), function(v) sim_kind(x[[v]]), character(1))
  miss <- setdiff(p[, column], names(have))
  wrong <- p[column %in% names(have) & kind != have[column], column]
  if (length(miss) || length(wrong)) stop(source, ": missing ", paste(miss, collapse = ", "),
                                          "; other kind ", paste(wrong, collapse = ", "))
  invisible(TRUE)
}
