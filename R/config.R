# Shared configuration for the NYC data store
#
# The root is taken from the environment variable NYC_DATA, or else from
# NYC_DATA in config.local at the repo root (copy config.example). Subfolders:
# taxi/, crashes/, streets/, traffic_counts/, citibike/.

# config.local sits one level above this file
nyc_config_file <- local({
  ofiles <- unlist(lapply(sys.frames(), function(f) if (is.character(f$ofile)) f$ofile))
  this <- tail(ofiles[grepl("config\\.R$", ofiles)], 1)
  normalizePath(file.path(dirname(if (length(this)) dirname(this) else "R"), "config.local"),
                winslash = "/", mustWork = FALSE)
})

nyc_data_root <- function() {
  d <- Sys.getenv("NYC_DATA", unset = "")
  if (d == "" && file.exists(nyc_config_file)) {
    readRenviron(nyc_config_file)
    d <- Sys.getenv("NYC_DATA", unset = "")
  }
  if (d == "") stop("NYC_DATA not set: copy config.example to ", nyc_config_file, " and edit it")
  normalizePath(d, winslash = "/", mustWork = FALSE)
}

tlc_data_dir <- function() file.path(nyc_data_root(), "taxi")

tlc_url_base <- "https://d37ci6vzurychx.cloudfront.net/trip-data/"

# first month each trip type is published as parquet and used by our projects
tlc_start <- c(
  yellow = "2012-01",
  green  = "2014-01",  # 2013-08..12 are not published as parquet
  fhvhv  = "2019-02",
  fhv    = "2015-01"
)

tlc_file_name <- function(type, ym) paste0(type, "_tripdata_", ym, ".parquet")

tlc_months <- function(from, to = format(Sys.Date(), "%Y-%m")) {
  format(seq(as.Date(paste0(from, "-01")), as.Date(paste0(to, "-01")), by = "month"), "%Y-%m")
}
