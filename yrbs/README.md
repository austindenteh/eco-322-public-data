# YRBS — Youth Risk Behavior Surveillance System

Starter code and documentation for working with the YRBS combined dataset (national + state + district), 1991–2023.

> **📥 Data download required.** The raw data files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/hxal7xxtckhx2qw6bnyn7/ABbzlW6jzq1pcYHClOA-aPk?rlkey=zsy1ad8wvcno2ag8m8lbe88vz&st=d4fp20qg&dl=0) and place the contents in `data/raw/`. See [Step 1](#step-1-obtain-the-data) for details.

## Overview

The Youth Risk Behavior Surveillance System (YRBSS), commonly called the **YRBS**, is a biennial school-based survey conducted by the CDC's Division of Adolescent and School Health (DASH). It monitors priority health-risk behaviors among high school students (grades 9–12) in the United States.

**Key features:**
- **Repeated cross-section** — a new sample every 2 years (odd years: 1991, 1993, ..., 2023)
- **Student-level records** from grades 9–12
- **~15,000–17,000 students per year** (national sample); much larger with state/district samples
- **Combined dataset** pools national, state, and district surveys into a single file
- **Mental health**: felt sad/hopeless, suicidal ideation, suicide plan, suicide attempts
- **Substance use**: cigarettes, alcohol, marijuana, and other drugs
- **Sexual behavior**: sexual activity, condom use, number of partners
- **Nutrition and physical activity**: fruit/vegetable consumption, physical activity, screen time
- **Violence and safety**: bullying, fighting, weapon carrying, unsafe at school
- **Survey years covered here:** 1991–2023 (17 biennial waves)

### Data Source

The combined dataset was downloaded from the **CDC YRBS Data and Documentation** page:
- https://www.cdc.gov/yrbs/data/index.html

The combined file is built from 9 separate CDC SAS files (1 national + 1 district + 7 state chunks), which are appended into a single dataset. The starter scripts handle this automatically.

**File details:**
- Combined file: `sadc_2023_combined_all.dta` (~837 MB, created by starter scripts)
- Years: 1991–2023 (biennial)
- Site types: National, State, District

**Source files** (9 SAS files from CDC, stored in `data/raw/`):

| File | Description |
|---|---|
| `sadc_2023_national.sas7bdat` | National survey |
| `sadc_2023_district.sas7bdat` | District-level surveys |
| `sadc_2023_state_a_d.sas7bdat` | States A–D |
| `sadc_2023_state_e_h.sas7bdat` | States E–H |
| `sadc_2023_state_i_l.sas7bdat` | States I–L |
| `sadc_2023_state_m.sas7bdat` | States M |
| `sadc_2023_state_n_p.sas7bdat` | States N–P |
| `sadc_2023_state_q_t.sas7bdat` | States Q–T |
| `sadc_2023_state_u_z.sas7bdat` | States U–Z |

## Directory Structure

```
yrbs/
├── README.md                      ← This file
├── code/
│   ├── 01_load_and_prepare.do     ← Build combined file + validate (Stata)
│   ├── 01_load_and_prepare.R      ← Same in R
│   ├── 02_clean_and_analyze.do    ← Clean variables, descriptive stats, regressions (Stata)
│   └── 02_clean_and_analyze.R     ← Same in R
├── data/
│   └── raw/                       ← Raw CDC SAS files + combined .dta
│       ├── sadc_2023_national.sas7bdat
│       ├── sadc_2023_district.sas7bdat
│       ├── sadc_2023_state_*.sas7bdat  (7 files)
│       └── sadc_2023_combined_all.dta  (created by scripts)
├── docs/                          ← CDC documentation PDFs
│   ├── 2023-YRBS-SADC-Documentation.pdf
│   ├── 2023-hs-participation-history508.pdf
│   └── YRBS_Questionnaire_Content_1991-2023_508.pdf
├── output/                        ← Cleaned datasets (created by scripts)
```

## Quick Start

### Step 1: Obtain the Data

The raw data files are too large for GitHub and must be downloaded separately.

**Option A — Dropbox (recommended):**
Download all data files from the shared folder:
https://www.dropbox.com/scl/fo/hxal7xxtckhx2qw6bnyn7/ABbzlW6jzq1pcYHClOA-aPk?rlkey=zsy1ad8wvcno2ag8m8lbe88vz&st=d4fp20qg&dl=0

Place the contents in `data/raw/`.

**Option B — CDC website:**
1. Go to https://www.cdc.gov/yrbs/data/index.html
2. Select "Combined Datasets" under "YRBS Data Files and Documentation"
3. Download the SAS data files for national, state, and district (high school)
4. Place the `.sas7bdat` files in `data/raw/`

The starter scripts will automatically import and combine these files on first run.

### Step 2: Load and Validate

**Stata:**
```stata
cd "/path/to/yrbs"
do code/01_load_and_prepare.do
```

**R:**
```r
source("code/01_load_and_prepare.R")
```

This script performs two steps:
1. **Build combined file** (first run only): Imports the 9 CDC SAS files, appends them into one dataset, and saves to `data/raw/sadc_2023_combined_all.dta`. Skips this step if the combined file already exists.
2. **Load and validate**: Loads the combined file, lowercases variable names, fixes state code issues (AZB→AZ, NYA→NY), runs validation checks, and saves a working copy to `output/`.

### Step 3: Clean and Analyze

**Stata:**
```stata
do code/02_clean_and_analyze.do
```

**R:**
```r
source("code/02_clean_and_analyze.R")
```

This creates cleaned demographic indicators, mental health outcomes, substance use variables, and other health behaviors. Includes descriptive statistics and example regressions.

## Key Variables Created

### Demographics

| Variable | Description | Values |
|---|---|---|
| `female` | Female indicator | 0/1 (sex==1 is Female in YRBS) |
| `age_years` | Age in years (approximate) | 12–18 |
| `age12`–`age18` | Age dummies | 0/1 for each age |
| `white` | White non-Hispanic | 0/1 |
| `black` | Black/African American | 0/1 |
| `hispanic` | Hispanic/Latino | 0/1 |
| `otherrace` | Other race | 0/1 |
| `grade9`–`grade12` | Grade dummies | 0/1 for each grade |

### Mental Health Outcomes

| Variable | Source | Description | Available |
|---|---|---|---|
| `felt_sad` | Q26 | Felt sad/hopeless ≥2 weeks (past 12 months) | 1999–2023 |
| `considered_suicide` | Q27 | Seriously considered attempting suicide | 1991–2023 |
| `made_suicide_plan` | Q28 | Made a suicide plan | 1991–2023 |
| `attempted_suicide` | Q29 | Attempted suicide ≥1 time (binary) | 1991–2023 |
| `injury_suicide_attempt` | Q30 | Injury from attempt (among attempters) | 1991–2023 |

### Substance Use

| Variable | Source | Description | Available |
|---|---|---|---|
| `current_cigarettes` | Q33 | Smoked cigarettes (past 30 days) | 1991–2023 |
| `current_alcohol` | Q42 | Drank alcohol (past 30 days) | 1991–2023 |
| `current_marijuana` | Q48 | Used marijuana (past 30 days) | 1991–2023 |

### Other Health Behaviors

| Variable | Source | Description | Available |
|---|---|---|---|
| `unsafe_at_school` | Q14 | Missed school due to feeling unsafe | 1993–2023 |

### Identifiers and Survey Design

| Variable | Description |
|---|---|
| `year` | Survey year (biennial: 1991, 1993, ..., 2023) |
| `sitetype` | "National", "State", or "District" |
| `sitecode` | 2-letter state code or district ID |
| `sitename` | Full name of state or district |
| `weight` | Survey weight |

## Important Notes

### Site Types

The combined dataset contains three types of samples:

| Site Type | Description | Use For |
|---|---|---|
| **National** | Nationally representative sample (~15K–17K/year) | National prevalence estimates |
| **State** | State-representative samples (voluntary participation) | State-level analyses, DID designs |
| **District** | Urban school district samples | District-level analyses |

**Always filter by `sitetype` before analysis.** Combining site types without adjustment would double/triple count some respondents.

### Survey Timing

The YRBS is conducted every **two years** in **odd years**:
```
1991, 1993, 1995, 1997, 1999, 2001, 2003, 2005, 2007,
2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023
```

There was **no 2020 survey** (the YRBS was not conducted due to COVID-19). The 2021 wave was the first post-COVID administration, so comparisons between 2019 and 2021+ should be interpreted cautiously.

### State Participation

States participate voluntarily. **Not all states have data in every survey year.** The participation history document (`docs/2023-hs-participation-history508.pdf`) lists which states participated in which years. This creates an **unbalanced panel** for state-level analyses.

### Question Number Stability

Most key question numbers have been stable for many years:
- Q14 (unsafe at school): stable since 1993
- Q26 (felt sad): stable since 1999
- Q27–Q30 (suicide questions): stable since 1991
- Q33 (cigarettes), Q42 (alcohol), Q48 (marijuana): generally stable

However, the CDC occasionally renumbers questions when items are added or removed. **Always consult the questionnaire content document** (`docs/YRBS_Questionnaire_Content_1991-2023_508.pdf`) to verify question wording and numbering for your specific years of interest.

### String vs. Numeric Variables

In the combined `.dta` file:
- **q-prefix variables** (q14, q26, q27, etc.) are **string** variables with values like `"1"`, `"2"`, `"3"`
- **qn-prefix variables** (qn14, qn26, qn27, etc.) are **numeric** CDC-computed binary indicators coded as `1` = response of interest, `2` = otherwise

The cleaning scripts create binary indicators from the q-prefix variables and cross-validate against the qn-prefix variables.

### Variable Coding Details

| Raw Variable | Coding |
|---|---|
| `sex` | 1 = Female, 2 = Male |
| `age` | 1 = ≤12, 2 = 13, 3 = 14, 4 = 15, 5 = 16, 6 = 17, 7 = ≥18 |
| `grade` | 1 = 9th, 2 = 10th, 3 = 11th, 4 = 12th |
| `race4` | 1 = White, 2 = Black, 3 = Hispanic, 4 = Other |
| `race7` | More detailed race (7 categories, if available) |
| `q26`–`q28` | "1" = Yes, "2" = No |
| `q29` | "1" = 0 times, "2" = 1 time, "3" = 2–3, "4" = 4–5, "5" = 6+ |
| `q30` | "1" = Did not attempt, "2" = Yes (injury), "3" = No (no injury) |

### State Code Issues

Two states have alternate codes in some years:
- **AZB** → Arizona (use `AZ`)
- **NYA** → New York (use `NY`)

The starter scripts automatically recode these.

### Weights

- Use `weight` for all weighted analyses
- In Stata: `[pweight=weight]`
- In R with the `survey` package:
```r
library(survey)
des <- svydesign(ids = ~1, weights = ~weight, data = yrbs)
svyglm(considered_suicide ~ female + age_years, design = des)
```

### Q29 and Q30 Coding Notes

- **Q29 (attempted suicide)**: The value `"1"` means "0 times" (no attempt). Our binary indicator codes `"1"` → 0 and `"2"`–`"5"` → 1.
- **Q30 (injury from attempt)**: The value `"1"` means "I did not attempt suicide" — these respondents are **not in the denominator** for this question. Our indicator sets `"1"` → `NA`, `"2"` → 1, `"3"` → 0.

## Common Research Applications

The YRBS is widely used in health economics and public health research for:
- **Time trends** in adolescent health behaviors (using national data)
- **Difference-in-differences** studies exploiting state-level policy variation
- **Cross-state comparisons** of health behavior prevalence
- **Demographic disparities** in health-risk behaviors (by sex, race, age)
- **Program evaluation** of school-based health interventions

## Citation

When using YRBS data, cite:

> Centers for Disease Control and Prevention (CDC). Youth Risk Behavior Surveillance System (YRBSS). Available at: https://www.cdc.gov/yrbs/

For specific survey years:

> Centers for Disease Control and Prevention (CDC). [Year] Youth Risk Behavior Survey Data. Available at: https://www.cdc.gov/yrbs/data/index.html
