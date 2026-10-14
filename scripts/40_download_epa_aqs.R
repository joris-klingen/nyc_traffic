# Download EPA AQS pre-generated monitor files (national, hourly and daily) into air_pollution/epa_aqs
#
# Usage (from repo root):  Rscript scripts/40_download_epa_aqs.R [first_year] [params]
#   first_year  default 2012
#   params      comma-separated subset of the parameter codes below, default all
#
# Files come from https://aqs.epa.gov/aqsweb/airdata/download_files.html, are published per
# parameter and year for the whole US, and are revised about twice a year (recent years most).
# A file is downloaded when it is missing or its Last-Modified / size differs from manifest.csv;
# the replaced file is kept as *.superseded_YYYYMMDD.zip. Site and monitor lists are dated snapshots.

library(data.table)
source("R/config.R")

base <- "https://aqs.epa.gov/aqsweb/airdata/"
params <- c(
  "44201"    = "ozone",
  "42602"    = "NO2",
  "NONOxNOy" = "NO, NOx, NOy",
  "42101"    = "CO",
  "42401"    = "SO2",
  "88101"    = "PM2.5 FRM/FEM",
  "88502"    = "PM2.5 non-FRM",
  "81102"    = "PM10",
  "WIND"     = "wind speed and direction",
  "TEMP"     = "temperature"
)

args <- commandArgs(trailingOnly = TRUE)
first_year <- if (length(args) >= 1) as.integer(args[1]) else 2012L
if (length(args) >= 2) params <- params[strsplit(args[2], ",")[[1]]]
years <- first_year:as.integer(format(Sys.Date(), "%Y"))

root <- file.path(nyc_data_root(), "air_pollution", "epa_aqs")
for (d in c("hourly", "daily", "sites")) dir.create(file.path(root, d), recursive = TRUE, showWarnings = FALSE)
manifest_file <- file.path(root, "manifest.csv")
manifest <- if (file.exists(manifest_file)) fread(manifest_file, colClasses = "character") else
  data.table(file = character(), dir = character(), remote_modified = character(), size = character(), downloaded = character())
today <- format(Sys.Date(), "%Y%m%d")
options(timeout = 3600)

head_info <- function(url) {
  h <- tryCatch(curlGetHeaders(url), error = function(e) NULL)
  if (is.null(h) || attr(h, "status") != 200) return(NULL)
  get <- function(k) { l <- grep(paste0("^", k, ":"), h, ignore.case = TRUE, value = TRUE); trimws(sub("^[^:]*:", "", l[length(l)])) }
  list(modified = get("Last-Modified"), size = get("Content-Length"))
}

fetch <- function(fname, subdir, dest_name = fname) {
  url <- paste0(base, fname)
  info <- head_info(url)
  if (is.null(info)) { message(fname, ": not published"); return(invisible()) }
  dest <- file.path(root, subdir, dest_name)
  known <- manifest[file == dest_name & dir == subdir]
  if (file.exists(dest) && nrow(known) && known[.N, remote_modified] == info$modified && known[.N, size] == info$size) return(invisible())
  part <- paste0(dest, ".part")
  ok <- tryCatch({ curl::curl_download(url, part, quiet = TRUE); file.size(part) == as.numeric(info$size) }, error = function(e) FALSE)
  if (!ok) { unlink(part); message(fname, ": FAILED"); return(invisible()) }
  if (file.exists(dest)) {
    if (unname(tools::md5sum(dest)) == unname(tools::md5sum(part))) unlink(part)
    else file.rename(dest, sub("\\.zip$", paste0(".superseded_", today, ".zip"), dest))
  }
  if (file.exists(part)) file.rename(part, dest)
  manifest <<- rbind(manifest, data.table(file = dest_name, dir = subdir, remote_modified = info$modified, size = info$size, downloaded = today))
  fwrite(manifest, manifest_file)
  message(dest_name, ": saved, ", round(as.numeric(info$size) / 1e6), " MB (", info$modified, ")")
}

# Monitor data ----
for (p in names(params)) for (y in years) {
  fetch(sprintf("hourly_%s_%d.zip", p, y), "hourly")
  fetch(sprintf("daily_%s_%d.zip", p, y), "daily")
}

# Sites and monitors (current lists, dated) ----
for (f in c("aqs_sites", "aqs_monitors")) {
  latest <- tail(sort(list.files(file.path(root, "sites"), pattern = paste0("^", f, "_\\d{8}\\.zip$"))), 1)
  info <- head_info(paste0(base, f, ".zip"))
  if (!is.null(info) && (!length(latest) || !identical(manifest[file == latest, remote_modified][1], info$modified)))
    fetch(paste0(f, ".zip"), "sites", paste0(f, "_", today, ".zip"))
}
