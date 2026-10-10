# Shared configuration for the NYC TLC data store
#
# The data directory is taken from the environment variable NYC_TLC_DATA
# (set it in ~/.Renviron), falling back to the shared Dropbox folder.

tlc_data_dir <- function() {
  d <- Sys.getenv("NYC_TLC_DATA", unset = "")
  if (d == "") d <- file.path(Sys.getenv("USERPROFILE"), "Dropbox/1_research/data_NYC/taxi")
  normalizePath(d, winslash = "/", mustWork = FALSE)
}

tlc_url_base <- "https://d37ci6vzurychx.cloudfront.net/trip-data/"

# first month each trip type is published as parquet and used by our projects
tlc_start <- c(
  yellow = "2012-01",
  green  = "2013-08",
  fhvhv  = "2019-02",
  fhv    = "2015-01"
)

tlc_file_name <- function(type, ym) paste0(type, "_tripdata_", ym, ".parquet")

tlc_months <- function(from, to = format(Sys.Date(), "%Y-%m")) {
  format(seq(as.Date(paste0(from, "-01")), as.Date(paste0(to, "-01")), by = "month"), "%Y-%m")
}
