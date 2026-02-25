# RAND HRS Longitudinal File — Starter Data Repository

> **📥 Data download required.** The raw data file (~1.7 GB) is too large for GitHub. Download it from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/85981elavqjxsgnab303u/AEB68Dy0fLN8Qn97Z6JjwE8?rlkey=2xci5kuc5its8x2p9yx297kz2&st=ydig5d7s&dl=0) and place it in `data/raw/`. See [How to Obtain the Data](#how-to-obtain-the-data) for details.

## Overview

The **Health and Retirement Study (HRS)** is a longitudinal household survey conducted by the Institute for Social Research at the University of Michigan, with funding from the National Institute on Aging (NIA) and the Social Security Administration (SSA). The HRS surveys a nationally representative sample of approximately 20,000 Americans aged 50 and older, collecting data biennially on demographics, income, assets, health, health insurance, cognition, family structure, retirement plans, expectations, and employment history.

The **RAND HRS Longitudinal File** is a cleaned, easy-to-use, and streamlined version of the HRS data produced by the RAND Center for the Study of Aging. It contains derived variables covering a large range of topics, with consistent naming and coding across all survey waves.

**This repository** contains starter code (in both Stata and R) to help users quickly load, reshape, and begin cleaning the RAND HRS data for their own analysis.

---

## Data Version

| Item | Detail |
|---|---|
| **File** | RAND HRS Longitudinal File 2022 (V1) |
| **Coverage** | 1992--2022 (16 waves) |
| **Observations** | 45,234 respondents |
| **Release date** | May 2025 |
| **Format used** | Stata (.dta) |

---

## How to Obtain the Data

The raw RAND HRS data file is too large (~1.7 GB) to include in this repository. You must download it separately.

**Option A — Dropbox (recommended):**
Download the data file from the shared folder:
https://www.dropbox.com/scl/fo/85981elavqjxsgnab303u/AEB68Dy0fLN8Qn97Z6JjwE8?rlkey=2xci5kuc5its8x2p9yx297kz2&st=ydig5d7s&dl=0

Place `randhrs1992_2022v1.dta` in `data/raw/`.

**Option B — HRS website:**
1. Go to the HRS data products page: <https://hrsdata.isr.umich.edu/data-products/rand-hrs-longitudinal-file-2022>
2. Register for an account (free) and agree to the Conditions of Use
3. Download the **Stata** version of the RAND HRS Longitudinal File 2022 (V1)
4. Place the file `randhrs1992_2022v1.dta` in `data/raw/`

The codebook PDF (`randhrs1992_2022v1.pdf`) is included in `data/raw/` for reference.

---

## Citation Instructions

When using these data, please cite both the HRS and the RAND file:

> Health and Retirement Study, (RAND HRS Longitudinal File 2022 (V1)) public use dataset. Produced and distributed by the University of Michigan with funding from the National Institute on Aging (grant numbers NIA U01AG009740 and NIA R01AG073289). Ann Arbor, MI, (May 2025).

> RAND HRS Longitudinal File 2022 (V1). Produced by the RAND Center for the Study of Aging, with funding from the National Institute on Aging and the Social Security Administration. Santa Monica, CA (May 2025).

In the text of your paper, please include:

> The HRS (Health and Retirement Study) is sponsored by the National Institute on Aging (grant numbers NIA U01AG009740 and NIA R01AG073289) and is conducted by the University of Michigan.

---

## Repository Structure

```
hrs/
├── README.md                         # This file
├── code/
│   ├── 01_reshape_and_save.do        # Stata: load wide data, reshape to long, save
│   ├── 01_reshape_and_save.R         # R: load wide data, reshape to long, save
│   ├── 02_clean_demographics.do      # Stata: clean demographics, descriptive stats, simple regression
│   └── 02_clean_demographics.R       # R: clean demographics, descriptive stats, simple regression
├── data/
│   └── raw/                          # Place downloaded .dta file here
│       ├── randhrs1992_2022v1.dta    # (user must download)
│       └── randhrs1992_2022v1.pdf    # Codebook
├── output/                           # Cleaned datasets saved here by the scripts
└── docs/
    └── data_preparation_instructions_HRS.docx
```

---

## What the Starter Scripts Do

### Script 1: `01_reshape_and_save` (Stata `.do` / R `.R`)

**Purpose:** Load the raw RAND HRS file (wide format), reshape **all** wave-varying variables from wide to long panel format, and save.

The raw RAND HRS file is distributed in **wide format**: one row per respondent, with wave-prefixed variables (e.g., `R1SHLT`, `R2SHLT`, ..., `R16SHLT`). Most panel analyses require **long format**: one row per respondent-wave.

**All wave-varying variables are reshaped.** The scripts programmatically discover every variable following the `[R/S/H][wave][concept]` naming convention and reshape them all at once. This means you get the full dataset in long format — health, cognition, finances, employment, insurance, pensions, and more — without having to manually specify which variables to include. Time-invariant variables (e.g., `RAGENDER`, `RABYEAR`, `HACOHORT`) are carried along automatically.

Here are some of the key variable categories available after reshaping:

| Category | Example Variables | Description |
|---|---|---|
| Identifiers | `HHIDPN`, `HHID`, `PN`, `HACOHORT` | Person/household ID, entry cohort |
| Demographics (time-invariant) | `RAGENDER`, `RABYEAR`, `RAEDUC`, `RARACEM`, `RAHISPAN` | Gender, birth year, education, race, Hispanic |
| Interview status | `RwIWSTAT`, `INW` | Whether respondent was interviewed in wave w |
| Health | `RwSHLT`, `RwCESD`, `RwBMI`, `RwCONDE` | Self-rated health, depression (CES-D 0--8), BMI, condition count |
| Health utilization | `RwHOSP`, `RwNHMLIV`, `RwTOTMBF` | Hospitalization, nursing home, medical expenses |
| Functional limitations | `RwADL5A`, `RwIADL5A`, `RwMOBILA` | ADLs, IADLs, mobility index |
| Cognition | `RwCOGTOT`, `RwTR20` | Total cognition score, word recall |
| Labor/retirement | `RwLBRF`, `RwWORK`, `RwJLTEN` | Labor force status, working, job tenure |
| Demographics (time-varying) | `RwAGEY_B`, `RwMSTAT` | Age at interview, marital status |
| Household finances | `HwITOT`, `HwATOTA`, `HwAHOUS` | Total income, total assets, housing assets |
| Health insurance | `RwCOVRT`, `RwHICOV` | Coverage type, any coverage |
| Weights | `RwWTRESP` | Respondent-level weight |
| Spouse variables | `SwSHLT`, `SwCESD`, `SwLBRF`, ... | Spouse equivalents of R-variables |

Consult the codebook (`data/raw/randhrs1992_2022v1.pdf`) for the full list of variables.

**Output:** Saves the long-format panel dataset as:
- `output/hrs_long.dta` (Stata)
- `output/hrs_long.csv` (CSV)
- `output/hrs_long.rds` (R only)

### Script 2: `02_clean_demographics` (Stata `.do` / R `.R`)

**Purpose:** Load the reshaped long data and demonstrate how to:
1. Clean and create analysis-ready demographic variables
2. Handle HRS missing value codes
3. Produce descriptive statistics
4. Run a simple regression

---

## Understanding the RAND HRS Data

### Entry Cohorts

The HRS consists of eight entry cohorts. Not all cohorts are present in all waves:

| Cohort | `HACOHORT` | Birth Years | First Interviewed | Waves Available |
|---|---|---|---|---|
| Initial HRS | 3 | 1931--1941 | 1992 (Wave 1) | 1--16 |
| AHEAD | 0, 1 | Before 1924 | 1993 (Wave 2A) | 2--16 |
| CODA | 2 | 1924--1930 | 1998 (Wave 4) | 4--16 |
| War Baby | 4 | 1942--1947 | 1998 (Wave 4) | 4--16 |
| Early Baby Boomer | 5 | 1948--1953 | 2004 (Wave 7) | 7--16 |
| Mid Baby Boomer | 6 | 1954--1959 | 2010 (Wave 10) | 10--16 |
| Late Baby Boomer | 7 | 1960--1965 | 2016 (Wave 13) | 13--16 |
| Early Gen X | 8 | 1966--1971 | 2022 (Wave 16) | 16 |

### Wave-to-Year Mapping

| Wave | Year(s) |
|---|---|
| 1 | 1992 |
| 2 | 1993/1994 |
| 3 | 1995/1996 |
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

Note: Waves 1--3 have different survey years for HRS vs. AHEAD cohorts. From Wave 4 (1998) onward, all cohorts are surveyed together.

### Variable Naming Conventions

Variable names follow a consistent pattern:

```
[Prefix][Wave][Concept]

  R  2  SHLT
  │  │   │
  │  │   └── Self-rated health
  │  └────── Wave 2 (1993/1994)
  └───────── Respondent
```

- **R** = Respondent, **S** = Spouse, **H** = Household
- Wave number: 1--16 (single or double digit)
- **RA** prefix = time-invariant respondent attributes (e.g., `RAGENDER`, `RABYEAR`)

### Missing Value Codes

The RAND HRS uses Stata extended missing values to distinguish reasons for missing data:

| Code | Meaning |
|---|---|
| `.` | Did not respond to this wave |
| `.D` | Don't know |
| `.R` | Refused |
| `.X` | Does not apply |
| `.Q` | Question not asked |
| `.U` | Unmarried (for spouse variables) |
| `.V` | Spouse did not respond this wave |
| `.S` | Skip pattern (proxy interview) |
| `.M` | Other missing |
| `.N` | Not applicable (context-specific) |

**Important:** In Stata, all extended missing values (`.D`, `.R`, etc.) are treated as greater than any non-missing number. Be careful with inequality conditions — `if health < 5` will exclude missing values, but `if health != 5` will include them.

In R, when loading with `haven::read_dta()`, extended missing values are converted to tagged `NA` values. Use `haven::is_tagged_na()` to distinguish them if needed, or simply treat all as `NA`.

---

## Tips for Working with the HRS

1. **Panel attrition:** Not all respondents are present in every wave. Always check `INW` (in-wave indicator) or `RwIWSTAT` before analyzing outcomes — missing data may mean attrition, not a missing response.

2. **Survey weights:** Use `RwWTRESP` for respondent-level cross-sectional analyses. The HRS oversamples Hispanics, Blacks, and Florida residents. Note: Wave 16 weights are not available for the new Early Gen X cohort (`HACOHORT=8`).

3. **Cohort composition changes over time:** Newer cohorts enter at later waves. A simple time trend may confound age, period, and cohort effects.

4. **Spouse data:** The "S" variables capture data on the respondent's spouse/partner. These come from the spouse's own interview when available, or from proxy reports.

5. **Cognition measures:** From Wave 14 (2018) onward, some cognition measures were collected via web interviews, which may not be directly comparable to in-person/phone measures. Check the codebook for details.

6. **The data is BIG:** The full RAND HRS file has thousands of variables. The starter scripts reshape all of them. If you need a smaller working dataset, you can subset columns after loading the reshaped long file, or modify Script 01 to select variables before reshaping.

---

## Updating for New Waves

When a new version of the RAND HRS is released (e.g., with Wave 17 data):

1. Download the new `.dta` file and place it in `data/raw/`
2. In `01_reshape_and_save`:
   - Update the filename in the load command
   - **Stata:** In Section 4, add `r17*` (and `h17*`, `s17*`) to both the exclusion list in the single-digit `ds` commands and the double-digit `ds` commands. Check for any new problematic variable names that need renaming in Section 3.
   - **R:** The programmatic stub detection adapts automatically — no changes needed beyond the filename.
   - Add the new wave-to-year mapping (e.g., wave 17 = 2024)
3. In `02_clean_demographics`:
   - No changes needed if the variable structure remains the same
   - Check the codebook for any new variables or coding changes
4. Update this README with the new version info

---

## Further Resources

- RAND HRS data products: <https://hrsdata.isr.umich.edu/data-products/rand-hrs-longitudinal-file-2022>
- HRS documentation: <https://hrs.isr.umich.edu/documentation>
- RAND Center for the Study of Aging: <https://www.rand.org/well-being/social-and-behavioral-policy/centers/aging.html>
