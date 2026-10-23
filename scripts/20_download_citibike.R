# Download Citi Bike (NYC, not Jersey City) trip data zips into nyc_traffic_data/raw/citibike/trips
#
# Usage (from repo root):  Rscript scripts/20_download_citibike.R
#
# Files are listed from the public S3 bucket. Existing files whose size differs
# from the bucket (republished) are kept as *.superseded_YYYYMMDD.zip.

library(data.table)
source("R/config.R")

bucket <- "https://s3.amazonaws.com/tripdata"
raw_dir <- file.path(nyc_data_root(), "raw", "citibike", "trips")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 7200)

# List bucket ----
x <- paste(readLines(paste0(bucket, "?list-type=2"), warn = FALSE), collapse = "")
keys <- regmatches(x, gregexpr("<Key>[^<]+</Key>", x))[[1]]
sizes <- regmatches(x, gregexpr("<Size>\\d+</Size>", x))[[1]]
if (grepl("<IsTruncated>true", x)) warning("bucket listing truncated; add pagination")

files <- data.table(obj = gsub("</?Key>", "", keys), size = as.numeric(gsub("</?Size>", "", sizes)))
files <- files[grepl("citibike-tripdata\\.zip$", obj) & !grepl("^JC", obj)]

# Download ----
for (i in seq_len(nrow(files))) {
  k <- files[i, obj]; s <- files[i, size]
  dest <- file.path(raw_dir, k)

  if (file.exists(dest)) {
    if (file.size(dest) == s) next
    file.rename(dest, sub("\\.zip$", paste0(".superseded_", format(Sys.Date(), "%Y%m%d"), ".zip"), dest))
    message(k, ": size changed on server, re-downloading")
  }

  message(k, ": downloading (", round(s / 1e6), " MB)")
  part <- paste0(dest, ".part")
  ok <- tryCatch(download.file(paste0(bucket, "/", k), part, mode = "wb", quiet = TRUE) == 0,
                 error = function(e) FALSE)
  if (ok && file.size(part) == s) file.rename(part, dest) else { unlink(part); message(k, ": FAILED") }
}

# Manifest ----
local <- list.files(raw_dir, pattern = "\\.zip$", full.names = TRUE)
fwrite(data.table(file = basename(local), size = file.size(local), mtime = format(file.mtime(local))),
       { dir.create(file.path(nyc_data_root(), "_meta"), showWarnings = FALSE)
         file.path(nyc_data_root(), "_meta", "citibike_manifest.csv") })
message("citibike: ", length(local), " files, ", round(sum(file.size(local)) / 1e9, 1), " GB")
