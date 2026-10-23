# Simulated street network history for code development without nyc_streets_data
#
# source("sim/sim.R")                                   # from the repo root
# source("../nyc_streets_repo/sim/sim.R")               # from a project next to this repo
# keys <- sim_key_segments(2000)
# sp <- sim_street_spells(keys)
# panel <- streets_panel("2018-01-01", "2019-12-01", spells = sp, keys = keys)   # the real panel code
#
# Needs the nyc_traffic repo next to this one (as nyc_traffic_repo or nyc_traffic): its
# R/simulate.R draws from the profiles, and its profiles/lion_releases_full.csv gives the LION
# release dates. Loads R/streets.R too, so streets_panel() and streets_state() run on simulated
# spells. Each sim_<source>() returns a table shaped like the reader's output (see the header of
# each script and profiles/<source>.csv). The data are made up: for writing and testing code only.

library(data.table)

local({
  ofiles <- unlist(lapply(sys.frames(), function(f) if (is.character(f$ofile)) f$ofile))
  this <- tail(ofiles[grepl("sim\\.R$", ofiles)], 1)
  sim_dir <- normalizePath(if (length(this)) dirname(this) else "sim", winslash = "/")
  repo <- dirname(sim_dir)
  tr <- Find(dir.exists, file.path(repo, "..", c("nyc_traffic_repo", "nyc_traffic")))
  if (is.null(tr)) stop("sim.R needs the nyc_traffic repo next to this one (nyc_traffic_repo or nyc_traffic)")
  source(file.path(tr, "R", "simulate.R"), local = FALSE)
  source(file.path(repo, "R", "streets.R"), local = FALSE)
  prof <- normalizePath(file.path(repo, "profiles"), winslash = "/")
  rel_file <- normalizePath(file.path(tr, "profiles", "lion_releases_full.csv"), winslash = "/")
  assign("streets_profiles_dir", function() prof, envir = globalenv())
  assign("sim_lion_releases", function() {
    r <- data.table::fread(rel_file)
    r[, release_date := data.table::as.IDate(release_date)]
    r[]
  }, envir = globalenv())
  for (f in list.files(sim_dir, "^sim_.+\\.R$", full.names = TRUE)) source(f, local = FALSE)
})

# draw from a profile of this repo
sim_streets_profile <- function(source, n, seed = NULL) sim_profile(source, n, seed, dir = streets_profiles_dir())
