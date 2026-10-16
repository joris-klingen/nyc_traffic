# Bicycle and pedestrian count sensors (real list)
#
# Real data: traffic_counts/bicycle/Bicycle_and_Pedestrian_Count_Sensors_YYYYMMDD.csv, read with
# bike_count_sensors(): one row per sensor (42): sensor_id, name, longitude, latitude,
# first_data, last_data (IDate), travel_modes ("bike", "bike, pedestrian", ...), devices (number
# of counters over time), x, y (EPSG 2263), segment_id (nearest LION centerline), segment_ft
# (distance to it; bridge paths can be far).
#
# The sensor list is small public reference data, so this returns the real table
# (profiles/bike_ped_sensors_full.csv) rather than a simulation.
#
# s <- sim_bike_ped_sensors()

sim_bike_ped_sensors <- function() {
  s <- sim_ref("bike_ped_sensors_full.csv")
  s[, `:=`(first_data = as.IDate(first_data), last_data = as.IDate(last_data))]
  s[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(sim_bike_ped_sensors())
}
