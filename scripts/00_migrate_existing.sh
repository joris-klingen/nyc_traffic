#!/usr/bin/env bash
# One-time migration: copy TLC files already downloaded by the project repos
# into the shared store, renamed to TLC's own file names. Never deletes or
# overwrites; identical duplicates are skipped, differing duplicates logged.
#
# Usage: bash scripts/00_migrate_existing.sh [DATA_DIR]

set -u

RESEARCH=/c/Users/admin/Dropbox/1_research
DATA_DIR=${1:-$RESEARCH/data_NYC/taxi}
RAW=$DATA_DIR/raw
LOG=$DATA_DIR/migration_log.csv

BL=$RESEARCH/5_NYC_bikelanes/data/raw/taxi
CC=$RESEARCH/6_NYC_CC/NYC_CC_analysis/data/raw/taxi

mkdir -p "$RAW"/{yellow,green,fhvhv,yellow_csv_legacy}
[ -f "$LOG" ] || echo "source,dest,size,status" > "$LOG"

copy_one () {
  local src=$1 dest=$2
  local size_src; size_src=$(stat -c %s "$src")
  if [ -f "$dest" ]; then
    if [ "$(stat -c %s "$dest")" = "$size_src" ]; then
      echo "$src,$dest,$size_src,skipped_identical" >> "$LOG"
    else
      echo "$src,$dest,$size_src,CONFLICT_size_differs" >> "$LOG"
    fi
    return
  fi
  if cp --preserve=timestamps "$src" "$dest.part" && mv "$dest.part" "$dest"; then
    echo "$src,$dest,$size_src,copied" >> "$LOG"
  else
    rm -f "$dest.part"
    echo "$src,$dest,$size_src,FAILED" >> "$LOG"
  fi
}

# NYC_CC: taxitrips_{type}_YYYY_MM.parquet (2021 onwards, includes fhvhv) ----
for f in "$CC"/taxitrips_*_*_*.parquet; do
  b=$(basename "$f" .parquet)            # taxitrips_yellow_2021_01
  type=$(echo "$b" | cut -d_ -f2)
  ym=$(echo "$b" | cut -d_ -f3-4 | tr _ -)
  copy_one "$f" "$RAW/$type/${type}_tripdata_$ym.parquet"
done

# bikelanes: yellow and green parquet, taxitrips_YYYY_MM.parquet ----
for type in yellow green; do
  for f in "$BL"/taxi_data_${type}_2025/taxitrips_*.parquet; do
    ym=$(basename "$f" .parquet | cut -d_ -f2-3 | tr _ -)
    copy_one "$f" "$RAW/$type/${type}_tripdata_$ym.parquet"
  done
done

# bikelanes: legacy yellow CSVs with coordinates (2012-01 to 2016-06) ----
for f in "$BL"/taxi_data_raw/taxitrips_*.csv; do
  ym=$(basename "$f" .csv | cut -d_ -f2-3 | tr _ -)
  copy_one "$f" "$RAW/yellow_csv_legacy/yellow_tripdata_$ym.csv"
done

echo "done: $(grep -c ',copied$' "$LOG") copied, $(grep -c 'CONFLICT' "$LOG") conflicts, $(grep -c 'FAILED' "$LOG") failed"
