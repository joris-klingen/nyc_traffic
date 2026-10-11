#!/usr/bin/env bash
# One-time migration of traffic and bicycle counts (and two street-works files)
# from 5_NYC_bikelanes/data/raw/NYC_traffic into data_NYC. Undated files get the
# date of their modification time appended. Never deletes or overwrites.
#
# Usage: bash scripts/03_migrate_traffic.sh [DATA_ROOT]

set -u

CONFIG=$(dirname "$0")/../config.local
[ -f "$CONFIG" ] && . "$CONFIG"
: "${NYC_DATA:?set NYC_DATA in config.local (see config.example)}"
: "${NYC_RESEARCH:?set NYC_RESEARCH in config.local (see config.example)}"
RESEARCH=$NYC_RESEARCH
ROOT=${1:-$NYC_DATA}
LOG=$ROOT/migration_log_other.csv
SRC=$RESEARCH/5_NYC_bikelanes/data/raw/NYC_traffic

mkdir -p "$ROOT"/traffic_counts/{automated,legacy,bicycle} "$ROOT"/streets/other
[ -f "$LOG" ] || echo "source,dest,status" > "$LOG"

mdate () { date -r "$1" +%Y%m%d; }

copy_one () {
  local src=$1 dest=$2
  if [ -e "$dest" ]; then echo "$src,$dest,skipped_exists" >> "$LOG"; return; fi
  if cp --preserve=timestamps "$src" "$dest.part" && mv "$dest.part" "$dest" && cmp -s "$src" "$dest"; then
    echo "$src,$dest,copied" >> "$LOG"
  else
    rm -f "$dest.part"; echo "$src,$dest,FAILED" >> "$LOG"
  fi
}

# with modification date appended before the extension
copy_dated () {
  local src=$1 dir=$2 b; b=$(basename "$src")
  copy_one "$src" "$dir/${b%.*}_$(mdate "$src").${b##*.}"
}

# Automated vehicle volume counts (dated snapshots already) ----
for f in "$SRC"/traffic_volume_counters/Automated_Traffic_Volume_Counts_*.csv; do
  copy_one "$f" "$ROOT/traffic_counts/automated/$(basename "$f")"
done

# Older vehicle counts: fixed periods, keep names ----
for f in "$SRC"/traffic_volume_counters/Traffic_Volume_Counts__*.csv \
         "$SRC"/traffic_volume_counters/Vehicle_Classification_Counts__*.csv \
         "$SRC"/Midtown_Counts_Total_Volume_-_12H_-_2018_-_Open_Data_Portal.xlsx; do
  copy_one "$f" "$ROOT/traffic_counts/legacy/$(basename "$f")"
done

# Bicycle counts ----
copy_dated "$SRC/Bicycle_Counts.csv"   "$ROOT/traffic_counts/bicycle"
copy_dated "$SRC/Bicycle_Counters.csv" "$ROOT/traffic_counts/bicycle"
for f in "$SRC"/NYCDCP_Manhattan_Bike_Counts_-_*.csv; do
  copy_one "$f" "$ROOT/traffic_counts/bicycle/$(basename "$f")"
done
copy_one "$SRC/NYCDOT_Bicycle_Counts_2017-_East_River_Bridges.zip.zip" \
         "$ROOT/traffic_counts/bicycle/NYCDOT_Bicycle_Counts_2017-_East_River_Bridges.zip"

# Street works ----
copy_dated "$SRC/Speed_Reducer_Tracking_System__SRTS_.csv" "$ROOT/streets/other"
copy_dated "$SRC/Street_Closures_due_to_construction_activities_by_Block.csv" "$ROOT/streets/other"

grep "NYC_traffic" "$LOG" | cut -d, -f3 | sort | uniq -c
