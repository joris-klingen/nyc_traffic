# Simulated LION street centerlines
#
# Real data: raw/street_layout/lion/nyclion_*.zip / nyc_lion*.zip (57 quarterly releases 2012-2026 and a
# current snapshot), read with lion_read() (centerlines: FeatureTyp 0, 6, A, C on the generic and
# both-roadbed layers; 165,139 segments citywide in 26c), sf in EPSG 2263 with SegmentID, Street,
# StreetCode, LBoro, FeatureTyp, RB_Layer, RW_TYPE, TrafDir (T two-way, W with, A against the
# drawing direction, P pedestrian), NodeIDFrom, NodeIDTo (7-character text), Number_Travel_Lanes,
# StreetWidth_Min, BikeLane (LION bike code, " " none), POSTED_SPEED and the house number ranges
# LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen; text columns are padded with spaces as in LION
# (" 2"). profiles/lion.csv lists all columns of the lion layer in its notes.
#
# grid = TRUE (default): a connected Manhattan-like grid, `avenues` north-south avenues 900 ft
# apart and `streets` east-west streets 264 ft apart, rotated 29 degrees like the Manhattan grid
# and placed in Midtown. Segments run between intersections and share node ids, so the network
# can be routed (sf / dodgr / igraph). Avenues alternate one-way (W / A) with 3-5 lanes and 60-100 ft
# widths; streets are one-way with 1-2 lanes and 30-34 ft, every tenth street two-way and wider;
# some avenues and streets carry a bike lane code. grid = FALSE: n segments drawn from the
# profile, placed where LION segments are, not connected.
#
# lion <- sim_lion()                               # 12 x 60 grid, ~1,400 segments
# lion <- sim_lion(grid = FALSE, n = 5000)

sim_lion <- function(avenues = 12, streets = 60, grid = TRUE, n = 1000, seed = NULL) {
  stopifnot(requireNamespace("sf", quietly = TRUE))
  if (!is.null(seed)) set.seed(seed)
  if (!grid) {
    x <- sim_profile("lion", n)
    x[["SegmentID"]] <- sort(sample.int(330000L, nrow(x)))
    return(x)
  }
  pad <- function(v, w) formatC(v, width = w)
  ang <- 29 * pi / 180
  rot <- function(u, v) cbind(988000 + u * cos(ang) - v * sin(ang), 210000 + u * sin(ang) + v * cos(ang))
  node <- function(i, j) (i - 1L) * streets + j            # avenue i, street j
  nodes <- data.table(i = rep(seq_len(avenues), each = streets), j = rep(seq_len(streets), avenues))
  nodes[, `:=`(id = node(i, j), u = (i - 1) * 900, v = (j - 1) * 264)]
  # avenue segments: between streets j and j+1 along avenue i
  av <- nodes[j < streets, .(from = id, to = node(i, j + 1L), i, j, kind = "avenue")]
  # street segments: between avenues i and i+1 along street j
  st <- nodes[i < avenues, .(from = id, to = node(i + 1L, j), i, j, kind = "street")]
  seg <- rbind(av, st)
  seg[, SegmentID := 20000L + seq_len(.N)]
  seg[kind == "avenue", `:=`(Street = paste(i, "AVENUE"), StreetCode = sprintf("1%02d010", i),
                             TrafDir = fifelse(i %% 2 == 0, "W", "A"), lanes = sample(3:5, .N, replace = TRUE),
                             width = sample(c(60, 70, 80, 100), .N, replace = TRUE))]
  seg[kind == "street", `:=`(Street = paste(fifelse(i <= avenues / 2, "WEST", "EAST"), j + 10L, "STREET"),
                             StreetCode = sprintf("1%03d20", j), TrafDir = fifelse(j %% 10 == 0, "T", fifelse(j %% 2 == 0, "W", "A")),
                             lanes = fifelse(j %% 10 == 0, 2L, sample(1:2, .N, replace = TRUE, prob = c(0.7, 0.3))),
                             width = fifelse(j %% 10 == 0, 60, sample(c(30, 32, 34), .N, replace = TRUE)))]
  bike_av <- sample(seq_len(avenues), max(1, round(avenues / 4)))
  bike_st <- sample(seq_len(streets), max(1, round(streets / 8)))
  seg[, BikeLane := fifelse((kind == "avenue" & i %in% bike_av) | (kind == "street" & j %in% bike_st),
                            sample(c(" 1", " 2", " 3"), .N, replace = TRUE, prob = c(0.4, 0.4, 0.2)), " ")]
  seg[, `:=`(LBoro = 1L, FeatureTyp = "0", RB_Layer = "B", RW_TYPE = "1",
             NodeIDFrom = sprintf("%07d", 9000000L + from), NodeIDTo = sprintf("%07d", 9000000L + to),
             Number_Travel_Lanes = pad(lanes, 2), StreetWidth_Min = width, POSTED_SPEED = "25")]
  # house numbers: avenues by street, streets by avenue
  lo <- seg[, fifelse(kind == "avenue", (j - 1L) * 20L + 1L, (i - 1L) * 100L + 1L)]
  seg[, `:=`(LLo_Hyphen = pad(lo + 1L, 7), LHi_Hyphen = pad(lo + 19L, 7), RLo_Hyphen = pad(lo, 7), RHi_Hyphen = pad(lo + 18L, 7))]
  a <- nodes[match(seg[, from], id)]; b <- nodes[match(seg[, to], id)]
  pa <- rot(a[, u], a[, v]); pb <- rot(b[, u], b[, v])
  g <- sf::st_sfc(lapply(seq_len(nrow(seg)), function(k) sf::st_multilinestring(list(rbind(pa[k, ], pb[k, ])))), crs = 2263)
  out <- seg[, .(SegmentID, Street, StreetCode, LBoro, FeatureTyp, RB_Layer, RW_TYPE, TrafDir, NodeIDFrom, NodeIDTo,
                 Number_Travel_Lanes, StreetWidth_Min, BikeLane, POSTED_SPEED, LLo_Hyphen, LHi_Hyphen, RLo_Hyphen, RHi_Hyphen)]
  sf::st_sf(out, geometry = g)
}

if (sys.nframe() == 0) {
  source("sim/sim.R")
  lion <- sim_lion(seed = 1)
  print(lion)
  print(table(lion[["TrafDir"]]))
  print(summary(as.numeric(sf::st_length(lion))))
}
