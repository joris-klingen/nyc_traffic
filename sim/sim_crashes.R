# Simulated NYPD motor vehicle crashes
#
# Real data: raw/crashes/Motor_Vehicle_Collisions_-_Crashes_YYYYMMDD.csv (2.27M crashes from 2012-07),
# read with crashes_read() (snake_case names, coordinates outside NYC as NA, crash_date IDate).
# One row per police-reported crash (someone injured or killed, or damage over $1,000):
# crash_date, crash_time (text "H:MM"), borough, zip_code (NA for 30%: highways, bridges),
# latitude, longitude (NA for 11%), location "(lat, lon)", on_street_name, cross_street_name,
# off_street_name (an address when the crash is not at a junction), number_of_persons_injured /
# _killed and the same for pedestrians, cyclist and motorist, contributing_factor_vehicle_1..5,
# collision_id (links persons and vehicles), vehicle_type_code_1..5. House-number crashes were
# geocoded to address points from 2024-11: use crashes_relocate() for consistent locations.
#
# Kept: collision_id unique and increasing with the date; injured and killed totals the sums over
# road users; vehicle columns filled for vehicles 1..k and NA after (k vehicles, as in the real
# shares: 80% two or more); location text from the coordinates; borough and zip code missing
# together; coordinates where crashes happen (cells of the real ones). Not kept: streets that
# match the coordinates, the decline in crashes after 2019.
#
# cr <- sim_crashes(5000, from = "2018-01-01", to = "2019-12-31")

sim_crashes <- function(n = 1000, from = NULL, to = NULL, seed = NULL) {
  x <- sim_profile("crashes", n, seed)
  if (!is.null(from) || !is.null(to)) {
    d <- seq(as.Date(if (is.null(from)) "2012-07-01" else from), as.Date(if (is.null(to)) "2026-09-30" else to), by = "day")
    x[, crash_date := as.IDate(sample(d, .N, replace = TRUE))]
  }
  setorder(x, crash_date, crash_time)
  x[, collision_id := 3000000L + cumsum(sample.int(3L, .N, replace = TRUE))]
  x[, location := fifelse(is.na(latitude), NA_character_, sprintf("(%.6f, %.6f)", latitude, longitude))]
  x[is.na(borough), zip_code := NA_character_]
  x[is.na(zip_code), borough := NA_character_]
  x[, number_of_persons_injured := number_of_pedestrians_injured + number_of_cyclist_injured + number_of_motorist_injured]
  x[, number_of_persons_killed := number_of_pedestrians_killed + number_of_cyclist_killed + number_of_motorist_killed]
  # vehicles: k per crash, columns 1..k filled
  k <- sample(1:5, n, replace = TRUE, prob = c(0.20, 0.73, 0.054, 0.012, 0.004))
  for (j in 1:5) {
    tv <- paste0("vehicle_type_code_", j); cf <- paste0("contributing_factor_vehicle_", j)
    for (v in c(tv, cf)) {
      pool <- x[[v]][!is.na(x[[v]])]
      if (!length(pool)) pool <- x[[sub("_[0-9]$", "_1", v)]][!is.na(x[[sub("_[0-9]$", "_1", v)]])]
      y <- x[[v]]
      fill <- k >= j & is.na(y)
      y[fill] <- sample(pool, sum(fill), replace = TRUE)
      y[k < j] <- NA_character_
      set(x, j = v, value = y)
    }
  }
  x[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  cr <- sim_crashes(2000, seed = 1)
  str(cr)
  print(cr[, .(injured = sum(number_of_persons_injured), two_plus = mean(!is.na(vehicle_type_code_2)))])
}
