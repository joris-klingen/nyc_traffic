# Simulated historical count files (no longer updated)
#
# Real data, read raw with data.table::fread(file.path(nyc_data_root(), <file>)):
#   traffic_counts/legacy/Traffic_Volume_Counts__2011-2012_.csv, __2012-2013_, __2014-2018_
#       DOT volume counts: one row per segment, direction and day with hourly volume columns
#       (12:00-1:00 AM ... 11:00-12:00AM), ID, Segment ID, Roadway Name, From, To, Direction, Date
#   traffic_counts/legacy/Vehicle_Classification_Counts__2011-2012_.csv, __2012-2013_, __2014-2018_
#       counts by FHWA vehicle class (bikes, cars, buses, trucks of 2 to 6+ axles) per location and day
#   traffic_counts/bicycle/Bicycle_Counts_20200204.csv, Bicycle_Counters_20200204.csv
#       the DOT counter data as published until 2020 (counts per counter id and 15 minutes; counters)
#   traffic_counts/bicycle/NYCDCP_Manhattan_Bike_Counts_-_On_Street_Weekday.csv, _Off_Street.csv
#       DCP screenline cyclist counts in Manhattan, one row per location with yearly columns
# Profiles: profiles/counts_<file name in snake case>.csv.
#
# Kept: columns, types and value shares (dates as text in the files' format). Not kept: the
# hourly profile within a day, counts that belong to a location.
#
# sim_counts_legacy()                                  # names of the files
# v <- sim_counts_legacy("counts_traffic_volume_counts_2014_2018", 500)

sim_counts_legacy <- function(name = NULL, n = 1000, seed = NULL) {
  idx <- data.table::fread(file.path(sim_profiles_dir(), "index.csv"))
  names_ok <- idx[grepl("^counts_", source), source]
  if (is.null(name)) return(names_ok)
  if (!name %in% names_ok) stop("unknown legacy count file ", name, "; one of: ", paste(names_ok, collapse = ", "))
  sim_profile(name, n, seed)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(sim_counts_legacy())
  print(head(sim_counts_legacy("counts_vehicle_classification_counts_2014_2018", 5, seed = 1)))
}
