# Simulated address points
#
# Real data: streets/address_points/AddressPoint_YYYYMMDD.csv (~970k building addresses), read
# with address_points_read(): borough (MANHATTAN ... STATEN ISLAND), b5sc (borough + 5-digit
# street code, shared by all names of a street), street (full street name), hn_lo, hn_hi (house
# number range; Queens "137-70" becomes 137070), parity (0 even side, 1 odd), longitude, latitude.
# Used by crashes_relocate() to place house-number crashes.
#
# Kept: one b5sc per street name and its borough digit; hn_hi >= hn_lo, parity from hn_lo;
# points where buildings are (cells of the real ones). Not kept: numbers that increase along the
# street, streets that run where their points are.
#
# ap <- sim_address_points(10000)

sim_address_points <- function(n = 1000, seed = NULL) {
  x <- sim_profile("address_points", n, seed)
  x[, b5sc := b5sc[1], by = street]
  boro_digit <- c(MANHATTAN = "1", BRONX = "2", BROOKLYN = "3", QUEENS = "4", "STATEN ISLAND" = "5")
  x[, borough := names(boro_digit)[match(substr(b5sc, 1, 1), boro_digit)]]
  x[, hn_lo := round(pmax(1, hn_lo))]
  x[, hn_hi := pmax(hn_lo, round(hn_hi))]
  x[, parity := hn_lo %% 2]
  x[]
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_address_points(10, seed = 1)))
}
