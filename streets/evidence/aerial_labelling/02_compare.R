# Compare blind aerial labels with the claimed protection dates (fixed pipeline, DOT 2026)
#
# The aerial evidence is a bracket: protection appeared after the last image labelled
# N/C (no lane / conventional) and on or before the first image labelled P. Images are
# flown in spring (NYS: "Spring <year>"), so a claimed date counts as consistent with a
# first-P year Y if it falls between the previous non-P image and ~May of Y.
# Run from repo root: Rscript evidence/aerial_labelling/02_compare.R

library(data.table)

lab <- fread("evidence/aerial_labelling/out/labels.csv", colClasses = "character")
cl <- fread("evidence/aerial_labelling/out/project_claims.csv")
years <- seq(2008L, 2024L, 2L)
ycols <- paste0("y", years)

# aerial bracket per project ----
bracket <- function(row) {
  v <- unlist(row[, ..ycols])
  firm_p <- which(v == "P")
  first_p <- if (length(firm_p)) min(firm_p) else NA_integer_
  # last firm non-protected image before the first firm P
  nonp <- which(v %in% c("N", "C"))
  last_np <- if (!is.na(first_p)) suppressWarnings(max(nonp[nonp < first_p])) else suppressWarnings(max(nonp))
  if (is.infinite(last_np)) last_np <- NA_integer_
  data.table(upper = if (is.na(first_p)) NA_integer_ else years[first_p],
             lower = if (is.na(last_np)) NA_integer_ else years[last_np],
             any_firm = any(v %in% c("P", "N", "C")))
}
b <- lab[, bracket(.SD), by = proj_id]
d <- merge(merge(lab[, .(proj_id, first_protected_year, note)], b, by = "proj_id"), cl, by = "proj_id")

# capture dates of the Manhattan flights (NYC OTI metadata) ----
# An image showing no lane means installation came after that flight's FIRST capture day;
# an image showing protection means installation came on or before its LAST capture day.
cap <- fread("layers/bike_lanes/manual/aerial_capture_dates_manhattan.csv")
cap_start <- function(y) as.IDate(cap[match(y, cap$year), capture_start])
cap_end <- function(y) as.IDate(cap[match(y, cap$year), capture_end])

check <- function(claim, upper, lower) {
  claim <- as.IDate(claim)
  fcase(
    is.na(claim), "no claim",
    is.na(upper) & is.na(lower), "undecidable",
    is.na(upper) & !is.na(lower) & claim < cap_start(lower), "CONFLICT: claimed before an image showing no lane",
    is.na(upper), "no protection seen (claim after last readable image or not visible)",
    !is.na(lower) & claim < cap_start(lower), "CONFLICT: claimed before an image showing no lane",
    claim > cap_end(upper), "CONFLICT: protection visible before claimed date",
    default = "consistent")
}
d[, check_pipe := check(prot_pipe, upper, lower)]
d[, check_dot := check(prot_dot, upper, lower)]
d[, `:=`(window_from = cap_start(lower), window_to = cap_end(upper))]
d[, aerial_window := fifelse(is.na(upper), NA_character_,
                             paste0(fifelse(is.na(lower), "before Jun 2008", paste("after", format(window_from, "%d %b %Y"))),
                                    ", by ", format(window_to, "%d %b %Y")))]

cat("projects:", nrow(d), "\n\npipeline claim:\n"); print(d[, .N, by = check_pipe][order(-N)])
cat("\nDOT 2026 claim:\n"); print(d[, .N, by = check_dot][order(-N)])

conf <- d[grepl("CONFLICT", check_pipe) | grepl("CONFLICT", check_dot)]
cat("\nconflicts (either source):", nrow(conf), "\n")
print(conf[order(street), .(proj_id, street, n_segments, prot_pipe, prot_dot, aerial_window, check_pipe = sub("CONFLICT: ", "", check_pipe), check_dot = sub("CONFLICT: ", "", check_dot))])

fwrite(d, "evidence/aerial_labelling/out/comparison.csv")
