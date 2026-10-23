# Simulated crash vehicles
#
# Real data: raw/crashes/Motor_Vehicle_Collisions_-_Vehicles_YYYYMMDD.csv (~4.5M rows), read raw with
# data.table::fread(nyc_latest("vehicles")). One row per vehicle in a crash: UNIQUE_ID,
# COLLISION_ID (crashes collision_id), CRASH_DATE (text MM/DD/YYYY), CRASH_TIME (text H:MM),
# VEHICLE_ID (text, a number or a UUID), STATE_REGISTRATION, VEHICLE_TYPE, VEHICLE_MAKE,
# VEHICLE_MODEL, VEHICLE_YEAR, TRAVEL_DIRECTION, VEHICLE_OCCUPANTS, DRIVER_SEX,
# DRIVER_LICENSE_STATUS, DRIVER_LICENSE_JURISDICTION, PRE_CRASH, POINT_OF_IMPACT,
# VEHICLE_DAMAGE (_1, _2, _3), PUBLIC_PROPERTY_DAMAGE (_TYPE), CONTRIBUTING_FACTOR_1, _2.
# Persons link to vehicles by persons VEHICLE_ID = vehicles UNIQUE_ID.
#
# Kept: one row per vehicle of each simulated crash (the vehicle_type_code_j that are filled),
# with the crash's id, date and time, VEHICLE_TYPE and CONTRIBUTING_FACTOR_1 from the crash's
# vehicle j; UNIQUE_ID unique. Not kept: make, model and year that go together.
#
# cr <- sim_crashes(2000); veh <- sim_crash_vehicles(cr)

sim_crash_vehicles <- function(crashes = sim_crashes(), seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  long <- rbindlist(lapply(1:5, function(j) crashes[!is.na(get(paste0("vehicle_type_code_", j))),
    .(COLLISION_ID = collision_id, crash_date, crash_time, j = j,
      VEHICLE_TYPE = get(paste0("vehicle_type_code_", j)), CONTRIBUTING_FACTOR_1 = get(paste0("contributing_factor_vehicle_", j)))]))
  setorder(long, COLLISION_ID, j)
  x <- sim_profile("crash_vehicles", nrow(long))
  x[, `:=`(UNIQUE_ID = 10000000L + seq_len(.N), COLLISION_ID = long[, COLLISION_ID],
           CRASH_DATE = format(long[, crash_date], "%m/%d/%Y"), CRASH_TIME = long[, crash_time],
           VEHICLE_ID = as.character(long[, j]), VEHICLE_TYPE = long[, VEHICLE_TYPE],
           CONTRIBUTING_FACTOR_1 = long[, CONTRIBUTING_FACTOR_1])]
  x[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  cr <- sim_crashes(500, seed = 1)
  v <- sim_crash_vehicles(cr)
  print(head(v[, 1:8]))
  print(v[, .N, COLLISION_ID][, mean(N)])
}
