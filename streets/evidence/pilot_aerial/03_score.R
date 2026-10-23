# Aerial imagery pilot: score Claude's blind labels against the answer key
# Run from repo root: Rscript evidence/pilot_aerial/03_score.R

library(data.table)

lab <- fread("evidence/pilot_aerial/out/claude_labels.csv", colClasses = "character")
tru <- fread("evidence/pilot_aerial/out/pilot_truth.csv")
d <- merge(lab, tru, by = "pilot_id")
d[, truth_year := year(as.IDate(prot_pipe))]
d[, claude_year := suppressWarnings(as.integer(sub("\\?$", "", first_protected_year)))]
d[grepl("before", first_protected_year), claude_year := 2006L]   # "before 2008" -> earlier than first image

years <- seq(2008, 2024, 2)
# image bracket containing the true date: first image year >= truth (images are flown in spring)
d[, truth_bracket := sapply(as.IDate(prot_pipe), function(x) { y <- years[years >= year(x) + (month(x) > 4)]; if (length(y)) min(y) else NA_integer_ })]
d[group != "A", truth_bracket := fifelse(group == "B", 2006L, NA_integer_)]

d[, decided := !is.na(claude_year) & !grepl("\\?", first_protected_year)]
d[, verdict := fcase(
  group == "C" & is.na(claude_year), "correct (never protected)",
  group == "C" & !is.na(claude_year), "WRONG (called protected)",
  is.na(claude_year), "undecided",
  claude_year == truth_bracket, "correct bracket",
  abs(claude_year - truth_bracket) <= 2, "off by one image",
  default = "WRONG")]

print(d[order(group, pilot_id), .(pilot_id, group, street, truth = as.character(prot_pipe), truth_bracket, claude = first_protected_year, verdict)])
cat("\nsummary by group:\n")
print(dcast(d[, .N, by = .(group, verdict)], verdict ~ group, value.var = "N", fill = 0))
fwrite(d, "evidence/pilot_aerial/out/pilot_scored.csv")
