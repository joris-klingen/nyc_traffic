# Travel lanes

| Script | Output |
|---|---|
| `01_lion_panel.R` | `nyc_streets_data/travel_lanes/lion_lanes_panel.parquet`: citywide segment x release panel from 57 quarterly LION releases (12a-26c; 12d, 22d not archived); `out/release_changes.csv`: segments whose travel-lane count changed per release and borough |
| `03_key_panels.R` | both panels on the segment key: `lion_lanes_panel_keyed.parquet` (key_id x release, values from the source segment covering most of the key segment in that release) and `manhattan_lanes_monthly_keyed.parquet` (key_id x month, sources limited to ids in LION that month) |
| `02_manhattan_lane_panel.R` | `out/manhattan_lane_spells.csv` (one row per segment), `out/lane_review.csv` (by street), `nyc_streets_data/travel_lanes/manhattan_lanes_monthly.parquet` (segment x month, 2012-07 to 2026-08) |

## What LION can and cannot tell

- Lane counts exist from release 16a (Feb 2016); 2012-2015 releases have no lane fields.
- Counts are frozen from 16a to 24a apart from small batches (19b, 23d); release 24b (Apr 2024) recounted 25,507 segments citywide (1,104 in Manhattan), mostly upward, so partly a change of counting method.
- So LION gives a 2016 and a 2024 value per segment, not the date of a change.

## Dating rules (02)

| LION 2016 -> 2024 | Bike facility change in between | Treatment |
|---|---|---|
| unchanged | | constant |
| fewer lanes | yes | dated at the facility change; Street View review date where available |
| fewer lanes | no | review (placeholder: LION recount date, flagged `undated`) |
| more lanes | no | correction: 2024 value for the whole period |
| more lanes | yes | review |

Segments that got a protected lane between 2012-07 and 2016-02 are flagged `pre2016_project`: their 2016 count may already reflect the project.
Central Park drives (2 -> 1 lane) are to be dated at the car-free dates (decision in `layers/bike_lanes/manual/decisions.md`), not yet applied.
