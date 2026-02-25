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
- **Years covered here:** 2005-2025 (default), raw data extends to 1988

### Why Start at 2005?

We default to 2005 forward to keep the analysis dataset manageable and to ensure availability of replicate weights (REPWTP1-REPWTP160) for variance estimation. This period covers the key policy events most relevant for health economics research: the Great Recession, the Affordable Care Act, and the COVID-19 pandemic. The raw extract includes data back to 1988 — see the "Extending to Earlier Years" section below.

### Data Source: IPUMS CPS

This data was extracted from **IPUMS CPS** (https://cps.ipums.org), which provides harmonized, consistently coded CPS data. IPUMS has already done extensive cross-year variable harmonization.

**Extract details:**
- Extract ID: cps_00010
- IPUMS CPS Version: 13.0 (February 2026)
- Raw year range: 1988-2025

## Directory Structure

```
march_cps/
├── README.md                      ← This file
├── code/
│   ├── 01_load_and_subset.do      ← Load raw data, restrict to 2005+ (Stata)
│   ├── 01_load_and_subset.R       ← Same in R
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

Two extracts are available:

| File | Years | Size | Notes |
|---|---|---|---|
| `cps_00012_2021_2025.dta` | 2021–2025 | ~2.6 GB | **Start here** — loads quickly, good for learning the code |
| `cps_00011_2005_2025.dta` | 2005–2025 | ~14 GB | Full analysis file — requires 16+ GB RAM |

Place whichever file(s) you download in `data/raw/`. The starter scripts will auto-detect which file is present.

**Option B — Create your own IPUMS CPS extract:**
If you need different years or variables, you can build a custom extract directly from IPUMS CPS. The starter scripts will work with any IPUMS CPS ASEC extract as long as the core variables are included.

1. **Create an account** at https://cps.ipums.org (free for researchers/students)
2. **Select samples**: Click "SELECT SAMPLES" → check the **ASEC** box for each year you want (e.g., 2010–2025). Make sure you are selecting ASEC samples, not the basic monthly CPS.
3. **Select variables**: Click "SELECT VARIABLES" and add at minimum the variables listed in our codebook (`docs/cps_00011_2005_2025.cbk`). The key variables needed by the starter scripts are:
   - *Demographics*: `AGE`, `SEX`, `RACE`, `HISPAN`, `EDUC`, `MARST`, `STATEFIP`
   - *Employment*: `EMPSTAT`, `LABFORCE`, `CLASSWKR`, `OCC`, `IND`
   - *Income*: `INCTOT`, `INCWAGE`, `INCSS`, `INCSSI`, `INCWELFR`, `INCUNEMP`
   - *Insurance*: `HIMCAIDLY`, `HIMCARELY`, `PHINSUR`, `ANYCOVLY`, `ANYCOVNW`
   - *Other*: `ASECWT`, `CPSIDP`, `FOODSTMP`, `CITIZEN`, `BPL`, `YRIMMIG`, `OFFPOV`, `POVERTY`
   - *Replicate weights (optional)*: `REPWTP` (adds REPWTP1–REPWTP160 for variance estimation)
4. **Submit extract**: Choose `.dta` (Stata) format, then click "SUBMIT EXTRACT"
5. **Download**: Once the extract is ready (check your email), download the `.dta` file and place it in `data/raw/`

The starter scripts auto-detect any `.dta` file in `data/raw/`, so your custom extract will work automatically.

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

The scripts auto-detect which data file is in `data/raw/`, load it, and save a working copy to `output/cps_asec.dta` (or `.rds`). If you have the full 2005–2025 extract, it restricts to the default year range; if you have the 2021–2025 extract, it loads everything directly.

### Step 3: Clean and Create Variables

**Stata:**
```stata
do code/02_clean_demographics.do
```

**R:**
```r
source("code/02_clean_demographics.R")
```

This creates cleaned demographic, income, employment, health insurance, immigration, and poverty variables with clear labels.

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

### Employment

| Variable | Description | Values |
|---|---|---|
| `employed` | Currently employed | 0/1 |
| `unemployed` | Currently unemployed | 0/1 (among labor force) |
| `in_labor_force` | In labor force | 0/1 |

### Income

| Variable | Description | Notes |
|---|---|---|
| `totalinc` | Total personal income | Nominal dollars |
| `wageinc` | Wage and salary income | Nominal, positive values only |
| `lnwage` | Log wage income | For regression |
| `ssinc` | Social Security income | If receiving |
| `ssiinc` | SSI income | If receiving |
| `welfareinc` | Welfare/TANF income | If receiving |

### Health Insurance

| Variable | Description | Years |
|---|---|---|
| `has_private_ins` | Has private insurance | Most years |
| `medicaid` | Covered by Medicaid | All years |
| `medicare` | Covered by Medicare | All years |
| `uninsured` | No health insurance | All years (harmonized) |
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
| `below_poverty` | Below 100% FPL |
| `below_138fpl` | Below 138% FPL (Medicaid expansion threshold) |
| `below_200fpl` | Below 200% FPL |
| `below_400fpl` | Below 400% FPL (ACA subsidy threshold) |

### Immigration

| Variable | Description | Available |
|---|---|---|
| `foreign_born` | Born outside US | 1994+ |
| `noncitizen` | Not a US citizen | 1994+ |
| `naturalized` | Naturalized citizen | 1994+ |

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
CPS households are in the sample for 4 months, out for 8, then in for 4 more. Use `CPSIDP` to link individuals across the two March supplements they appear in.

## Extending to Earlier Years

The raw extract covers 1988-2025. To include pre-2005 data, change `first_year` in the `01_load_and_subset` scripts. Key considerations:

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
