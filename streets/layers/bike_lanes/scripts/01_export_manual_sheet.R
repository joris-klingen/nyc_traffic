# Export the manual Street View verification sheet to versioned CSVs
#
# Source: Google Sheet "Manual Streetview NYC Bikelanes"
#         https://docs.google.com/spreadsheets/d/1C6HbbYN08fPlwxrynk0p-2KZoDeHIF0leQJLBlMrk50
# Usage (from repo root):  Rscript layers/bike_lanes/scripts/01_export_manual_sheet.R
#
# Needs a cached googlesheets4 token with read access to Sheets; create once in an
# interactive R session (tick the Sheets checkbox on the consent screen):
#   googlesheets4::gs4_auth(email = "<you>@gmail.com",
#                           scopes = "https://www.googleapis.com/auth/spreadsheets.readonly")
#
# All columns are exported as text so nothing is reinterpreted. Commit the CSVs after
# exporting; git history then records every change made in the sheet.

library(googlesheets4)
library(data.table)

sheet_id <- "1C6HbbYN08fPlwxrynk0p-2KZoDeHIF0leQJLBlMrk50"
email <- Sys.getenv("GS4_EMAIL", unset = "jorisklingen@gmail.com")

gs4_auth(email = email, scopes = "https://www.googleapis.com/auth/spreadsheets.readonly")

tabs <- c(
  "dot 2020"              = "layers/bike_lanes/manual/streetview_dot2020.csv",
  "initial try 2019 data" = "layers/bike_lanes/manual/streetview_initial_2019.csv",
  "rules"                 = "layers/bike_lanes/manual/rules.csv"
)

# Export ----
for (tab in names(tabs)) {
  d <- setDT(read_sheet(sheet_id, sheet = tab, col_types = "c", .name_repair = "minimal"))
  # unnamed trailing columns are empty spreadsheet columns
  d <- d[, names(d) != "", with = FALSE]
  fwrite(d, tabs[[tab]])
  message(tab, ": ", nrow(d), " rows x ", ncol(d), " cols -> ", tabs[[tab]])
}

writeLines(format(Sys.time(), "%Y-%m-%d %H:%M %Z"), "layers/bike_lanes/manual/exported_at.txt")
