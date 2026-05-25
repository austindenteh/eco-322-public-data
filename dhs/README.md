# Ghana DHS — Demographic and Health Surveys

Starter code and documentation for working with the Ghana Demographic and Health Surveys (DHS), 1988–2022.

> **📥 Data download required.** The raw DHS data files require registration and cannot be redistributed. Download them from [the DHS Program](https://dhsprogram.com/data/) and place the recode files in `data/raw/ghana_YYYY/`. See [Step 1](#step-1-obtain-the-data) for details.

## Overview

The Demographic and Health Surveys (DHS) Program has conducted nationally representative household surveys in over 90 countries since 1984. The **Ghana DHS** has been conducted 7 times (1988, 1993, 1998, 2003, 2008, 2014, 2022), providing detailed data on health, fertility, nutrition, and demographic characteristics of the Ghanaian population.

**Key features:**
- **Repeated cross-section** — new sample each wave
- **Women (ages 15–49)** and **men (ages 15–59)** interviewed separately
- **Demographics**: age, education, literacy, marital status, employment, religion, ethnicity
- **Health insurance**: Ghana's National Health Insurance Scheme (NHIS) enrollment
- **Wealth**: DHS-constructed wealth index quintiles
- **Regional data**: 10 regions (1988–2014), 16 regions (2022, post-2019 reorganization)
- **Complex survey design** with weights, clusters, and strata
- **Additional recodes available**: births (BR), children (CR/KR), household (HR), household members (PR)

**What the starter scripts produce (for each wave):**
- `ghana_dhs_YYYY_working.dta` / `.rds` — Harmonized women + men pooled dataset
- `ghana_dhs_YYYY_analysis.dta` / `.rds` — Cleaned analysis dataset with constructed variables

For selected-year or pooled work, use `code/01_load_selected_years.R` or
`code/01_load_selected_years.do`. These standalone loaders read only the
columns needed for the starter output plus any user-requested extra variables,
support selected waves and women/men recodes, and save a combined selected-years
working file. The wave-specific `01_load_YYYY` scripts remain available for
full-file builds and for inspecting the detailed harmonization logic for a
single survey wave.

### Data Source

Downloaded from the **DHS Program** data repository:
- https://dhsprogram.com/data/
- Country: Ghana
- Registration required (free for academic use)

---

## Available Waves

| Wave | DHS Phase | Women (IR) | Men (MR) | Regions | Insurance Data | Wealth Index |
|------|-----------|-----------|----------|---------|----------------|--------------|
| 1988 | II | 4,488 | — | 10* | No | No |
| 1993 | III | 4,562 | 1,302 | 10 | No | No |
| 1998 | IV | 4,843 | 1,546 | 10 | No | No |
| 2003 | IV+ | 5,691 | 5,015 | 10 | No | Yes |
| 2008 | V | 4,916 | 4,568 | 10 | Yes (NHIS) | Yes |
| 2014 | VII | 9,396 | 4,388 | 10 | Yes (NHIS) | Yes |
| 2022 | VIII | 15,014 | 7,044 | 16 | Yes (NHIS) | Yes |

\* 1988 uses `v101`/`v102` for region/residence instead of `v024`/`v025`.

**Starter scripts are provided for all 7 waves (1988–2022)** in both Stata and R. The three most recent waves (2008, 2014, 2022) include health insurance data relevant to health economics research.

---

## Directory Structure

```
dhs/
├── README.md                    ← This file
├── code/
│   ├── 01_load_1988.do/.R       ← Load & harmonize 1988 women only (no men's recode)
│   ├── 01_load_1993.do/.R       ← Load & harmonize 1993 women + men
│   ├── 01_load_1998.do/.R       ← Load & harmonize 1998 women + men
│   ├── 01_load_2003.do/.R       ← Load & harmonize 2003 women + men
│   ├── 01_load_2008.do/.R       ← Load & harmonize 2008 women + men
│   ├── 01_load_2014.do/.R       ← Load & harmonize 2014 women + men
│   ├── 01_load_2022.do/.R       ← Load & harmonize 2022 women + men
│   ├── 01_load_selected_years.do  ← Load selected waves/samples and combine
│   ├── 01_load_selected_years.R
│   ├── 02_clean_1988.do/.R      ← Clean & analyze 1988 (no literacy/wealth/insurance)
│   ├── 02_clean_1993.do/.R      ← Clean & analyze 1993 (no literacy/wealth/insurance)
│   ├── 02_clean_1998.do/.R      ← Clean & analyze 1998 (no literacy/wealth/insurance)
│   ├── 02_clean_2003.do/.R      ← Clean & analyze 2003 (has literacy/wealth, no insurance)
│   ├── 02_clean_2008.do/.R      ← Clean & analyze 2008 (full variable set incl. NHIS)
│   ├── 02_clean_2014.do/.R      ← Clean & analyze 2014 (full variable set incl. NHIS)
│   └── 02_clean_2022.do/.R      ← Clean & analyze 2022 (full variable set, 16 regions)
├── data/
│   └── raw/
│       ├── ghana_1988/          ← DHS recode files for 1988
│       ├── ghana_1993/          ← DHS recode files for 1993
│       ├── ghana_1998/          ← DHS recode files for 1998
│       ├── ghana_2003/          ← DHS recode files for 2003
│       ├── ghana_2008/          ← DHS recode files for 2008
│       ├── ghana_2014/          ← DHS recode files for 2014
│       └── ghana_2022/          ← DHS recode files for 2022
├── docs/                        ← Reference code and documentation
├── output/                      ← Generated datasets and logs (ignored)
└── legacy/                      ← Original files (preserved per project rules)
```

---

## Quick Start

### Step 1: Obtain the Data

1. Register at [dhsprogram.com](https://dhsprogram.com/data/) (free for academic users)
2. Request access to the Ghana DHS datasets
3. Download the **Stata (.DTA)** recode files for each wave
4. Place the Stata recode folders in the appropriate `data/raw/ghana_YYYY/` subfolder, preserving the DHS subfolder structure

**Expected file paths (example for 2008):**
```
data/raw/ghana_2008/GHIR5ADT/GHIR5AFL.DTA    ← Women's Individual Recode
data/raw/ghana_2008/GHMR5ADT/GHMR5AFL.DTA    ← Men's Recode
```

**File naming convention:**
- `GH` = Ghana, `IR` = Individual (Women) Recode, `MR` = Men's Recode
- `5A` = Phase V (2008), `72`/`71` = Phase VII (2014), `8C` = Phase VIII (2022)
- `DT` = Stata format, `FL` = flat file

| Wave | Women's IR File | Men's MR File |
|------|----------------|---------------|
| 1988 | `GHIR02DT/GHIR02FL.DTA` | Not available |
| 1993 | `GHIR31DT/GHIR31FL.DTA` | `GHMR31DT/GHMR31FL.DTA` |
| 1998 | `GHIR41DT/GHIR41FL.DTA` | `GHMR41DT/GHMR41FL.DTA` |
| 2003 | `GHIR4BDT/GHIR4BFL.DTA` | `GHMR4BDT/GHMR4BFL.DTA` |
| 2008 | `GHIR5ADT/GHIR5AFL.DTA` | `GHMR5ADT/GHMR5AFL.DTA` |
| 2014 | `GHIR72DT/GHIR72FL.DTA` | `GHMR71DT/GHMR71FL.DTA` |
| 2022 | `GHIR8CDT/GHIR8CFL.DTA` | `GHMR8CDT/GHMR8CFL.DTA` |

### Step 2: Load and Harmonize

The selected-years loaders are usually the easiest way to create a pooled
starter file. By default, they process all available waves, write
`ghana_dhs_selected_working.*`, and also write per-wave working files. Set
selected years, samples, extras, and output directories before running if you
want a smaller or scratch build.

**Stata** (example from the repository root):
```stata
global dhs_years "2008 2022"
global dhs_samples "women men"
global dhs_output_dir "/private/tmp/dhs_smoke"
global dhs_write_wave_outputs "1"
global dhs_extra_keep_vars "v133"
global dhs_extra_var_families `" "insurance_type:v481c v481e mv481c mv481e" "'
do "dhs/code/01_load_selected_years.do"
```

**R** (example from the repository root):
```r
dhs_years <- c(2008, 2022)
dhs_samples <- c("women", "men")
dhs_output_dir <- "/private/tmp/dhs_smoke"
write_wave_outputs <- TRUE
extra_vars <- c("v133")
extra_var_families <- list(
  insurance_type = c("v481c", "v481e", "mv481c", "mv481e")
)
source("dhs/code/01_load_selected_years.R")
```

From `dhs/`, use `code/01_load_selected_years.*`; from `dhs/code/`, use
`01_load_selected_years.*`.

This loads the women's individual recode and men's recode, harmonizes the DHS
variable names (women use `v` prefix, men use `mv` prefix) into a common
surface, appends selected samples and years, and saves a working dataset. The
combined output includes `survey_year`, which records the DHS wave year even
when fieldwork spans two calendar years.

### Combining Waves Responsibly

DHS waves are not equally easy to pool. The selected-years loaders create a
starter surface that is useful for teaching, first-pass descriptives, and
building your own harmonized file, but they do not make every DHS concept fully
comparable across time.

Recommended pooled windows:

- **2008 and 2014**: strongest pair for NHIS work because both have health-insurance variables and the same 10-region geography.
- **2008, 2014, and 2022**: useful for national NHIS/descriptive work, but 2022 uses Ghana's post-2019 16-region geography; map regions before raw region comparisons.
- **2003, 2008, 2014, and 2022**: good for common demographics, wealth, and literacy; health insurance remains missing in 2003.
- **1993 onward**: reasonable for basic demographics, education level, marital status, employment, religion, ethnicity, and sex-pooled women/men samples; no wealth or literacy before 2003 and no health insurance before 2008.
- **1988 plus later waves**: use mainly for women-only long-run comparisons; 1988 has no men's recode and uses older region/residence variables that the loader maps onto the starter surface.

The combined selected-years output includes these wave-level flags to keep the
warnings visible in the data: `region_scheme`, `has_men_recode`,
`has_wealth_index`, `has_literacy`, and `has_health_insurance`. Extra-variable
families only coalesce aliases by name; users should verify coding and meaning
before interpreting added variables across waves.

Manual root overrides are available if auto-detection fails:

```stata
global dhs_root "/path/to/econ-data-starters/dhs"
do "$dhs_root/code/01_load_selected_years.do"
```

```r
dhs_root_manual <- "/path/to/econ-data-starters/dhs"
source(file.path(dhs_root_manual, "code", "01_load_selected_years.R"))
```

The older wave-specific loaders still work from `dhs/code/`:

```stata
do 01_load_2008.do
```

```r
source("01_load_2008.R")
```

### Step 3: Clean and Analyze

**Stata:**
```stata
do 02_clean_2008.do    // or 02_clean_2014.do, 02_clean_2022.do
```

**R:**
```r
source("02_clean_2008.R")    # or 02_clean_2014.R, 02_clean_2022.R
```

---

## Key Variables Created

### Identifiers and Design

| Variable | Description |
|----------|-------------|
| `female` | Female respondent indicator (1=women's sample, 0=men's sample) |
| `source_sample` | Source sample ("women" or "men") |
| `survey_year` | DHS survey wave year, stable for pooled selected-years files |
| `region_scheme` | Region coding scheme for the wave (`10_region` or `16_region`) |
| `has_men_recode` | Indicator that the wave has a men's recode in this starter |
| `has_wealth_index` | Indicator that the wave has DHS wealth-index variables |
| `has_literacy` | Indicator that the wave has literacy variables |
| `has_health_insurance` | Indicator that the wave has health-insurance variables |
| `cluster_id` | DHS survey cluster number |
| `household_id` | Household number within cluster |
| `respondent_id` | Respondent line number within household |
| `sample_weight` | De-normalized individual sample weight (divide by 1,000,000) |
| `interview_year` | Year of interview |
| `interview_month` | Month of interview |

### Demographics

| Variable | Description | Values |
|----------|-------------|--------|
| `age_years` | Respondent's current age | 15–49 (women), 15–59 (men) |
| `age_group` | 5-year age group | 1–8 |
| `urban` | Urban residence | 0/1 |
| `region` | Administrative region (DHS code) | 1–10 (2008/2014), 1–16 (2022) |
| `northern` | Northern Ghana indicator | 0/1 |
| `married` | Currently married | 0/1 |
| `cohabiting` | Living with partner | 0/1 |
| `in_union` | Currently in union (married or cohabiting) | 0/1 |
| `employed` | Currently working | 0/1 |

### Education

| Variable | Description | Values |
|----------|-------------|--------|
| `educ_level` | Highest education level | 0=None, 1=Primary, 2=Secondary, 3=Higher |
| `educ_none` | No formal education | 0/1 |
| `educ_primary` | Primary education | 0/1 |
| `educ_second` | Secondary education | 0/1 |
| `educ_higher` | Higher/tertiary education | 0/1 |
| `literate` | Can read at least parts of a sentence | 0/1 |

### Health Insurance

| Variable | Description | Values |
|----------|-------------|--------|
| `any_insurance` | Covered by any health insurance | 0/1 |
| `nhis_enrolled` | Enrolled in NHIS (National Health Insurance Scheme) | 0/1 |
| `non_nhis_insurance` | Has non-NHIS insurance only | 0/1 |

### Religion

| Variable | Description | Values |
|----------|-------------|--------|
| `christian` | Any Christian denomination | 0/1 |
| `catholic` | Catholic | 0/1 |
| `protestant` | Protestant (Anglican, Methodist, Presbyterian) | 0/1 |
| `pentecostal` | Pentecostal/Charismatic | 0/1 |
| `muslim` | Muslim | 0/1 |
| `traditional` | Traditional/spiritualist | 0/1 |

### Ethnicity

| Variable | Description | Values |
|----------|-------------|--------|
| `akan` | Akan ethnic group | 0/1 |
| `ga_dangme` | Ga/Dangme | 0/1 |
| `ewe` | Ewe | 0/1 |
| `mole_dagbani` | Mole-Dagbani | 0/1 |
| `grusi` | Grusi | 0/1 |
| `gurma` | Gurma | 0/1 |

### Wealth

| Variable | Description | Values |
|----------|-------------|--------|
| `wealth_index` | DHS wealth index quintile | 1=Poorest, …, 5=Richest |
| `poor` | Bottom two wealth quintiles | 0/1 |

---

## Important Notes

### NHIS Variable Mapping Across Waves

The DHS variable for NHIS enrollment **changed location between 2008 and 2014**. The load scripts handle this automatically, but researchers working with raw DHS data should be aware:

| Wave | NHIS Variable (Women) | NHIS Variable (Men) | Notes |
|------|-----------------------|---------------------|-------|
| 2008 | `v481c` | `mv481c` | "health insurance type: national/district (nhis)" |
| 2014 | `v481e` | `mv481e` | `v481c` reassigned to "social security" (all missing in Ghana) |
| 2022 | `v481e` | `mv481e` | Same as 2014 |

### Ghana's 2019 Regional Reorganization

Ghana created **6 new regions** in 2019, expanding from 10 to 16 administrative regions:

| Old Region | New Region(s) |
|-----------|--------------|
| Western | Western + **Western North** |
| Brong Ahafo | **Bono** + **Bono East** + **Ahafo** |
| Volta | Volta + **Oti** |
| Northern | Northern + **Savannah** + **North East** |

The 2008 and 2014 DHS use the **10-region** structure; the 2022 DHS uses the **16-region** structure. Direct region-level comparisons across these waves require mapping the new regions back to the old boundaries.

### Sample Weights

DHS individual sample weights are stored with **6 implied decimal places**. The load scripts de-normalize them:
```
sample_weight = v005 / 1,000,000
```

Use `sample_weight` for all weighted analyses. For example:
```stata
* Stata
svyset cluster_id [pweight=sample_weight]
svy: mean nhis_enrolled, over(female)
```
```r
# R
library(survey)
des <- svydesign(ids = ~cluster_id, weights = ~sample_weight, data = dhs)
svymean(~nhis_enrolled, des, na.rm = TRUE)
```

### Women vs. Men Recodes

- **Women's Individual Recode (IR)**: ages 15–49, variables use `v` prefix (e.g., `v012` = age)
- **Men's Recode (MR)**: ages 15–59, variables use `mv` prefix (e.g., `mv012` = age)

The load scripts harmonize these into a common set of variable names and stack both samples into a single dataset, with `female` (1/0) distinguishing the two samples.

### Missing Values

The DHS uses **9** or **99** as missing value codes for many variables. The load scripts recode these to system missing (`.` in Stata, `NA` in R) for the insurance variables. The clean scripts handle missing codes for religion (99) and ethnicity (99) when creating binary indicators.

### 2022 DHS File Size

The 2022 women's individual recode has **5,584 variables** (15,014 observations). The selected-years loaders avoid importing all 5,584 variables when a starter build only needs selected columns. In full-file Stata builds, you may need:
```stata
set maxvar 10000
```

### Raw Data and Output Hygiene

The `data/`, `legacy/`, and `output/` folders are ignored by Git. Do not commit
DHS raw recode files, generated `.dta` or `.rds` outputs, local logs, or scratch
smoke-test directories. Use `dhs_output_dir` to point smoke tests to a temporary
directory such as `/private/tmp/dhs_smoke`.

---

## Earlier-Wave Differences

The starter scripts cover all seven waves. Earlier waves differ from the
2008+ health-insurance waves in several important ways:

| Feature | 1988 | 1993–1998 | 2003 | 2008+ |
|---------|------|-----------|------|-------|
| Region variable | `v101` | `v024` | `v024` | `v024` |
| Urban/rural | `v102` | `v025` | `v025` | `v025` |
| Men's recode | Not available | Available | Available | Available |
| Wealth index (`v190`) | No | No | Yes | Yes |
| Literacy (`v155`) | No | No | Yes | Yes |
| Health insurance (`v481`) | No | No | No | Yes |
| Educational attainment (`v149`) | No | Yes | Yes | Yes |

---

## Citation

If you use these data, cite the specific DHS survey:

> Ghana Statistical Service (GSS), Ghana Health Service (GHS), and ICF International. *Ghana Demographic and Health Survey [year]*. Accra, Ghana: GSS, GHS, and ICF International.

The DHS Program also provides formatted citations at: https://dhsprogram.com/data/
