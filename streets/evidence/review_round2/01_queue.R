# Review round 2: one queue for Manhattan bike lane dates and travel-lane counts
#
# Items (one per contiguous piece of a street with one question set):
#   A  M###  projects of round 1 (aerial sheets exist) with segments on the lane review list: lanes
#            before / after and when they changed; the protection date pre-filled from round 1 or DOT
#   B  L###  lane review segments outside those projects (road diets), grouped by street, adjacency
#            and the LION 2016 -> 2024 counts; park drives excluded (dated by the car-free rule in
#            layers/travel_lanes/02_manhattan_lane_panel.R)
#   C  D###  segments whose protection date in the windows (manual checks before 2020, DOT 2026
#            after) differs from the DOT 2026 history by more than a year, outside the round 1
#            projects and the reviewed overrides
#   M029 (3 Av) is added to A to record its protection date as a window.
# Lane review segments: case review_* or a protected lane before LION's first lane count
# (pre2016_project) in layers/travel_lanes/out/manhattan_lane_spells.csv.
# Writes evidence/review_round2/out/: items.csv, item_segments.csv, points.csv (item_id, lon, lat,
# bearing: sheet centre, for 05_review_sheets.py), segment_lines.csv.
# Run from repo root: Rscript evidence/review_round2/01_queue.R

library(data.table)
library(sf)

source("R/streets.R")
out <- "evidence/review_round2/out"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
park_drives <- c("EAST DRIVE", "WEST DRIVE", "TERRACE DRIVE", "CENTER DRIVE")
# Governors Island (its roads and paths are not part of the street network studied)
on_gov_island <- function(lon, lat) lon > -74.030 & lon < -74.008 & lat > 40.682 & lat < 40.696

spells <- fread("layers/travel_lanes/out/manhattan_lane_spells.csv")
ps <- fread("evidence/aerial_labelling/out/project_segments.csv")[, proj_id := sprintf("M%03d", project)]
claims <- fread("evidence/aerial_labelling/out/project_claims.csv")
r1 <- fread("layers/bike_lanes/manual/streetview_review_answers.csv", colClasses = "character")
ov <- fread("layers/bike_lanes/manual/protection_overrides.csv", colClasses = c(SegmentID = "numeric"))

need <- spells[grepl("^review", case) | pre2016_project == TRUE]
need[, lane_q := fifelse(pre2016_project == TRUE & !grepl("^review", case), "pre-project count", case)]

# Segment geometry (latest version of each id) ----
v <- segment_versions_read()
geom_of <- function(ids) {
  g <- v[v$segment_id %in% ids, ]
  g <- g[order(g$segment_id, -g$version), ]
  g <- g[!duplicated(g$segment_id), ]
  g
}

# group segments of a street into contiguous pieces (within max_gap ft) with the same signature
pieces <- function(dt, sig_cols, max_gap = 50) {
  g <- geom_of(dt[, unique(SegmentID)])
  dt <- dt[SegmentID %in% g$segment_id]
  dt[, sig := do.call(paste, c(.SD, sep = "|")), .SDcols = c("street", sig_cols)]
  dt[, piece := 0L]
  n <- 0L
  for (s in dt[, unique(sig)]) {
    ids <- dt[sig == s, SegmentID]
    gi <- g[match(ids, g$segment_id), ]
    adj <- st_is_within_distance(gi, gi, max_gap)
    comp <- rep(NA_integer_, length(ids))
    for (i in seq_along(ids)) if (is.na(comp[i])) {
      n <- n + 1L; queue <- i
      while (length(queue)) { j <- queue[1]; queue <- queue[-1]; if (is.na(comp[j])) { comp[j] <- n; queue <- c(queue, adj[[j]][is.na(comp[adj[[j]]])]) } }
    }
    dt[sig == s, piece := comp]
  }
  dt[, sig := NULL][]
}

# A: round 1 projects with lane questions ----
a_seg <- merge(ps[, .(SegmentID, proj_id)], need[, .(SegmentID, lane_q, lanes_before, lanes_after)], by = "SegmentID")
a <- a_seg[, .(n_lane_segments = .N, lion_counts = paste(names(sort(table(paste(lanes_before, "->", lanes_after)), decreasing = TRUE)), collapse = "; "),
               lane_q = paste(unique(lane_q), collapse = "; ")), by = proj_id]
a <- unique(rbind(a, data.table(proj_id = "M029", n_lane_segments = 0L, lion_counts = "", lane_q = "protection window"), fill = TRUE), by = "proj_id")
a <- merge(a, claims[, .(proj_id, street, n_segments, prot_pipe, prot_dot)], by = "proj_id")
a <- merge(a, r1[, .(proj_id, r1_protected_from = protected_from, r1_before_type = before_type)], by = "proj_id", all.x = TRUE)
a[, `:=`(kind = "A", item_id = proj_id)]
a_items_seg <- ps[proj_id %in% a[, proj_id], .(item_id = proj_id, SegmentID)]

# B: lane corridors outside the projects ----
b <- need[!SegmentID %in% ps[, SegmentID] & !street %in% park_drives]
gb <- st_transform(geom_of(b[, SegmentID]), 4326)
cb <- st_coordinates(st_centroid(st_geometry(gb)))
b <- b[!SegmentID %in% gb$segment_id[on_gov_island(cb[, 1], cb[, 2])]]
b[, change := fcase(lanes_after < lanes_before, "fewer", lanes_after > lanes_before, "more", default = "same")]
b <- pieces(b, "change", max_gap = 300)
b[, item_id := sprintf("L%03d", frank(piece, ties.method = "dense"))]
b_items <- b[, .(street = street[1], n_segments = .N, n_lane_segments = .N, lion_counts = paste(names(sort(table(paste(lanes_before, "->", lanes_after)), decreasing = TRUE)), collapse = "; "),
                 lane_q = paste(unique(lane_q), collapse = "; "), prot_pipe = if (any(!is.na(prot_from))) as.character(min(as.IDate(prot_from), na.rm = TRUE)) else NA_character_), by = item_id]
b_items[, kind := "B"]

# C: protection date conflicts with the DOT 2026 history ----
bl_types <- setDT(readxl::read_excel("layers/bike_lanes/manual/lookup_bikelane_types.xlsx"))
bl_types <- setNames(bl_types[, facility_code], bl_types[, facility_text])
d26 <- setDT(st_drop_geometry(st_read(nyc_latest("bike_routes", as_of = "20261010"), quiet = TRUE)))[boro == "1"]
on_street <- d26[, .(on = all(onoffst == "ON")), by = .(SegmentID = as.integer(segmentid))][on == TRUE, SegmentID]
d26[, prot := bl_types[tf_facilit] %in% "I" | bl_types[ft_facilit] %in% "I" | bl_types[tf2facilit] %in% "I" | bl_types[ft2facilit] %in% "I"]
dot_prot <- d26[prot == TRUE, .(prot_dot = min(as.IDate(instdate), na.rm = TRUE)), by = .(SegmentID = as.integer(segmentid))]
w <- setDT(bikelane_windows_read("dot2026"))
our <- w[tf_facilit == "Protected" | ft_facilit == "Protected", .(prot_ours = min(as.IDate(date_from))), by = .(SegmentID = as.integer(SegmentID))]
cf <- merge(dot_prot, our, by = "SegmentID", all = TRUE)[SegmentID %in% c(d26[, as.integer(segmentid)])]
cf <- cf[is.na(prot_dot) != is.na(prot_ours) | abs(as.numeric(prot_dot - prot_ours)) > 365]
cf <- cf[(year(prot_dot) %between% c(2008, 2026)) | (year(prot_ours) %between% c(2008, 2026))]
cf <- cf[!SegmentID %in% ps[, SegmentID] & !SegmentID %in% ov[, SegmentID] & SegmentID %in% on_street]
cf[, street := d26[match(cf[, SegmentID], as.integer(d26[, segmentid])), street]]
cf <- cf[!street %in% c("E DRIVE", "W DRIVE", park_drives)]
cf[, `:=`(y_dot = fcoalesce(as.character(year(prot_dot)), "none"), y_ours = fcoalesce(as.character(year(prot_ours)), "none"))]
cf <- pieces(cf, c("y_dot", "y_ours"), max_gap = 300)
cf[, item_id := sprintf("D%03d", frank(piece, ties.method = "dense"))]
c_items <- cf[, .(street = street[1], n_segments = .N, prot_pipe = as.character(min(prot_ours)), prot_dot = as.character(min(prot_dot))), by = item_id]
c_items[, kind := "C"]

# Combine ----
items <- rbind(a[, .(item_id, kind, street, n_segments, n_lane_segments, lion_counts, lane_q, prot_pipe = as.character(prot_pipe),
                     prot_dot = as.character(prot_dot), r1_protected_from, r1_before_type)],
               b_items, c_items, fill = TRUE)
item_seg <- rbind(a_items_seg, b[, .(item_id, SegmentID)], cf[, .(item_id, SegmentID)])

# Proposed timelines, for the review page's confirm-or-correct form ----
# bike lane changes on the item's segments: best facility over both directions per window (pipeline
# windows: DOT 2026 history, manual checks before 2020, round 1 overrides), and per DOT 2026 version
rank_fac <- c("Protected", "Standard", "Sharrows", "none")
best_fac <- function(a, b) rank_fac[pmin(match(fcoalesce(a, "none"), rank_fac), match(fcoalesce(b, "none"), rank_fac))]
precision <- function(d) fcase(mday(d) == 1 & month(d) == 1, "year", mday(d) == 1, "month", default = "day")
wi <- w[SegmentID %in% item_seg[, SegmentID], .(SegmentID = as.integer(SegmentID), date = as.IDate(date_from), fac = best_fac(tf_facilit, ft_facilit))]
setorder(wi, SegmentID, date)
ev <- wi[, .(date = date[-1], from = fac[-.N], to = fac[-1]), by = SegmentID][from != to & date > as.IDate("1900-01-01")]
dot_dates <- d26[, .(SegmentID = as.integer(segmentid), date = as.IDate(instdate))]
ev[, source := fcase(paste(SegmentID, format(date, "%Y-%m")) %in% ov[, paste(SegmentID, substr(protected_from, 1, 7))], "round 1 review",
                     paste(SegmentID, date) %in% dot_dates[, paste(SegmentID, date)], "DOT", default = "manual check")]
d26[, fac := c("Protected", "Standard", "Sharrows")[pmin(match(bl_types[tf_facilit], c("I", "II", "III")), match(bl_types[ft_facilit], c("I", "II", "III")),
                                                         match(bl_types[tf2facilit], c("I", "II", "III")), match(bl_types[ft2facilit], c("I", "II", "III")), na.rm = TRUE)]]
d26[is.na(fac), fac := "none"]
dv <- unique(d26[, .(SegmentID = as.integer(segmentid), date = as.IDate(instdate), fac)])[order(SegmentID, date)]
dev <- dv[, .(date = date, from = c("none", fac[-.N]), to = fac), by = SegmentID][from != to]
dev[, source := "DOT"]
summarise_events <- function(e) {
  e <- merge(item_seg, e, by = "SegmentID")
  e[, precision := precision(date)]
  n_seg <- item_seg[, .(n = .N), by = item_id]
  s <- e[, .(segments = .N), by = .(item_id, date, from, to, precision, source)][n_seg, on = "item_id"]
  s <- s[segments >= pmax(1, 0.25 * n)][order(item_id, date)]
  s[, .(events = as.character(jsonlite::toJSON(.SD[, .(date = as.character(date), from, to, precision, source, segments, of = n)]))), by = item_id]
}
items <- merge(items, summarise_events(ev)[, .(item_id, bike_events = events)], by = "item_id", all.x = TRUE)
items <- merge(items, summarise_events(dev)[, .(item_id, dot_events = events)], by = "item_id", all.x = TRUE)
items[is.na(bike_events), bike_events := "[]"][is.na(dot_events), dot_events := "[]"]

# travel lanes: the typical LION 2016 and last counts of the item's lane review segments; a lane change
# is proposed at the item's main bike lane change when there is one, else between 16a and the 24b recount
mode_of <- function(x) { x <- x[!is.na(x)]; if (length(x)) as.numeric(names(sort(table(x), decreasing = TRUE))[1]) else NA_real_ }
ln <- merge(item_seg, need[, .(SegmentID, trav_lion16, trav_lion_last, lane_q)], by = "SegmentID")
ln <- ln[, .(lion_before = mode_of(trav_lion16), lion_after = mode_of(trav_lion_last),
             pre_project = mean(lane_q == "pre-project count") > 0.5), by = item_id]
items <- merge(items, ln, by = "item_id", all.x = TRUE)
# no lane questions where nothing is to be dated: M029 (protection window only) and the park items
# (park drives dated at the car-free dates; approaches without a LION change)
items[, ask_lanes := kind %in% c("A", "B") & !is.na(lion_before) & item_id != "M029" &
                     !grepl("DRIVE|APPR|APPROACH|CENTRAL PARK", street)]

# sheet centre: the segment nearest the middle of the item, bearing along it
g <- st_transform(geom_of(item_seg[, unique(SegmentID)]), 4326)
xy <- as.data.table(st_coordinates(g)); fid <- names(xy)[ncol(xy)]
ends <- xy[, .(lon_start = X[1], lat_start = Y[1], lon_end = X[.N], lat_end = Y[.N]), by = fid]
ends[, SegmentID := g$segment_id[get(fid)]][, (fid) := NULL]
ends[, `:=`(MidP_lon = (lon_start + lon_end) / 2, MidP_lat = (lat_start + lat_end) / 2)]
lines <- merge(item_seg, ends, by = "SegmentID")
pts <- lines[, {
  i <- which.min((MidP_lon - mean(MidP_lon))^2 + (MidP_lat - mean(MidP_lat))^2)
  dx <- (lon_end[i] - lon_start[i]) * cos(lat_start[i] * pi / 180); dy <- lat_end[i] - lat_start[i]
  .(lon = MidP_lon[i], lat = MidP_lat[i], bearing = (atan2(dx, dy) * 180 / pi) %% 360)
}, by = item_id]

# Cross streets: the item's extent and a label per Street View point ----
# LION records of the segments (latest release each), and the streets meeting at each node
lion <- setDT(arrow::read_parquet(streets_dir("spine", "lion_segment_releases.parquet"),
                                  col_select = c("segment_id", "street", "node_from", "node_to", "feature_typ", "release_date")))
lion <- lion[feature_typ %in% c("0", "6", "A", "C", "W")]
seg_rec <- lion[segment_id %in% item_seg[, SegmentID]][order(-release_date)][!duplicated(segment_id)]
node_st <- unique(rbind(lion[, .(node = node_from, street)], lion[, .(node = node_to, street)]))
setkey(node_st, node)
cross_at <- function(n, own) {
  s <- node_st[.(n), street]
  s <- unique(s[!is.na(s) & s != own & !grepl("^(UNNAMED|DRIVEWAY|PEDESTRIAN|BIKE PATH)", s)])
  if (!length(s)) return("")
  s[order(!grepl("^(EAST|WEST|E|W) [0-9]+ ", s), nchar(s))][1]   # prefer numbered streets, then short names
}
# order segments along the item (projection on its bearing); the outer node of the first and last segment
lines[pts, on = "item_id", bearing := i.bearing]
lines[, along := (MidP_lon - mean(MidP_lon)) * sin(bearing * pi / 180) * cos(MidP_lat * pi / 180) + (MidP_lat - mean(MidP_lat)) * cos(bearing * pi / 180), by = item_id]
lines[seg_rec, on = .(SegmentID = segment_id), `:=`(lion_street = i.street, node_from = i.node_from, node_to = i.node_to)]
proj_t <- function(lon, lat, b, lon0, lat0) (lon - lon0) * sin(b * pi / 180) * cos(lat * pi / 180) + (lat - lat0) * cos(b * pi / 180)
ext <- lines[!is.na(node_from), {
  o <- order(along)
  lon0 <- mean(MidP_lon); lat0 <- mean(MidP_lat)
  # nodes in order along the item: for each segment the end further back first; the first named cross
  # street from either end is the extent (roadbed pieces of the same street have no cross street)
  seq_nodes <- unlist(lapply(o, function(k) {
    back_first <- proj_t(lon_start[k], lat_start[k], bearing[k], lon0, lat0) < proj_t(lon_end[k], lat_end[k], bearing[k], lon0, lat0)
    if (back_first) c(node_from[k], node_to[k]) else c(node_to[k], node_from[k])
  }))
  own <- rep(lion_street[o], each = 2)
  names_along <- mapply(cross_at, seq_nodes, own)
  hit <- which(names_along != "")
  .(from_street = if (length(hit)) names_along[min(hit)] else "", to_street = if (length(hit)) names_along[max(hit)] else "")
}, by = item_id]
items <- merge(items, ext, by = "item_id", all.x = TRUE)

# Street View links at 25 / 50 / 75 % along the item, looking along the street, labelled by the cross street
sv <- function(lat, lon, heading) sprintf("https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=%.6f,%.6f&heading=%.0f&pitch=-10&fov=90", lat, lon, heading)
views <- lines[order(along), { i <- unique(pmax(1L, round(c(0.25, 0.5, 0.75) * .N))); .(view = seq_along(i), lat = MidP_lat[i], lon = MidP_lon[i], n1 = node_to[i], n2 = node_from[i], own = lion_street[i]) }, by = item_id]
views[, label := mapply(function(a, b, o) { if (is.na(a)) return(""); x <- cross_at(a, o); if (x == "") cross_at(b, o) else x }, n1, n2, own)]
views <- merge(views, pts[, .(item_id, bearing)], by = "item_id")[, link := sv(lat, lon, bearing)]
items <- merge(items, dcast(views, item_id ~ paste0("streetview_", view), value.var = "link"), by = "item_id", all.x = TRUE)
items <- merge(items, dcast(views, item_id ~ paste0("sv_label_", view), value.var = "label"), by = "item_id", all.x = TRUE)
# priority: 1 round 1 projects, 2 lane corridors of 3+ segments, 3 date conflicts, 4 small lane items
items[, priority := fcase(kind == "A", 1L, kind == "B" & n_segments >= 3, 2L, kind == "C", 3L, default = 4L)]
setorder(items, priority, -n_segments)

fwrite(items, file.path(out, "items.csv"))
fwrite(item_seg, file.path(out, "item_segments.csv"))
fwrite(pts[, .(proj_id = item_id, lon, lat, bearing)], file.path(out, "points.csv"))
fwrite(lines[, .(proj_id = item_id, SegmentID, lat_start, lon_start, lat_end, lon_end, MidP_lat, MidP_lon)], file.path(out, "segment_lines.csv"))
print(items[, .(items = .N, segments = sum(n_segments)), by = kind])
cat("lane review segments: total", nrow(need), "| in A", a_seg[, .N], "| in B", nrow(b), "| park drives", need[street %in% park_drives, .N],
    "| other (no geometry)", nrow(need) - a_seg[, .N] - nrow(b) - need[street %in% park_drives, .N], "\n")
