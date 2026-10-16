# Simulated crash persons
#
# Real data: crashes/Motor_Vehicle_Collisions_-_Person_YYYYMMDD.csv (~5.8M rows), read raw with
# data.table::fread(nyc_latest("persons")). One row per person involved: UNIQUE_ID,
# COLLISION_ID, CRASH_DATE (text MM/DD/YYYY), CRASH_TIME (text H:MM), PERSON_ID (UUID),
# PERSON_TYPE (Occupant, Pedestrian, Bicyclist, Other Motorized), PERSON_INJURY (Unspecified,
# Injured, Killed), VEHICLE_ID (= vehicles UNIQUE_ID; NA for pedestrians), PERSON_AGE, EJECTION,
# EMOTIONAL_STATUS, BODILY_INJURY, POSITION_IN_VEHICLE, SAFETY_EQUIPMENT, PED_LOCATION,
# PED_ACTION, COMPLAINT, PED_ROLE (Driver, Passenger, Pedestrian, Registrant, ...),
# CONTRIBUTING_FACTOR_1, _2, PERSON_SEX. Only crashes since 2016 have person rows for everyone.
#
# Kept: per crash, a driver for every vehicle (sim_crash_vehicles()), a few passengers, and the
# crash's injured and killed pedestrians and cyclists as their own persons; PERSON_INJURY matches
# the crash's counts by road user (cyclists are linked to a vehicle, the bike, as in the real
# data); pedestrian columns only for pedestrians. Not kept: ages and injuries that go together.
#
# cr <- sim_crashes(2000); veh <- sim_crash_vehicles(cr); per <- sim_crash_persons(cr, veh)

sim_crash_persons <- function(crashes = sim_crashes(), vehicles = sim_crash_vehicles(crashes), seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  cr <- crashes[, .(COLLISION_ID = collision_id, crash_date, crash_time, ped_inj = number_of_pedestrians_injured,
                    ped_kil = number_of_pedestrians_killed, cyc_inj = number_of_cyclist_injured, cyc_kil = number_of_cyclist_killed,
                    mot_inj = number_of_motorist_injured, mot_kil = number_of_motorist_killed)]
  # drivers and passengers of motor vehicles; cyclists replace the occupant of a "Bike" vehicle
  occ <- vehicles[, .(COLLISION_ID, VEHICLE_ID = UNIQUE_ID, n = 1L + stats::rpois(.N, 0.3))]
  # enough occupants for the crash's injured and killed motorists (extra ones in the first vehicle)
  need <- cr[, .(COLLISION_ID, m = mot_inj + mot_kil)]
  occ[need, on = "COLLISION_ID", m := i.m]
  occ[, first := seq_len(.N) == 1L, by = COLLISION_ID]
  occ[, short := pmax(0L, m - sum(n)), by = COLLISION_ID]
  occ[first == TRUE, n := n + short]
  occ[, c("m", "first", "short") := NULL]
  occ <- occ[rep(seq_len(.N), n)][, PED_ROLE := fifelse(seq_len(.N) == 1L, "Driver", "Passenger"), by = VEHICLE_ID]
  occ[, `:=`(PERSON_TYPE = "Occupant", n = NULL)]
  cyc <- cr[cyc_inj + cyc_kil > 0, .(COLLISION_ID, n = cyc_inj + cyc_kil, kil = cyc_kil)]
  cyc <- cyc[rep(seq_len(.N), n)][, .(COLLISION_ID, PERSON_TYPE = "Bicyclist", PED_ROLE = "Driver",
                                      PERSON_INJURY = fifelse(seq_len(.N) <= kil, "Killed", "Injured")), by = .(g = COLLISION_ID)][, g := NULL]
  cyc[vehicles, on = "COLLISION_ID", VEHICLE_ID := i.UNIQUE_ID, mult = "last"]
  ped <- cr[ped_inj + ped_kil > 0, .(COLLISION_ID, n = ped_inj + ped_kil, kil = ped_kil)]
  ped <- ped[rep(seq_len(.N), n)][, .(COLLISION_ID, PERSON_TYPE = "Pedestrian", PED_ROLE = "Pedestrian", VEHICLE_ID = NA_integer_,
                                      PERSON_INJURY = fifelse(seq_len(.N) <= kil, "Killed", "Injured")), by = .(g = COLLISION_ID)][, g := NULL]
  p <- rbindlist(list(occ, cyc, ped), fill = TRUE)
  # motorists injured and killed: the first occupants of the crash
  p[PERSON_TYPE == "Occupant", i := seq_len(.N), by = COLLISION_ID]
  p[cr, on = "COLLISION_ID", `:=`(mk = i.mot_kil, mi = i.mot_inj)]
  p[PERSON_TYPE == "Occupant", PERSON_INJURY := fcase(i <= mk, "Killed", i <= mk + mi, "Injured", default = "Unspecified")]
  p[, c("i", "mk", "mi") := NULL]
  setorder(p, COLLISION_ID)
  x <- sim_profile("crash_persons", nrow(p))
  for (v in c("COLLISION_ID", "PERSON_TYPE", "PERSON_INJURY", "VEHICLE_ID", "PED_ROLE")) set(x, j = v, value = p[[v]])
  x[cr, on = "COLLISION_ID", `:=`(CRASH_DATE = format(i.crash_date, "%m/%d/%Y"), CRASH_TIME = i.crash_time)]
  x[, UNIQUE_ID := 20000000L + seq_len(.N)]
  x[, PERSON_ID := sprintf("%s-%s-%s-%s-%s", sim_ids(.N, "hex", 8, 8), sim_ids(.N, "hex", 4, 4), sim_ids(.N, "hex", 4, 4),
                           sim_ids(.N, "hex", 4, 4), sim_ids(.N, "hex", 12, 12))]
  x[PERSON_TYPE != "Pedestrian", c("PED_LOCATION", "PED_ACTION") := NA_character_]
  x[PERSON_TYPE == "Pedestrian", c("POSITION_IN_VEHICLE", "EJECTION") := NA_character_]
  x[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  cr <- sim_crashes(1000, seed = 1)
  per <- sim_crash_persons(cr)
  print(per[, .N, .(PERSON_TYPE, PERSON_INJURY)])
  print(cr[, sum(number_of_persons_injured)]); print(per[PERSON_INJURY == "Injured", .N])
}
