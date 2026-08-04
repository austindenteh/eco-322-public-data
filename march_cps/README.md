# March CPS — Current Population Survey, Annual Social and Economic Supplement

Starter code and documentation for working with the CPS ASEC (March CPS) via IPUMS CPS, 2005-2025.

> **📥 Data download required.** The raw data files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/9qlcqfe2u3sn1aufsv2tz/AH2i2TJdqraRGfG1_Ovu1Sk?rlkey=1vrhlm1nrosfzkzbon4jtmpoo&st=9dsmexpc&dl=0) and place them in `data/raw/`. See [Step 1](#step-1-obtain-the-data) for details.

## Overview

The Current Population Survey Annual Social and Economic Supplement (CPS ASEC), commonly called the "March CPS," is the primary U.S. government source for data on income, poverty, health insurance coverage, and detailed labor force characteristics. Conducted each March by the U.S. Census Bureau, it supplements the monthly CPS with extensive questions about the prior calendar year.

**Key features:**
- **Repeated cross-section** — a new sample each year (with partial 2-year overlap)
- **Person-level records** with household linkage
- **~150,000-200,000 persons per year**
- **Rich income detail**: wages, self-employment, Social Security, SSI, welfare, UI, pensions, interest, dividends, etc.
- **Health insurance coverage** (redesigned in 2014 and 2019)
- **Immigration and citizenship status** (1994+)
- **Transfer program participation** (SNAP, welfare/TANF, SSI, etc.)
- **Poverty status** using official Census thresholds
- **Years available here:** 2005-2025; the starter loaders default to 2005-2010 and can be extended to 2025

### Why Start at 2005?

We start the scripts at 2005 to ensure availability of replicate weights (REPWTP1-REPWTP160) for variance estimation. The default teaching window ends at 2010 so the starter workflow stays manageable, but the downloaded yearly files cover 2005-2025. Set `last_year` to 2025, or use the year-list overrides below, for the full period. Earlier CPS ASEC years can be added with additional yearly IPUMS extracts; see the "Extending to Earlier Years" section below.

### Data Source: IPUMS CPS

This data was extracted from **IPUMS CPS** (https://cps.ipums.org), which provides harmonized, consistently coded CPS data. IPUMS has already done extensive cross-year variable harmonization.

**Extract details:**
- Pre-built extracts used here: one yearly IPUMS CPS ASEC file per survey year, `cps_<extract id>_<year>.dta`
- Current yearly file set: `cps_00015_2005.dta` through `cps_00035_2025.dta`
- IPUMS CPS Version: 13.0 (February 2026)
- Raw year range available in the shared yearly files: 2005-2025
- Default loader range: 2005-2010

## Directory Structure

```
march_cps/
├── README.md                      ← This file
├── code/
│   ├── 01_load_and_subset.do      ← Load raw data, restrict to 2005+ (Stata)
│   ├── 01_load_and_subset.R       ← Same in R
│   ├── 01_load_and_subset_optional_low_memory.do  ← Optional selected-column loader
│   ├── 01_load_and_subset_optional_low_memory.R   ← Same in R
│   ├── 02_clean_demographics.do   ← Clean variables, create indicators (Stata)
│   └── 02_clean_demographics.R    ← Same in R
├── data/
│   └── raw/                       ← IPUMS CPS extract(s) — see Step 1
├── docs/                          ← Codebooks, XML metadata
└── output/                        ← Cleaned datasets (created by scripts)
```

## Quick Start

### Step 1: Obtain the Data

The raw data files are too large for GitHub and must be downloaded separately.

**Option A — Dropbox (recommended):**
Download data files from the shared folder:
https://www.dropbox.com/scl/fo/9qlcqfe2u3sn1aufsv2tz/AH2i2TJdqraRGfG1_Ovu1Sk?rlkey=1vrhlm1nrosfzkzbon4jtmpoo&st=9dsmexpc&dl=0

Download the yearly March CPS files and place them in `data/raw/`:

| Files | Years | Notes |
|---|---:|---|
| `cps_00015_2005.dta` ... `cps_00035_2025.dta` | 2005-2025 | One IPUMS CPS ASEC extract per survey year |

The starter scripts now expect one yearly file per requested year. The older bulk files, `cps_00012_2021_2025.dta` and `cps_00011_2005_2025.dta`, are deprecated for this workflow and can be deleted after the yearly files verify locally.

**Option B — Create your own IPUMS CPS extract:**
If you need different years or variables, you can build a custom extract directly from IPUMS CPS. The starter scripts will work with any IPUMS CPS ASEC extract as long as the core variables are included.

1. **Create a free account** at https://cps.ipums.org
2. **Select samples**: Click "SELECT SAMPLES" → check the **ASEC** box for each year you want (e.g., 2010–2025). Make sure you are selecting ASEC samples, not the basic monthly CPS.
3. **Select variables**: Click "SELECT VARIABLES" and add at minimum the variables listed in the yearly codebooks in `docs/` (for example, `docs/cps_00015.cbk`). The key variables needed by the starter scripts are:
   - *Demographics*: `AGE`, `SEX`, `RACE`, `HISPAN`, `EDUC`, `MARST`, `STATEFIP`
   - *Employment*: `EMPSTAT`, `LABFORCE`, `CLASSWKR`, `OCC`, `IND`
   - *Income*: `INCTOT`, `INCWAGE`, `INCSS`, `INCSSI`, `INCWELFR`, `INCUNEMP`
   - *Insurance*: `HIMCAIDLY`, `HIMCARELY`, `PHINSUR`, `ANYCOVLY`, `ANYCOVNW`
   - *Other*: `ASECWT`, `CPSIDP`, `FOODSTMP`, `CITIZEN`, `BPL`, `YRIMMIG`, `OFFPOV`, `OFFPOVUNIV`, `OFFTOTVAL`, `OFFCUTOFF`
   - *Replicate weights (optional)*: `REPWTP` (adds REPWTP1–REPWTP160 for variance estimation)
4. **Submit extract**: Choose `.dta` (Stata) format, then click "SUBMIT EXTRACT"
5. **Download**: Once each extract is ready (check your email), download the `.dta` file and place it in `data/raw/`. Name each file with its survey year at the end, such as `cps_00015_2005.dta`.

The starter scripts auto-detect files named `cps_<extract id>_<year>.dta` in `data/raw/`. If you build custom yearly extracts, keep the same naming pattern.

### Step 2: Load and Subset

**Stata:**
```stata
cd "/path/to/march_cps"
do code/01_load_and_subset.do
```

**R:**
```r
source("code/01_load_and_subset.R")
```

The scripts auto-detect the requested yearly files in `data/raw/`, append them, and save a working copy to `output/`.

- Stata writes `output/cps_asec.dta`
- R writes `output/cps_asec.rds` and an optional `output/cps_asec_from_r.dta` export

If path auto-detection fails, set the March CPS folder manually before running the scripts:

**Stata:**
```stata
global cps_root "/path/to/econ-data-starters/march_cps"
do "$cps_root/code/01_load_and_subset.do"
```

**R:**
```r
cps_root_manual <- "/path/to/econ-data-starters/march_cps"
source(file.path(cps_root_manual, "code", "01_load_and_subset.R"))
```

You can also set the R override before sourcing:

```r
Sys.setenv(CPS_ROOT = "/path/to/econ-data-starters/march_cps")
source("/path/to/econ-data-starters/march_cps/code/01_load_and_subset.R")
```

By default, the loaders use yearly files from 2005 through 2010. To load the full 2005-2025 period, change `last_year` inside the loader to `2025` or set an explicit year list first:

**Stata:**
```stata
global cps_years_to_load "2021 2022"
do code/01_load_and_subset.do
```

**R:**
```r
Sys.setenv(CPS_YEARS = "2021,2022")
source("code/01_load_and_subset.R")
```

The standard loaders keep all columns from the yearly files. For most student projects, use the low-memory loader and add only the project-specific variables that are needed:

**Stata:**
```stata
do code/01_load_and_subset_optional_low_memory.do
```

**R:**
```r
source("code/01_load_and_subset_optional_low_memory.R")
```

The optional loaders read one year at a time, keep only the columns needed by `02_clean_demographics.*`, write temporary selected-column files, append those smaller files, and then save the usual `output/cps_asec.*` working data. Both R and Stata select columns while reading each yearly DTA file. This avoids loading the full-column 2005-2025 CPS stack at once, although the final appended selected-column file must still fit in memory.

The R settings can be supplied before `source()`. For example:

```r
years_to_load <- c(2019L, 2021L, 2023L, 2025L)
extra_keep_vars <- c("diffhear", "diffeye")
source("code/01_load_and_subset_optional_low_memory.R")
```

Replicate weights are off by default in the optional loaders because they add 160 columns; turn on `keep_replicate_weights` inside the optional script if you need design-based standard errors. Add stable IPUMS variable names to `extra_keep_vars` / `local extra_keep_vars` if you want the low-memory loader to carry extra columns forward.

R writes the compact `output/cps_asec.rds` by default and skips the duplicate Stata export. Set `write_dta_export <- TRUE` before `source()` only when an R-created `.dta` copy is needed.

If an extra variable changes names across years, use `extra_var_families` instead. Each family lists raw aliases and creates one merged output column by filling from those aliases in order. This is only a name-alias merge; if the coding or meaning changes across years, harmonize that added variable later in `02_clean_demographics.*` or in your analysis code.

### Step 3: Clean and Create Variables

**Stata:**
```stata
do code/02_clean_demographics.do
```

**R:**
```r
source("code/02_clean_demographics.R")
```

This creates cleaned demographic, income, employment, health insurance, immigration, and poverty variables with clear labels. Stata writes `output/cps_clean.dta`; R writes `output/cps_clean.rds` and an optional `output/cps_clean_from_r.dta` export.

## Key Variables Created

### Demographics

| Variable | Description | Values |
|---|---|---|
| `age` | Age in years | 0-90 (top-coded) |
| `age_cat` | Age group | 1=0-17, 2=18-25, 3=26-34, 4=35-44, 5=45-54, 6=55-64, 7=65+ |
| `working_age` | Working-age adult | 0/1 (ages 18-64) |
| `female` | Female indicator | 0/1 |
| `race_eth` | Race/ethnicity | 1=White NH, 2=Black NH, 3=Hispanic, 4=Other NH |
| `marital_cat` | Marital status | 1=Married, 2=Div/Sep, 3=Widowed, 4=Never married |
| `educ_cat` | Education | 1=<HS, 2=HS, 3=Some college, 4=Bachelor's+ |
| `statefip` | State FIPS code | Standard FIPS |
| `individ` | Unique record ID within the saved extract | `year * 10000000 + serial * 100 + pernum` |

### Employment

| Variable | Description | Values |
|---|---|---|
| `employed` | Currently employed | 0/1 |
| `unemployed` | Currently unemployed | 0/1 (among labor force) |
| `in_labor_force` | In labor force | 0/1 |
| `fulltime_ly` | Full-time worker last year | 0/1 among valid `FULLPART` |
| `weeks_worked` | Weeks worked last year | Continuous `WKSWORK1` |

### Income

| Variable | Description | Notes |
|---|---|---|
| `totalinc` | Total personal income | Nominal dollars |
| `wageinc` | Wage and salary income | Nominal, positive values only |
| `lnwage` | Log wage income | Positive wage income only |
| `businc` | Business/self-employment income | Nominal, valid values only |
| `ssinc` | Social Security income | If receiving |
| `ssiinc` | SSI income | If receiving |
| `welfareinc` | Welfare/TANF income | If receiving |

### Health Insurance

| Variable | Description | Years |
|---|---|---|
| `has_private_ins` | Has private insurance | Most years |
| `medicaid` | Covered by Medicaid | All years |
| `medicare` | Covered by Medicare | All years |
| `employer_ins` | Employer/group health plan coverage | Through 2018 in this extract |
| `uninsured` | No health insurance | All years (harmonized) |
| `any_ins_ly` | Any coverage last year | 2019+ |
| `any_ins_now` | Any coverage at interview | 2014+ |

### Transfer Programs

| Variable | Description |
|---|---|
| `snap` | Household received SNAP/food stamps |
| `receives_ss` | Receives Social Security |
| `receives_ssi` | Receives SSI |
| `receives_welfare` | Receives welfare/TANF |
| `receives_ui` | Receives unemployment insurance |

### Poverty

| Variable | Description |
|---|---|
| `official_poverty_ratio` | Official family income divided by the official poverty cutoff |
| `below_poverty` | Below the official poverty line (`OFFPOV`) |
| `below_138fpl` | Below 138% of the official poverty cutoff |
| `below_200fpl` | Below 200% of the official poverty cutoff |
| `below_400fpl` | Below 400% of the official poverty cutoff |

### Immigration

| Variable | Description | Available |
|---|---|---|
| `foreign_born` | Born outside US | 1994+ |
| `us_citizen` | U.S. citizen | 1994+ |
| `noncitizen` | Not a US citizen | 1994+ |
| `naturalized` | Naturalized citizen | 1994+ |
| `yrimm` | Year of immigration | If foreign-born |

## Important Notes

### Income Reference Period
CPS ASEC income and insurance questions refer to the **prior calendar year**. For example, YEAR=2025 data contains income data for calendar year 2024. Current-status variables (employment, labor force status) refer to the survey week.

### Health Insurance Redesign
The CPS ASEC has redesigned health insurance questions twice:
- **2014**: ACA-era changes (new questions on marketplace coverage)
- **2019**: Major redesign of insurance battery

Cross-year comparisons of insurance rates should account for these breaks.

### Weights
- **ASECWT**: Person-level weight for the ASEC supplement (use for all analyses)
- **REPWTP1-REPWTP160**: Replicate weights for variance estimation (2005+)

```stata
* Simple weighted regression
regress outcome treatment controls [pweight = asecwt]

* With replicate weights for correct standard errors
svyset [pw=asecwt], sdr(repwtp*) vce(sdr)
svy: regress outcome treatment controls
```

### Linking Across Years
CPS households are in the sample for 4 months, out for 8, then in for 4 more. Use `CPSIDP` to link individuals across the two March supplements they appear in. The starter-created `individ` is only a unique record ID within the saved extract; it is not a longitudinal link key.

## Extending to Earlier Years

The current public file set covers 2005-2025. To include pre-2005 data, download additional yearly ASEC files, name them `cps_<extract id>_<year>.dta`, and change `first_year` in the `01_load_and_subset` scripts. Key considerations:

| Period | Notes |
|---|---|
| 1988-1991 | Education uses HIGRADE (not EDUC); no immigration variables |
| 1992-1993 | EDUC variable introduced (EDUC99 comparable 1992+) |
| 1994-2004 | Immigration variables available; no replicate weights |
| 2005-2013 | Full variable set; replicate weights available |
| 2014-2018 | ACA era; insurance questions updated |
| 2019-2025 | Major insurance redesign; ANYCOVLY introduced |

## Citation

When using IPUMS CPS data, cite:

> Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren, Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Megan Schouweiler, and Michael Westberry. IPUMS CPS: Version 13.0 [dataset]. Minneapolis, MN: IPUMS, 2026. https://doi.org/10.18128/D030.V13.0
