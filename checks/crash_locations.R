# How are crashes without a house number located, and which have no coordinates?
#
# - Intersection crashes (on + cross street) sit on the LION node of the two streets (~96%).
# - Street-only crashes (on street, no cross street or address) are mostly highways. Highway
#   crashes lie along the named highway, surface-street ones on a node of the named street: the
#   cross street was known but is not in the published text.
# - About 11% of crashes have no coordinates. crashes_relocate() fills intersection crashes from
#   the LION node where the two streets meet and address crashes from the address point; this
#   script checks the node method against crashes that do have coordinates.
#
# Run from the repo root: Rscript checks/crash_locations.R

library(data.table)
library(sf)
source("R/nyc_transport.R")

# Crashes ----
cr <- crashes_read()
streets <- nyc_street_codes()
nodes <- nyc_street_nodes()
cr <- crashes_relocate(cr, streets = streets, nodes = nodes)
cr[, yr := year(crash_date)]
cr[, gtype := fifelse(!is.na(off_street_name), "address", fifelse(!is.na(cross_street_name), "intersection",
              fifelse(!is.na(on_street_name), "on street only", "no location text")))]
cr[, had_xy := !is.na(latitude)]

# Missing coordinates ----
print(cr[, .(N = .N, no_xy = sum(!had_xy), share_no_xy = round(mean(!had_xy), 3),
             filled = sum(!had_xy & !is.na(latitude_ap))), gtype][order(-N)])
print(cr[, .(missing_before = round(mean(!had_xy), 3), missing_after = round(mean(is.na(latitude_ap)), 3)), yr][order(yr)])

# Placement of intersection and street-only crashes ----
set.seed(1)
s <- cr[had_xy == TRUE & gtype %in% c("on street only", "intersection") & yr >= 2016][, .SD[sample(.N, min(.N, 20000))], gtype]
p <- st_transform(st_as_sf(s, coords = c("longitude", "latitude"), crs = 4326), 2263)
nd <- st_transform(st_as_sf(unique(nodes[, .(node, longitude, latitude)]), coords = c("longitude", "latitude"), crs = 4326), 2263)
s[, node_ft := as.numeric(st_distance(p, nd[st_nearest_feature(p, nd), ], by_element = TRUE))]

# distance to the named street: nearest LION line with one of the name's street codes
lines <- nyc_street_lines()
s[, key := nyc_street_key(on_street_name)]
k <- streets[s[, .(collision_id, borough, key)], on = "key", nomatch = 0L, allow.cartesian = TRUE, .(collision_id, b5sc, sb = x.borough, cb = i.borough)]
k <- unique(k[is.na(cb) | cb == sb, .(collision_id, b5sc)])
pid <- setNames(seq_len(nrow(s)), s[, collision_id])
s[, street_ft := NA_real_]
for (b in intersect(unique(k[, b5sc]), lines[["b5sc"]])) {
  i <- pid[as.character(k[b5sc == b, collision_id])]
  l <- lines[lines[["b5sc"]] == b, ]
  d <- as.numeric(st_distance(p[i, ], l[st_nearest_feature(p[i, ], l), ], by_element = TRUE))
  s[i, street_ft := pmin(street_ft, d, na.rm = TRUE)]
}
s[, highway := grepl("EXPRESSWAY|EXPY|EXPWY|PARKWAY|PKWY|BRIDGE|TUNNEL|FDR|HIGHWAY|TURNPIKE|BQE", on_street_name)]
print(s[, .(N = .N, at_node_10ft = round(mean(node_ft < 10), 3), named_street_found = round(mean(!is.na(street_ft)), 3),
            on_named_street_50ft = round(mean(street_ft < 50, na.rm = TRUE), 3), node_ft_median = round(median(node_ft))),
        .(gtype, highway)][order(gtype, highway)])
print(head(cr[gtype == "on street only", .N, on_street_name][order(-N)], 15))

# Intersection nodes vs known coordinates ----
it <- cr[gtype == "intersection" & had_xy == TRUE & yr >= 2016][sample(.N, 50000)]
g <- crashes_intersection_nodes(it, streets, nodes)
it <- g[it, on = "collision_id"]
it[, err_ft := sqrt(((i.longitude - longitude) * 276500)^2 + ((i.latitude - latitude) * 364000)^2)]
print(it[, .(N = .N, located = round(mean(!is.na(longitude)), 3), err_median_ft = round(median(err_ft, na.rm = TRUE)),
             within_150ft = round(mean(err_ft < 150, na.rm = TRUE), 3), over_1000ft = round(mean(err_ft > 1000, na.rm = TRUE), 4)),
         .(borough_known = !is.na(borough))])
