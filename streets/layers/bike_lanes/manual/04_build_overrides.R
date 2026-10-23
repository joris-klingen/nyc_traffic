# Segment-level protection overrides from the Street View review and the park-drive decision
#
# Inputs: manual/streetview_review_answers.csv (review page, imported by scripts/02),
#         manual/park_drive_dates.csv (manual/03), aerial_labelling/out/project_segments.csv
# Output: manual/protection_overrides.csv, one row per SegmentID:
#   protected_from  YYYY-MM-01, or "always" / "never"
#   before_class    facility before protected_from: "none" or "Standard" (conventional)
#   rule, source
# Rules (decisions 2026-10-11/12, see manual/decisions.md):
#   park drives            protected from the car-free date; painted lane (Standard) before
#   answer "none"          never protected: protected windows become Standard
#   before = protected     always protected (protected before the review period)
#   before = buffered      buffered counts as protected, so the earlier of the pipeline date
#                          and the reviewed (physical protection) date
#   otherwise              reviewed date; before = none or conventional as answered
# Run from repo root: Rscript layers/bike_lanes/manual/04_build_overrides.R

library(data.table)

ans <- fread("layers/bike_lanes/manual/streetview_review_answers.csv", colClasses = "character")
park <- fread("layers/bike_lanes/manual/park_drive_dates.csv", colClasses = "character")
chk <- fread("evidence/aerial_labelling/out/review_checklist.csv", colClasses = "character")
seg <- fread("evidence/aerial_labelling/out/project_segments.csv")[, proj_id := sprintf("M%03d", project)]

# confirmations given in the conversation on 2026-10-12
always_protected <- c("M068", "M124")   # Broadway: already protected; Willis Av Bridge approach: always protected

a <- merge(ans[, .(proj_id, protected_from, before_type, note)],
           chk[, .(proj_id, street, category, prot_pipe)], by = "proj_id")
a[, rule := fcase(
  proj_id %in% park$proj_id, "park drive car-free date",
  proj_id %in% always_protected | before_type == "protected", "always protected",
  protected_from == "none", "never protected",
  before_type == "buffered", "buffered counts as protected",
  default = "reviewed date")]

a[, from := fcase(
  rule == "always protected", "always",
  rule == "never protected", "never",
  rule == "buffered counts as protected",
    pmin(paste0(protected_from, "-01"), fifelse(prot_pipe == "", "9999-12-31", substr(prot_pipe, 1, 10))),
  rule == "reviewed date", paste0(protected_from, "-01"),
  default = NA_character_)]
a[rule == "park drive car-free date", from := paste0(park[match(a[rule == "park drive car-free date", proj_id], proj_id), carfree_from], "-01")]
# month precision for the buffered rule (pipeline dates are days)
a[rule == "buffered counts as protected", from := paste0(substr(from, 1, 7), "-01")]

a[, before_class := fcase(rule == "park drive car-free date", "Standard",
                          before_type == "conventional", "Standard",
                          default = "none")]
a[, source := fcase(rule == "park drive car-free date", park[match(a$proj_id, proj_id), source],
                    default = "Street View review (lane date review page, 2026-10)")]

ov <- merge(seg[, .(SegmentID, proj_id)], a[, .(proj_id, street, protected_from = from, before_class, rule, source)], by = "proj_id")
fwrite(ov[order(proj_id, SegmentID)], "layers/bike_lanes/manual/protection_overrides.csv")
print(a[, .(proj_id, street, rule, from, before_class)][order(rule, proj_id)])
cat(nrow(ov), "segments in", uniqueN(ov$proj_id), "projects\n")
