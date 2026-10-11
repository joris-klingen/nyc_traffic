# Download dated snapshots of NYC Open Data datasets into nyc_traffic_data
#
# Usage (from repo root):  Rscript scripts/10_download_opendata.R [names]
#   names  comma-separated subset of the datasets below, default all
#
# A new snapshot is only downloaded when the dataset was updated after the
# most recent local snapshot. Snapshots are named <prefix>_YYYYMMDD.<ext>.
# Every attempt is logged to opendata_download_log.csv at the data root.

library(data.table)
source("R/config.R")

url_csv     <- "https://data.cityofnewyork.us/api/views/%s/rows.csv?accessType=DOWNLOAD"
url_geojson <- "https://data.cityofnewyork.us/api/geospatial/%s?method=export&format=GeoJSON"
url_zip     <- "https://data.cityofnewyork.us/download/%s/application/zip"

datasets <- rbindlist(list(
  list("crashes",             "h9gi-nx95", "crashes",                  "Motor_Vehicle_Collisions_-_Crashes",   "csv",     url_csv),
  list("persons",             "f55k-p6yu", "crashes",                  "Motor_Vehicle_Collisions_-_Person",    "csv",     url_csv),
  list("vehicles",            "bm4k-52h4", "crashes",                  "Motor_Vehicle_Collisions_-_Vehicles",  "csv",     url_csv),
  list("bike_routes",         "mzxg-pwib", "streets/bike_routes",      "New York City Bike Routes",            "geojson", url_geojson),
  list("lion",                "2v4z-66xt", "streets/lion",             "nyclion",                              "zip",     url_zip),
  list("address_points",      "uf93-f8nk", "streets/address_points",   "AddressPoint",                         "csv",     url_csv),
  list("traffic_counts",      "7ym2-wayt", "traffic_counts/automated", "Automated_Traffic_Volume_Counts",      "csv",     url_csv),
  list("bike_ped_counts",     "ct66-47at", "traffic_counts/bicycle",   "Bicycle_and_Pedestrian_Counts",        "csv",     url_csv),
  list("bike_ped_sensors",    "6up2-gnw8", "traffic_counts/bicycle",   "Bicycle_and_Pedestrian_Count_Sensors", "csv",     url_csv),
  list("boroughs",            "gthc-hcne", "boundaries",               "borough_boundaries",                   "geojson", url_geojson),
  list("community_districts", "5crt-au7u", "boundaries",               "community_districts",                  "geojson", url_geojson),
  list("ntas",                "9nt8-h7nd", "boundaries",               "nta_2020",                             "geojson", url_geojson),
  list("tracts",              "63ge-mke6", "boundaries",               "census_tracts_2020",                   "geojson", url_geojson),
  list("blocks",              "wmsu-5muw", "boundaries",               "census_blocks_2020",                   "geojson", url_geojson),
  list("precincts",           "y76i-bdw7", "boundaries",               "police_precincts",                     "geojson", url_geojson),
  list("tract_nta",           "hm78-6dwm", "boundaries",               "census_tract_2020_to_nta_cdta",        "csv",     url_csv)
))
setnames(datasets, c("name", "id", "dir", "prefix", "ext", "url"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) datasets <- datasets[name %in% strsplit(args[1], ",")[[1]]]

root <- nyc_data_root()
today <- format(Sys.Date(), "%Y%m%d")
log_file <- file.path(root, "opendata_download_log.csv")
options(timeout = 7200)

last_updated <- function(id) {
  j <- jsonlite::fromJSON(sprintf("https://data.cityofnewyork.us/api/views/%s.json", id))
  ts <- j$rowsUpdatedAt %||% j$viewLastModified
  as.Date(as.POSIXct(ts, origin = "1970-01-01"))
}

log_row <- function(d, status, remote, size = NA_real_, msg = "") {
  fwrite(data.table(time = format(Sys.time()), name = d[, name], id = d[, id], status, remote_updated = format(remote),
                    size, message = msg), log_file, append = file.exists(log_file))
}

# an error page or empty export instead of data
looks_valid <- function(f, ext) {
  if (!file.exists(f) || file.size(f) < 200) return(FALSE)
  head <- readChar(f, 200, useBytes = TRUE)
  if (grepl("^\\s*<", head) || grepl('"error"\\s*:\\s*true', head)) return(FALSE)
  if (ext == "geojson") return(grepl("FeatureCollection", head))
  TRUE
}

# Download loop ----
for (i in seq_len(nrow(datasets))) {
  d <- datasets[i]
  out_dir <- file.path(root, d[, dir])
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  pattern <- paste0("^", gsub("([.()+])", "\\\\\\1", d[, prefix]), "_(\\d{8})\\.", d[, ext], "$")
  local <- list.files(out_dir, pattern = pattern)
  latest_local <- if (length(local)) max(as.Date(sub(pattern, "\\1", local), "%Y%m%d")) else as.Date("1900-01-01")
  updated <- tryCatch(last_updated(d[, id]), error = function(e) NA)
  if (is.na(updated)) { message(d[, name], ": metadata FAILED"); log_row(d, "metadata failed", NA); next }

  message(d[, name], ": remote updated ", updated, ", latest local snapshot ", latest_local)
  if (updated <= latest_local) { log_row(d, "up to date", updated); next }

  dest <- file.path(out_dir, paste0(d[, prefix], "_", today, ".", d[, ext]))
  part <- paste0(dest, ".part")
  url <- sprintf(d[, url], d[, id])
  # curl handles multi-GB exports more reliably than download.file
  err <- tryCatch({
    if (requireNamespace("curl", quietly = TRUE)) curl::curl_download(url, part, quiet = TRUE)
    else if (download.file(url, part, mode = "wb", quiet = TRUE) != 0) stop("download.file returned non-zero")
    ""
  }, error = function(e) conditionMessage(e))
  if (err == "" && !looks_valid(part, d[, ext])) err <- "response is not data"
  if (err == "") {
    file.rename(part, dest)
    log_row(d, "downloaded", updated, file.size(dest))
    message(d[, name], ": saved ", basename(dest), " ", round(file.size(dest) / 1e6), " MB")
  } else {
    unlink(part)
    log_row(d, "FAILED", updated, msg = err)
    message(d[, name], ": FAILED (", err, ")")
  }
}
