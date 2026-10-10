# Open TLC trip records as a lazy arrow dataset
#
# source("<path>/nyc_tlc_data/R/tlc_open.R")
# ds <- tlc_open("fhvhv", years = 2019:2020)
# dt <- ds |> dplyr::select(PULocationID, DOLocationID) |> dplyr::collect() |> setDT()
#
# Column names differ between types (e.g. tpep_/lpep_ prefixes, trip_distance vs
# trip_miles) and across years within a type; harmonize after selecting.

source(file.path(dirname(sys.frame(1)$ofile %||% "R/tlc_open.R"), "config.R"))

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
