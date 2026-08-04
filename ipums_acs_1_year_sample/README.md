# IPUMS ACS — American Community Survey (1-Year Samples)

Starter code and documentation for working with the ACS 1-year samples via IPUMS USA, 2006--2024.

> **📥 Data files are too large for GitHub.** Download pre-built extracts from the shared Dropbox folder, or create your own extract from IPUMS:
> **[Dropbox: IPUMS ACS Data](https://www.dropbox.com/scl/fo/ds69nbylyp6582opynk3w/AIOmznaVTgjnjtcNY7rSFsw?rlkey=ctrwg26u0c2z6prjwz4llnx5a&st=6hts8sht&dl=0)**

## Overview

The **American Community Survey (ACS)** is an annual survey conducted by the U.S. Census Bureau that replaced the decennial census long form. The **1-year samples** provide cross-sectional data for areas with populations of 65,000 or more.

**Key features:**
- **Repeated cross-section** — a new sample every year (2006--2024 in this extract)
- **Person-level records** covering the entire U.S. population
- **Approx. 3.5 million respondents per year**
- **Demographics**: age, sex, race/ethnicity, marital status, household structure
- **Education**: attainment, school enrollment, grade level
- **Employment and income**: labor force status, wages, total income, poverty
- **Health insurance**: any coverage, private, public, Medicaid, Medicare (2008+)
- **Immigration**: citizenship, year of immigration, birthplace, language
- **Disability**: cognitive, physical, mobility, self-care, sensory difficulties
- **Housing**: rooms, plumbing, phone, internet access
- **Survey years covered here:** 2006--2024 (19 annual waves)

### Data Source

The data was extracted from **IPUMS USA** (University of Minnesota):
- https://usa.ipums.org/usa/

**Yearly ACS files on Dropbox:**

The Dropbox folder now centers the yearly ACS files used by the starter scripts.

| File | Years | Approx. Size | Best For |
|---|---|---|---|
| `acs_YYYY.dta` | Single-year ACS 1-year files, 2006--2024 | 1.6--2.0 GB each | Main full-column workflow and optional low-memory workflow |

These yearly files include the ACS 1-year sample for the named year and are the expected inputs for both the main `01_*` scripts and the optional low-memory `01_*` scripts.

**Using your own IPUMS extract:** You can also create your own yearly extracts at [IPUMS USA](https://usa.ipums.org/usa/) with only the variables and years you need. Download one ACS 1-year sample per year as Stata `.dta` and place the files in `data/raw/` as `acs_YYYY.dta`.

## Directory Structure

```
ipums_acs_1_year_sample/
├── README.md                          ← This file
├── code/
│   ├── 01_load_and_subset.do          ← Load data, restrict to ACS years (Stata)
│   ├── 01_load_and_subset.R           ← Same in R
│   ├── 01_load_and_subset_optional_low_memory.do  ← Optional yearly low-memory loader (Stata)
│   ├── 01_load_and_subset_optional_low_memory.R   ← Same in R
│   ├── 02_clean_demographics.do       ← Clean variables, descriptive stats (Stata)
│   └── 02_clean_demographics.R        ← Same in R
├── data/
│   └── raw/                           ← Place yearly acs_YYYY.dta files here
├── docs/                              ← Codebook, XML metadata, COVID-19 guidance
│   ├── usa_00001.cbk
│   ├── usa_00001.xml
│   └── ACS AND COVID-19-...pdf
└── output/                            ← Working datasets created by scripts
```

## Quick Start

### Step 1: Obtain the Data

Place your yearly ACS files in `data/raw/` and name them `acs_YYYY.dta`.

- Main full-column workflow: the main `01_*` scripts append the selected yearly files and keep all available columns.
- Optional low-memory workflow: the optional `01_*` scripts append the selected yearly files but keep only the raw columns needed by `02_*`.

**Option A — Download from Dropbox (recommended):**
1. Go to the [Dropbox folder](https://www.dropbox.com/scl/fo/ds69nbylyp6582opynk3w/AIOmznaVTgjnjtcNY7rSFsw?rlkey=ctrwg26u0c2z6prjwz4llnx5a&st=6hts8sht&dl=0)
2. Download the yearly files for the years you want
3. Place it in `data/raw/`

**Option B — Create your own IPUMS extract:**
1. Go to https://usa.ipums.org/usa/
2. Create an account (free for researchers)
3. Select samples: ACS 1-year for your desired years
4. Select variables (see Key Variables below for suggestions)
5. Download each sample as a Stata `.dta` file
6. Rename the files `acs_YYYY.dta` and place them in `data/raw/`

> **Note:** The `02_*` scripts skip sections whose source variables are not in your extract.

### Step 2: Load and Subset

The scripts can be launched from:
- `ipums_acs_1_year_sample/`
- `ipums_acs_1_year_sample/code/`
- the repo root

They also accept a manual root override:
- Stata: `global acs_root "/path/to/ipums_acs_1_year_sample"`
- R: `Sys.setenv(ACS_ROOT = "/path/to/ipums_acs_1_year_sample")`

**Main full-column yearly workflow**

**Stata:**
```stata
cd "/path/to/ipums_acs_1_year_sample"
do code/01_load_and_subset.do
```

**R:**
```r
source("code/01_load_and_subset.R")
```

Set either `first_year` / `last_year` or an explicit `years_to_load` list at the top of the script.
The main full-column scripts now default to `2023-2024`. If full-column multi-year `R` is too heavy on your machine, use the optional low-memory workflow or scale the year range back.

These scripts load one yearly ACS file at a time, append the selected years, create a unique record ID, validate key variables, and save a working copy to `output/`.

- Stata writes `output/acs_working.dta`
- R writes `output/acs_working.rds` and `output/acs_working_from_r.dta`

**Recommended low-memory yearly workflow**

For most student projects, begin here. Use the full-column loader only when the project needs a broad raw-variable surface beyond the starter and requested extras. The low-memory workflow expects yearly files named `data/raw/acs_YYYY.dta`.

Set either `first_year` / `last_year` or an explicit `years_to_load` list at the top of the optional script.

**Stata:**
```stata
cd "/path/to/ipums_acs_1_year_sample"
do code/01_load_and_subset_optional_low_memory.do
```

**R:**
```r
source("code/01_load_and_subset_optional_low_memory.R")
```

These scripts load one yearly ACS file at a time, keep only the raw columns needed by `02_clean_demographics.*`, save temporary yearly files, and then build the usual working dataset.

For an individual project, edit the visible `USER SETTINGS` block before running. For example, choose `years_to_load <- c(2019, 2021, 2024)` and `extra_keep_vars <- c("ageimmig", "english")` in R, or the matching `local years_to_load` and `local extra_keep_vars` settings in Stata.

- Stata writes `output/acs_working.dta`
- R writes `output/acs_working.rds`
- R can also write `output/acs_working_from_r.dta` if `write_dta_export <- TRUE`

Both implementations select columns while reading the yearly DTA files. The final combined working file still needs to fit once the selected years are appended.

### Step 3: Clean and Analyze

**Stata:**
```stata
do code/02_clean_demographics.do
```

**R:**
```r
source("code/02_clean_demographics.R")
```

This creates cleaned demographic indicators, education variables, employment and income measures, health insurance indicators, and immigration variables. Includes descriptive statistics and an example regression.

## Key Variables Created

### Demographics

| Variable | Description | Values |
|---|---|---|
| `female` | Female indicator | 0/1 |
| `hisp` | Hispanic/Latino (any race) | 0/1 |
| `white` | White non-Hispanic | 0/1 |
| `black` | Black non-Hispanic | 0/1 |
| `asian` | Asian / Pacific Islander non-Hispanic | 0/1 |
| `other` | Other race non-Hispanic | 0/1 |
| `race_eth` | Mutually exclusive race/ethnicity | White NH, Black NH, Hispanic, Asian/PI NH, Other NH |
| `married` | Currently married | 0/1 |
| `age_18_24` ... `age_65plus` | Age group indicators | 0/1 |

### Education

| Variable | Description | Values |
|---|---|---|
| `yrsed` | Years of education (from detailed `educd`) | 0--21 |
| `hs` | High school diploma or more | 0/1 |
| `some_college` | Some college or more | 0/1 |
| `college` | Bachelor's degree or more | 0/1 |

### Employment and Income

| Variable | Description | Values |
|---|---|---|
| `employed` | Currently employed | 0/1 (NA if under 16) |
| `unemployed` | Currently unemployed | 0/1 (NA if under 16) |
| `in_lf` | In labor force | 0/1 (NA if under 16) |
| `wage` | Wage/salary income | Dollars (NA if missing) |
| `inpov` | Below 100% federal poverty line | 0/1 |
| `finc_to_pov` | Family income-to-poverty ratio | Continuous |

### Health Insurance (2008+)

| Variable | Description | Values |
|---|---|---|
| `any_insurance` | Has any health insurance | 0/1 |
| `priv_ins` | Has private insurance | 0/1 |
| `pub_ins` | Has public insurance | 0/1 |
| `medicaid` | Has Medicaid | 0/1 |
| `medicare` | Has Medicare | 0/1 |
| `uninsured` | No health insurance | 0/1 |

### Immigration and Citizenship

| Variable | Description | Values |
|---|---|---|
| `noncitizen` | Not a U.S. citizen | 0/1 |
| `usborn` | Born in the U.S. or territories | 0/1 |
| `naturalized` | Naturalized citizen | 0/1 |
| `bpl_us` | Born in U.S. | 0/1 |
| `bpl_mexico` | Born in Mexico | 0/1 |
| `bpl_centam` | Born in Central/South America | 0/1 |
| `bpl_asia` | Born in Asia | 0/1 |
| `bpl_europe` | Born in Europe | 0/1 |
| `ageimmig` | Age at immigration | Years |
| `english` | Primary language is English | 0/1 |
| `spanish` | Primary language is Spanish | 0/1 |
| `nonfluent` | Does not speak English well | 0/1 |

### Identifiers and Survey Design

| Variable | Description |
|---|---|
| `year` | Survey year (2006--2024) |
| `serial` | Household serial number (unique within year) |
| `pernum` | Person number within household |
| `individ` | Unique record ID within the saved extract (`sample * 1e10 + serial * 100 + pernum` when `sample` is present) |
| `perwt` | Person-level survey weight |
| `hhwt` | Household-level survey weight |
| `strata` | Survey stratum |
| `cluster` | Survey cluster (PSU) |
| `statefip` | State FIPS code |
| `countyfip` | County FIPS code |
| `puma` | Public Use Microdata Area |

`individ` is a unique record ID within the saved extract, not a longitudinal person identifier across years.

## Important Notes

### Survey Design

The ACS uses a complex survey design with stratification and clustering. The starter regression examples use person weights directly, while design-based or replicate-weight methods are recommended when your application needs design-correct standard errors.

**Stata:**
```stata
reg uninsured female age i.race_eth [pw=perwt], robust
```

**R:**
```r
lm(uninsured ~ female + age + factor(race_eth), data = acs, weights = perwt)
```

Replicate weights (`repwtp1`--`repwtp80`) are also available for BRR standard errors, and you can still use `survey` / `svyset` workflows when you need them.

### COVID-19 and 2020 Data

The 2020 ACS had disrupted data collection due to the COVID-19 pandemic. The Census Bureau released **experimental weights** for the 2020 1-year data to account for nonresponse bias. See `docs/ACS AND COVID-19-...pdf` for guidance. Use 2020 data with caution in time-series analyses.

### Insurance Variables (2008+)

Health insurance variables (`hcovany`, `hcovpriv`, `hcovpub`, `hinscaid`, `hinscare`, etc.) are only available starting in **2008**. Analyses of insurance coverage should restrict to 2008+.

### Education Coding

When `educd` is available, the starter uses a codebook-aligned mapping from IPUMS detailed education codes to approximate years of schooling. Grouped lower-schooling categories are assigned rounded midpoints, while the higher categories preserve the common degree transitions:

- `062`, `063`, `064` map to completed high school / GED
- `081`, `082`, `083` map to associate's degree categories
- `101` maps to bachelor's degree
- `114`, `115`, `116` map to postgraduate degrees

The degree indicators are coded directly from `educd` when available so that `hs`, `some_college`, and `college` line up with the detailed degree definitions. If `educd` is absent but `educ` is present, the starter falls back to the coarser `educ` categories.

### File Size

The yearly ACS files are about 1.6--2.0 GB each. Loading many years with all columns can still require substantial RAM. If memory is an issue:
- Start with fewer years in the main full-column yearly workflow
- Use the optional yearly low-memory workflow with `acs_YYYY.dta` files
- Create yearly IPUMS extracts with fewer variables

## Common Research Applications

The ACS is widely used in health economics and applied microeconomics for:
- **Health insurance coverage** — ACA effects, Medicaid expansion, uninsured trends
- **Immigration economics** — DACA effects, immigrant assimilation, citizenship
- **Education** — returns to schooling, educational attainment, enrollment
- **Labor economics** — employment, wages, labor force participation
- **Poverty and inequality** — income distribution, transfer programs, SNAP
- **Disability** — prevalence, employment barriers, insurance coverage
- **Housing** — homeownership, crowding, internet access

## Citation

When using IPUMS ACS data, cite:

> Steven Ruggles, Sarah Flood, Matthew Sobek, Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Renae Rogers, and Megan Schouweiler. IPUMS USA: Version 15.0 [dataset]. Minneapolis, MN: IPUMS, 2024. https://doi.org/10.18128/D010.V15.0
