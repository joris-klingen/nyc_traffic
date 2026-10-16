# Shared configuration for the NYC traffic data store
#
# The root is taken from the environment variable NYC_TRAFFIC_DATA, or else from
# NYC_TRAFFIC_DATA in config.local at the repo root (copy config.example). The old name
# NYC_DATA is still read as a fallback. Subfolders: taxi/, crashes/, streets/, boundaries/,
# traffic_counts/, citibike/, documents/, derived/.

# config.local sits one level above this file
nyc_config_file <- local({
  ofiles <- unlist(lapply(sys.frames(), function(f) if (is.character(f$ofile)) f$ofile))
  this <- tail(ofiles[grepl("config\\.R$", ofiles)], 1)
  normalizePath(file.path(dirname(if (length(this)) dirname(this) else "R"), "config.local"),
                winslash = "/", mustWork = FALSE)
})

nyc_data_root <- function() {
  d <- Sys.getenv("NYC_TRAFFIC_DATA", unset = "")
  if (d == "" && file.exists(nyc_config_file)) {
    readRenviron(nyc_config_file)
    d <- Sys.getenv("NYC_TRAFFIC_DATA", unset = "")
  }
  if (d == "") d <- Sys.getenv("NYC_DATA", unset = "")
  if (d == "") stop("NYC_TRAFFIC_DATA not set: copy config.example to ", nyc_config_file, " and edit it")
  normalizePath(d, winslash = "/", mustWork = FALSE)
}

# Street network history built by the nyc_streets repo (spine/, spells/, bike_lanes/, travel_lanes/).
# NYC_STREETS_DATA in the environment or config.local; by default nyc_streets_data next to the store.
nyc_streets_data_root <- function() {
  d <- Sys.getenv("NYC_STREETS_DATA", unset = "")
  if (d == "" && file.exists(nyc_config_file)) {
    readRenviron(nyc_config_file)
    d <- Sys.getenv("NYC_STREETS_DATA", unset = "")
  }
  if (d == "") d <- file.path(dirname(nyc_data_root()), "nyc_streets_data")
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

# NYC Open Data sets kept as dated snapshots <dir>/<prefix>_YYYYMMDD.<ext>: downloaded by
# scripts/10_download_opendata.R, found by nyc_latest(name). Street layout sets that are published
# as current state only (parking, bus lanes, speed limits, ...) are snapshotted so that their
# history builds up from the first download.
nyc_opendata <- data.table::rbindlist(list(
  list("crashes",             "h9gi-nx95", "crashes",                  "Motor_Vehicle_Collisions_-_Crashes",   "csv"),
  list("persons",             "f55k-p6yu", "crashes",                  "Motor_Vehicle_Collisions_-_Person",    "csv"),
  list("vehicles",            "bm4k-52h4", "crashes",                  "Motor_Vehicle_Collisions_-_Vehicles",  "csv"),
  list("bike_routes",         "mzxg-pwib", "streets/bike_routes",      "New York City Bike Routes",            "geojson"),
  list("lion",                "2v4z-66xt", "streets/lion",             "nyclion",                              "zip"),
  list("address_points",      "uf93-f8nk", "streets/address_points",   "AddressPoint",                         "csv"),
  list("bus_lanes",           "ycrg-ses3", "streets/bus_lanes",        "Bus_Lanes_Local_Streets",              "geojson"),
  list("parking_signs",       "nfid-uabd", "streets/parking",          "Parking_Regulation_Locations_and_Signs", "csv"),
  list("parking_meters",      "693u-uax6", "streets/parking",          "Parking_Meters_Locations_and_Status",  "csv"),
  list("meter_blockfaces",    "e7yp-wx55", "streets/parking",          "Parking_Meters_ParkNYC_Block_Faces",   "geojson"),
  list("meter_rate_zones",    "f72k-2u3b", "streets/parking",          "Parking_Meters_Citywide_Rate_Zones",   "geojson"),
  list("speed_limits",        "5mad-ntua", "streets/traffic_rules",    "VZV_Speed_Limits",                     "geojson"),
  list("arterial_slow_zones", "2i8t-es4u", "streets/traffic_rules",    "VZV_Arterial_Slow_Zones",              "geojson"),
  list("neighborhood_slow_zones", "bqye-aqft", "streets/traffic_rules", "VZV_Neighborhood_Slow_Zones",         "geojson"),
  list("truck_routes",        "jjja-shxy", "streets/traffic_rules",    "New_York_City_Truck_Routes",           "geojson"),
  list("street_network_changes", "as9z-kwsh", "streets/traffic_rules", "Street_Network_Changes_Historical",    "csv"),
  list("speed_humps",         "jknp-skuy", "streets/calming",          "VZV_Speed_Humps",                      "geojson"),
  list("srts",                "9n6h-pt9g", "streets/calming",          "Speed_Reducer_Tracking_System__SRTS_", "csv"),
  list("lpi_signals",         "xc4v-ntf4", "streets/signals",          "VZV_Leading_Pedestrian_Interval_Signals", "csv"),
  list("barnes_dance",        "8kuj-2n3u", "streets/signals",          "Exclusive_Pedestrian_Signal_Locations", "csv"),
  list("open_streets",        "uiay-nctu", "streets/public_space",     "Open_Streets_Locations",               "geojson"),
  list("ped_plazas",          "k5k6-6jex", "streets/public_space",     "NYC_DOT_Pedestrian_Plazas",            "geojson"),
  list("ped_space_added",     "uebm-cmjr", "streets/public_space",     "Pedestrian_Space_Added",               "csv"),
  list("bike_parking",        "592z-n7dk", "streets/bike_parking",     "Bicycle_Parking",                      "csv"),
  list("bike_shelters",       "dimy-qyej", "streets/bike_parking",     "Bicycle_Parking_Shelters",             "csv"),
  list("pavement_ratings",    "6yyb-pb25", "streets/pavement",         "Street_Pavement_Ratings",              "csv"),
  list("street_closures",     "i6b5-j7bu", "streets/closures",         "Street_Closures_due_to_construction_activities_by_Block", "csv"),
  list("traffic_counts",      "7ym2-wayt", "traffic_counts/automated", "Automated_Traffic_Volume_Counts",      "csv"),
  list("bike_ped_counts",     "ct66-47at", "traffic_counts/bicycle",   "Bicycle_and_Pedestrian_Counts",        "csv"),
  list("bike_ped_sensors",    "6up2-gnw8", "traffic_counts/bicycle",   "Bicycle_and_Pedestrian_Count_Sensors", "csv"),
  list("boroughs",            "gthc-hcne", "boundaries",               "borough_boundaries",                   "geojson"),
  list("community_districts", "5crt-au7u", "boundaries",               "community_districts",                  "geojson"),
  list("ntas",                "9nt8-h7nd", "boundaries",               "nta_2020",                             "geojson"),
  list("tracts",              "63ge-mke6", "boundaries",               "census_tracts_2020",                   "geojson"),
  list("blocks",              "wmsu-5muw", "boundaries",               "census_blocks_2020",                   "geojson"),
  list("precincts",           "y76i-bdw7", "boundaries",               "police_precincts",                     "geojson"),
  list("tract_nta",           "hm78-6dwm", "boundaries",               "census_tract_2020_to_nta_cdta",        "csv")
))
data.table::setnames(nyc_opendata, c("name", "id", "dir", "prefix", "ext"))

nyc_snapshot_pattern <- function(prefix, ext) paste0("^", gsub("([.()+])", "\\\\\\1", prefix), "_(\\d{8})\\.", ext, "$")
