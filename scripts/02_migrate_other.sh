#!/usr/bin/env bash
# One-time migration of crash, street, bike-route and Citi Bike station files
# from the project repos into data_NYC. Undated snapshots get the date of their
# file modification time appended. Never deletes or overwrites.
#
# Usage: bash scripts/02_migrate_other.sh [DATA_ROOT]

set -u

RESEARCH=/c/Users/admin/Dropbox/1_research
ROOT=${1:-$RESEARCH/data_NYC}
LOG=$ROOT/migration_log_other.csv

BL=$RESEARCH/5_NYC_bikelanes/data/raw
CC=$RESEARCH/6_NYC_CC/NYC_CC_analysis/data/raw

mkdir -p "$ROOT"/crashes/{raw,reference} "$ROOT"/streets/{lion,bike_routes,other} "$ROOT"/citibike/stations
[ -f "$LOG" ] || echo "source,dest,status" > "$LOG"

mdate () { date -r "$1" +%Y%m%d; }

# copy file or directory; skip if destination exists
copy_one () {
  local src=$1 dest=$2
  if [ -e "$dest" ]; then echo "$src,$dest,skipped_exists" >> "$LOG"; return; fi
  # directories are copied in place: Dropbox locks new folders while syncing, so renaming fails
  if [ -d "$src" ]; then
    if robocopy "$(cygpath -w "$src")" "$(cygpath -w "$dest")" //E //COPY:DAT //DCOPY:T //R:3 //W:5 //NFL //NDL //NJH //NJS //NP > /dev/null; [ $? -lt 8 ]; then
      echo "$src,$dest,copied" >> "$LOG"
    else
      echo "$src,$dest,FAILED" >> "$LOG"
    fi
    return
  fi
  if cp --preserve=timestamps "$src" "$dest.part" && mv "$dest.part" "$dest"; then
    echo "$src,$dest,copied" >> "$LOG"
  else
    rm -rf "$dest.part"; echo "$src,$dest,FAILED" >> "$LOG"
  fi
}

# Crashes ----
for f in "$BL"/road_accidents/Motor_Vehicle_Collisions_-_*_2*.csv "$CC"/road_accidents/Motor_Vehicle_Collisions_-_*_2*.csv; do
  copy_one "$f" "$ROOT/crashes/raw/$(basename "$f")"
done
for n in Crashes Person Vehicles; do
  f="$BL/road_accidents/Motor_Vehicle_Collisions_-_$n.csv"
  [ -f "$f" ] && copy_one "$f" "$ROOT/crashes/raw/Motor_Vehicle_Collisions_-_${n}_$(mdate "$f").csv"
done
f="$BL/road_accidents/NYPD_Motor_Vehicle_Collisions.csv"
copy_one "$f" "$ROOT/crashes/raw/NYPD_Motor_Vehicle_Collisions_$(mdate "$f").csv"
copy_one "$BL/road_accidents/NYC_vehicle_lookup_table.csv" "$ROOT/crashes/reference/NYC_vehicle_lookup_table.csv"

# Streets: LION releases ----
S=$BL/NYC_spatial
for f in "$S"/lion_archive/*; do copy_one "$f" "$ROOT/streets/lion/$(basename "$f")"; done
copy_one "$S/lion_16d"        "$ROOT/streets/lion/lion_16d"
copy_one "$S/lion"            "$ROOT/streets/lion/lion_201911"
copy_one "$S/nyclion_19d.zip" "$ROOT/streets/lion/nyclion_19d.zip"

# Streets: other street layers ----
for n in NYC_streets_shape NYC_streets_shape.zip NYC_Streets.csv dot_VZV_Speed_Limits dot_VZV_Speed_Limits.zip \
         dot_VZV_Speed_Limits_20200626.csv NYC_bikelanes_shape NYC_bikelanes.zip; do
  copy_one "$S/$n" "$ROOT/streets/other/$n"
done

# Bike routes (DOT) ----
R=$BL/bikeroutes
for n in Archived_nyc_bike_routes_2019 Archived_nyc_bike_routes_2019.zip Archived_nyc_bike_routes_2020 \
         Archived_nyc_bike_routes_2020.zip DOT_Bicycle_Routes_20200218.zip nyc-bike-routes nyc-bike-routes.zip; do
  copy_one "$R/$n" "$ROOT/streets/bike_routes/$n"
done
for f in "$R"/New\ York\ City\ Bike\ Routes_*.geojson; do
  copy_one "$f" "$ROOT/streets/bike_routes/$(basename "$f")"
done

# Citi Bike stations ----
f="$R/citibikestationsNYC.json"
copy_one "$f" "$ROOT/citibike/stations/citibikestationsNYC_$(mdate "$f").json"

echo "done: $(grep -c ',copied$' "$LOG") copied, $(grep -c 'skipped' "$LOG") skipped, $(grep -c 'FAILED' "$LOG") failed"
