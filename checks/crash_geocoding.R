# Where do Manhattan crashes sit along their block?
#
# Crashes geocoded from a house number ("250 WEST 34 STREET", in OFF STREET NAME) are placed by
# interpolating the number along the LION segment's address range. On the numbered cross streets
# they pile up toward the low-number end (5th Ave / Central Park): west on the East Side, east on
# the West Side. The skew is strongest where LION pads the range to xx98/xx99. Traffic direction
# plays no role. Intersection-coded crashes sit on LION nodes.
#
# crashes_relocate() moves these crashes to the address point of the building, snapped onto the
# street centerline. This script compares the original and relocated positions.
#
# Run from the repo root: Rscript checks/crash_geocoding.R
# Writes figures to output/crash_geocoding/

library(data.table)
library(sf)
library(ggplot2)
source("R/nyc_data.R")

out_dir <- "output/crash_geocoding"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Crashes ----
cr <- crashes_read(select = c("CRASH DATE", "BOROUGH", "LATITUDE", "LONGITUDE", "ON STREET NAME",
                              "CROSS STREET NAME", "OFF STREET NAME", "COLLISION_ID"))
cr <- crashes_relocate(cr)
print(cr[!is.na(off_street_name), .N, loc_method][, share := round(N / sum(N), 3)][])

cr <- cr[!is.na(latitude) & latitude > 40.69 & latitude < 40.89 & longitude > -74.03 & longitude < -73.90]
cr[, yr := year(crash_date)]
cr[, gtype := fifelse(!is.na(off_street_name), "address",
              fifelse(!is.na(cross_street_name), "intersection", "on street only"))]
print(dcast(cr[, .N, .(yr, gtype)], yr ~ gtype, value.var = "N"))
to_ft <- function(lon, lat) st_coordinates(st_transform(st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326), 2263))
xy <- to_ft(cr[, longitude], cr[, latitude])
cr[, `:=`(X = xy[, 1], Y = xy[, 2])]
xy <- to_ft(cr[, longitude_ap], cr[, latitude_ap])
cr[, `:=`(Xa = xy[, 1], Ya = xy[, 2])]

# LION ----
lion_gdb <- paste0("/vsizip/", nyc_latest("lion"), "/lion/lion.gdb")
# type = 5 linearizes the curved segments, which GEOS cannot handle
ln <- st_read(lion_gdb, quiet = TRUE, type = 5, query =
  "SELECT Street, RW_TYPE, FeatureTyp FROM lion WHERE LBoro = 1 AND FeatureTyp IN ('0','6','C')")
ln <- st_zm(ln[trimws(ln[["RW_TYPE"]]) == "1", ])

segs <- as.data.table(st_drop_geometry(st_read(lion_gdb, quiet = TRUE, query =
  "SELECT Street, RW_TYPE, TrafDir, XFrom, YFrom, XTo, YTo, LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen
   FROM lion WHERE LBoro = 1 AND FeatureTyp = '0' AND (Street LIKE 'EAST %STREET' OR Street LIKE 'WEST %STREET')")))
segs <- segs[trimws(RW_TYPE) == "1"]
for (v in c("LLo_Hyphen", "LHi_Hyphen", "RLo_Hyphen", "RHi_Hyphen")) set(segs, j = v, value = suppressWarnings(as.integer(segs[[v]])))
segs[, `:=`(lo = pmin(LLo_Hyphen, RLo_Hyphen, na.rm = TRUE), hi = pmax(LHi_Hyphen, RHi_Hyphen, na.rm = TRUE))]
segs <- segs[!is.na(lo) & !is.na(hi) & hi > lo]

# Point maps ----
windows <- list(
  UWS     = c(xmin = 989000, ymin = 225000, xmax = 993500, ymax = 229000),
  UES     = c(xmin = 994500, ymin = 220500, xmax = 999000, ymax = 224500),
  Chelsea = c(xmin = 982500, ymin = 210000, xmax = 987000, ymax = 214000))
p <- cr[yr %in% 2018:2019]
pts <- rbind(st_as_sf(p[, .(gtype, coords = "original", X, Y)], coords = c("X", "Y"), crs = 2263),
             st_as_sf(p[, .(gtype, coords = "relocated (address point snapped to street)", X = Xa, Y = Ya)], coords = c("X", "Y"), crs = 2263))
for (w in names(windows)) {
  b <- st_bbox(windows[[w]], crs = 2263)
  g <- ggplot() +
    geom_sf(data = st_crop(ln, b), colour = "grey60", linewidth = .3) +
    geom_sf(data = st_crop(pts, b), aes(colour = gtype), size = .6, alpha = .6) +
    coord_sf(datum = 2263, expand = FALSE) + facet_wrap(~coords) +
    labs(title = paste(w, "crashes 2018-19"), colour = NULL) +
    guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
    theme_void() + theme(legend.position = "bottom")
  print(g)
  ggsave(file.path(out_dir, paste0("map_", w, ".png")), g, width = 15, height = 8, dpi = 130)
}

# Position along block ----
a <- cr[gtype == "address"]
a[, hn := suppressWarnings(as.integer(sub("^([0-9]+) .*", "\\1", off_street_name)))]
a[, street := sub("^[0-9]+ ", "", off_street_name)]
a <- a[!is.na(hn) & grepl("^(EAST|WEST) [0-9]+ STREET$", street)]

# segment whose address range contains the house number
m <- segs[a, on = .(Street = street, lo <= hn, hi >= hn), nomatch = 0L,
          .(collision_id, yr, loc_method, street = i.street, hn, X = i.X, Y = i.Y, Xa = i.Xa, Ya = i.Ya, TrafDir,
            XFrom, YFrom, XTo, YTo, LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen)]
m <- m[, .SD[1], collision_id]
cat("address crashes on numbered cross streets matched to a LION segment:", nrow(m), "of", nrow(a), "\n")

m[, `:=`(dx = XTo - XFrom, dy = YTo - YFrom)]
m[, L := sqrt(dx^2 + dy^2)]
# 0 = From node, 1 = To node; perp in feet right of From -> To
m[, `:=`(t_act = ((X - XFrom) * dx + (Y - YFrom) * dy) / L^2, perp = ((X - XFrom) * dy - (Y - YFrom) * dx) / L,
         t_ap = ((Xa - XFrom) * dx + (Ya - YFrom) * dy) / L^2)]
# expected position: interpolate the number on the side with matching parity
m[, odd := hn %% 2 == 1]
m[, left := (LLo_Hyphen %% 2 == 1) == odd]
m[, `:=`(slo = fifelse(left, LLo_Hyphen, RLo_Hyphen), shi = fifelse(left, LHi_Hyphen, RHi_Hyphen))]
m[, t_exp := fifelse(shi > slo, (hn - slo) / (shi - slo), 0.5)]
m[, padded := shi %% 100 >= 98]
m[, west_from := XFrom < XTo]
m[, `:=`(w_act = fifelse(west_from, t_act, 1 - t_act), w_exp = fifelse(west_from, t_exp, 1 - t_exp),
         w_ap = fifelse(west_from, t_ap, 1 - t_ap))]
m[, side := sub(" .*", "", street)]
m[, period := cut(yr, c(2011, 2015, 2019, 2022, 2026), labels = c("2012-15", "2016-19", "2020-22", "2023-26"))]
# about 10% land on the right street but on another block
m[, on_seg := t_act > -.1 & t_act < 1.1 & abs(perp) < 40]

print(m[, .(N = .N, share_on_block = round(mean(on_seg), 3),
            mean_pos_on_block = round(mean(w_act[on_seg]), 3), mean_pos_off_block = round(mean(w_act[!on_seg]), 2)),
        .(side, period)][order(side, period)])
print(m[on_seg == TRUE & !is.na(padded), .(N = .N, mean_pos = round(mean(w_act), 3)), .(side, padded)][order(side, padded)])

# traffic direction: same skew on eastbound, westbound and two-way blocks
m[, eastbound := fifelse(TrafDir == "W", west_from, fifelse(TrafDir == "A", !west_from, NA))]
print(m[on_seg == TRUE, .(N = .N, mean_pos = round(mean(w_act), 3)),
        .(side, dir = fifelse(is.na(eastbound), "two-way", fifelse(eastbound, "eastbound", "westbound")))][order(side, dir)])

# relocated vs original, on padded segments only: those span the whole block (median ~475 ft),
# while segments with actual ranges are mostly partial blocks (median ~210 ft)
r <- m[loc_method != "original" & padded == TRUE]
print(r[, .(N = .N, original = round(mean(w_act), 3), relocated = round(mean(w_ap), 3),
            relocated_on_block = round(mean(t_ap > -.1 & t_ap < 1.1), 3)), side][order(side)])

# Figures ----
h <- melt(r[, .(side, original = w_act, `relocated (address point snapped to street)` = w_ap)],
          id.vars = "side", variable.name = "coords", value.name = "pos")
h <- h[pos > -.1 & pos < 1.1]
h[, panel := fifelse(side == "EAST", "East side streets (E xx St)", "West side streets (W xx St)")]
g <- ggplot(h, aes(pos)) +
  geom_histogram(binwidth = .025, boundary = 0, fill = "grey40") +
  geom_vline(data = h[, .(mu = mean(pos)), .(panel, coords)], aes(xintercept = mu), colour = "red") +
  geom_vline(xintercept = .5, linetype = 2) +
  facet_grid(coords ~ panel, scales = "free_y") +
  labs(x = "position along block (0 = west end, 1 = east end); red = mean", y = "address-geocoded crashes",
       title = "Manhattan cross-street crashes geocoded from a house number",
       subtitle = "Full-block LION segments: original NYPD points vs the same crashes at the building, snapped to the street") +
  theme_minimal()
print(g)
ggsave(file.path(out_dir, "hist_pos.png"), g, width = 10, height = 6.5, dpi = 120)

h <- m[on_seg == TRUE & !is.na(padded)]
h[, `:=`(lowend_exp = fifelse(side == "EAST", w_exp, 1 - w_exp), lowend_act = fifelse(side == "EAST", w_act, 1 - w_act))]
s <- h[, .SD[sample(.N, min(.N, 3000))], .(side, period)]
g <- ggplot(s, aes(lowend_exp, lowend_act)) +
  geom_point(size = .3, alpha = .25) + geom_abline(colour = "red") +
  coord_equal(xlim = c(-.05, 1.05), ylim = c(-.05, 1.05)) + facet_grid(side ~ period) +
  labs(x = "expected position from house number (0 = low-number end)", y = "geocoded position (0 = low-number end)",
       title = "Original geocoded vs house-number position along block") +
  theme_minimal()
print(g)
ggsave(file.path(out_dir, "act_vs_exp.png"), g, width = 11, height = 6, dpi = 120)
