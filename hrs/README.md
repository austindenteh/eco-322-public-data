# RAND HRS Longitudinal File - Starter Data Repository

> Data download required. The raw RAND HRS file is too large for GitHub. Download `randhrs1992_2022v1.dta` and place it in `hrs/data/raw/`.

## Overview

The Health and Retirement Study (HRS) is a longitudinal household survey conducted by the University of Michigan's Institute for Social Research, with funding from the National Institute on Aging and the Social Security Administration. The HRS follows older adults and their households over time and includes demographics, income, assets, health, insurance, cognition, family structure, retirement plans, expectations, and employment history.

This folder uses the RAND HRS Longitudinal File 2022 (V1), a cleaned and harmonized public-use HRS extract produced by the RAND Center for the Study of Aging. The starter scripts help users reshape the RAND file from wide to long format and create a compact set of analysis-ready demographic variables.

## Data Version

| Item | Detail |
|---|---|
| File | RAND HRS Longitudinal File 2022 (V1) |
| Coverage | 1992-2022 (16 waves) |
| Observations | 45,234 respondents |
| Release date | May 2025 |
| Format used | Stata `.dta` |

## How to Obtain the Data

The raw RAND HRS data file is too large to include in this repository.

Option A: Download the file from the shared Dropbox folder: <https://www.dropbox.com/scl/fo/85981elavqjxsgnab303u/AEB68Dy0fLN8Qn97Z6JjwE8?rlkey=2xci5kuc5its8x2p9yx297kz2&st=ydig5d7s&dl=0>. Place `randhrs1992_2022v1.dta` in `hrs/data/raw/`.

Option B: Download directly from the HRS website:

1. Go to the HRS data products page: <https://hrsdata.isr.umich.edu/data-products/rand-hrs-longitudinal-file-2022>
2. Register for an account and agree to the Conditions of Use.
3. Download the Stata version of the RAND HRS Longitudinal File 2022 (V1).
4. Place `randhrs1992_2022v1.dta` in `hrs/data/raw/`.

The codebook PDF, if downloaded, can also be placed in `hrs/data/raw/` for reference.

## Citation Instructions

When using these data, cite both the HRS and the RAND file:

> Health and Retirement Study, RAND HRS Longitudinal File 2022 (V1) public use dataset. Produced and distributed by the University of Michigan with funding from the National Institute on Aging (grant numbers NIA U01AG009740 and NIA R01AG073289). Ann Arbor, MI, May 2025.

> RAND HRS Longitudinal File 2022 (V1). Produced by the RAND Center for the Study of Aging, with funding from the National Institute on Aging and the Social Security Administration. Santa Monica, CA, May 2025.

## Repository Structure

```text
hrs/
|-- README.md
|-- code/
|   |-- 01_reshape_and_save.do
|   |-- 01_reshape_and_save.R
|   |-- 01_reshape_and_save_optional_low_memory.do
|   |-- 01_reshape_and_save_optional_low_memory.R
|   |-- 02_clean_demographics.do
|   `-- 02_clean_demographics.R
|-- data/
|   `-- raw/
|       |-- randhrs1992_2022v1.dta
|       `-- randhrs1992_2022v1.pdf
|-- output/
`-- docs/
```

## Running the Starter Scripts

### 1. Reshape Wide RAND HRS to Long Format

Full build:

```r
source("code/01_reshape_and_save.R")
```

```stata
do code/01_reshape_and_save.do
```

The full build reshapes every R/H/S wave-prefixed variable, the `INW` interview indicators, and selected suffix-numbered death/admin variables. It is useful when you want broad access to the RAND file, but it can require substantial RAM and disk space.

Outputs:

- R: `output/hrs_long.rds`
- Stata: `output/hrs_long.dta`
- Stata CSV export: `output/hrs_long.csv`
- Optional R exports: `output/hrs_long_from_r.dta`, `output/hrs_long_from_r.csv`

The R loader writes only `.rds` by default to avoid accidentally creating multi-gigabyte duplicate files. Set `write_dta_export <- TRUE` or `write_csv_export <- TRUE` before sourcing if you need those optional R exports.

### 2. Low-Memory Reshape

Low-memory build:

```r
source("code/01_reshape_and_save_optional_low_memory.R")
```

```stata
do code/01_reshape_and_save_optional_low_memory.do
```

The standalone low-memory scripts keep the starter variables needed by `02_clean_demographics` plus any extras you request. In R, the loader uses `haven::read_dta(col_select = ...)` so it does not import every raw column. In Stata, the loader uses `use varlist using ...` so it also reads only selected raw columns.

Select waves/years and add variables before running the low-memory script. Leave `hrs_waves` and `hrs_years` unset/`NULL` to keep all 16 waves.

```r
hrs_years <- c(2018, 2020, 2022)      # or hrs_waves <- c(14, 15, 16)
extra_time_invariant_vars <- c("raedyrs")
extra_wave_stubs <- c("rcovrt", "scovrt")
source("code/01_reshape_and_save_optional_low_memory.R")
```

```stata
global hrs_years "2018 2020 2022"   // or global hrs_waves "14 15 16"
global hrs_extra_time_invariant_vars "raedyrs"
global hrs_extra_wave_stubs "rcovrt scovrt"
do code/01_reshape_and_save_optional_low_memory.do
```

Use long-format stub names for wave-varying extras. The loader expands each stub only for the selected waves:

- `rcovrt` loads `r1covrt` through `r16covrt`
- `scovrt` loads `s1covrt` through `s16covrt`
- `hitot` loads `h1itot` through `h16itot`
- `radtype` loads `radtype1` through `radtype16` when those wave-specific variables exist
- `inw` loads `inw1` through `inw16`

### 3. Clean Demographics

```r
source("code/02_clean_demographics.R")
```

```stata
do code/02_clean_demographics.do
```

Outputs:

- R: `output/hrs_demographics_clean.rds`
- Stata: `output/hrs_demographics_clean.dta`
- Optional R export: `output/hrs_demographics_clean_from_r.dta`

The cleaners create:

- `female`
- `educ_cat`
- `race_eth`
- `marital`
- `cohort_label` in R, and value labels for `hacohort` in Stata
- `total_waves`

Example tables and regression examples are available but off by default. To run them:

```r
run_examples <- TRUE
source("code/02_clean_demographics.R")
```

```stata
global hrs_run_examples 1
do code/02_clean_demographics.do
```

## Path Overrides

All scripts auto-detect the `hrs/` folder when run from `hrs/`, `hrs/code/`, or the repo root.

Manual R override:

```r
hrs_root_manual <- "/path/to/econ-data-starters/hrs"
source("/path/to/econ-data-starters/hrs/code/01_reshape_and_save.R")
```

or:

```r
Sys.setenv(HRS_ROOT = "/path/to/econ-data-starters/hrs")
source("/path/to/econ-data-starters/hrs/code/01_reshape_and_save.R")
```

Manual Stata override:

```stata
global hrs_root "/path/to/econ-data-starters/hrs"
do "$hrs_root/code/01_reshape_and_save.do"
```

## Understanding the RAND HRS Data

### Entry Cohorts

| Cohort | `HACOHORT` | Birth Years | First Interviewed | Waves Available |
|---|---:|---|---|---|
| Initial HRS | 3 | 1931-1941 | 1992 | 1-16 |
| AHEAD | 0, 1 | Before 1924 | 1993 | 2-16 |
| CODA | 2 | 1924-1930 | 1998 | 4-16 |
| War Baby | 4 | 1942-1947 | 1998 | 4-16 |
| Early Baby Boomer | 5 | 1948-1953 | 2004 | 7-16 |
| Mid Baby Boomer | 6 | 1954-1959 | 2010 | 10-16 |
| Late Baby Boomer | 7 | 1960-1965 | 2016 | 13-16 |
| Early Gen X | 8 | 1966-1971 | 2022 | 16 |

### Wave-to-Year Mapping

| Wave | Year |
|---:|---:|
| 1 | 1992 |
| 2 | 1994 |
| 3 | 1996 |
| 4 | 1998 |
| 5 | 2000 |
| 6 | 2002 |
| 7 | 2004 |
| 8 | 2006 |
| 9 | 2008 |
| 10 | 2010 |
| 11 | 2012 |
| 12 | 2014 |
| 13 | 2016 |
| 14 | 2018 |
| 15 | 2020 |
| 16 | 2022 |

Waves 1-3 have different survey years for HRS versus AHEAD cohorts. The scripts use the main HRS wave-year mapping above.

### Variable Naming

RAND HRS variables generally follow this pattern:

```text
[Prefix][Wave][Concept]

R  2  SHLT
|  |  |
|  |  Self-rated health
|  Wave 2
Respondent
```

- `R` = respondent
- `S` = spouse
- `H` = household
- `RA` and `HA` prefixes usually identify time-invariant attributes
- Some death/admin variables use suffix wave numbering, such as `radtype1`, `radtype2`, and so on

### Missing Value Codes

The RAND HRS uses Stata extended missing values to distinguish missing reasons:

| Code | Meaning |
|---|---|
| `.` | Did not respond to this wave |
| `.D` | Don't know |
| `.R` | Refused |
| `.X` | Does not apply |
| `.Q` | Question not asked |
| `.U` | Unmarried, for spouse variables |
| `.V` | Spouse did not respond this wave |
| `.S` | Skip pattern or proxy context |
| `.M` | Other missing |
| `.N` | Not applicable |

In Stata, extended missing values are larger than any non-missing number. Use `missing(x)` or `x < .` carefully when filtering. In R, `haven::read_dta()` preserves them as tagged `NA` values.

## Tips for Working with HRS

1. Check `inw` before analyzing outcomes. An outcome can be missing because the respondent was not interviewed in that wave.
2. Choose weights carefully. `rwtresp` is the respondent-level cross-sectional weight, but longitudinal analyses require more thought.
3. Cohorts enter at different waves, so simple time trends can mix age, period, and cohort composition.
4. Spouse variables use the `s` prefix and may come from the spouse interview or proxy information.
5. Cognition measures changed in some later waves. Check the codebook before treating long-run trends as directly comparable.
6. The full long files are large. Use the optional low-memory scripts when you only need starter variables plus a few extra stubs.

## Updating for New Waves

When a new RAND HRS file is released:

1. Download the new `.dta` and place it in `hrs/data/raw/`.
2. Update the raw filename in `01_reshape_and_save.R` and `01_reshape_and_save.do`.
3. Add the new wave-year mapping in both 01 scripts.
4. In Stata, update the wave loop limits if the new file has more than 16 waves.
5. Re-run the validation checks and update this README with the new version information.
