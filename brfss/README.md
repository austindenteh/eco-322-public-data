# BRFSS — Behavioral Risk Factor Surveillance System

> **📥 Data download required.** The raw data files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/hjphv5f8dug0metx88l7c/AIqQ5rff1M_ipkjdeT9-3oE?rlkey=52hnkp7vfcoqwfbmpekhewu99&st=8hiwybzh&dl=0) and place them in `data/raw/`. See [Step 1](#step-1-obtain-the-data) for details.

Starter code and documentation for working with the CDC's Behavioral Risk Factor Surveillance System (BRFSS), 2000–2024.

## Overview

The BRFSS is the largest continuously conducted health survey in the world. Each year the CDC collects data on health-related risk behaviors, chronic health conditions, and use of preventive services from over 400,000 adults across all 50 U.S. states, the District of Columbia, and participating territories.

**Key features:**
- **Repeated cross-section** (not a panel) — a new random sample each year
- **Telephone survey** using random-digit dialing (primarily landline through 2010; landline + cell phone since 2011)
- **Complex survey design** requiring weights, strata, and PSU for correct inference
- **400,000-500,000 respondents per year** across 50 states + DC + territories
- **Years covered here:** 2000–2024, using separate 2000–2010 pre-2011 and 2011–2024 workflows
- **Manageable defaults:** pre-2011 scripts default to 2009–2010; 2011-plus scripts default to 2023–2024

### Why There Are Two Workflows

In 2011, BRFSS added cell-phone interviews to the existing landline design and changed its weighting method from post-stratification to raking. CDC cautions against treating estimates across this redesign as a seamless series. This repository therefore provides:

- a `*_pre2011` workflow for 2000–2010, using `_FINALWT`, `_STSTR`, and `_PSU`; and
- the 2011-plus workflow, currently supporting 2011–2024, using `_LLCPWT`, `_STSTR`, and `_PSU`.

The era-specific loaders and cleaners do not automatically append the two eras. The optional bridge below makes that append explicit; research spanning 2010 and 2011 should still state the design break and assess comparability for each outcome.

## Directory Structure

```
brfss/
├── README.md                  ← This file
├── code/
│   ├── 01_load_2011plus.do    ← Full-width 2011-plus loader (Stata)
│   ├── 01_load_2011plus.R     ← Full-width 2011-plus loader (R)
│   ├── 01_load_2011plus_optional_low_memory.do  ← Selected-column loader
│   ├── 01_load_2011plus_optional_low_memory.R   ← Selected-column loader
│   ├── 02_clean_2011plus.do   ← Clean 2011-plus files (Stata)
│   ├── 02_clean_2011plus.R    ← Clean 2011-plus files (R)
│   ├── 01_load_pre2011.do         ← Full-width 2000-2010 loader (Stata)
│   ├── 01_load_pre2011.R          ← Full-width 2000-2010 loader (R)
│   ├── 01_load_pre2011_optional_low_memory.do  ← Selected-column pre-2011 loader
│   ├── 01_load_pre2011_optional_low_memory.R   ← Selected-column pre-2011 loader
│   ├── 02_clean_pre2011.do        ← Clean 2000-2010 files (Stata)
│   ├── 02_clean_pre2011.R         ← Clean 2000-2010 files (R)
│   ├── 03_build_cross_era_bridge.do  ← Explicit opt-in era bridge (Stata)
│   └── 03_build_cross_era_bridge.R   ← Explicit opt-in era bridge (R)
├── data/
│   └── raw/                   ← LLCP20XX.XPT and CDBRFSYYXPT.zip files
├── docs/                      ← Codebooks, DQRs, calculated variable docs,
│                                and brfss_pre2011_inventory.md
└── output/                    ← Cleaned/appended datasets (created by scripts)
```

## Quick Start

### Step 1: Obtain the Data

The raw data files are too large for GitHub and must be downloaded separately. Files for 2011 onward are named `LLCP20XX.XPT`; pre-2011 downloads are normally named `CDBRFSYYXPT.zip` and contain `CDBRFSYY.XPT`.

**Option A — Dropbox (recommended):**
Download the data files from the shared folder:
https://www.dropbox.com/scl/fo/hjphv5f8dug0metx88l7c/AIqQ5rff1M_ipkjdeT9-3oE?rlkey=52hnkp7vfcoqwfbmpekhewu99&st=8hiwybzh&dl=0

| What to download | Size (approx.) | Script default? |
|---|---|---|
| `LLCP2023.XPT` + `LLCP2024.XPT` | ~2.0 GB | **Yes — start here** |
| All 14 files (2011–2024) | ~12 GB | Optional (expand year range in scripts) |
| `CDBRFS09XPT.zip` + `CDBRFS10XPT.zip` | Varies | **Pre-2011 default** |
| All 11 archives (2000–2010) | Varies | Optional pre-2011 expansion |

Place the `.XPT` files or pre-2011 ZIP archives in `data/raw/`.

**Option B — CDC website:**
1. Go to https://www.cdc.gov/brfss/annual_data/annual_data.htm
2. Select a survey year, then download the main annual **SAS Transport Format** file (`.XPT` or `.zip` containing the `.XPT`)
3. Repeat for each year you want
4. Place the `.XPT` files in `data/raw/`

> **Tip:** The 2011-plus scripts default to **2023–2024** and the pre-2011 scripts to **2009–2010**. Both families support a consecutive range or an explicit year list. Pre-2011 loaders accept the ZIP archive directly and match archive/member filename case safely.

The scripts auto-detect the `brfss/` folder if you run them either:
- from the `brfss/` directory, or
- from the `brfss/code/` directory, or
- from the repo root

You can also set `BRFSS_ROOT` in R or `global brfss_root` in Stata if you want to override the auto-detected path.

### Step 2: Load and Append 2011-Plus Years (currently 2011–2024)

**Stata:**
```stata
cd "/path/to/brfss"
do code/01_load_2011plus.do
```

Or from the repo root:
```stata
cd "/path/to/econ-data-starters"
do brfss/code/01_load_2011plus.do
```

**R:**
```r
setwd("/path/to/brfss")
source("code/01_load_2011plus.R")
```

Or from the repo root:
```r
setwd("/path/to/econ-data-starters")
source("brfss/code/01_load_2011plus.R")
```

This imports each year's `.XPT` file, adds a `surveyyear` identifier, and appends everything into a single stacked dataset. Outputs are language-specific:
- Stata: `output/brfss_2011plus_appended.dta`
- R: `output/brfss_2011plus_appended.rds`
- R export for Stata users: `output/brfss_2011plus_appended_from_r.dta`

Inside the main `01_*` scripts, you can either:
- set `first_year` / `last_year` for a consecutive range, or
- set `years_to_load` for an explicit non-consecutive year list

Examples:

- Stata: `local years_to_load "2011 2014 2024"`
- R: `years_to_load <- c(2011, 2014, 2024)`

For non-editing test overrides, set `BRFSS_YEARS` and `BRFSS_OUTPUT_DIR` in R or globals `$brfss_years` and `$brfss_output_dir` in Stata. Both 2011-plus loaders honor these settings; the 2011-plus cleaners honor the output-directory setting.

### Optional 2011-Plus Low-Memory Workflows

If you want to load many BRFSS years on a machine with limited RAM, you can use the optional low-memory `01_*` script for your language instead of the standard one.

Use:
- `01_load_2011plus.do` or `01_load_2011plus_optional_low_memory.do` in Stata
- `01_load_2011plus.R` or `01_load_2011plus_optional_low_memory.R` in R

Do not run both `01_*` scripts for the same language. Pick one path, then continue to Step 3 exactly as usual.

**Optional low-memory Stata loader**

```stata
cd "/path/to/brfss"
do code/01_load_2011plus_optional_low_memory.do
```

Use this instead of `01_load_2011plus.do` if you want a smaller appended Stata dataset and year-by-year temporary files. This Stata version still imports a full `.XPT` year before dropping unused columns, so the memory savings are smaller than in R, but it still helps by shrinking the kept columns before append and before the downstream harmonization step.

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
source("code/01_load_2011plus_optional_low_memory.R")
```

Use this instead of `01_load_2011plus.R`, not in addition to it. For most users, `01_load_2011plus.R` remains the default and simplest choice.

This optional script:
- reads one year at a time
- keeps only the raw columns needed by `02_clean_2011plus.R`
- can use `years_to_load <- c(...)` for non-consecutive years
- supports user-added variables through `extra_keep_vars` and `extra_var_families`
- still writes `output/brfss_2011plus_appended.rds`, so Step 3 stays the same

Example:

```r
years_to_load <- c(2011, 2014, 2024)

extra_var_families <- list(
  dental_visit = c("_denvst2", "_denvst3")
)
```

This creates a single `dental_visit` column by coalescing the listed aliases in order. If a variable family is absent in some loaded years, the optional script reports which years matched and leaves the unmatched years missing for that added column.

Use the standard `01_load_2011plus.R` instead if you want the full BRFSS raw file or many optional-module variables.

### Step 3: Clean and Harmonize 2011-Plus Years

**Stata:**
```stata
cd "/path/to/brfss"
do code/02_clean_2011plus.do
```

Or from the repo root:
```stata
cd "/path/to/econ-data-starters"
do brfss/code/02_clean_2011plus.do
```

**R:**
```r
setwd("/path/to/brfss")
source("code/02_clean_2011plus.R")
```

Or from the repo root:
```r
setwd("/path/to/econ-data-starters")
source("brfss/code/02_clean_2011plus.R")
```

This creates harmonized versions of variables that changed names or coding across years, cleans health outcomes, and includes lightweight example analysis. Outputs are language-specific:
- Stata: `output/brfss_2011plus_clean.dta`
- R: `output/brfss_2011plus_clean.rds`
- R export for Stata users: `output/brfss_2011plus_clean_from_r.dta`

## Pre-2011 Workflow (2000–2010)

Do not mix these scripts with the `01_load_2011plus` / `02_clean_2011plus` pair. Choose either the full-width or low-memory pre-2011 loader, then run the matching pre-2011 cleaner.

**Stata:**

```stata
cd "/path/to/brfss"
do code/01_load_pre2011.do
do code/02_clean_pre2011.do
```

For the selected-column alternative, substitute `01_load_pre2011_optional_low_memory.do` for the first command.

**R:**

```r
setwd("/path/to/brfss")
source("code/01_load_pre2011.R")
source("code/02_clean_pre2011.R")
```

For the selected-column alternative, substitute `01_load_pre2011_optional_low_memory.R` for the first script.

The outputs are kept separate from the 2011-plus era:

- Stata: `output/brfss_pre2011_appended.dta` and `output/brfss_pre2011_clean.dta`
- R: `output/brfss_pre2011_appended.rds` and `output/brfss_pre2011_clean.rds`
- Optional R-to-Stata exports use distinct `_from_r.dta` names

Edit `first_year` / `last_year` or `years_to_load` inside a loader, or use non-editing overrides for reproducible smoke tests:

```r
Sys.setenv(
  BRFSS_PRE2011_YEARS = "2000 2001 2002 2003",
  BRFSS_PRE2011_OUTPUT_DIR = "/path/to/scratch/output"
)
```

```stata
global brfss_pre2011_years "2000 2001 2002 2003"
global brfss_pre2011_output_dir "/path/to/scratch/output"
```

The full-width R loader preserves raw values when a legacy column switches between numeric and character storage. The cleaners handle year-specific aliases and BMI implied decimals, retain transparent raw/source fields, and run source-to-clean value checks. See [`docs/brfss_pre2011_inventory.md`](docs/brfss_pre2011_inventory.md) for file counts, variable transitions, county coverage, and completed R/Stata validation.

## Optional Cross-Era Bridge

Run the bridge only after creating both era-specific clean files. It performs an explicit mechanical append while retaining the 2011 methodology break.

**Stata:**

```stata
cd "/path/to/brfss"
do code/03_build_cross_era_bridge.do
```

**R:**

```r
setwd("/path/to/brfss")
source("code/03_build_cross_era_bridge.R")
```

Outputs:

- Stata: `output/brfss_cross_era_bridge.dta`
- R: `output/brfss_cross_era_bridge.rds`
- Optional R export: `output/brfss_cross_era_bridge_from_r.dta`

The bridge keeps a conservative set of variables already cleaned under the same names in both eras. It adds `survey_era`, `post2011`, `sampling_frame`, `weighting_method`, `weight_source`, `analysis_weight_raw`, `psu_raw`, and `strata_raw`. Because the source-era BMI categories differ, it preserves them as `bmi_cat_era_specific` and constructs a four-level `bmi_cat_cross_era` from continuous BMI.

The bridge does **not** normalize annual weights, issue a pooled survey declaration, or make a pooled trend specification. Those choices depend on the research estimand. The nominal `surveyyear + statefips + seqno` key is also not unique in the early files, so the bridge reports duplicated-key rows rather than treating them as an error.

Additional variables can be requested with `extra_bridge_vars` in R or `$brfss_bridge_extra_vars` in Stata, but they must already exist under the same name and have comparable coding in both cleaned files.

No separate low-memory bridge is needed. When RAM is constrained, build both era inputs with their optional low-memory loaders and add any needed bridge variables through the loaders' extra-variable hooks. The R bridge loads one era at a time and selects the bridge columns immediately, but R must still open a full-width RDS before it can select from it.

## 2011-Plus Variable Harmonization

Several key variables changed names or coding over the 2011–2024 period:

| Variable | Source variable(s) by year | Harmonized Name |
|---|---|---|
| Age | `_IMPAGE` (2011–2012), `_AGE80` (2013–2024) | `age` |
| Race/ethnicity | `_RACEGR2` (2011–2014), `_RACEGR3` (2015–2021, 2023–2024), `_RACEGR4` (2022) | `race_eth` |
| Income | `INCOME2` (2011–2020), `INCOME3` (2021–2024) | `income_cat` |
| Employment | `EMPLOY` (2011–2012), `EMPLOY1` (2013–2024) | `working`, `student` |
| Sex | `SEX` (2011–2020), `SEXVAR` with `BIRTHSEX` fallback when present (2021–2024) | `female` |
| County | `CTYCODE1` (2011–2012 only) | `county_code_raw`, `county_code_source`, `countyfips` |
| Diabetes | `DIABETE3` (2011–2018), `DIABETE4` (2019–2024) | `diabetes` |
| COPD | `CHCCOPD` / `CHCCOPD1` in older public-file layouts, `CHCCOPD3` in newer layouts | `copd` |

The cleaning scripts resolve these transitions automatically by checking which source variable is present.

`CTYCODE1` is present in the local 2011 and 2012 annual files and absent from 2013–2024. The cleaner accepts numeric county codes `1`–`840`, excludes `777`, `888`, and `999`, and constructs `countyfips = statefips * 1000 + county_code_raw`. Validation found 451,402 usable county rows in 2011 and 420,706 in 2012. These identifiers are a convenience for linkage, not a guarantee of county-level representativeness or adequate sample size.

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
| `surveyyear` | BRFSS survey year | 2011–2024 in the currently supported 2011-plus workflow |

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

### Dual / Multiple Questionnaire Files in 2006–2010

Some states used two or three questionnaire versions so that the unchanged core was asked of everyone while optional modules could rotate across sample subsets. CDC posted separate version data sets and version-specific weights to reduce ambiguity for those module analyses; see, for example, the [2008 multiple-questionnaire documentation](https://www.cdc.gov/brfss/annual_data/2008/2008_multiple.html).

These files are not additional survey waves or extra respondents. Do **not** append them to the main annual `CDBRFSYY.XPT` file, which is the correct source for this starter's core outcomes. If a project needs an optional module asked on only one version, retain `QSTVER`, use the year-specific version weight documented by CDC, or start from CDC's corresponding version-specific data set. The low-memory pre-2011 loader intentionally keeps only the standard core weight.

## Complex Sampling and Weighting

The BRFSS uses a **stratified, disproportionate random sample** design. The 2011-plus workflow uses `_LLCPWT`; the pre-2011 workflow uses `_FINALWT` and exposes it as `analysis_weight`. For correct standard errors and confidence intervals:

1. **Always use the era-appropriate survey weight** for weighted point estimates
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

## Changing the Loaded Years

The 2011-plus scripts currently support 2011–2024 and default to 2023–2024. The pre-2011 scripts support 2000–2010 and default to 2009–2010. Within the appropriate loader family:

1. Download the desired annual files and place them in `data/raw/`.
2. Set `first_year` / `last_year`, set an explicit `years_to_load`, or use the documented environment/global override.
3. Run one loader and its matching cleaner.
4. Review the annual codebooks for any project-specific variables not harmonized by the starter.

The optional low-memory loaders support the same year choices. Do not use one loader to cross the 2011 design break.

## Updating for New Years

When a new 2011-plus BRFSS annual file becomes available:

1. Download the `LLCP20XX.XPT` file from [CDC BRFSS](https://www.cdc.gov/brfss/annual_data/annual_data.htm)
2. Place it in `data/raw/`
3. Test it first through `BRFSS_YEARS` / `$brfss_years` and a scratch output directory
4. Check the new header and codebook for changed aliases, weights, optional modules, and disclosure fields
5. Extend the supported range only after both full/low-memory and R/Stata validation pass
