# Download dated snapshots of NYC Open Data datasets into data_NYC
#
# Usage (from repo root):  Rscript scripts/10_download_opendata.R [names]
#   names  comma-separated subset of the datasets below, default all
#
# A new snapshot is only downloaded when the dataset was updated after the
# most recent local snapshot. Snapshots are named <prefix>_YYYYMMDD.<ext>.

library(data.table)
source("R/config.R")

datasets <- data.table(
  name   = c("crashes", "persons", "bike_routes", "lion"),
  id     = c("h9gi-nx95", "f55k-p6yu", "mzxg-pwib", "2v4z-66xt"),
  dir    = c("crashes/raw", "crashes/raw", "streets/bike_routes", "streets/lion"),
  prefix = c("Motor_Vehicle_Collisions_-_Crashes", "Motor_Vehicle_Collisions_-_Person",
             "New York City Bike Routes", "nyclion"),
  ext    = c("csv", "csv", "geojson", "zip"),
  url    = c("https://data.cityofnewyork.us/api/views/%s/rows.csv?accessType=DOWNLOAD",
             "https://data.cityofnewyork.us/api/views/%s/rows.csv?accessType=DOWNLOAD",
             "https://data.cityofnewyork.us/api/geospatial/%s?method=export&format=GeoJSON",
             "https://data.cityofnewyork.us/download/%s/application/zip")
)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) datasets <- datasets[name %in% strsplit(args[1], ",")[[1]]]

root <- nyc_data_root()
today <- format(Sys.Date(), "%Y%m%d")
options(timeout = 7200)

last_updated <- function(id) {
  j <- jsonlite::fromJSON(sprintf("https://data.cityofnewyork.us/api/views/%s.json", id))
  ts <- j$rowsUpdatedAt %||% j$viewLastModified
  as.Date(as.POSIXct(ts, origin = "1970-01-01"))
}

# Download loop ----
for (i in seq_len(nrow(datasets))) {
  d <- datasets[i]
  out_dir <- file.path(root, d[, dir])
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  pattern <- paste0("^", gsub("([.()+])", "\\\\\\1", d[, prefix]), "_(\\d{8})\\.", d[, ext], "$")
  local <- list.files(out_dir, pattern = pattern)
  latest_local <- if (length(local)) max(as.Date(sub(pattern, "\\1", local), "%Y%m%d")) else as.Date("1900-01-01")
  updated <- last_updated(d[, id])

  message(d[, name], ": remote updated ", updated, ", latest local snapshot ", latest_local)
  if (updated <= latest_local) next

  dest <- file.path(out_dir, paste0(d[, prefix], "_", today, ".", d[, ext]))
  part <- paste0(dest, ".part")
  ok <- tryCatch(download.file(sprintf(d[, url], d[, id]), part, mode = "wb", quiet = TRUE) == 0,
                 error = function(e) FALSE)
  if (ok) file.rename(part, dest) else unlink(part)
  message(d[, name], ": ", if (ok) paste("saved", basename(dest), round(file.size(dest) / 1e6), "MB") else "FAILED")
}
