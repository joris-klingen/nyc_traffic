# Daily snapshot of the Citi Bike station list (GBFS station_information)
#
# Usage (from repo root):  Rscript scripts/21_snapshot_citibike_stations.R
#
# The feed only gives the current stations (id, name, location, capacity), so station openings,
# moves and capacity changes are only recorded from the first snapshot on. Saved as
# citibike/stations/station_information_YYYYMMDD.json; not kept when the station list equals the
# latest snapshot (the feed's last_updated and ttl are ignored in the comparison).

library(data.table)
source("R/config.R")

url <- "https://gbfs.citibikenyc.com/gbfs/en/station_information.json"
out_dir <- file.path(nyc_data_root(), "citibike", "stations")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dest <- file.path(out_dir, paste0("station_information_", format(Sys.Date(), "%Y%m%d"), ".json"))

txt <- paste(readLines(url, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
feed <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
stations <- feed$data$stations
if (length(stations) < 1000) stop("only ", length(stations), " stations in the feed")

local <- sort(list.files(out_dir, pattern = "^station_information_\\d{8}\\.json$", full.names = TRUE))
if (length(local)) {
  prev <- jsonlite::fromJSON(local[length(local)], simplifyVector = FALSE)$data$stations
  by_id <- function(s) s[order(vapply(s, function(x) x$station_id, ""))]
  if (identical(by_id(prev), by_id(stations))) {
    message("unchanged since ", basename(local[length(local)]), " (", length(stations), " stations)")
    quit(save = "no")
  }
}
writeLines(txt, dest, useBytes = TRUE)
message("saved ", basename(dest), ": ", length(stations), " stations")
