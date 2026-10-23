# Simulated parking signs
#
# Real data: raw/street_layout/parking/Parking_Regulation_Locations_and_Signs_20261014.csv, read with
# data.table::fread(nyc_latest('parking_signs')); 441,509 rows, returned as a data.table.
# Parking regulation signs: one row per sign with the DOT order number, sign description and
# code, on / from / to street, side of street, sign position (x, y) and the date the order was
# completed (order_completed_on_date).
# Columns: order_number, record_type, order_type, borough, on_street, on_street_suffix,
# from_street, from_street_suffix, to_street, to_street_suffix, side_of_street,
# order_completed_on_date, sign_code, sign_description, sign_size, sign_design_voided_on_date,
# sign_location, distance_from_intersection, arrow_direction, facing_direction, sheeting_type,
# support, sign_notes, sign_x_coord, sign_y_coord (profiles/parking_signs.csv).
#
# Kept: column types, NA shares and value shares (dates as text in the file's format). Not
# kept: relations between columns (streets that match the location, dates in order).
#
# x <- sim_parking_signs(500)

sim_parking_signs <- function(n = 1000, seed = NULL) sim_profile("parking_signs", n, seed)

if (sys.nframe() == 0) {
  source("sim/sim.R")
  print(head(sim_parking_signs(10, seed = 1)))
}
