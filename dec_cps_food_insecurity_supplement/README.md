# December CPS — Food Security Supplement

Starter code and documentation for working with the CPS Food Security Supplement (CPS-FSS) via IPUMS CPS, December 2001--2025.

> **📥 Data files are too large for GitHub.** Download from the shared Dropbox folder and place in `data/raw/`:
> **[Dropbox: December CPS Data](https://www.dropbox.com/scl/fo/7vsklolwr6okgeltgnlvh/AEXNi-A9rHdJixqDGU84Hhw?rlkey=evb1qxksclcfruesklzt3z34n&st=4zjckgro&dl=0)**

## Overview

The **CPS Food Security Supplement (CPS-FSS)** is conducted each December as part of the Current Population Survey. It is the primary U.S. government source for measuring household food security — the extent to which households have consistent access to adequate food. The supplement also collects detailed information on SNAP participation, food spending, and use of other food assistance programs.

**Key features:**
- **Repeated cross-section** — a new sample each December (with partial 2-year overlap via CPS rotation)
- **Person-level records** with household linkage (~100,000--200,000 persons per year)
- **Food security status**: 4-category scale (high, marginal, low, very low) for households, adults, and children
- **Food security raw scores**: 18-item household, 10-item adult, 8-item child questionnaires
- **SNAP/food stamps**: participation, benefit amounts, monthly receipt patterns
- **Food spending**: weekly amounts by source (grocery, restaurant, other) — continuous through 2015, categorical thereafter
- **Other food assistance**: school lunch, WIC, food banks, soup kitchens, community meals
- **Demographics**: age, sex, race/ethnicity, education, employment, marital status, nativity
- **Years covered here:** December 2001--2025 (25 annual waves)

### Data Source: IPUMS CPS

This data was extracted from **IPUMS CPS** (https://cps.ipums.org), which provides harmonized, consistently coded CPS data.

**Extract details:**
- Extract ID: `cps_00014`
- IPUMS CPS Version: 13.0
- Samples: December CPS, 2001--2025
- Format: Fixed-format ASCII (`.dat`) with IPUMS load scripts
- Raw file size: approx. 2.3 GB

## Directory Structure

```
dec_cps_food_insecurity_supplement/
├── README.md                         ← This file
├── code/
│   ├── 01_load_and_subset.do         ← Load data, validate, save working copy (Stata)
│   ├── 01_load_and_subset.R          ← Same in R
│   ├── 01_load_and_subset_optional_low_memory.do  ← Optional selected-column loader
│   ├── 01_load_and_subset_optional_low_memory.R   ← Same in R
│   ├── 02_clean_and_analyze.do       ← Clean variables, food security outcomes (Stata)
│   └── 02_clean_and_analyze.R        ← Same in R
├── data/
│   └── raw/                          ← IPUMS extract files (.dat, .do, .xml, .R)
├── docs/                             ← Codebook (cps_00014.cbk)
├── output/                           ← Cleaned datasets (created by scripts)
└── legacy/                           ← Original research scripts
```

## Quick Start

### Step 1: Obtain the Data

Place data files in `data/raw/`. The starter scripts auto-detect whichever format is available.

**Option A — Dropbox (recommended):**
1. Download from the [Dropbox folder](https://www.dropbox.com/scl/fo/7vsklolwr6okgeltgnlvh/AEXNi-A9rHdJixqDGU84Hhw?rlkey=evb1qxksclcfruesklzt3z34n&st=4zjckgro&dl=0)
2. Place files in `data/raw/`
3. If a pre-converted `.dta` file is available on Dropbox, the scripts will use it directly
4. Otherwise, download `cps_00014.dat` + `cps_00014.do` + `cps_00014.xml` — the scripts will load from the raw ASCII

**Option B — Create your own IPUMS CPS extract:**
1. Go to https://cps.ipums.org and create an account
2. Select samples: check **December** for each year you want (2001--2025)
3. Select variables: see Key Variables below
4. Download and place in `data/raw/`

> **Note on data formats:** The IPUMS extract is a fixed-format ASCII file (`.dat`) that requires the accompanying `.do` file (Stata) or `.xml` file (R/ipumsr) to load. The starter scripts handle this automatically. If a pre-converted `.dta` file is available, the scripts will load that instead (faster).

### Step 2: Load and Validate

**Stata:**
```stata
cd "/path/to/dec_cps_food_insecurity_supplement"
do code/01_load_and_subset.do
```

**R:**
```r
source("code/01_load_and_subset.R")
```

This loads the IPUMS extract (auto-detecting `.dta` or `.dat` format), verifies all records are December, creates unique identifiers, validates key variables, and saves a working copy to `output/`.

If path auto-detection fails, set the December CPS folder manually before running the scripts:

**Stata:**
```stata
global dec_cps_root "/path/to/eco-322-public-data/dec_cps_food_insecurity_supplement"
do "$dec_cps_root/code/01_load_and_subset.do"
```

**R:**
```r
dec_cps_root_manual <- "/path/to/eco-322-public-data/dec_cps_food_insecurity_supplement"
source(file.path(dec_cps_root_manual, "code", "01_load_and_subset.R"))
```

You can also set the R override before sourcing:

```r
Sys.setenv(DEC_CPS_ROOT = "/path/to/eco-322-public-data/dec_cps_food_insecurity_supplement")
source("/path/to/eco-322-public-data/dec_cps_food_insecurity_supplement/code/01_load_and_subset.R")
```

The standard loaders keep all columns from the IPUMS extract. If you only need the starter variables, use the optional low-memory loader instead:

**Stata:**
```stata
do code/01_load_and_subset_optional_low_memory.do
```

**R:**
```r
source("code/01_load_and_subset_optional_low_memory.R")
```

The optional loaders read only the columns needed by `02_clean_and_analyze.*`, plus any user-requested extra columns, and then save the usual `output/dec_cps_working.*` file. The current December CPS extract is a single focused 2.3 GB IPUMS file, so yearly files are not required for the low-memory workflow.

Add stable IPUMS variable names to `extra_keep_vars` / `local extra_keep_vars` if you want the low-memory loader to carry extra columns forward. In R, you can either edit those settings inside the script or set them before `source()`. If an extra variable changes names across years, use `extra_var_families` instead. Each family lists raw aliases and creates one merged output column by filling from those aliases in order. This is only a name-alias merge; if the coding or meaning changes across years, harmonize that added variable later in `02_clean_and_analyze.*` or in your analysis code.

### Step 3: Clean and Analyze

**Stata:**
```stata
do code/02_clean_and_analyze.do
```

**R:**
```r
source("code/02_clean_and_analyze.R")
```

This creates demographics, food security outcomes, SNAP participation indicators, and other food assistance variables. The R script keeps descriptive statistics and example regression blocks optional; the Stata script prints starter tabulations while cleaning.

## Key Variables Created

### Food Security Status

| Variable | Description | Values |
|---|---|---|
| `fs_high` | High food security | 0/1 |
| `fs_marginal` | Marginal food security | 0/1 |
| `fs_low` | Low food security | 0/1 |
| `fs_verylow` | Very low food security | 0/1 |
| `food_insecure` | Food insecure (low + very low) | 0/1 |
| `fsa_high` ... `fsa_verylow` | Adult food security indicators | 0/1 |
| `adult_food_insecure` | Adult food insecure | 0/1 |
| `fsc_low`, `fsc_verylow` | Child food security indicators | 0/1 |
| `child_food_insecure` | Child food insecure | 0/1 |
| `fsrawscr` | Raw food security score (18-item, household) | 0--18 |
| `fsrawscra` | Raw food security score (10-item, adult) | 0--10 |
| `fsrawscrc` | Raw food security score (8-item, child) | 0--8 |

### SNAP and Food Assistance

| Variable | Description | Values |
|---|---|---|
| `snap_participant` | Received SNAP in past year | 0/1 |
| `school_lunch` | Children received free/reduced lunch | 0/1 |
| `wic` | Received WIC | 0/1 |
| `food_bank` | Received food from food bank/pantry | 0/1 |
| `soup_kitchen` | Used soup kitchen | 0/1 |

### Demographics

| Variable | Description | Values |
|---|---|---|
| `female` | Female indicator | 0/1 |
| `hisp` | Hispanic (any race) | 0/1 |
| `white` ... `other` | Race indicators (non-Hispanic) | 0/1 |
| `race_eth` | Mutually exclusive race/ethnicity | White NH, Black NH, Hispanic, Asian NH, Other NH |
| `married` | Currently married | 0/1 |
| `senior` | Age 60 or older | 0/1 |
| `foreignborn` | Born outside the U.S. | 0/1 |
| `age_18_24` ... `age_65plus` | Age group indicators | 0/1 |

### Education

| Variable | Description | Values |
|---|---|---|
| `educ_lths` | Less than high school | 0/1 |
| `educ_hs` | High school / GED / some college | 0/1 |
| `educ_assoc` | Associate degree | 0/1 |
| `educ_bach` | Bachelor's degree | 0/1 |
| `educ_advdeg` | Advanced degree (MA/PhD/professional) | 0/1 |

### Employment

| Variable | Description | Values |
|---|---|---|
| `employed` | Currently employed | 0/1 |
| `unemployed` | Currently unemployed | 0/1 |
| `not_in_lf` | Not in labor force | 0/1 |

### Household Composition

| Variable | Description | Values |
|---|---|---|
| `any_child` | Household has children | 0/1 |
| `hh_anysenior` | Household has any member 60+ | 0/1 |
| `hh_allsenior` | All household members 60+ | 0/1 |

### Identifiers and Survey Design

| Variable | Description |
|---|---|
| `year` | Survey year (2001--2025) |
| `hhid` | Unique household ID (year × 10M + serial) |
| `individ` | Unique person ID (hhid × 100 + pernum) |
| `fshwtscale` | Food security scale weight |
| `fssuppwth` | FSS household supplement weight |
| `wtfinl` | CPS final person weight |

## Important Notes

### Weights

The CPS-FSS provides several weight variables for different analyses:

| Weight | Use For |
|---|---|
| `fshwtscale` | Food security status and raw score analyses |
| `fssuppwth` | Other FSS variables (SNAP, food spending, food assistance) |
| `wtfinl` | Basic CPS demographic variables |

**Stata:**
```stata
* Food security analysis
reg food_insecure female age i.race_eth [pw=fshwtscale], robust

* SNAP participation analysis
reg snap_participant female age i.race_eth [pw=fssuppwth], robust
```

**R:**
```r
lm(food_insecure ~ female + age + factor(race_eth),
   data = cps, weights = fshwtscale)
```

### Food Security Measurement

The USDA's food security scale classifies households into four categories based on responses to an 18-item questionnaire:

| Category | Raw Score (18-item) | Description |
|---|---|---|
| **High** food security | 0 | No reported food access problems |
| **Marginal** food security | 1--2 | Anxiety about food sufficiency, minor adjustments |
| **Low** food security | 3--5 (no children) or 3--7 (with children) | Reduced quality/variety, but no reduced intake |
| **Very low** food security | 6--18 (no children) or 8--18 (with children) | Disrupted eating, reduced intake |

"Food insecure" = low + very low food security.

### Food Spending Variables

Continuous food spending variables (`fstotxpn`, `fsspdmkt`, `fsspdstr`, `fsspdrest`, `fsspdoth`, `fsulxpns`) were **discontinued after 2015**. From 2016 onward, only categorical versions are available (e.g., `fstotxpnc`). For time-series analyses of food spending, either:
- Restrict to 2001--2015 (continuous values), or
- Use categorical versions throughout (2001--2025)

### December-Only Data

All records in this extract are from the **December** CPS. The Food Security Supplement is administered only in December. This means:
- Each year contributes one cross-section
- Employment and demographic variables reflect December conditions
- SNAP participation questions refer to the past 12 months

### Household vs. Person Level

Food security status is measured at the **household level** — all persons in a household share the same food security status. When analyzing food security:
- Consider restricting to one person per household (e.g., the household reference person where `relate == 101`)
- Use household-level weights (`fshwtscale` or `fssuppwth`)

## Citation

When using IPUMS CPS data, cite:

> Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren, Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Megan Schouweiler, and Michael Westberry. IPUMS CPS: Version 13.0 [dataset]. Minneapolis, MN: IPUMS, 2025. https://doi.org/10.18128/D030.V13.0
