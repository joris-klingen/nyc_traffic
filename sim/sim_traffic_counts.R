# Simulated DOT automated traffic counts (ATR)
#
# Real data: raw/traffic_counts/automated/Automated_Traffic_Volume_Counts_YYYYMMDD.csv (~1.7M rows),
# read with traffic_counts_read(). One row per 15 minutes, direction and count location, from
# short campaigns (usually a week or two) at changing locations since 2006: RequestID (campaign),
# Boro, Yr, M, D, HH, MM, Vol (vehicles in the 15 minutes), SegmentID (LION), WktGeom (point in
# EPSG 2263), street, fromSt, toSt, Direction (NB, SB, EB, WB), plus time (POSIXct,
# America/New_York) and x, y (EPSG 2263) added by the reader.
#
# Kept: real count locations (SegmentID, point, borough and streets together, with their share of
# rows: profiles/traffic_counts_locations.csv); campaigns of `days` days at a random start in
# [from, to], one or two directions (NB/SB or EB/WB); volumes that follow the real hour-of-week
# pattern around a level per location drawn from the profiled volumes. Not kept: volumes that
# fit the street type, campaigns repeated at the same place.
#
# tc <- sim_traffic_counts(30, days = 14, from = "2018-01-01", to = "2019-12-31")

sim_traffic_counts <- function(n_locations = 20, days = 7, from = "2014-01-01", to = "2025-12-31", seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  tz <- "America/New_York"
  loc <- sim_ref("traffic_counts_locations.csv")
  loc <- loc[sample(.N, min(n_locations, .N), prob = share)]
  sh <- sim_ref("traffic_counts_hour_of_week.csv")
  vol <- sim_profile("traffic_counts", nrow(loc))[, Vol]
  out <- rbindlist(lapply(seq_len(nrow(loc)), function(i) {
    start <- as.POSIXct(format(sample(seq(as.Date(from), as.Date(to) - days, by = "day"), 1)), tz = tz)
    t <- seq(start, by = "15 min", length.out = days * 96)
    dirs <- if (stats::runif(1) < 0.5) c("NB", "SB") else c("EB", "WB")
    if (stats::runif(1) < 0.3) dirs <- dirs[1]
    how <- ((data.table::wday(t) + 5L) %% 7L) * 24L + data.table::hour(t) + 1L
    pattern <- sh[match(how, hour_of_week), share] * 168
    level <- max(1, vol[i])
    rbindlist(lapply(dirs, function(d) data.table(RequestID = 30000L + i, time = t, Direction = d,
                                                   Vol = as.integer(stats::rpois(length(t), level * pattern)))))
  }), idcol = "loc")
  out <- cbind(out, loc[out[, loc], .(SegmentID, WktGeom, x, y, Boro, street, fromSt, toSt)])
  out[, `:=`(Yr = data.table::year(time), M = data.table::month(time), D = data.table::mday(time),
             HH = data.table::hour(time), MM = data.table::minute(time), loc = NULL)]
  setcolorder(out, c("WktGeom", "x", "y", "RequestID", "Boro", "Yr", "M", "D", "HH", "MM", "Vol", "SegmentID",
                     "street", "fromSt", "toSt", "Direction", "time"))
  out[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  tc <- sim_traffic_counts(5, seed = 1)
  str(tc)
  print(tc[, .(vol = mean(Vol)), HH][order(HH)])
}
