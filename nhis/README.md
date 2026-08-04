# NHIS — National Health Interview Survey

Starter code and documentation for working with the NHIS, 2004–2024.

> **📥 Data download required.** The raw data files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/oxcdw665ng3q39d11r5yf/ABOW0em1n3G2nsnt4ddrvIY?rlkey=beca6kii18iktke0vweqd83z8&st=txepj9zb&dl=0) and place the year folders in `data/`. See [Step 1](#step-1-obtain-the-data) for details.

## Overview

The National Health Interview Survey (NHIS) is an annual household interview survey conducted by the National Center for Health Statistics (NCHS), part of the CDC. It is one of the primary data sources on the health of the US civilian noninstitutionalized population.

**Key features:**
- **Repeated cross-section** — new sample each year (annual since 1957)
- **Person-level data** from household interviews
- **~30,000–40,000 adults per year** (2019+ design); ~90,000 persons per year (pre-2019)
- **Health insurance**: coverage type, source, gaps
- **Health status**: self-rated health, chronic conditions, functional limitations
- **Health care access/utilization**: usual source of care, ER visits, delayed care
- **Mental health**: PHQ-8 depression screener, GAD-7 anxiety screener (2019+)
- **Demographics**: age, sex, race/ethnicity, education, income, immigration
- **Health behaviors**: smoking, alcohol, physical activity, BMI
- **Complex survey design** with weights, strata, and PSUs

**What the starter scripts produce:**
- `nhis_adult.dta` / `nhis_child.dta` — Combined adult and child files from the Stata loader
- `nhis_adult.rds` / `nhis_child.rds` — Combined adult and child files from the R loader
- `nhis_adult_clean.dta` — Cleaned adult file from the Stata cleaner
- `nhis_adult_clean.rds` — Cleaned adult file from the R cleaner
- Optional R-created Stata exports use `_from_r.dta` suffixes so they do not overwrite Stata outputs

### Data Source

Downloaded from the **NCHS NHIS** data page:
- https://www.cdc.gov/nchs/nhis/data-questionnaires-documentation.htm

---

## The 2019 NHIS Redesign

The NHIS underwent a **major redesign in 2019**. The pre-2019 and post-2019 surveys differ in structure, variable names, and sampling design. Understanding this break is essential for working with NHIS data across time.

**Our approach:** The starter scripts handle this complexity by (1) harmonizing variable **names** to the post-2019 convention in the load/append step, and (2) handling coding **differences** with era-specific logic in the cleaning step, using an `era_post2019` indicator variable.

### Pre-2019 (2004–2018): Hierarchical 5-File Design

Each year has 5 separate data files that must be **merged** to create an analytic dataset:

| File | Level | Merge Keys | Description |
|---|---|---|---|
| `househld` | Household | `hhx, srvy_yr` | Household characteristics |
| `familyxx` | Family | `hhx, fmx, srvy_yr` | Family-level info (income, SNAP) |
| `personsx` | Person | `hhx, fmx, fpx, srvy_yr` | Demographics for ALL household members |
| `samadult` | Person (adult) | `hhx, fmx, fpx, srvy_yr` | Detailed health for 1 random adult per family |
| `samchild` | Person (child) | `hhx, fmx, fpx, srvy_yr` | Detailed health for 1 random child per family |

**Merge order:** `personsx` ← `familyxx` ← `househld`, then join `samadult` or `samchild`.

**Sampling unit:** One sample adult and one sample child per **family** (not household).

**Data format:** Fixed-width ASCII (`.DAT`) files, read into Stata using CDC-provided do-files that use `infix`.

### Post-2019 (2019–2024): Flat 2-File Design

Each year has 2 self-contained data files (no merging needed):

| File | Description |
|---|---|
| `adult` | All data for one sample adult per **household** |
| `child` | All data for one sample child per **household** |

**Everything is in one file:** demographics, family composition, health conditions, insurance, utilization, income — all contained in the adult or child file.

**Sampling unit:** One sample adult and one sample child per **household**.

**Data format:** CSV files in `.zip` archives.

### Key Differences Summary

| Feature | Pre-2019 (2004–2018) | Post-2019 (2019–2024) |
|---|---|---|
| Files per year | 5 (must merge) | 2 (self-contained) |
| Merging required | Yes (up to 4-way) | No |
| Identifiers | `hhx` + `fmx` + `fpx` | `hhx` only |
| Variable suffix | None (e.g., `sex`, `age_p`) | `_a` for adult, `_c` for child |
| Sampling unit | Family | Household |
| Data format | Fixed-width ASCII (`.DAT`) + do-files | CSV (`.csv`) in `.zip` archives |
| Weight variable | `wtfa_sa` (sample adult), `wtfa_sc` (sample child) | `wtfa_a` (adult), `wtfa_c` (child) |
| Strata/PSU | `stratum`/`psu` (2004–05), `strat_p`/`psu_p` (2006+) | `pstrat`/`ppsu` |
| PHQ-8 / GAD-7 | Not available | Available |

---

## Directory Structure

```
nhis/
├── README.md                    ← This file
├── code/
│   ├── 01_load_and_append.do    ← Full data build pipeline (Stata)
│   ├── 01_load_and_append.R     ← Same in R
│   ├── 01_load_and_append_optional_low_memory.do ← Optional low-memory Stata entry point
│   ├── 01_load_and_append_optional_low_memory.R  ← Optional low-memory R entry point
│   ├── 02_clean_and_analyze.do  ← Clean variables, descriptive stats (Stata)
│   └── 02_clean_and_analyze.R   ← Same in R
├── data/
│   ├── NHIS 2004/               ← Pre-2019: .DAT + CDC do-files + .dta
│   ├── NHIS 2005/
│   ├── ...
│   ├── NHIS 2014/               ← Last year with .dta files readily available
│   ├── NHIS 2015/               ← 2015-2018: .zip only (need extraction)
│   ├── ...
│   ├── NHIS 2018/               ← Last pre-redesign year
│   ├── NHIS 2019/               ← First redesigned year
│   ├── ...
│   └── NHIS 2024/               ← Most recent year
├── docs/
│   ├── NHIS_2019_Redesign_sr02-207.pdf
│   ├── NHIS_2024_adult_codebook.pdf
│   └── NHIS_2024_child_codebook.pdf
└── output/                      ← Cleaned datasets (created by scripts)
    ├── nhis_adult.dta           ← Combined raw adult file
    ├── nhis_adult.rds           ← Combined raw adult file from R
    ├── nhis_child.dta           ← Combined raw child file
    ├── nhis_child.rds           ← Combined raw child file from R
    ├── nhis_adult_clean.dta     ← Cleaned adult file from Stata
    └── nhis_adult_clean.rds     ← Cleaned adult file from R
```

---

## Quick Start

### Step 1: Obtain the Data

The raw data files are too large for GitHub and must be downloaded separately. Each year's data lives in its own folder under `data/` (e.g., `data/NHIS 2022/`).

**Option A — Dropbox (recommended):**
Download whichever year folders you need from the shared folder:
https://www.dropbox.com/scl/fo/oxcdw665ng3q39d11r5yf/ABOW0em1n3G2nsnt4ddrvIY?rlkey=beca6kii18iktke0vweqd83z8&st=txepj9zb&dl=0

| Year Range | What to Download | Size | Notes |
|---|---|---|---|
| **2019–2024** | `NHIS 2019/` through `NHIS 2024/` | ~200 MB total | **Start here** — simple CSV files, no special setup |
| 2004–2014 | `NHIS 2004/` through `NHIS 2014/` | ~5 GB total | Pre-redesign era — requires CDC do-files to build `.dta` |
| 2015–2018 | `NHIS 2015/` through `NHIS 2018/` | ~1 GB total | Pre-redesign era — scripts extract archives or use CSV fallback when needed |

Place each year folder in `data/`. The starter scripts auto-detect which years are present and process only those.

**Option B — CDC website:**
1. Go to https://www.cdc.gov/nchs/nhis/data-questionnaires-documentation.htm
2. Select the survey year
3. For 2019+: download the CSV data files (adult and child)
4. For pre-2019: download the ASCII data files + Stata programs
5. Place files in `data/NHIS YYYY/` folders

### Step 2: Load and Append (All Years)

**Stata:**
```stata
cd "/path/to/nhis"
do code/01_load_and_append.do
```

**R:**
```r
source("code/01_load_and_append.R")
```

The scripts can be run from `nhis/`, `nhis/code/`, or the repo root. If automatic path detection fails, set the dataset root explicitly:

```stata
global nhis_root "/path/to/nhis"
do "$nhis_root/code/01_load_and_append.do"
```

```r
nhis_root_manual <- "/path/to/nhis"
source(file.path(nhis_root_manual, "code", "01_load_and_append.R"))

# Or before sourcing:
Sys.setenv(NHIS_ROOT = "/path/to/nhis")
```

This script performs the **full data build pipeline.**

**Default (2019–2024 only):** Unzips and imports CSV files — fast and simple, no special setup needed.

**With pre-2019 years enabled:** The Stata loader creates or reuses component `.dta` files, merges the 5-file hierarchical structure (personsx + familyxx + househld + samadult/samchild), and harmonizes variable names. For 2015–2018, it extracts archives and uses CSV fallback when fixed-width ASCII is absent or CDC do-files assume Windows-only paths. To include pre-2019 years, set or edit the `pre2019_years` settings in the script.

The script auto-detects which year folders are present in `data/` and skips any missing years, so you only need to download the years you want to analyze.

**Output:**
- `output/nhis_adult.dta` / `output/nhis_child.dta` — Stata combined files
- `output/nhis_adult.rds` / `output/nhis_child.rds` — R combined files
- `output/nhis_adult_from_r.dta` / `output/nhis_child_from_r.dta` — optional R-created Stata exports if `write_dta_export <- TRUE`

**Note on R:** The R script requires that `.dta` files already exist for pre-2019 years (since CDC do-files are Stata programs). Run the Stata script first to create the `.dta` files, then the R script can load them. For post-2019 years, R works standalone. R writes compact `.rds` files by default; set `write_dta_export <- TRUE` only if you also need R-created Stata files.

### Recommended Lower-Memory Path

For most student projects, use `01_load_and_append_optional_low_memory.*`. Its teaching-friendly default is 2023-2024 with pre-2019 years off. Confirm that default and any project-specific variables before expanding the range.

```stata
do code/01_load_and_append_optional_low_memory.do
```

```r
source("code/01_load_and_append_optional_low_memory.R")
```

The R low-memory loader selects requested columns while reading both post-2019 CSVs and pre-2019 component DTA files. The Stata loader processes one year at a time, but its post-2019 CSV imports read the full annual CSV before dropping columns; pre-2019 component construction can also require a broader annual import.

For scratch runs, set `nhis_output_dir` or `NHIS_OUTPUT_DIR` in R, or global `nhis_output_dir` in Stata. The matching cleaner honors the same output-directory override, so test builds do not have to replace the normal `output/` files.

**Full 2004–2024 build:**

Stata is the all-column full-build path:

```stata
global nhis_pre2019_years "2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018"
global nhis_post2019_years "2019 2020 2021 2022 2023 2024"
do code/01_load_and_append.do
```

For a lower-memory full-span build, explicitly enable all years. The loader keeps the starter variables needed by the cleaner plus any user-requested extras:

```stata
global nhis_pre2019_years "2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018"
global nhis_post2019_years "2019 2020 2021 2022 2023 2024"
do code/01_load_and_append_optional_low_memory.do
```

```r
pre2019_years <- 2004:2018
post2019_years <- 2019:2024
source("code/01_load_and_append_optional_low_memory.R")
```

With the current shared files, both the adult and child files cover 2004–2024 when all years are enabled.

### Step 3: Clean and Analyze

**Stata:**
```stata
do code/02_clean_and_analyze.do
```

**R:**
```r
source("code/02_clean_and_analyze.R")
```

Creates harmonized cleaned variables across all years using era-aware logic and saves the cleaned adult dataset to `output/`. The descriptive tables and example regressions are kept in the scripts as optional teaching blocks but do not run by default. Set `run_examples <- TRUE` in R, or `local run_examples 1` in Stata, to print the examples.

**Output:**
- `output/nhis_adult_clean.dta` — Cleaned adult file from Stata
- `output/nhis_adult_clean.rds` — Cleaned adult file from R
- `output/nhis_adult_clean_from_r.dta` — optional R-created Stata export if `write_dta_export <- TRUE`

### Memory and File-Size Notes

The recommended teaching path is `code/01_load_and_append_optional_low_memory.R` or `.do`, which defaults to 2023-2024 and writes the usual cleaner inputs. These standalone scripts keep the variables needed by the starter cleaner, plus any names listed in `extra_vars` / `nhis_extra_keep_vars`.

The implementations have different peak-memory behavior:

- R inspects each source header and selects only the requested raw columns before reading observations.
- Stata processes and saves one reduced year at a time, but its delimited-text importer reads a complete post-2019 annual CSV before unused columns are dropped.
- The final appended adult and child working files must still fit in memory in either language.

Use `extra_vars` in R for additional variables with stable names after NHIS harmonization:

```r
pre2019_years <- 2004:2018
post2019_years <- 2019:2024
extra_vars <- c("regionbr_a", "plborn_a")
source("code/01_load_and_append_optional_low_memory.R")
```

Use `nhis_extra_keep_vars` in Stata for the same stable-name case:

```stata
global nhis_extra_keep_vars "regionbr_a plborn_a"
do code/01_load_and_append_optional_low_memory.do
```

In Stata, set either year global to `"none"` or `"skip"` if you want to omit that era while testing a smaller build.

Use `extra_var_families` when the same concept appears under different raw names across years. Each named entry keeps all listed aliases during the low-memory load and then coalesces them into one column:

```r
pre2019_years <- 2004:2018
post2019_years <- 2019:2024
extra_var_families <- list(
  health_status_raw = c("phstat_a", "phstat")
)
source("code/01_load_and_append_optional_low_memory.R")
```

```stata
global nhis_extra_var_families ///
    `" "health_status_raw:phstat_a phstat_c phstat" "'
do code/01_load_and_append_optional_low_memory.do
```

Alias families merge columns by name only. If the coding or meaning changes across NHIS eras, harmonize that added variable in `02_clean_and_analyze.R` or in your analysis code.

The large files are the Stata-format outputs. A full 2004–2024 all-column Stata adult file and cleaned adult file are each several GB. The R scripts skip `.dta` export by default and, when requested, write `_from_r.dta` files so R outputs do not collide with Stata outputs. For long pre-2019 builds, start with a small `pre2019_years` list and add years incrementally.

Reference measurements from the reviewed local files are below. They are approximate and machine-specific; they are intended to show the scale of the selected-column route, not guarantee runtime on another computer.

| R low-memory selection | Columns read | Result | Saved RDS size | Reference runtime / R heap high-water |
|---|---|---|---:|---:|
| Default 2023-2024 | Adult: 31 of 647/630 per year; child: 13 of 370/358 | Adult: 62,151 rows x 32 columns; child: 16,052 x 14 | Adult: 1.1 MB; child: 212 KB | About 2.5 seconds / 134 MB |
| Pre-redesign check, 2014 only | Adult components: 33 of 641 person, 6 of 127 family, 4 of 17 household, 19 of 787 sample-adult columns | Adult: 36,697 rows x 31 columns; child: 13,380 x 15 | Adult: 606 KB; child: 151 KB | About 2.9 seconds; heap not recorded |

The R heap figure is the sum of R's recorded high-water cell allocations, not total operating-system process memory. Storage speed, software versions, requested extras, and optional exports can materially change these figures.

---

## How Variable Harmonization Works

The starter scripts use a two-step approach to handle the 2019 redesign:

### Step 1: Name Harmonization (01_load_and_append)

Pre-2019 variable names and post-redesign aliases are renamed to stable starter names. This allows a clean `append` across all years. In particular, the 2021-2024 adult files use `educp_a` rather than the 2019-2020 `educ_a`, and post-2019 citizenship is released as `citznstp_a`; the loaders normalize these to `educ_a` and `citizenp_a`.

| Source name(s) | Harmonized starter name | Description |
|---|---|---|
| `age_p` | `agep_a` | Age |
| `sex` | `sex_a` | Sex (same coding: 1=Male, 2=Female) |
| `origin_i` | `hisp_a` | Hispanic origin |
| `racerpi2` | `raceallp_a` | Race |
| `educ1`; `educp_a` in 2021+ | `educ_a` | Education |
| `notcov` | `notcov_a` | Uninsured |
| `medicaid` | `medicaid_a` | Medicaid |
| `private` | `private_a` | Private insurance |
| `medicare` | `medicare_a` | Medicare |
| `phstat` | `phstat_a` | Self-rated health |
| `wtfa_sa` | `wtfa_a` | Sample adult weight |
| `strat_p` | `pstrat` | Pseudo-stratum (with offset) |
| `psu_p` | `ppsu` | Pseudo-PSU |
| `citizenp`; `citznstp_a` in 2019+ | `citizenp_a` | Citizenship |
| `plborn` | `plborn_a` | Place of birth |
| `rat_cat*` | `ratcat_a` | Poverty ratio category (14-level) |
| `incgrp*` | `incgrp_a` | Family income group |
| `ernyr_p` | `ernyr_a` | Personal earnings (adults, pre-2019 only) |

**Within pre-2019 name changes** (some variable names changed during 2004–2018):

| Earlier Name | Later Name | Years Changed |
|---|---|---|
| `othergov` | `othgov` | 2008+ |
| `otherpub` | `othpub` | 2008+ |
| `military` | `milcare` | 2008+ |
| `phospyr` | `phospyr2` | 2006+ |
| `ffdstyn` | `fsnap` | 2011+ |
| `stratum`/`psu` | `strat_p`/`psu_p` | 2006+ |
| `rat_cat` | `rat_cat2` → `rat_cat4` | `rat_cat2` in 2007+, `rat_cat4` in 2014 |
| `incgrp` | `incgrp2` → `incgrp4` | `incgrp2` in 2007+, `incgrp4` in 2014 |

### Step 2: Coding Harmonization (02_clean_and_analyze)

Even after names are harmonized, the **coding** of some variables differs across eras. The cleaning script uses the `era_post2019` indicator (created in Step 1) to apply era-specific recoding.

**Insurance variables (CRITICAL):**
| Code | Pre-2019 Meaning | Post-2019 Meaning |
|---|---|---|
| 1 | Mentioned (= Yes) | Yes |
| 2 | Probed yes (= Yes) | No |
| 3 | No | — |

Pre-2019: codes 1 OR 2 = Yes, code 3 = No. Post-2019: code 1 = Yes, code 2 = No. The `notcov` variable uses the same coding in both eras (1=Not covered, 2=Covered).

**Education:**
| Category | Pre-2019 Codes (`educ1`) | Post-2019 Codes (`educ_a`) |
|---|---|---|
| Less than HS | 0–12 | 0–9 |
| HS/GED | 13–14 | 10 |
| Some college/AA | 15–17 | 11–12 |
| Bachelor's | 18 | 13 |
| Graduate | 19–21 | 14–16 |

**Race (Asian category):**
- Pre-2019 (`racerpi2`): Codes 4–14 represent various Asian/Pacific Islander groups
- Post-2019 (`raceallp_a`): Code 4 = Asian (single collapsed category)
- White (1), Black (2), and AIAN (3) are the same across eras

---

## Key Variables Created

### Demographics

| Variable | Source | Description |
|---|---|---|
| `female` | `sex_a` | Female indicator (1=Female; **Note: sex_a=1 is Male in NHIS**) |
| `age_cat` | `agep_a` | Age category (18-25, 26-34, ..., 75+) |
| `race_eth` | `raceallp_a`, `hisp_a` | Race/ethnicity (White NH, Black NH, Hispanic, Asian NH, Other NH) — era-aware |
| `educ_cat` | `educ_a` | Education (Less than HS, HS/GED, Some college/AA, Bachelor's, Graduate) — era-aware |
| `us_born` | `citizenp_a` | Born in US or territory |
| `citizen` | `citizenp_a` | US citizen (including naturalized) |
| `noncitizen` | `citizenp_a` | Non-citizen |

### Health Insurance

| Variable | Source | Description |
|---|---|---|
| `uninsured` | `notcov_a` | Currently uninsured |
| `has_medicare` | `medicare_a` | Has Medicare — era-aware coding |
| `has_medicaid` | `medicaid_a` | Has Medicaid — era-aware coding |
| `has_private` | `private_a` | Has private insurance — era-aware coding |
| `insur_type` | Multiple | Insurance hierarchy (Medicare > Private > Medicaid > Uninsured > Other) |

### Health Status

| Variable | Source | Description |
|---|---|---|
| `health_status` | `phstat_a` | Self-rated health (1=Excellent to 5=Poor) |
| `fair_poor_health` | `phstat_a` | Fair or poor health (binary) |
| `excellent_vgood` | `phstat_a` | Excellent or very good health (binary) |

### Chronic Conditions

| Variable | Source | Description |
|---|---|---|
| `hypev` | `hypev_a` | Ever had hypertension |
| `chlev` | `chlev_a` | Ever had high cholesterol |
| `dibev` | `dibev_a` | Ever had diabetes |
| `depev` | `depev_a` | Ever had depression |
| `anxev` | `anxev_a` | Ever had anxiety |
| `asev` | `asev_a` | Ever had asthma |
| `copdev` | `copdev_a` | Ever had COPD |
| `arthev` | `arthev_a` | Ever had arthritis |
| `canev` | `canev_a` | Ever had cancer |
| `chdev` | `chdev_a` | Ever had coronary heart disease |
| `miev` | `miev_a` | Ever had heart attack (MI) |
| `strev` | `strev_a` | Ever had stroke |

### Mental Health Screeners (2019+ Only)

| Variable | Source | Description |
|---|---|---|
| `depression_moderate` | `phqcat_a` | Moderate+ depression (PHQ-8 score >= 10) |
| `anxiety_moderate` | `gadcat_a` | Moderate+ anxiety (GAD-7 score >= 10) |

These variables are missing for pre-2019 observations because the PHQ-8 and GAD-7 were introduced in the 2019 redesign.

### Health Care Utilization

| Variable | Source | Description |
|---|---|---|
| `delayed_care` | `pdmed12m_a` | Delayed medical care, past 12 months |
| `foregone_care` | `pnmed12m_a` | Needed but did not get medical care |

### Income / Poverty

| Variable | Source | Description |
|---|---|---|
| `pov_cat` | `ratcat_a` | Poverty category (Below poverty, 100-199% FPL, 200-399% FPL, 400%+ FPL) |
| `below_poverty` | `ratcat_a` | Below federal poverty level (binary) |
| `low_income` | `ratcat_a` | Below 200% FPL (binary) |
| `income_cat` | `incgrp_a` | Family income group ($0-$34,999 through $100,000+) — not available 2021+ |
| `earn_cat` | `ernyr_a` | Personal earnings category — pre-2019 only |

**Income harmonization across eras:** The poverty ratio category (`ratcat_a` → `pov_cat`) is the most consistently available income measure across all years. It uses the same 14-category coding in both eras (codes 1-14 map to poverty ratio ranges from under 0.50 to 5.00+).

**Income imputation files:** For continuous family income or precise poverty ratios, use the multiple imputation files (`INCMIMP/` pre-2019, `adultinc` post-2019). These provide 5 replicate implicates requiring proper MI estimation (Rubin's rules). Note that continuous dollar income (`faminctc_a`) is only available through 2022; by 2024, only the poverty ratio remains in the imputation file.

**Variable availability by era:**

| Variable | Pre-2019 | 2019-2020 | 2021-2024 |
|---|---|---|---|
| Poverty ratio category (`ratcat_a`) | Yes (from `rat_cat*`) | Yes | Yes |
| Income group (`incgrp_a`) | Yes (from `incgrp*`) | Yes | **No** |
| Continuous poverty ratio (`povrattc_a`) | Via INCMIMP only | Yes (main file) | Yes (main file) |
| Continuous family income | Via INCMIMP only | Via adultinc | **No** (dropped by 2024) |
| Personal earnings (`ernyr_a`) | Yes (11 categories) | **No** | **No** |

### Survey Design

| Variable | Description |
|---|---|
| `srvy_yr` | Survey year |
| `hhx` | Household identifier (string) |
| `era_post2019` | Era indicator (0=pre-2019, 1=2019+) |
| `wtfa_a` / `wtfa_c` | Final annual weight (adult / child) |
| `wtfa_adj` | Pooled weight (`wtfa_a / N_years`), created in cleaning script |
| `pstrat` | Pseudo-stratum (harmonized across eras with offsets) |
| `ppsu` | Pseudo-PSU (harmonized across eras) |

---

## Weights and Survey Design

**Single-year analysis:**
```stata
svyset ppsu [pweight=wtfa_a], strata(pstrat)
svy: reg outcome demographics
```

**Multi-year pooling:** Divide weights by the number of years:
```stata
gen wtfa_adj = wtfa_a / 6    // for 2019-2024 (6 years)
svyset ppsu [pweight=wtfa_adj], strata(pstrat)
```

The cleaning scripts create `wtfa_adj` automatically based on the number of years in the dataset.

**Stratum offsets for pooling across design periods:**
- 2004–2005: Uses `stratum`/`psu` → renamed to `pstrat`/`ppsu` with `pstrat = 1000 + stratum`
- 2006–2018: Uses `strat_p`/`psu_p` → renamed to `pstrat`/`ppsu` with `pstrat = 2000 + strat_p`
- 2019–2024: Uses `pstrat`/`ppsu` natively (no offset needed)

These offsets ensure that strata from different design periods are treated as distinct when pooling.

---

## Important Notes

### Coding Conventions

In both eras, most binary health variables use:
- `1` = Yes
- `2` = No

Pre-2019 missing codes: values > 2 (typically 7=Refused, 8=Not ascertained, 9=Don't know).
Post-2019 missing codes: `7` = Refused, `8` = Not ascertained, `9` = Don't know.

The cleaning scripts recode to `1`/`0` binary and treat all other values as missing.

**Sex coding differs from other surveys:** In the NHIS, `sex_a = 1` is **Male** and `sex_a = 2` is **Female**. This is opposite to the YRBS (where `sex = 1` is Female).

### Data Availability by Year

| Year Range | File Structure | Raw Format | Status in This Repo |
|---|---|---|---|
| 2004–2014 | 5-file hierarchical | `.DAT` → `.dta` (via CDC do-files) | Ready: `.dta` files available (or auto-created) |
| 2015–2018 | 5-file hierarchical | `.zip` archives / CSV alternatives | Ready for adult builds: Stata extracts archives and uses CSV fallback as needed |
| 2019–2024 | 2-file flat | `.csv` in `.zip` | Ready: scripts auto-unzip |

**Default coverage:** The starter scripts process **2019–2024** by default (post-redesign, simple CSV files). To include pre-2019 adult years, set `pre2019_years <- 2004:2018` in R after running the Stata loader once, or set `global nhis_pre2019_years "2004 ... 2018"` in Stata.

**Special file note:**
- 2017: `familyxx.zip` (fixed-width) is missing; the Stata loader uses `familyxxcsv.zip` as fallback

### Special Years

- **2020:** COVID-disrupted. Data collection was significantly affected. Extra files were created (`adultlong`, `adultpart`). Consider sensitivity analyses excluding 2020.
- **2019:** First year of the redesign. Has both interim (`wtia_a`) and final (`wtfa_a`) weights.
- **2004–2005:** Different stratum/PSU variable names (`stratum`/`psu` vs. `strat_p`/`psu_p`).
- **2004–2010:** No interview month variable; only quarter (`intv_qrt`) and week (`assignwk`).
- **2011–2018:** Has interview month (`intv_mon`).

### Child File

The starter scripts produce a combined child file (`nhis_child.dta`) alongside the adult file. The child file is built the same way — merging personsx + familyxx + househld + samchild for pre-2019, and importing child CSVs for post-2019. With the current shared files, child coverage is 2004–2024 when all years are enabled.

The cleaning script (`02_clean_and_analyze`) focuses on the adult file. To clean the child file, adapt the script using:
- Input: `output/nhis_child.dta` / `.rds`
- Variable suffix: `_c` instead of `_a` (for post-2019 variables)
- Weight: `wtfa_c` instead of `wtfa_a`
- Child-specific health variables from the `samchild` component

The original RDC research scripts provide a template for child health outcomes (access, utilization, school days lost, etc.).

### Income Imputation Files

Each year includes imputed income files (INCIMPS / INCMIMP for pre-2019; adultinc / childinc for 2019+). These contain multiple imputation replicates (typically 5) of income and poverty ratio variables. For income analyses, use these files with proper multiple imputation techniques.

### Content Changes Over Time

The NHIS questionnaire content changes annually. Key additions in the 2019+ redesign:
- **PHQ-8** (depression screener) and **GAD-7** (anxiety screener) — new in 2019+
- **Exchange/marketplace** insurance questions — new/expanded post-ACA
- **Social determinants of health** — added in later years (2022+)
- **Chronic fatigue, traumatic brain injury, allergies** — added in 2024

Always check the year-specific codebook before assuming a variable exists.

---

## Common Research Applications

The NHIS is widely used in health economics and health services research for:
- **Health insurance coverage** trends and disparities (long time series back to 2004+)
- **ACA evaluation** (comparing pre/post 2010, 2014 implementation)
- **Health disparities** by race/ethnicity, income, education, immigration status
- **Chronic disease** prevalence and trends
- **Health care access** and utilization patterns
- **Mental health** screening and trends (2019+)
- **Immigration and health** (citizenship, nativity, mixed-status families)

---

## Citation

When using NHIS data, cite:

> National Center for Health Statistics. National Health Interview Survey, [year]. Hyattsville, Maryland. Available at: https://www.cdc.gov/nchs/nhis/index.htm

The redesign documentation should also be cited when using 2019+ data:

> National Center for Health Statistics. Redesigned National Health Interview Survey. Series 2, Number 207. June 2024.
