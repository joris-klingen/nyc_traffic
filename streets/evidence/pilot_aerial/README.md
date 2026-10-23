# Aerial imagery pilot (2026-10-10)

Can bike lane installation dates be bracketed from orthophotos? This was a blind test on 30 Manhattan segments with known answers.

## Setup

- **Sample (`01_select_sample.R`):**
  - 14 segments that became protected between 2012-07 and 2022-06, where the fixed pipeline and DOT 2026 agree within a month (group A);
  - 8 protected before 2008 (group B);
  - 8 conventional throughout 2008–2024 (group C);
  - one segment per street, mid-block, longer than 60 m.
- **Images (`02_fetch_images.py`):**
  - 2008 and 2010 from NYC DoITT tiles; 2012–2024 (even years) from the NYS ITS orthos.
  - Each panel is a 70 m square, rotated so the street runs vertically.
  - One contact sheet per segment: `out/P01.jpg` … `out/P30.jpg`.
- **Labels:** Claude labelled each segment-year as P / C / N / ? before seeing `out/pilot_truth.csv`. The labels are in `out/claude_labels.csv`; the scoring script is `03_score.R`, with output in `out/pilot_scored.csv`.

## Results

| Group | n | Correct | Within one image | Wrong | Undecided |
|---|---|---|---|---|---|
| A: became protected 2012–22 | 14 | 6 | 4 | 1 (two images late) | 3 |
| B: protected before 2008 | 8 | 7 | – | 0 | 1 |
| C: conventional throughout | 8 | 5 | – | 3 (called protected) | 0 |

**No group A segment was dated too early.** Every miss was late: protection was first *seen* after it existed. That makes the first protected image a reliable upper bound.

## Why it misses

1. **Leaf-on years.** The 2008–2016 images were partly flown in summer. Street trees hide the curb lane (P01 Hudson St, P03 Columbus Av).
   - The real flight dates per year are needed. A spring image showing a lane installed "in June" means the DOT date is wrong, not the image.
2. **Shadows on narrow crosstown streets.** The three undecided group A cases are E 55 St, W 55 St and W 29 St.
   - North–south avenues, the street type the paper's treatment uses, were mostly readable.
3. **Definitions, not vision.** Two of the three group C false positives were real facilities that DOT does not class as protected:
   - a buffered lane on Adam Clayton Powell Blvd;
   - the Highbridge Park dirt trail, which is class II in the lookup.

   The third (Prince St) was a green-painted conventional lane mistaken for a protected one.
4. **Structures.** Bike paths on bridges hidden under trusses (Queensboro Bridge) can't be seen.
5. **Precision.** Images are two years apart, so this brackets installation within about two years. That's enough to catch errors larger than a year, which are the ones that bias the estimates, but it can't refine dates within the bracket.

## Implications

- **Usable for Manhattan north–south avenues** as a check on dates that are off by more than a year. Treat the first protected image as an upper bound and the last clearly unprotected image as a lower bound.
- **A classifier** (planned `aerial/` module) faces the same limits. It needs:
  - an explicit "obscured" class (shadow or tree canopy);
  - the flight date per image year;
  - labels by facility *type* (painted green / buffered / parking-protected / path), so the DOT class definitions can be applied afterwards rather than learned implicitly.
