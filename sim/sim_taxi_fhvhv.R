# Simulated high-volume for-hire trips (Uber, Lyft, Via, Juno)
#
# Real data: raw/taxi/fhvhv/fhvhv_tripdata_YYYY-MM.parquet, 2019-02 onward (91 months, ~20 million trips
# a month), read with tlc_open("fhvhv"). One row per trip: hvfhs_license_num (HV0003 Uber, HV0005
# Lyft, HV0002 Juno, HV0004 Via), dispatching_base_num, originating_base_num, request_datetime,
# on_scene_datetime (NA for some), pickup_datetime, dropoff_datetime (local clock stored as UTC),
# PULocationID, DOLocationID (taxi zones), trip_miles, trip_time (seconds), base_passenger_fare,
# tolls, bcf, sales_tax, congestion_surcharge, airport_fee (2022 on), tips, driver_pay,
# shared_request_flag, shared_match_flag, access_a_ride_flag, wav_request_flag, wav_match_flag,
# cbd_congestion_fee (2025 on). Types per year: profiles/taxi_fhvhv_schema_by_year.csv.
#
# Kept: request <= on scene <= pickup < dropoff, trip_time = dropoff - pickup in seconds and in
# line with trip_miles; pickups by the real hour-of-week pattern; value shares of license numbers,
# bases and flags. Not kept: base numbers that belong to their license, fares that follow miles.
#
# fh <- sim_taxi_fhvhv(10000, month = "2022-06")

sim_taxi_fhvhv <- function(n = 1000, month = "2025-06", seed = NULL) {
  x <- sim_profile("taxi_fhvhv", n, seed)
  r <- sim_month_range(month, tz = "UTC")
  x[, pickup_datetime := sim_times(n, r[["from"]], r[["to"]], "taxi_fhvhv", tz = "UTC")]
  x[, trip_miles := pmax(0, trip_miles)]
  mph <- stats::rlnorm(n, log(12), 0.35)
  x[, trip_time := as.integer(round(90 + pmin(trip_miles, 80) / mph * 3600))]
  x[, dropoff_datetime := pickup_datetime + trip_time]
  wait <- round(stats::rexp(n, 1 / 300))
  x[, request_datetime := pickup_datetime - wait - round(stats::rexp(n, 1 / 60))]
  x[!is.na(on_scene_datetime), on_scene_datetime := (pickup_datetime - round(stats::rexp(.N, 1 / 60)))]
  yr <- as.integer(substr(month, 1, 4))
  if (yr < 2022) x[, airport_fee := NA_real_]
  if (yr < 2025) x[, cbd_congestion_fee := NA_real_]
  sim_tlc_cast(x, "fhvhv", yr)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  fh <- sim_taxi_fhvhv(1000, "2022-06", seed = 1)
  str(fh)
  print(fh[, all(request_datetime <= pickup_datetime & pickup_datetime < dropoff_datetime)])
}
