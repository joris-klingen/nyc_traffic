# Inspection of the street spells and panel (build/01_street_spells.R): figures in build/out/inspect/
#
# 1 network length in LION by borough (centerline: roadbed layers B and G)
# 2 bike lane km by facility and borough (layers B, R, N: roadbeds of divided streets count separately)
# 3 travel lanes: share of street length by lane count, LION vs the dated Manhattan panel
# 4 bike lanes in the spells on 2026-10-01 against the DOT 2026 bike route release
# 5 direction: bike lanes on one-way streets with or against traffic
# 6 maps: Manhattan bike lanes 2013 / 2019 / 2025, travel-lane changes 2016 -> 2025, date precision
# Run from repo root: Rscript build/checks_street_panel.R

library(data.table)
library(sf)
library(ggplot2)
library(patchwork)

source("R/streets.R")
out <- "build/out/inspect"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
boro_names <- c("1" = "Manhattan", "2" = "Bronx", "3" = "Brooklyn", "4" = "Queens", "5" = "Staten Island")
fac_cols <- c(Protected = "#1b7837", Standard = "#5aae61", Sharrows = "#c2a5cf", none = "grey80")
save <- function(p, f, w = 10, h = 6) { ggsave(file.path(out, f), p, width = w, height = h, dpi = 120, bg = "white"); print(p) }

ks <- key_segments_read()
ks[, borough := factor(boro_names[as.character(boro)], levels = boro_names)]

# 1 Network length ----
inl <- streets_panel("2012-07-01", "2026-07-01", "3 months", attributes = "in_lion", wide = FALSE)
inl <- merge(inl, ks[, .(key_id, length_ft, borough, rb_layer, rw_type)], by = "key_id")
net <- inl[rb_layer %in% c("B", "G") & rw_type %in% c("1", "2", "3", "4", "9"),
           .(km = sum(length_ft) * 0.3048 / 1000), by = .(date, borough, type = fifelse(rw_type == "1", "street", "highway, bridge, tunnel, ramp"))]
p1 <- ggplot(net[!is.na(borough)], aes(date, km, colour = borough)) + geom_line() + facet_wrap(~type, scales = "free_y") +
  labs(title = "Network in LION mapped to the 26c key segments (centerline km)",
       subtitle = "Rises as the key network fills in: segments that did not exist yet are not in the panel", x = NULL, y = "km") +
  theme_minimal()
save(p1, "1_network_length.png")
cat("network km, first and last date:\n"); print(dcast(net[date %in% range(date)], borough + type ~ date, value.var = "km"))

# 2 Bike lane km ----
bl <- streets_panel("2008-01-01", "2026-07-01", "3 months", attributes = "bike_lane", wide = FALSE)
bl <- merge(bl, ks[, .(key_id, length_ft, borough, rb_layer)], by = "key_id")[rb_layer %in% c("B", "R", "N")]
# street km with a facility (best of the two directions) and directional lane km
best <- bl[, .(fac = fcase(any(value == "Protected"), "Protected", any(value == "Standard"), "Standard",
                          any(value == "Sharrows"), "Sharrows", default = "none")), by = .(key_id, date, length_ft, borough)]
bkm <- best[fac != "none", .(km = sum(length_ft) * 0.3048 / 1000), by = .(date, borough, fac)]
bkm[, fac := factor(fac, levels = c("Sharrows", "Standard", "Protected"))]
p2 <- ggplot(bkm[!is.na(borough)], aes(date, km, fill = fac)) + geom_area() + facet_wrap(~borough, nrow = 1) +
  scale_fill_manual(values = fac_cols) +
  labs(title = "Street km with a bike facility (best direction), quarterly", x = NULL, y = "km", fill = NULL) +
  theme_minimal() + theme(legend.position = "bottom")
save(p2, "2_bike_lane_km.png", w = 14)
tot <- bkm[, .(km = round(sum(km))), by = .(date, fac)][date %in% as.IDate(c("2008-01-01", "2012-01-01", "2016-01-01", "2020-01-01", "2024-01-01", "2026-07-01"))]
cat("bike facility street km, citywide:\n"); print(dcast(tot, date ~ fac, value.var = "km")); fwrite(dcast(tot, date ~ fac, value.var = "km"), file.path(out, "2_bike_km.csv"))
cat("protected lane km (directional, both sides counted):\n")
print(bl[value == "Protected", .(km = sum(length_ft) * 0.3048 / 1000), by = date][date %in% tot[, date]])

# 3 Travel lanes ----
tlp <- streets_panel("2012-07-01", "2026-07-01", "3 months", attributes = "travel_lanes", boro = 1, wide = FALSE)
tlp <- merge(tlp, ks[, .(key_id, length_ft, rw_type)], by = "key_id")[rw_type == "1"]
lp <- streets_panel("2012-07-01", "2026-07-01", "3 months", attributes = "travel_lanes", boro = 1, wide = FALSE, sources = "lion")
lp <- merge(lp, ks[, .(key_id, length_ft, rw_type)], by = "key_id")[rw_type == "1"]
shares <- rbind(tlp[, .(version = "resolved (dated Manhattan panel)", date, lanes = pmin(as.numeric(value), 5), length_ft)],
                lp[, .(version = "LION per release", date, lanes = pmin(as.numeric(value), 5), length_ft)])
shares <- shares[, .(km = sum(length_ft)), by = .(version, date, lanes)][, share := km / sum(km), by = .(version, date)]
shares[, lanes_lab := factor(fifelse(lanes >= 5, "5+", as.character(lanes)), levels = c(0:4, "5+"))]
p3 <- ggplot(shares, aes(date, share, fill = lanes_lab)) +
  geom_area() + facet_wrap(~version) + scale_fill_viridis_d(direction = -1) + scale_y_continuous(labels = scales::percent) +
  labs(title = "Manhattan streets: share of street length by travel lanes", subtitle = "LION has lane counts from 16a and recounted in 24b",
       x = NULL, y = NULL, fill = "lanes") + theme_minimal()
save(p3, "3_travel_lanes_manhattan.png")

# 4 Against DOT 2026 ----
st <- streets_state("2026-10-01", attributes = "bike_lane", wide = FALSE)
st_best <- st[, .(spells = fcase(any(value == "Protected"), "Protected", any(value == "Standard"), "Standard",
                                any(value == "Sharrows"), "Sharrows", default = "none")), by = key_id]
dot <- setDT(st_drop_geometry(st_read(nyc_latest("bike_routes"), quiet = TRUE)))
dot <- dot[is.na(ret_date), .(SegmentID = as.integer(segmentid), cl = toupper(trimws(facilitycl)))][!is.na(SegmentID)]
dot[, dot := fcase(cl == "I", "Protected", cl == "II", "Standard", cl == "III", "Sharrows", default = "other")]
dot <- dot[, .(dot = fcase(any(dot == "Protected"), "Protected", any(dot == "Standard"), "Standard", any(dot == "Sharrows"), "Sharrows",
                           default = "other")), by = SegmentID]
dk <- segment_key_attach(dot, "SegmentID")[!is.na(key_id)]
dk <- dk[dk[, .I[which.max(key_cover)], by = key_id][, V1]]
cmp <- merge(dk[, .(key_id, dot)], st_best, by = "key_id", all = TRUE)
cmp[is.na(dot), dot := "not in DOT 2026"][is.na(spells), spells := "not in spells"]
cmp <- merge(cmp, ks[, .(key_id, borough)], by = "key_id", all.x = TRUE)
cat("spells (2026-10-01) vs DOT 2026 release, key segments:\n"); print(dcast(cmp[, .N, by = .(spells, dot)], spells ~ dot, value.var = "N", fill = 0))
fwrite(dcast(cmp[, .N, by = .(borough, spells, dot)], borough + spells ~ dot, value.var = "N", fill = 0), file.path(out, "4_spells_vs_dot2026.csv"))
cat("agreement on Manhattan segments in both:", cmp[borough == "Manhattan" & !dot %in% c("not in DOT 2026", "other") & spells != "not in spells", round(mean(dot == spells), 3)], "\n")

# 5 Direction on one-way streets ----
bw <- streets_state("2024-01-01", attributes = c("bike_lane", "traffic_dir"))
bw <- bw[traffic_dir %in% c("W", "A") & !is.na(bike_lane_tf)]
bw[, `:=`(with_traffic = fifelse(traffic_dir == "W", bike_lane_ft, bike_lane_tf), against = fifelse(traffic_dir == "W", bike_lane_tf, bike_lane_ft))]
dirtab <- bw[, .N, by = .(with_traffic = with_traffic != "none", against = against != "none")]
cat("one-way streets with bike lane records, 2024-01-01 (lane present with / against traffic):\n"); print(dirtab)
cat("against traffic only:", bw[with_traffic == "none" & against != "none", .N], "of", bw[with_traffic != "none" | against != "none", .N], "\n")

# 6 Maps ----
geom <- segment_versions_read()
geom <- geom[geom$last_release == max(segment_key_read()[, last_release]), "segment_id"]
names(geom)[1] <- "key_id"
man <- ks[boro == 1, key_id]
gm <- geom[geom$key_id %in% man, ]
base <- gm[gm$key_id %in% ks[boro == 1 & rw_type == "1" & rb_layer %in% c("B", "G"), key_id], ]
map_year <- function(d) {
  s <- streets_state(d, attributes = "bike_lane", boro = 1, wide = FALSE)
  s <- s[, .(fac = fcase(any(value == "Protected"), "Protected", any(value == "Standard"), "Standard",
                         any(value == "Sharrows"), "Sharrows", default = "none")), by = key_id][fac != "none"]
  x <- merge(gm, s, by = "key_id")
  ggplot() + geom_sf(data = base, colour = "grey85", linewidth = 0.15) +
    geom_sf(data = x, aes(colour = factor(fac, levels = names(fac_cols))), linewidth = 0.5) +
    scale_colour_manual(values = fac_cols, drop = FALSE) + labs(title = substr(d, 1, 4), colour = NULL) +
    theme_void() + theme(legend.position = "bottom")
}
p6 <- map_year("2013-01-01") + map_year("2019-01-01") + map_year("2025-01-01") + plot_layout(guides = "collect") &
  theme(legend.position = "bottom")
save(p6 + plot_annotation(title = "Manhattan bike facilities on 1 January"), "6a_map_bike_lanes_manhattan.png", w = 15, h = 9)

l16 <- streets_state("2016-06-01", attributes = "travel_lanes", boro = 1)[, .(key_id, l16 = travel_lanes)]
l25 <- streets_state("2025-06-01", attributes = "travel_lanes", boro = 1)[, .(key_id, l25 = travel_lanes)]
lc <- merge(l16, l25, by = "key_id")[, change := fcase(l25 < l16, "fewer", l25 > l16, "more", default = "same")]
x <- merge(gm, lc[change != "same"], by = "key_id")
p6b <- ggplot() + geom_sf(data = base, colour = "grey85", linewidth = 0.15) +
  geom_sf(data = x, aes(colour = change), linewidth = 0.6) + scale_colour_manual(values = c(fewer = "#b2182b", more = "#2166ac")) +
  labs(title = "Manhattan travel lanes, mid-2016 to mid-2025", subtitle = paste(lc[change == "fewer", .N], "segments fewer,", lc[change == "more", .N], "more"),
       colour = NULL) + theme_void()
save(p6b, "6b_map_travel_lane_change_manhattan.png", w = 7, h = 9)

prec <- streets_spells_read("bike_lane")[key_id %in% man & value != "none" & date_precision != "open"]
prec <- prec[prec[, .I[which.max(valid_from)], by = key_id][, V1]]
x <- merge(gm, prec[, .(key_id, date_precision)], by = "key_id")
p6c <- ggplot() + geom_sf(data = base, colour = "grey85", linewidth = 0.15) +
  geom_sf(data = x, aes(colour = date_precision), linewidth = 0.6) +
  scale_colour_manual(values = c(verified = "#1b7837", day = "#2166ac", month = "#f4a582", year = "#b2182b", release = "grey40")) +
  labs(title = "Manhattan bike lanes: precision of the latest change date", colour = NULL) + theme_void()
save(p6c, "6c_map_date_precision_manhattan.png", w = 7, h = 9)
cat("precision of latest bike lane date, Manhattan:\n"); print(prec[, .N, by = date_precision])
