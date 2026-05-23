# BRFSS — Behavioral Risk Factor Surveillance System

> **📥 Data download required.** The raw data files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/hjphv5f8dug0metx88l7c/AIqQ5rff1M_ipkjdeT9-3oE?rlkey=52hnkp7vfcoqwfbmpekhewu99&st=8hiwybzh&dl=0) and place them in `data/raw/`. See [Step 1](#step-1-obtain-the-data) for details.

Starter code and documentation for working with the CDC's Behavioral Risk Factor Surveillance System (BRFSS), 2011–2024.

## Overview

The BRFSS is the largest continuously conducted health survey in the world. Each year the CDC collects data on health-related risk behaviors, chronic health conditions, and use of preventive services from over 400,000 adults across all 50 U.S. states, the District of Columbia, and participating territories.

**Key features:**
- **Repeated cross-section** (not a panel) — a new random sample each year
- **Telephone survey** using random-digit dialing (landline + cell phone since 2011)
- **Complex survey design** requiring weights, strata, and PSU for correct inference
- **400,000-500,000 respondents per year** across 50 states + DC + territories
- **Years covered here:** 2011–2024 (14 years of the dual-frame methodology). Scripts default to **2023–2024**; users who download additional years can easily expand the range.

### Why Start at 2011?

In 2011, the BRFSS made a fundamental methodological change: it added cell phone interviews to the existing landline-only design, creating a **dual-frame** (landline + cell phone) survey. This change also introduced new weighting methodology (raking instead of post-stratification). As a result, **pre-2011 and post-2011 data are not directly comparable** for most estimates. This repository focuses on the modern, dual-frame era (2011 forward).

## Directory Structure

```
brfss/
├── README.md                  ← This file
├── code/
│   ├── 01_load_and_append.do  ← Import XPT files, append all years (Stata)
│   ├── 01_load_and_append.R   ← Same in R
│   ├── 01_load_and_append_optional_low_memory.do  ← Optional low-memory Stata loader
│   ├── 01_load_and_append_optional_low_memory.R  ← Optional low-memory R loader
│   ├── 02_clean_and_harmonize.do  ← Harmonize variables across years (Stata)
│   └── 02_clean_and_harmonize.R   ← Same in R
├── data/
│   └── raw/                   ← LLCP20XX.XPT files (2011-2024)
├── docs/                      ← Codebooks, DQRs, calculated variable docs
└── output/                    ← Cleaned/appended datasets (created by scripts)
```

## Quick Start

### Step 1: Obtain the Data

The raw data files (`LLCP20XX.XPT`) are too large for GitHub and must be downloaded separately. Each file is 600 MB – 1.2 GB.

**Option A — Dropbox (recommended):**
Download the data files from the shared folder:
https://www.dropbox.com/scl/fo/hjphv5f8dug0metx88l7c/AIqQ5rff1M_ipkjdeT9-3oE?rlkey=52hnkp7vfcoqwfbmpekhewu99&st=8hiwybzh&dl=0

| What to download | Size (approx.) | Script default? |
|---|---|---|
| `LLCP2023.XPT` + `LLCP2024.XPT` | ~2.0 GB | **Yes — start here** |
| All 14 files (2011–2024) | ~12 GB | Optional (expand year range in scripts) |

Place the `.XPT` files in `data/raw/`.

**Option B — CDC website:**
1. Go to https://www.cdc.gov/brfss/annual_data/annual_data.htm
2. Select a survey year, then download the **SAS Transport Format** file (`.XPT` or `.zip` containing the `.XPT`)
3. Repeat for each year you want
4. Place the `.XPT` files in `data/raw/`

> **Tip:** The scripts default to **2023–2024** to keep file sizes manageable. To use additional years, download the corresponding `.XPT` files and then either set `first_year` / `last_year` for a consecutive range or set `years_to_load` for an explicit year list in the `01_load_and_append` scripts.

The scripts auto-detect the `brfss/` folder if you run them either:
- from the `brfss/` directory, or
- from the `brfss/code/` directory, or
- from the repo root

You can also set `BRFSS_ROOT` in R or `global brfss_root` in Stata if you want to override the auto-detected path.

### Step 2: Load and Append All Years

**Stata:**
```stata
cd "/path/to/brfss"
do code/01_load_and_append.do
```

Or from the repo root:
```stata
cd "/path/to/econ-data-starters"
do brfss/code/01_load_and_append.do
```

**R:**
```r
setwd("/path/to/brfss")
source("code/01_load_and_append.R")
```

Or from the repo root:
```r
setwd("/path/to/econ-data-starters")
source("brfss/code/01_load_and_append.R")
```

This imports each year's `.XPT` file, adds a `surveyyear` identifier, and appends everything into a single stacked dataset. Outputs are language-specific:
- Stata: `output/brfss_appended.dta`
- R: `output/brfss_appended.rds`
- Optional R export for Stata users: `output/brfss_appended_from_r.dta`

Inside the main `01_*` scripts, you can either:
- set `first_year` / `last_year` for a consecutive range, or
- set `years_to_load` for an explicit non-consecutive year list

Examples:
- Stata: `local years_to_load "2011 2014 2024"`
- R: `years_to_load <- c(2011, 2014, 2024)`

### Optional Low-Memory Workflows

If you want to load many BRFSS years on a machine with limited RAM, you can use the optional low-memory `01_*` script for your language instead of the standard one.

Use:
- `01_load_and_append.do` or `01_load_and_append_optional_low_memory.do` in Stata
- `01_load_and_append.R` or `01_load_and_append_optional_low_memory.R` in R

Do not run both `01_*` scripts for the same language. Pick one path, then continue to Step 3 exactly as usual.

**Optional low-memory Stata loader**

```stata
cd "/path/to/brfss"
do code/01_load_and_append_optional_low_memory.do
```

Use this instead of `01_load_and_append.do` if you want a smaller appended Stata dataset and year-by-year temporary files. This Stata version still imports a full `.XPT` year before dropping unused columns, so the memory savings are smaller than in R, but it still helps by shrinking the kept columns before append and before the downstream harmonization step.

Inside the script, you can:
- set `local years_to_load "2011 2014 2024"` for non-consecutive years
- add stable extra raw variables with `local extra_keep_vars "..."`
- add alias families with `local extra_var_families`

Example:

```stata
local years_to_load "2011 2014 2024"

local extra_var_families ///
    `" "dental_visit:_denvst2 _denvst3" "'
```

This creates one `dental_visit` column by filling from the listed aliases in order. If a family is absent in some loaded years, the script reports which years matched and leaves unmatched years missing for that added column.

**Optional low-memory R loader**

```r
setwd("/path/to/brfss")
source("code/01_load_and_append_optional_low_memory.R")
```

Use this instead of `01_load_and_append.R`, not in addition to it. For most users, `01_load_and_append.R` remains the default and simplest choice.

This optional script:
- reads one year at a time
- keeps only the raw columns needed by `02_clean_and_harmonize.R`
- can use `years_to_load <- c(...)` for non-consecutive years
- supports user-added variables through `extra_keep_vars` and `extra_var_families`
- still writes the usual `output/brfss_appended.rds`, so Step 3 stays the same

Example:

```r
years_to_load <- c(2011, 2014, 2024)

extra_var_families <- list(
  dental_visit = c("_denvst2", "_denvst3")
)
```

This creates a single `dental_visit` column by coalescing the listed aliases in order. If a variable family is absent in some loaded years, the optional script reports which years matched and leaves the unmatched years missing for that added column.

Use the standard `01_load_and_append.R` instead if you want the full BRFSS raw file or many optional-module variables.

### Step 3: Clean and Harmonize

**Stata:**
```stata
cd "/path/to/brfss"
do code/02_clean_and_harmonize.do
```

Or from the repo root:
```stata
cd "/path/to/econ-data-starters"
do brfss/code/02_clean_and_harmonize.do
```

**R:**
```r
setwd("/path/to/brfss")
source("code/02_clean_and_harmonize.R")
```

Or from the repo root:
```r
setwd("/path/to/econ-data-starters")
source("brfss/code/02_clean_and_harmonize.R")
```

This creates harmonized versions of variables that changed names or coding across years, cleans health outcomes, and includes lightweight example analysis. Outputs are language-specific:
- Stata: `output/brfss_clean.dta`
- R: `output/brfss_clean.rds`
- Optional R export for Stata users: `output/brfss_clean_from_r.dta`

## Variable Harmonization

Several key variables changed names or coding over the 2011–2024 period:

| Variable | Source variable(s) by year | Harmonized Name |
|---|---|---|
| Age | `_IMPAGE` (2011–2012), `_AGE80` (2013–2024) | `age` |
| Race/ethnicity | `_RACEGR2` (2011–2014), `_RACEGR3` (2015–2021, 2023–2024), `_RACEGR4` (2022) | `race_eth` |
| Income | `INCOME2` (2011–2020), `INCOME3` (2021–2024) | `income_cat` |
| Employment | `EMPLOY` (2011–2012), `EMPLOY1` (2013–2024) | `working`, `student` |
| Sex | `SEX` (2011–2020), `SEXVAR` with `BIRTHSEX` fallback when present (2021–2024) | `female` |
| Diabetes | `DIABETE3` (2011–2018), `DIABETE4` (2019–2024) | `diabetes` |
| COPD | `CHCCOPD` / `CHCCOPD1` in older public-file layouts, `CHCCOPD3` in modern layouts | `copd` |

The cleaning scripts resolve these transitions automatically by checking which source variable is present.

## Key Variables

### Survey Design (required for correct inference)

| Variable | Description |
|---|---|
| `_LLCPWT` | Final weight (landline + cell combined) |
| `_STSTR` | Sample design stratification variable |
| `_PSU` | Primary sampling unit |

**Use these design variables in a way that matches your task:**
```stata
svyset _psu [pweight = _llcpwt], strata(_ststr)
svy: tab surveyyear fair_or_poor, row
regress outcome treatment controls [pweight = _llcpwt]
```

In this starter, the Stata examples keep `svyset` for descriptive survey tables
and use `[pweight = _llcpwt]` directly in regression commands. The R examples
use `_LLCPWT` directly in `weighted.mean()`, `lm(..., weights = ...)`, and
`glm(..., weights = ...)` as a simple weighted workflow. If you want full
design-based survey inference in R, use the `survey` package with `_LLCPWT`,
`_STSTR`, and `_PSU`.

### Demographics

| Cleaned Variable | Description | Values |
|---|---|---|
| `age` | Age in years (imputed, top-coded at 80) | 18-80 |
| `female` | Female indicator | 0/1 |
| `race_eth` | Race/ethnicity (harmonized) | 1=White NH, 2=Black NH, 3=Hispanic, 4=Other/Multi NH |
| `educ_cat` | Education | 1=<HS, 2=HS grad, 3=Some college, 4=College grad |
| `marital_cat` | Marital status | 1=Married/partnered, 2=Divorced/separated, 3=Widowed, 4=Never married |
| `income_cat` | Household income (harmonized) | 1-8 (see codebook) |
| `working` | Currently employed | 0/1 |
| `statefips` | State FIPS code | Standard FIPS codes |
| `surveyyear` | BRFSS survey year | 2011–2024 (depends on years loaded) |

### Health Outcomes

| Cleaned Variable | Description | Values |
|---|---|---|
| `genhealth` | Self-rated health | 1=Excellent ... 5=Poor |
| `fair_or_poor` | Fair or poor health indicator | 0/1 |
| `mental_days` | Days mental health not good (past 30) | 0-30 |
| `physical_days` | Days physical health not good (past 30) | 0-30 |
| `bmi` | Body mass index (continuous) | ~12-90 |
| `bmi_cat` | BMI category (CDC calculated) | 1=Underweight, 2=Normal, 3=Overweight, 4=Obese |
| `current_smoker` | Current smoker (daily or some days) | 0/1 |
| `diabetes` | Ever told have diabetes | 0/1 |
| `asthma_ever` | Ever told have asthma | 0/1 |
| `asthma_current` | Still have asthma | 0/1 |
| `copd` | Ever told have COPD/emphysema/chronic bronchitis | 0/1 |
| `heartdisease` | Ever told have angina/coronary heart disease | 0/1 |
| `heartattack` | Ever told have heart attack (MI) | 0/1 |

## CDC Calculated Variables

Variables starting with `_` (underscore) are **CDC-calculated** variables derived from multiple survey responses. Key ones include:

| Variable | Description |
|---|---|
| `_AGE80` | Imputed age, top-coded at 80 |
| `_AGEG5YR` | Age in 5-year categories |
| `_RACEGR2`/`_RACEGR3`/`_RACEGR4` | Race/ethnicity (computed) |
| `_BMI5` | BMI * 100 |
| `_BMI5CAT` | BMI category |
| `_SMOKER3` | Four-level smoking status |
| `_RFHLTH` | Adults with good or better health |
| `_PHYS14D` | 14+ days of poor physical health |
| `_MENT14D` | 14+ days of poor mental health |
| `_LLCPWT` | Final combined weight |

Full documentation for each year is in `docs/20XX-calculated-variables-*.pdf`.

## Missing Value Conventions

The BRFSS uses numeric codes for non-response:

| Code | Meaning |
|---|---|
| 7, 77, 777 | Don't know / Not sure |
| 9, 99, 999 | Refused |
| `BLANK` / `.` | Not asked or missing |

The cleaning scripts recode these to missing (`.` in Stata, `NA` in R) for the harmonized variables.

## Optional Modules

The BRFSS includes **optional modules** that individual states choose to administer. These cover topics such as:
- Cannabis use
- Adverse childhood experiences (ACEs)
- Social determinants of health
- Firearm safety
- Sexual orientation and gender identity

Module participation varies by state and year. See `docs/20XX-ModuleAnalysis.pdf` or `docs/AnalysisofModules_20XX.pdf` for which states administered which modules.

## Complex Sampling and Weighting

The BRFSS uses a **stratified, disproportionate random sample** design. For correct standard errors and confidence intervals:

1. **Always use survey weights** (`_LLCPWT`) for weighted point estimates
2. **Use PSU and strata design information** when you want design-based standard errors or official survey-style inference
3. **Never ignore the survey design entirely** — naive unweighted analyses can mislead

The bundled examples keep `svyset` for descriptive survey tables in Stata and
use direct weights in regression examples:
- Stata: `[pweight = _llcpwt]`
- R: `weighted.mean()`, `lm(..., weights = ...)`, and `glm(..., weights = ...)`

Those R examples are a simple weighted workflow, not full design-based survey
inference. If you want full survey-design standard errors in R, use the
`survey` package with `_LLCPWT`, `_STSTR`, and `_PSU`.

The example-analysis sections also use reproducible sampling so the
demonstrations finish faster on a typical laptop.

For more details, see `docs/Complex-Sampling-Weights-*.pdf`.

## Data Quality

Annual data quality reports document:
- Response rates by state
- Disposition codes
- Cooperation rates
- Weighting methodology details

See `docs/20XX-DQR-*.pdf` or `docs/20XX-sdqr-*.pdf`.

## Citation

When using BRFSS data, cite:

> Centers for Disease Control and Prevention (CDC). Behavioral Risk Factor Surveillance System Survey Data. Atlanta, Georgia: U.S. Department of Health and Human Services, Centers for Disease Control and Prevention, [YEAR(S)].

## Related Research

The `docs/` folder includes:
- Courtemanche et al. (2017), "Early Effects of the Affordable Care Act on Health Care Access, Risky Health Behaviors, and Self-Assessed Health" — *Southern Economic Journal*. A health economics paper using BRFSS data.

## Expanding to More Years

The scripts default to 2023–2024, but the full dataset (2011–2024) is available on Dropbox and from the CDC. To expand:

1. Download additional `LLCP20XX.XPT` files and place them in `data/raw/`
2. In either `01_load_and_append` script, either:
   - set `first_year` / `last_year` for a consecutive range, or
   - set `years_to_load` for an explicit non-consecutive year list
3. Re-run both scripts
4. The `02_clean_and_harmonize` scripts handle variable name changes automatically — no edits needed

The optional low-memory loaders support the same choice in both languages.

## Updating for New Years

When new BRFSS data become available:

1. Download the `LLCP20XX.XPT` file from [CDC BRFSS](https://www.cdc.gov/brfss/annual_data/annual_data.htm)
2. Place it in `data/raw/`
3. Update `last_year` in both `01_load_and_append` scripts
4. Re-run both scripts
5. Check for any new variable name changes in the codebook and update `02_clean_and_harmonize` if needed
