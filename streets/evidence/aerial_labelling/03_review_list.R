# Build the manual review list from the aerial comparison
#
# Categories:
#   park_drive_definition  Central Park drives: painted bike lanes are visible in all years; the
#                          claimed dates are the car-free / auto-limited changes (2012, 2018), which
#                          DOT codes as protected. Not a dating error; a definition choice.
#   claim_too_early        a clearly readable image after the claimed date shows no lane
#   claim_too_late         a protected/buffered lane is visible before the claimed date (often the
#                          earlier buffered phase of a later upgrade, or a date placeholder)
# Run from repo root: Rscript evidence/aerial_labelling/03_review_list.R

library(data.table)

d <- fread("evidence/aerial_labelling/out/comparison.csv")
park <- "CENTER DRIVE|WEST DRIVE|EAST DRIVE|CENTRAL PARK .* APPR|CPW 85"

d[, category := fcase(
  grepl(park, street), "park_drive_definition",
  grepl("claimed before", check_pipe) | grepl("claimed before", check_dot), "claim_too_early",
  grepl("visible before", check_pipe) | grepl("visible before", check_dot), "claim_too_late",
  default = NA_character_)]

rev <- d[!is.na(category) & (grepl("CONFLICT", check_pipe) | grepl("CONFLICT", check_dot))]
rev[, priority := fcase(category == "park_drive_definition", 3L, n_segments >= 10, 1L, default = 2L)]

print(rev[, .(projects = .N, segments = sum(n_segments)), by = category])
cat("\n")
print(rev[order(priority, category, -n_segments),
          .(priority, category, proj_id, street, n_segments, prot_pipe, prot_dot, aerial_window, note = substr(note, 1, 60))])

fwrite(rev[order(priority, category, -n_segments),
           .(priority, category, proj_id, street, corridor, n_segments, prot_pipe, prot_dot, aerial_window, check_pipe, check_dot, note)],
       "evidence/aerial_labelling/out/review_list.csv")
