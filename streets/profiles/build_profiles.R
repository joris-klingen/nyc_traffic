# Build the data profiles in profiles/ from the street history in derived/streets
#
# Run from streets/: Rscript profiles/build_profiles.R [source ...]
# Profiles the outputs of streets/ (segment key, spells, bike lane windows, travel lane panels) as
# the readers in R/streets.R return them, in the format of the repo-level profiles: per source a
# <source>.csv (one row per column), <source>_values.csv (common values and shares) and a row in
# index.csv. sim/ uses them to simulate data for code development without the data. The profiling
# and simulation functions are in the repo's R/simulate.R.

library(data.table)
library(arrow)
library(sf)
source("R/streets.R")
source("../R/simulate.R")

prof_dir <- normalizePath("profiles", winslash = "/")
max_rows <- 1e6
set.seed(20261016)
root <- nyc_streets_data_root()
rel <- function(f) sub(paste0("^", root, "/"), "derived/streets/", normalizePath(f, winslash = "/"))

sample_rows <- function(x, n = max_rows) if (nrow(x) > n) x[sort(sample(.N, n))] else x

run_profile <- function(source, x, reader, file, notes = "", xy = NULL, cell = NULL) {
  t0 <- Sys.time()
  rows <- nrow(x)
  if (!inherits(x, "sf")) x <- sample_rows(x)
  p <- profile_dt(x, xy = xy, cell = cell)
  profile_write(p, source, list(reader = reader, files = rel(file), rows_total = format(rows, scientific = FALSE),
                                rows_profiled = nrow(x), sample = if (nrow(x) < rows) "1,000,000 random rows" else "all rows",
                                notes = notes), dir = prof_dir)
  message(sprintf("%-30s %9s rows, %3d columns, %4.0f s", source, format(nrow(x), big.mark = ","),
                  nrow(p$columns), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

# Sources ----

sources <- list(
  segment_key = function() run_profile("segment_key", segment_key_read(), "segment_key_read()", streets_dir("spine", "segment_key.parquet"),
    notes = "one row per LION SegmentID x geometry version x key segment; key_id = SegmentID in the last release (26c); share of the version's length, key_cover of the key segment's length"),
  segment_links = function() run_profile("segment_links", setDT(read_parquet(streets_dir("spine", "segment_links.parquet"))),
    "arrow::read_parquet(streets_dir('spine', 'segment_links.parquet'))", streets_dir("spine", "segment_links.parquet"),
    notes = "links between consecutive versions (overlap, same id redrawn, LegacyID), chained to 26c by spine/03_segment_key.R"),
  lion_segment_releases = function() {
    f <- streets_dir("spine", "lion_segment_releases.parquet")
    tb <- read_parquet(f, as_data_frame = FALSE)
    i <- sort(sample(tb$num_rows, min(max_rows, tb$num_rows))) - 1L
    x <- as.data.table(tb$Take(Array$create(i, type = int64())))
    rows <- tb$num_rows; rm(tb); gc()
    p <- profile_dt(x)
    profile_write(p, "lion_segment_releases", list(reader = "arrow::read_parquet(streets_dir('spine', 'lion_segment_releases.parquet'))",
                  files = rel(f), rows_total = format(rows, scientific = FALSE), rows_profiled = nrow(x), sample = "1,000,000 random rows",
                  notes = "attributes of every LION record in each of the 57 releases 12a-26c (no geometry)"), dir = prof_dir)
    message("lion_segment_releases done")
  },
  segment_versions = function() run_profile("segment_versions", segment_versions_read(), "segment_versions_read()", streets_dir("spine", "segment_versions.gpkg"),
    notes = "one row per SegmentID x distinct geometry with first/last release, lines in EPSG 2263"),
  street_spells = function() {
    sp <- streets_spells_read()
    run_profile("street_spells", sp, "streets_spells_read()", streets_dir("spells", "street_spells.parquet"),
                notes = "all layers as spells on the key segments: attribute (see streets_attributes()), side, value (text), valid_from, valid_to (NA = still valid); per-attribute structure in street_spells_attributes.csv and street_spells_attribute_values.csv")
    # the profile pools all attributes; these keep what differs by attribute, for sim_street_spells()
    nk <- uniqueN(key_segments_read()[, key_id])
    per_key <- sp[, .N, .(key_id, attribute, side, source)]
    att <- per_key[, .(keys_share = signif(uniqueN(key_id) / nk, 6), spells_per_key = signif(mean(N), 6),
                       changed_share = signif(mean(N > 1), 6)), .(attribute, side, source)]
    att <- merge(att, sp[, .(first_from = min(valid_from[valid_from > as.IDate("1900-01-01")]), priority = priority[1],
                             precision = paste(names(sort(table(date_precision), decreasing = TRUE)), collapse = "|")),
                         .(attribute, side, source)], by = c("attribute", "side", "source"))
    fwrite(att, file.path(prof_dir, "street_spells_attributes.csv"))
    v <- sp[, .N, .(attribute, source, value)][order(attribute, source, -N)]
    v[, share := signif(N / sum(N), 6), .(attribute, source)]
    fwrite(v[, head(.SD, 40), .(attribute, source)][, .(attribute, source, value, share)], file.path(prof_dir, "street_spells_attribute_values.csv"))
    # dated bike lane spells: precision shares
    bp <- sp[attribute == "bike_lane" & date_precision != "open", .N, date_precision][, share := signif(N / sum(N), 6)][order(-N)]
    fwrite(bp[, .(date_precision, share)], file.path(prof_dir, "street_spells_bike_lane_precision.csv"))
  },
  key_segments = function() run_profile("key_segments", key_segments_read(), "key_segments_read()", streets_dir("spells", "key_segments.parquet"),
    notes = "one row per key segment: borough, street, street code, roadway type"),
  streets_panel_manhattan = function() {
    x <- streets_panel("2018-01-01", "2019-12-01", boro = 1)
    run_profile("streets_panel_manhattan", x, "streets_panel('2018-01-01', '2019-12-01', boro = 1)", streets_dir("spells", "street_spells.parquet"),
                notes = "wide street state per key segment and month, Manhattan 2018-2019 (the panel is built from the spells, not stored)")
  },
  bikelane_windows = function() {
    x <- as.data.table(bikelane_windows_read("dot2026"))
    run_profile("bikelane_windows", x, "bikelane_windows_read()", streets_dir("bike_lanes", "bike_lanes_time_windows.RDS"),
                notes = "SegmentID x time_window: date_from, date_to, tf_facilit / ft_facilit (Protected, Standard, Sharrows; NA no lane), all boroughs from the DOT 2026 version history")
  },
  bikelane_windows_dot2020 = function() {
    x <- as.data.table(bikelane_windows_read("dot2020"))
    run_profile("bikelane_windows_dot2020", x, "bikelane_windows_read('dot2020')", streets_dir("bike_lanes", "bike_lanes_time_windows_dot2020.RDS"),
                notes = "the earlier build from the DOT 2020 release plus the Manhattan 2025 updates")
  },
  bikelane_windows_keyed = function() run_profile("bikelane_windows_keyed", bikelane_windows_keyed_read(), "bikelane_windows_keyed_read()",
    streets_dir("bike_lanes", "bike_lanes_windows_keyed.parquet"),
    notes = "the windows on the key: key_id x source SegmentID x time_window; filter on main_source for one set per key segment"),
  bike_lane_updates = function() run_profile("bike_lane_updates", st_read(streets_dir("bike_lanes", "bike_lane_updates.gpkg"), quiet = TRUE),
    "sf::st_read(streets_dir('bike_lanes', 'bike_lane_updates.gpkg'))", streets_dir("bike_lanes", "bike_lane_updates.gpkg")),
  lion_lanes_panel = function() run_profile("lion_lanes_panel", setDT(read_parquet(streets_dir("travel_lanes", "lion_lanes_panel.parquet"))),
    "arrow::read_parquet(streets_dir('travel_lanes', 'lion_lanes_panel.parquet'))", streets_dir("travel_lanes", "lion_lanes_panel.parquet"),
    notes = "SegmentID x LION release: travel, parking and total lanes, street width (layers/travel_lanes/01_lion_panel.R)"),
  lion_lanes_panel_keyed = function() run_profile("lion_lanes_panel_keyed", setDT(read_parquet(streets_dir("travel_lanes", "lion_lanes_panel_keyed.parquet"))),
    "arrow::read_parquet(streets_dir('travel_lanes', 'lion_lanes_panel_keyed.parquet'))", streets_dir("travel_lanes", "lion_lanes_panel_keyed.parquet")),
  manhattan_lanes_monthly = function() run_profile("manhattan_lanes_monthly", setDT(read_parquet(streets_dir("travel_lanes", "manhattan_lanes_monthly.parquet"))),
    "arrow::read_parquet(streets_dir('travel_lanes', 'manhattan_lanes_monthly.parquet'))", streets_dir("travel_lanes", "manhattan_lanes_monthly.parquet"),
    notes = "Manhattan SegmentID x month: moving lanes dated with the bike lane changes and reviews (layers/travel_lanes/02_manhattan_lane_panel.R)"),
  manhattan_lanes_monthly_keyed = function() run_profile("manhattan_lanes_monthly_keyed", setDT(read_parquet(streets_dir("travel_lanes", "manhattan_lanes_monthly_keyed.parquet"))),
    "arrow::read_parquet(streets_dir('travel_lanes', 'manhattan_lanes_monthly_keyed.parquet'))", streets_dir("travel_lanes", "manhattan_lanes_monthly_keyed.parquet"))
)

# Run ----

args <- commandArgs(trailingOnly = TRUE)
todo <- if (length(args)) args else names(sources)
bad <- setdiff(todo, names(sources))
if (length(bad)) stop("unknown sources: ", paste(bad, collapse = ", "))
failed <- character()
for (s in todo) {
  ok <- tryCatch({ sources[[s]](); TRUE }, error = function(e) { message(s, " FAILED: ", conditionMessage(e)); FALSE })
  if (!ok) failed <- c(failed, s)
  gc()
}
if (length(failed)) message("failed: ", paste(failed, collapse = ", "))
