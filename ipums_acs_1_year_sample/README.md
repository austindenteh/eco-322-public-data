# IPUMS ACS — American Community Survey (1-Year Samples)

Starter code and documentation for working with the ACS 1-year samples via IPUMS USA, 2006--2024.

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

**Extract details:**
- Extract: `usa_00001`
- Format: Stata (.dta.gz, compressed)
- Samples: ACS 1-year, 2006--2024 (also includes 1970--2000 census samples, which are dropped by the starter scripts)
- File size: approx. 12 GB compressed

## Directory Structure

```
ipums_acs_1_year_sample/
├── README.md                          ← This file
├── code/
│   ├── 01_load_and_subset.do          ← Load data, restrict to ACS years (Stata)
│   ├── 01_load_and_subset.R           ← Same in R
│   ├── 02_clean_demographics.do       ← Clean variables, descriptive stats (Stata)
│   └── 02_clean_demographics.R        ← Same in R
├── data/
│   └── raw/                           ← usa_00001.dta.gz (IPUMS extract)
├── docs/                              ← Codebook, XML metadata, COVID-19 guidance
│   ├── usa_00001.cbk
│   ├── usa_00001.xml
│   └── ACS AND COVID-19-...pdf
└── output/                            ← Cleaned datasets (created by scripts)
```

## Quick Start

### Step 1: Obtain the Data

The IPUMS extract (`usa_00001.dta.gz`) should already be in `data/raw/`. If you need to create a new extract:

1. Go to https://usa.ipums.org/usa/
2. Create an account (free for researchers)
3. Select samples: ACS 1-year for your desired years
4. Select variables (see Key Variables below for suggestions)
5. Download as Stata (.dta) format
6. Place the `.dta.gz` file in `data/raw/`

### Step 2: Load and Subset

**Stata:**
```stata
cd "/path/to/ipums_acs_1_year_sample"
do code/01_load_and_subset.do
```

**R:**
```r
source("code/01_load_and_subset.R")
```

This script loads the IPUMS extract, drops any pre-2006 census samples, creates a unique person identifier, validates key variables, and saves a working copy to `output/`.

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
| `asian` | Asian non-Hispanic | 0/1 |
| `other` | Other race non-Hispanic | 0/1 |
| `race_eth` | Mutually exclusive race/ethnicity | White NH, Black NH, Hispanic, Asian NH, Other NH |
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
| `individ` | Unique person ID (`serial * 100 + pernum`) |
| `perwt` | Person-level survey weight |
| `hhwt` | Household-level survey weight |
| `strata` | Survey stratum |
| `cluster` | Survey cluster (PSU) |
| `statefip` | State FIPS code |
| `countyfip` | County FIPS code |
| `puma` | Public Use Microdata Area |

## Important Notes

### Survey Design

The ACS uses a complex survey design with stratification and clustering. For valid standard errors, use survey methods:

**Stata:**
```stata
svyset cluster [pw=perwt], strata(strata)
svy: reg uninsured female age i.race_eth
```

**R:**
```r
library(survey)
des <- svydesign(ids = ~cluster, strata = ~strata,
                 weights = ~perwt, data = acs)
svyglm(uninsured ~ female + age + factor(race_eth), design = des)
```

Replicate weights (`repwtp1`--`repwtp80`) are also available for BRR standard errors.

### COVID-19 and 2020 Data

The 2020 ACS had disrupted data collection due to the COVID-19 pandemic. The Census Bureau released **experimental weights** for the 2020 1-year data to account for nonresponse bias. See `docs/ACS AND COVID-19-...pdf` for guidance. Use 2020 data with caution in time-series analyses.

### Insurance Variables (2008+)

Health insurance variables (`hcovany`, `hcovpriv`, `hcovpub`, `hinscaid`, `hinscare`, etc.) are only available starting in **2008**. Analyses of insurance coverage should restrict to 2008+.

### Education Coding

The `yrsed` variable maps IPUMS detailed education codes (`educd`) to continuous years of schooling, following the approach in Kuka et al. (2020). Some rare education categories may not be mapped (resulting in missing values). The key mappings:

| `educd` | `yrsed` | Description |
|---|---|---|
| 2 | 0 | No schooling |
| 14 | 2 | Nursery to 4th grade |
| 22--23 | 7--8 | 7th--8th grade |
| 25--30 | 9--11 | 9th--11th grade |
| 40, 50, 63, 64 | 12 | HS diploma / GED |
| 61 | 12 | 12th grade, no diploma (excluded from `hs`) |
| 65 | 13 | Some college, less than 1 year |
| 70, 71 | 14 | Some college / Associate's |
| 101 | 16 | Bachelor's degree |
| 114 | 18 | Master's degree |
| 115 | 19 | Professional degree |
| 116 | 21 | Doctorate |

### File Size

The raw IPUMS extract is very large (approx. 12 GB compressed). Loading requires substantial RAM (16+ GB recommended). If memory is an issue:
- Download a smaller extract from IPUMS with fewer variables
- Download only the years you need
- Use column selection when reading (`col_select` in R's `read_dta()`)

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
