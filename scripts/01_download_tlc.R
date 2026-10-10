# Download TLC trip record parquet files into the shared data store
#
# Usage (from repo root):  Rscript scripts/01_download_tlc.R [types] [recheck_months]
#   types           comma-separated, default "yellow,green,fhvhv"
#   recheck_months  number of most recent local months whose size is compared
#                   with the server and re-downloaded if TLC republished them (default 3)
#
# Files that are not (yet) published return HTTP 403 and are skipped.

library(data.table)
source("R/config.R")

args <- commandArgs(trailingOnly = TRUE)
types <- if (length(args) >= 1) strsplit(args[1], ",")[[1]] else c("yellow", "green", "fhvhv")
recheck_months <- if (length(args) >= 2) as.integer(args[2]) else 3

data_dir <- tlc_data_dir()
raw_dir <- file.path(data_dir, "raw")
log_file <- file.path(data_dir, "download_log.csv")

options(timeout = 3600)

remote_size <- function(url) {
  h <- tryCatch(curlGetHeaders(url), error = function(e) NULL)
  if (is.null(h) || attr(h, "status") != 200) return(NA_real_)
  cl <- grep("^content-length:", h, ignore.case = TRUE, value = TRUE)
  if (length(cl) == 0) return(NA_real_)
  as.numeric(trimws(sub("^[^:]*:", "", cl[length(cl)])))
}

log_row <- function(type, ym, status, size = NA_real_) {
  fwrite(data.table(time = format(Sys.time()), type, ym, status, size),
         log_file, append = file.exists(log_file))
}

download_one <- function(url, dest) {
  part <- paste0(dest, ".part")
  ok <- tryCatch(download.file(url, part, mode = "wb", quiet = TRUE, cacheOK = FALSE) == 0,
                 error = function(e) FALSE, warning = function(w) FALSE)
  if (ok) file.rename(part, dest) else unlink(part)
  ok
}

# Download loop ----
for (type in types) {
  dir.create(file.path(raw_dir, type), recursive = TRUE, showWarnings = FALSE)
  months <- tlc_months(tlc_start[[type]])

  local_months <- months[file.exists(file.path(raw_dir, type, tlc_file_name(type, months)))]
  recheck <- tail(local_months, recheck_months)

  for (ym in months) {
    dest <- file.path(raw_dir, type, tlc_file_name(type, ym))
    url <- paste0(tlc_url_base, tlc_file_name(type, ym))

    if (file.exists(dest) && !ym %in% recheck) next

    rs <- remote_size(url)
    if (is.na(rs)) {
      if (!file.exists(dest)) { message(type, " ", ym, ": not published"); log_row(type, ym, "not_published") }
      next
    }

    if (file.exists(dest)) {
      if (file.size(dest) == rs) next
      # republished by TLC: keep the old version next to the new one
      file.rename(dest, sub("\\.parquet$", paste0(".superseded_", format(Sys.Date(), "%Y%m%d"), ".parquet"), dest))
      message(type, " ", ym, ": republished, re-downloading")
    }

    message(type, " ", ym, ": downloading (", round(rs / 1e6), " MB)")
    ok <- download_one(url, dest)
    log_row(type, ym, if (ok) "downloaded" else "FAILED", rs)
  }
}

# Manifest of everything on disk ----
files <- list.files(raw_dir, recursive = TRUE, full.names = TRUE)
files <- files[!grepl("\\.part$", files)]
manifest <- data.table(
  file  = sub(paste0(raw_dir, "/"), "", files, fixed = TRUE),
  size  = file.size(files),
  mtime = format(file.mtime(files))
)
manifest[, type := sub("/.*", "", file)]
manifest[, ym := regmatches(file, regexpr("\\d{4}-\\d{2}", file))]
fwrite(manifest[order(type, ym)], file.path(data_dir, "manifest.csv"))

print(manifest[, .(files = .N, first = min(ym), last = max(ym), GB = round(sum(size) / 1e9, 1)), by = type])
