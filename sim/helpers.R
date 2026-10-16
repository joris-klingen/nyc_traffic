# Helpers shared by the simulators in sim/ (loaded by sim/sim.R)

# read a reference table from profiles/ (lookups, station lists, hour-of-week shares, ...)
sim_ref <- function(file, ...) data.table::fread(file.path(sim_profiles_dir(), file), na.strings = "", ...)

# n timestamps in [from, to) that follow the hour-of-week shares of a source
# (profiles/<source>_hour_of_week.csv: Monday 0:00 = 1 ... Sunday 23:00 = 168)
sim_times <- function(n, from, to, source = NULL, tz = "America/New_York") {
  from <- as.POSIXct(from, tz = tz); to <- as.POSIXct(to, tz = tz)
  hours <- seq(from, to - 1, by = "hour")
  if (is.null(source)) {
    w <- rep(1, length(hours))
  } else {
    sh <- sim_ref(paste0(source, "_hour_of_week.csv"))
    how <- ((data.table::wday(hours) + 5L) %% 7L) * 24L + data.table::hour(hours) + 1L
    w <- sh[match(how, hour_of_week), share]
  }
  h <- sample(seq_along(hours), n, replace = TRUE, prob = w + 1e-9)
  sort(hours[h] + stats::runif(n, 0, 3600))
}

# first and last moment of a month "YYYY-MM"
sim_month_range <- function(month, tz = "America/New_York") {
  from <- as.POSIXct(paste0(month, "-01"), tz = tz)
  to <- as.POSIXct(seq(as.Date(paste0(month, "-01")), by = "month", length.out = 2)[2], tz = tz)
  list(from = from, to = to)
}

# columns and R types of a TLC trip type in a given year (profiles/taxi_<type>_schema_by_year.csv)
sim_tlc_schema <- function(type, year) {
  s <- sim_ref(paste0("taxi_", type, "_schema_by_year.csv"))
  yr <- as.integer(year)
  y <- max(s[year <= yr, year], min(s[, year]))
  s <- s[year == y]
  s[, r_type := data.table::fcase(grepl("^int", type), "integer", grepl("^double|^float", type), "numeric",
                                  grepl("string", type), "character", grepl("^timestamp", type), "POSIXct",
                                  type == "null", "logical", default = "character")]
  s[]
}

# cast a simulated TLC table to the columns and types of one year, NA for columns new that year
sim_tlc_cast <- function(x, type, year) {
  s <- sim_tlc_schema(type, year)
  # some years spell a column differently (Airport_fee / airport_fee)
  lower <- setNames(names(x), tolower(names(x)))
  out <- data.table::data.table(.row = seq_len(nrow(x)))
  for (i in seq_len(nrow(s))) {
    v <- s[i, column]; rt <- s[i, r_type]
    src <- if (v %in% names(x)) v else lower[tolower(v)]
    y <- if (!is.na(src)) x[[src]] else NA
    y <- switch(rt, integer = as.integer(round(y)), numeric = as.numeric(y), character = as.character(y),
                POSIXct = y, logical = as.logical(rep(NA, nrow(x))), y)
    if (length(y) == 1L) y <- rep(y, nrow(x))
    data.table::set(out, j = v, value = y)
  }
  out[, .row := NULL][]
}
