# Simulated green taxi (boro taxi) trips
#
# Real data: taxi/green/green_tripdata_YYYY-MM.parquet, 2014-01 onward (152 months), read with
# tlc_open("green"). One row per trip, mostly outside Manhattan below 110th St: VendorID,
# lpep_pickup_datetime, lpep_dropoff_datetime (local clock stored as UTC), store_and_fwd_flag,
# RatecodeID, PULocationID, DOLocationID, passenger_count, trip_distance, fare_amount, extra,
# mta_tax, tip_amount, tolls_amount, ehail_fee (almost always NA), improvement_surcharge,
# total_amount, payment_type, trip_type (1 street hail, 2 dispatch), congestion_surcharge (2019
# on), cbd_congestion_fee (2025 on). Types per year: profiles/taxi_green_schema_by_year.csv.
#
# Kept and not kept: as sim_taxi_yellow().
#
# tg <- sim_taxi_green(5000, month = "2016-06")

sim_taxi_green <- function(n = 1000, month = "2025-06", seed = NULL) {
  x <- sim_profile("taxi_green", n, seed)
  r <- sim_month_range(month, tz = "UTC")
  x[, lpep_pickup_datetime := sim_times(n, r[["from"]], r[["to"]], "taxi_green", tz = "UTC")]
  x[, trip_distance := pmax(0, trip_distance)]
  mph <- stats::rlnorm(n, log(12), 0.35)
  x[, lpep_dropoff_datetime := lpep_pickup_datetime + round(60 + pmin(trip_distance, 80) / mph * 3600)]
  yr <- as.integer(substr(month, 1, 4))
  if (yr < 2019) x[, congestion_surcharge := NA_real_]
  if (yr < 2025) x[, cbd_congestion_fee := NA_real_]
  parts <- intersect(c("fare_amount", "extra", "mta_tax", "tip_amount", "tolls_amount", "improvement_surcharge",
                       "ehail_fee", "congestion_surcharge", "cbd_congestion_fee"), names(x))
  x[, total_amount := round(rowSums(.SD, na.rm = TRUE), 2), .SDcols = parts]
  sim_tlc_cast(x, "green", yr)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  str(sim_taxi_green(1000, "2016-06", seed = 1))
}
