# Simulated EPA AQS monitor data (NYC area)
#
# Real data: derived/air_pollution/{hourly,daily}_<param>.parquet (scripts/41_air_pollution_nyc.R
# from the national EPA AQS files, 2012 onward), read with air_pollution_read(param, freq).
# hourly: one row per monitor (site_id, poc) and local hour: state_code, county_code, site_num,
# parameter_code, poc, latitude, longitude, datum, parameter_name, date_local, time_local,
# date_gmt, time_gmt (times as text "13:00"), sample_measurement, units_of_measure, mdl, uncertainty, qualifier,
# method_type, method_code, method_name, state_name, county_name, date_of_last_change, site_id,
# nyc (in the five boroughs). daily: one row per monitor, day and pollutant standard with
# arithmetic_mean, first_max_value, aqi, ... Profiled for ozone (44201, ppm); other parameters
# have the same columns.
#
# Kept: `sites` monitors with their attributes (one location and county per site), every hour
# (or day) from `from` to `to`; hourly ozone with its afternoon peak and summer high around the
# profiled levels; GMT = local + 5 hours (EST, as in AQS). Not kept: missing hours, other
# pollutants' levels and units.
#
# ap <- sim_air_pollution("hourly", from = "2019-06-01", to = "2019-06-30")

sim_air_pollution <- function(freq = c("hourly", "daily"), from = "2019-06-01", to = "2019-06-07", sites = 8, seed = NULL) {
  freq <- match.arg(freq)
  if (!is.null(seed)) set.seed(seed)
  src <- paste0("air_pollution_", freq)
  s <- sim_profile(src, sites)
  s[, site_id := sprintf("%s-%s-%04d", state_code, county_code, as.integer(sample(1:200, .N)))]
  days <- seq(as.Date(from), as.Date(to), by = "day")
  if (freq == "hourly") {
    g <- CJ(k = seq_len(nrow(s)), date_local = days, hour = 0:23)
    out <- s[g[, k]]
    out[, `:=`(date_local = g[, date_local], time_local = sprintf("%02d:00", g[, hour]))]
    gmt <- as.POSIXct(paste(out[, date_local], "00:00"), tz = "UTC") + (g[, hour] + 5L) * 3600
    out[, `:=`(date_gmt = as.Date(gmt), time_gmt = format(gmt, "%H:00"))]
    level <- stats::median(s[, sample_measurement], na.rm = TRUE)
    diurnal <- 0.6 + 0.8 * pmax(0, sin((g[, hour] - 7) / 24 * 2 * pi))
    season <- 1 + 0.4 * cos((as.numeric(format(out[, date_local], "%j")) - 190) / 365 * 2 * pi)
    out[, sample_measurement := round(pmax(0, level * diurnal * season * stats::rlnorm(.N, 0, 0.25)), 3)]
  } else {
    g <- CJ(k = seq_len(nrow(s)), date_local = days)
    out <- s[g[, k]]
    out[, date_local := g[, date_local]]
  }
  setorder(out, site_id, date_local)
  out[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  ap <- sim_air_pollution("hourly", seed = 1)
  print(ap[, .(ozone = mean(sample_measurement)), time_local])
}
