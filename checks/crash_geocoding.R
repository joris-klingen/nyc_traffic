# Where do crashes sit along their block?
#
# Crashes geocoded from a house number ("250 WEST 34 STREET", in OFF STREET NAME) are placed by
# interpolating the number along the LION segment's address range. Where LION pads the range to
# xx98/xx99 they pile up toward the low-number end of the block. On Manhattan's cross streets that
# end faces 5th Ave / Central Park: points shift west on the East Side and east on the West Side.
# Traffic direction plays no role. Intersection-coded crashes sit on LION nodes.
#
# From November 2024 the published coordinates are already the building's address point (about
# 45 ft off the centerline, no along-block skew); the skew is in the records before that.
#
# crashes_relocate() moves these crashes to the address point of the building, snapped onto the
# street centerline. This script compares the original and relocated positions.
#
# Run from the repo root: Rscript checks/crash_geocoding.R [MANHATTAN|BROOKLYN|QUEENS|BRONX|STATEN ISLAND]
# Writes figures to output/crash_geocoding/<borough>/

library(data.table)
library(sf)
library(ggplot2)
source("R/nyc_transport.R")

boro <- toupper(paste(commandArgs(trailingOnly = TRUE), collapse = " "))
if (boro == "") boro <- "MANHATTAN"
boro_code <- as.integer(names(borough_codes)[borough_codes == boro])
if (length(boro_code) != 1) stop("unknown borough: ", boro)
cat("Borough:", boro, "\n")

out_dir <- file.path("output/crash_geocoding", gsub(" ", "_", tolower(boro)))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# map windows: 4500 x 4000 ft around these points
windows <- list(
  MANHATTAN       = list(UWS = c(-73.976, 40.788), UES = c(-73.954, 40.776), Chelsea = c(-73.999, 40.745)),
  BROOKLYN        = list(Park_Slope = c(-73.978, 40.672), Bed_Stuy = c(-73.940, 40.687), Bensonhurst = c(-73.995, 40.605)),
  QUEENS          = list(Jackson_Heights = c(-73.885, 40.752), Flushing = c(-73.830, 40.760), Ridgewood = c(-73.905, 40.705)),
  BRONX           = list(Grand_Concourse = c(-73.915, 40.835), Parkchester = c(-73.860, 40.835)),
  `STATEN ISLAND` = list(St_George = c(-74.080, 40.640)))[[boro]]

to_ft <- function(lon, lat) st_coordinates(st_transform(st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326, na.fail = FALSE), 2263))

# Crashes ----
cr <- crashes_read(select = c("CRASH DATE", "BOROUGH", "LATITUDE", "LONGITUDE", "ON STREET NAME",
                              "CROSS STREET NAME", "OFF STREET NAME", "COLLISION_ID"))
cr <- crashes_relocate(cr)
cr <- cr[!is.na(latitude) & (is.na(borough) | borough == boro)]
cr[, yr := year(crash_date)]
cr[, era := fifelse(crash_date >= as.IDate("2024-11-01"), "from 2024-11", "before 2024-11")]
cr[, gtype := fifelse(!is.na(off_street_name), "address",
              fifelse(!is.na(cross_street_name), "intersection", "on street only"))]
print(cr[borough == boro & gtype == "address", .N, loc_method][, share := round(N / sum(N), 3)][])
print(dcast(cr[borough == boro, .N, .(yr, gtype)], yr ~ gtype, value.var = "N"))
xy <- to_ft(cr[, longitude], cr[, latitude])
cr[, `:=`(X = xy[, 1], Y = xy[, 2])]
xy <- to_ft(cr[, longitude_ap], cr[, latitude_ap])
cr[, `:=`(Xa = xy[, 1], Ya = xy[, 2])]

# LION ----
lion_gdb <- paste0("/vsizip/", nyc_latest("lion"), "/lion/lion.gdb")
# type = 5 linearizes the curved segments, which GEOS cannot handle
ln <- st_read(lion_gdb, quiet = TRUE, type = 5, query = sprintf(
  "SELECT RW_TYPE FROM lion WHERE LBoro = %d AND FeatureTyp IN ('0','6','C') AND RB_Layer IN ('G','B')", boro_code))
ln <- st_zm(ln[trimws(ln[["RW_TYPE"]]) == "1", ])

segs <- as.data.table(st_drop_geometry(st_read(lion_gdb, quiet = TRUE, query = sprintf(
  "SELECT Street, RW_TYPE, TrafDir, XFrom, YFrom, XTo, YTo, LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen
   FROM lion WHERE LBoro = %d AND FeatureTyp = '0' AND RB_Layer IN ('G','B')", boro_code))))
segs <- segs[trimws(RW_TYPE) == "1"]
for (v in c("LLo_Hyphen", "LHi_Hyphen", "RLo_Hyphen", "RHi_Hyphen")) set(segs, j = v, value = nyc_house_num(segs[[v]]))
segs[, `:=`(lo = pmin(LLo_Hyphen, RLo_Hyphen, na.rm = TRUE), hi = pmax(LHi_Hyphen, RHi_Hyphen, na.rm = TRUE))]
segs <- segs[!is.na(lo) & !is.na(hi) & hi > lo]
segs[, key := nyc_street_key(Street)]

# Point maps ----
p <- cr[yr %in% 2018:2019]
pts <- rbind(st_as_sf(p[, .(gtype, coords = "original", X, Y)], coords = c("X", "Y"), crs = 2263),
             st_as_sf(p[, .(gtype, coords = "relocated (address point snapped to street)", X = Xa, Y = Ya)], coords = c("X", "Y"), crs = 2263))
for (w in names(windows)) {
  ctr <- to_ft(windows[[w]][1], windows[[w]][2])
  b <- st_bbox(c(xmin = ctr[1] - 2250, ymin = ctr[2] - 2000, xmax = ctr[1] + 2250, ymax = ctr[2] + 2000), crs = 2263)
  g <- ggplot() +
    geom_sf(data = st_crop(ln, b), colour = "grey60", linewidth = .3) +
    geom_sf(data = st_crop(pts, b), aes(colour = gtype), size = .6, alpha = .6) +
    coord_sf(datum = 2263, expand = FALSE) + facet_wrap(~coords) +
    labs(title = paste(gsub("_", " ", w), "crashes 2018-19"), colour = NULL) +
    guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
    theme_void() + theme(legend.position = "bottom")
  print(g)
  ggsave(file.path(out_dir, paste0("map_", w, ".png")), g, width = 15, height = 8, dpi = 130)
}

# Position along block ----
a <- cr[gtype == "address" & grepl("^[0-9]", off_street_name)]
a[, `:=`(hn = nyc_house_num(sub(" .*", "", off_street_name)), street = sub("^[^ ]+ ", "", off_street_name))]
a[, key := nyc_street_key(street)]
a <- a[!is.na(hn)]

# segment whose address range contains the house number
m <- segs[a, on = .(key, lo <= hn, hi >= hn), nomatch = 0L,
          .(collision_id, yr, era, borough = i.borough, loc_method, street = i.street, hn, X = i.X, Y = i.Y, Xa = i.Xa, Ya = i.Ya,
            TrafDir, XFrom, YFrom, XTo, YTo, LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen)]
m <- m[, .SD[1], collision_id]

m[, `:=`(dx = XTo - XFrom, dy = YTo - YFrom)]
m[, L := sqrt(dx^2 + dy^2)]
# 0 = From node, 1 = To node; perp in feet right of From -> To. LION ranges run low -> high
# from the From node, so t is also the position from the low-number end.
m[, `:=`(t_act = ((X - XFrom) * dx + (Y - YFrom) * dy) / L^2, perp = ((X - XFrom) * dy - (Y - YFrom) * dx) / L,
         t_ap = ((Xa - XFrom) * dx + (Ya - YFrom) * dy) / L^2)]
# crashes without a borough only count when they lie near the matched segment
m <- m[borough == boro | (is.na(borough) & abs(perp) < 200 & t_act > -2 & t_act < 3)]
cat("address crashes matched to a LION segment by street and house number:", nrow(m), "of",
    nrow(a[borough == boro | is.na(borough)]), "\n")

# expected position: interpolate the number on the side with matching parity
m[, odd := hn %% 2 == 1]
m[, left := (LLo_Hyphen %% 2 == 1) == odd]
m[, `:=`(slo = fifelse(left, LLo_Hyphen, RLo_Hyphen), shi = fifelse(left, LHi_Hyphen, RHi_Hyphen))]
m[, t_exp := fifelse(shi > slo, (hn - slo) / (shi - slo), 0.5)]
m[, padded := shi %% 100 >= 98]
m[, period := cut(yr, c(2011, 2015, 2019, 2022, 2026), labels = c("2012-15", "2016-19", "2020-22", "2023-26"))]
# from 2024-11 the points sit at the building, ~45 ft beside the centerline
m[, on_seg := t_act > -.1 & t_act < 1.1 & abs(perp) < 100]

print(m[, .(N = .N, share_on_block = round(mean(on_seg), 3), pos_from_low_end = round(mean(t_act[on_seg]), 3)),
        period][order(period)])
print(m[on_seg == TRUE & !is.na(padded), .(N = .N, segment_ft = round(median(L)), pos_from_low_end = round(mean(t_act), 3)), padded][order(padded)])

# geocoding changed in November 2024: points move off the centerline and the skew disappears
print(m[on_seg == TRUE & padded == TRUE & yr >= 2016, .(N = .N, offset_from_centerline_ft = round(median(abs(perp))),
        pos_from_low_end = round(mean(t_act), 3), along_block_move_ft = round(median(abs(t_ap - t_act) * L), 1)), era])

# traffic direction: position from the upstream end of one-way blocks; 0.5 = no direction effect
m[, pos_down := fifelse(TrafDir == "W", t_act, fifelse(TrafDir == "A", 1 - t_act, NA_real_))]
print(m[on_seg == TRUE & !is.na(pos_down), .(N = .N, pos_from_upstream_end = round(mean(pos_down), 3)), padded][order(padded)])

if (boro == "MANHATTAN") {
  # the east/west pattern on the numbered cross streets
  ew <- m[on_seg == TRUE & grepl("^(EAST|WEST) [0-9]+ STREET$", street)]
  ew[, side := sub(" .*", "", street)]
  ew[, west_from := XFrom < XTo]
  print(ew[, .(N = .N, pos_from_west_end = round(mean(fifelse(west_from, t_act, 1 - t_act)), 3)), side])
}

# relocated vs original on padded segments: those mostly span the whole block, while segments
# with actual ranges are often partial blocks where the position says little
r <- m[loc_method != "original" & padded == TRUE & era == "before 2024-11"]
print(r[, .(N = .N, original = round(mean(t_act[on_seg]), 3), relocated = round(mean(t_ap[t_ap > -.1 & t_ap < 1.1]), 3),
            relocated_on_block = round(mean(t_ap > -.1 & t_ap < 1.1), 3))])

# Figures ----
h <- melt(r[, .(original = t_act, `relocated (address point snapped to street)` = t_ap)],
          measure.vars = 1:2, variable.name = "coords", value.name = "pos")
h <- h[pos > -.1 & pos < 1.1]
g <- ggplot(h, aes(pos)) +
  geom_histogram(binwidth = .025, boundary = 0, fill = "grey40") +
  geom_vline(data = h[, .(mu = mean(pos)), coords], aes(xintercept = mu), colour = "red") +
  geom_vline(xintercept = .5, linetype = 2) +
  facet_wrap(~coords, ncol = 1, scales = "free_y") +
  labs(x = "position along block (0 = low house number end, 1 = high end); red = mean", y = "address-geocoded crashes",
       title = paste0(boro, ": house-number crashes before 2024-11, LION segments with padded ranges"),
       subtitle = "Original NYPD points vs the same crashes at the building, snapped to the street") +
  theme_minimal()
print(g)
ggsave(file.path(out_dir, "hist_pos.png"), g, width = 9, height = 6.5, dpi = 120)

s <- m[on_seg == TRUE & !is.na(padded)][, .SD[sample(.N, min(.N, 3000))], period]
g <- ggplot(s, aes(t_exp, t_act)) +
  geom_point(size = .3, alpha = .25) + geom_abline(colour = "red") +
  coord_equal(xlim = c(-.05, 1.05), ylim = c(-.05, 1.05)) + facet_wrap(~period, nrow = 1) +
  labs(x = "expected position from house number (0 = low-number end)", y = "geocoded position (0 = low-number end)",
       title = paste(boro, ": original geocoded vs house-number position along block")) +
  theme_minimal()
print(g)
ggsave(file.path(out_dir, "act_vs_exp.png"), g, width = 11, height = 3.8, dpi = 120)
