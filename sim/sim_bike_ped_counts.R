# Simulated bicycle and pedestrian counts
#
# Real data: traffic_counts/bicycle/Bicycle_and_Pedestrian_Counts_YYYYMMDD.csv (21.4M rows from
# 2012), read with bike_counts_read() (~17 minutes). One row per sensor, flow (direction) and 15
# minutes: sensor_id, name, travel_mode (bike, pedestrian, scooter), direction (in, out),
# flow_id, flow_name, time (start of the interval, NYC local time), counts, status (raw,
# modified; deleted rows dropped), counter_id (the device mounted then), then longitude,
# latitude, x, y, segment_id from bike_count_sensors().
#
# Kept: the real sensors (sim_bike_ped_sensors()) with their travel modes, each mode counted in
# and out; counts that follow the real hour-of-week pattern of the counts around a level per
# sensor and mode drawn from the profiled counts; about 11% of rows "modified". Not kept:
# seasonality, weather, gaps and device swaps, sensors starting and stopping at their real dates.
#
# bc <- sim_bike_ped_counts(from = "2019-06-01", to = "2019-07-01")

sim_bike_ped_counts <- function(from = "2019-06-01", to = "2019-06-08", sensors = sim_bike_ped_sensors(), seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  tz <- "America/New_York"
  t <- seq(as.POSIXct(from, tz = tz), as.POSIXct(to, tz = tz) - 900, by = "15 min")
  sh <- sim_ref("bike_ped_counts_hour_of_week.csv")
  how <- ((data.table::wday(t) + 5L) %% 7L) * 24L + data.table::hour(t) + 1L
  pattern <- sh[match(how, hour_of_week), share] * 168
  prof <- sim_profile("bike_ped_counts", 2000)[!is.na(counts), counts]
  flows <- sensors[, .(travel_mode = trimws(strsplit(travel_modes, ",", fixed = TRUE)[[1]])), by = sensor_id]
  flows <- flows[rep(seq_len(.N), each = 2)][, direction := rep(c("in", "out"), .N / 2)]
  flows[, `:=`(flow_id = 100000L + .I, level = pmax(0.5, sample(prof, .N, replace = TRUE)))]
  flows[sensors, on = "sensor_id", flow_name := paste(i.name, direction)]
  out <- flows[rep(seq_len(.N), each = length(t))]
  out[, time := rep(t, nrow(flows))]
  out[, counts := as.integer(stats::rpois(.N, level * rep(pattern, nrow(flows))))]
  out[, status := fifelse(stats::runif(.N) < 0.11, "modified", "raw")]
  out[, counter_id := 200000L + sensor_id]
  out[, level := NULL]
  out <- sensors[, .(sensor_id, name, longitude, latitude, x, y, segment_id)][out, on = "sensor_id"]
  setcolorder(out, c("sensor_id", "name", "travel_mode", "direction", "flow_id", "flow_name", "time", "counts", "status", "counter_id"))
  out[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  bc <- sim_bike_ped_counts(seed = 1)
  str(bc)
  print(bc[, .(counts = sum(counts)), .(hour = data.table::hour(time))][order(hour)])
}
