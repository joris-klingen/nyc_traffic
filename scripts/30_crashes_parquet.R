# Parquet copies of the crash snapshots, for fast reading
#
# Usage (from repo root):  Rscript scripts/30_crashes_parquet.R
#
# Writes derived/crashes_parquet/<snapshot>.parquet with the crashes_read() harmonization
# (snake_case names, numeric coordinates, IDate). The CSVs stay the raw record; crashes_read()
# reads the parquet copy when it exists and is newer than the CSV.

library(data.table)
source("R/nyc_data.R")

out_dir <- crashes_parquet_dir()
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for (f in nyc_snapshot_files("crashes")) {
  dest <- file.path(out_dir, sub("\\.csv$", ".parquet", basename(f)))
  if (file.exists(dest) && file.mtime(dest) > file.mtime(f)) next
  cr <- crashes_read(f, use_parquet = FALSE)
  # write under a temporary name so crashes_read() never sees a half-written file
  arrow::write_parquet(cr, paste0(dest, ".part"))
  file.rename(paste0(dest, ".part"), dest)
  message(basename(dest), ": ", nrow(cr), " rows, ", round(file.size(dest) / 1e6), " MB (csv ", round(file.size(f) / 1e6), " MB)")
}
