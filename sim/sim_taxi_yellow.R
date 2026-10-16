# Simulated yellow taxi trips
#
# Real data: taxi/yellow/yellow_tripdata_YYYY-MM.parquet, 2012-01 onward (176 months, ~1.6 billion
# trips), read with tlc_open("yellow") or arrow::read_parquet(tlc_files("yellow")). One row per
# trip: VendorID, tpep_pickup_datetime, tpep_dropoff_datetime (local clock time stored as UTC),
# passenger_count, trip_distance (miles), RatecodeID, store_and_fwd_flag, PULocationID,
# DOLocationID (TLC taxi zones 1-265, see sim_taxi_zones()), payment_type, fare_amount, extra,
# mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge
# (2019 on), Airport_fee (2022 on; airport_fee in some years), cbd_congestion_fee (2025 on).
# Column types change between years (int64 vs double): profiles/taxi_yellow_schema_by_year.csv.
#
# Kept: the columns and types of the requested month's year; pickups spread over the month by the
# real hour-of-week pattern; dropoff after pickup at a plausible speed for the distance;
# total_amount the sum of the fare parts; the value shares of codes and fees (profiles/taxi_yellow.csv,
# pooled over 2013, 2019 and 2025). Not kept: zone-to-zone patterns, fares that follow distance,
# changes in fares and trip counts over the years.
#
# tt <- sim_taxi_yellow(10000, month = "2019-06")

sim_taxi_yellow <- function(n = 1000, month = "2025-06", seed = NULL) {
  x <- sim_profile("taxi_yellow", n, seed)
  r <- sim_month_range(month, tz = "UTC")
  x[, tpep_pickup_datetime := sim_times(n, r[["from"]], r[["to"]], "taxi_yellow", tz = "UTC")]
  x[, trip_distance := pmax(0, trip_distance)]
  mph <- stats::rlnorm(n, log(11), 0.35)
  x[, tpep_dropoff_datetime := tpep_pickup_datetime + round(60 + pmin(trip_distance, 80) / mph * 3600)]
  parts <- intersect(c("fare_amount", "extra", "mta_tax", "tip_amount", "tolls_amount", "improvement_surcharge",
                       "congestion_surcharge", "Airport_fee", "cbd_congestion_fee"), names(x))
  yr <- as.integer(substr(month, 1, 4))
  # fees that did not exist yet are absent in that year's schema; zero them before summing
  if (yr < 2019) x[, congestion_surcharge := NA_real_]
  if (yr < 2025) x[, cbd_congestion_fee := NA_real_]
  x[, total_amount := round(rowSums(.SD, na.rm = TRUE), 2), .SDcols = parts]
  sim_tlc_cast(x, "yellow", yr)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  tt <- sim_taxi_yellow(1000, "2019-06", seed = 1)
  str(tt)
  print(summary(as.numeric(tt[, tpep_dropoff_datetime - tpep_pickup_datetime], units = "mins")))
}
