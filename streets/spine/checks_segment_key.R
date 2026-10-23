# Checks of the segment key (spine/03_segment_key.R)
#
# - unlinked ended versions: distance to the nearest segment in the next release (removed street
#   or a move beyond the buffer?), feature and roadbed type
# - agreement with LION's own LegacyID: successors named by LegacyID that the geometric links find
# - coverage of ids used elsewhere: DOT automated traffic counts, DOT bike routes 2020
# Run from repo root: Rscript spine/checks_segment_key.R

library(data.table)
library(sf)
library(arrow)

source("../R/nyc_transport.R")
dir <- file.path(nyc_streets_data_root(), "spine")
v <- st_read(file.path(dir, "segment_versions.gpkg"), quiet = TRUE)
d <- setDT(st_drop_geometry(v))[, row := .I]
links <- setDT(read_parquet(file.path(dir, "segment_links.parquet")))
key <- setDT(read_parquet(file.path(dir, "segment_key.parquet")))
segs <- setDT(read_parquet(file.path(dir, "lion_segment_releases.parquet"),
                           col_select = c("segment_id", "legacy_id", "feature_typ", "rb_layer", "release", "release_date")))
rels <- unique(segs[, .(release, release_date)])[order(release_date)][, ri := .I]
d[rels, first_ri := i.ri, on = .(first_release = release)][rels, last_ri := i.ri, on = .(last_release = release)]

# Unlinked ended versions ----
ended <- d[last_ri < nrow(rels)]
ended[, linked := paste(segment_id, version) %in% links[, paste(old_id, old_version)]]
un <- ended[linked == FALSE]
types <- unique(segs[, .(segment_id, feature_typ, rb_layer)], by = "segment_id")
un <- merge(un, types, by = "segment_id", all.x = TRUE)
cat("unlinked:", nrow(un), "of", nrow(ended), "ended versions\n")
print(un[, .N, by = .(feature_typ, rb_layer)][order(-N)][1:6])
# distance to the nearest version alive in the next release
un[, near_ft := NA_real_]
for (r in un[, sort(unique(last_ri))]) {
  i <- un[last_ri == r, row]; j <- d[first_ri <= r + 1 & last_ri >= r + 1, row]
  nn <- st_nearest_feature(st_geometry(v)[i], st_geometry(v)[j])
  un[last_ri == r, near_ft := as.numeric(st_distance(st_geometry(v)[i], st_geometry(v)[j][nn], by_element = TRUE))]
}
un[, len := as.numeric(st_length(st_geometry(v)[row]))]
print(un[, .(n = .N, median_len_ft = round(median(len))), by = .(nearest = cut(near_ft, c(-1, 0, 10, 30, 100, 500, Inf)))][order(nearest)])
cat("still in the next release with another geometry (id persists):", un[segment_id %in% d[version > 1, segment_id] & last_ri < d[, max(last_ri)], .N], "\n")

# Agreement with LegacyID ----
leg <- unique(segs[!is.na(legacy_id) & legacy_id != segment_id, .(new_id = segment_id, old_id = legacy_id, release)])
leg <- leg[old_id %in% ended[, segment_id]][, .SD[1], by = .(new_id, old_id)]
leg[, found := paste(old_id, new_id) %in% links[, paste(old_id, new_id)]]
# only pairs where the old id ended right before the new one appeared
leg <- leg[old_id %in% d[, segment_id]]
cat("LegacyID pairs (old -> new):", nrow(leg), "| also found as geometric link:", leg[found == TRUE, .N],
    sprintf("(%.1f%%)", 100 * leg[, mean(found)]), "\n")

# Coverage of ids used elsewhere ----
cur <- key[key_status == "current", unique(segment_id)]
cover <- function(lab, ids) {
  ids <- unique(ids[!is.na(ids)])
  k <- key[segment_id %in% ids, .(status = if (any(key_status == "current")) "current"
                                  else if (any(key_status == "continued")) "continued" else "retired"), by = segment_id]
  cat(sprintf("%-28s %6d ids | current %5.1f%% | continued %5.1f%% | retired %5.1f%% | not in any release %5.1f%%\n", lab, length(ids),
              100 * k[status == "current", .N] / length(ids), 100 * k[status == "continued", .N] / length(ids),
              100 * k[status == "retired", .N] / length(ids), 100 * (length(ids) - nrow(k)) / length(ids)))
}
tc <- fread(nyc_latest("traffic_counts"), select = "SegmentID")
cover("traffic counts", tc[, as.integer(SegmentID)])
br <- st_read(paste0("/vsizip/", file.path(nyc_data_root(), "raw/street_layout/bike_routes/Archived_nyc_bike_routes_2020.zip/Archived_nyc_bike_routes_2020/nyc_bike_routes_2020.shp")), quiet = TRUE)
cover("DOT bike routes 2020", as.integer(br$segmentid))
