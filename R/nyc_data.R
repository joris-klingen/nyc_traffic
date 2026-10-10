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
  lion        = c("streets/lion",        "^nyclion_(\\d{8})\\.zip$")
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

# Citi Bike ----
citibike_files <- function() {
  list.files(file.path(nyc_data_root(), "citibike", "raw"),
             pattern = "citibike-tripdata\\.zip$", full.names = TRUE)
}
