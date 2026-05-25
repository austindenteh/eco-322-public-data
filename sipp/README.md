# Survey of Income and Program Participation Starter

> Data download required. The raw SIPP files are too large for GitHub. Download them from the [shared Dropbox folder](https://www.dropbox.com/scl/fo/09nttidfz47kfym1xnc3v/AMTKdPzN2AO3fGbRmyv7zZI?rlkey=3t91muaripn52a8hg2165a3nt&st=5k331ukw&dl=0), or download public-use SIPP data from the Census Bureau, and place them under `sipp/data/` using the layout below.

## Overview

The Survey of Income and Program Participation (SIPP) is a U.S. Census Bureau longitudinal household survey covering income, employment, program participation, wealth, family composition, health insurance, and related topics.

This starter begins with the modern annual SIPP public-use files for the 2018-2024 design era. It includes:

- a selected-year primary person-month loader
- a separate modern weights loader
- a starter cleaner for common analysis-ready person-month variables
- selected 2014 panel primary and weight loaders
- a selected 2014 SSA Supplement loader
- selected 2008 legacy fixed-width core and weight loaders
- selected 2008 topical module loaders that write one output per topical wave
- optional 2008 topical topic-family launchers, modeled after separate supplement loaders, for users who want assets/medical, child care/work schedule, retirement/pension, well-being/caregiving, history, or certification extracts

The 2008 topical module loader does not harmonize module concepts across waves. It reads selected topical wave files and writes separate outputs by wave, because the module content differs substantially by wave. The topic-family launchers make the recurring module families easier to start from, but they still produce family-tagged source extracts rather than analysis-ready harmonized topical variables.

## Data Version Checked

| Item | Local file checked | Detail |
|---|---|---|
| Modern annual primary files | `sipp/data/2018/` through `sipp/data/2024/` | Stata primary zips present; 2022 requires temporary extraction/system unzip fallback in R/Stata because of zip compression |
| Modern replicate weights | `sipp/data/2018/` through `sipp/data/2024/` | Cross-sectional replicate-weight zips present locally |
| Modern longitudinal weights | `sipp/data/2019/` through `sipp/data/2024/` | Horizon-specific final and replicate longitudinal weight zips present locally |
| 2019 primary file | `sipp/data/2019/pu2019_dta.zip` | Local primary zip is readable; a stale `.download/` artifact also exists locally and can be ignored |
| 2022 primary file | `sipp/data/2022/pu2022_dta.zip` | Zip passes system integrity check; R and Stata smoke tests pass via extraction fallback |
| 2024 primary file | `sipp/data/2024/pu2024_dta.zip` | Contains `pu2024.dta`, 3,185,810,030 uncompressed bytes |
| 2014 panel primary files | `sipp/data/2014/panel_wave1/` through `panel_wave4/` | Local waves 2-4 pass gzip/header checks; local wave 1 Stata gzip is truncated, but `pu2014w1.csv.gz` passes and is used as a fallback |
| 2014 panel weights | `sipp/data/2014/panel_wave1/` through `panel_wave4/` | Replicate, longitudinal, and longitudinal replicate files pass gzip/header checks |
| 2014 SSA Supplement | `sipp/data/2014/ssa_supplement/` | Primary file is a zip archive despite the `.dta.gz` suffix; replicate weights are fixed-width |
| 2008 legacy core/weights | `sipp/data/2008/` | Core waves 1-16 and weight files are fixed-width `.dat.gz`; loaders use local SAS/PDF layouts |
| 2008 topical modules | `sipp/data/2008/wave1/` through `wave11/`, plus `wave13/` | Public topical files are present locally for waves 1-11 and 13; wave 12 and waves 14-16 have no topical modules in the release schedule |

## How to Obtain the Data

Option A: Download the prepared SIPP folder from the shared Dropbox folder:

<https://www.dropbox.com/scl/fo/09nttidfz47kfym1xnc3v/AMTKdPzN2AO3fGbRmyv7zZI?rlkey=3t91muaripn52a8hg2165a3nt&st=5k331ukw&dl=0>

Place the downloaded year/panel folders under `sipp/data/` using the expected layout below.

Option B: Download SIPP files directly from the Census Bureau:

- SIPP datasets page: <https://www.census.gov/programs-surveys/sipp/data/datasets.html>
- 2024 SIPP data page: <https://www.census.gov/data/datasets/2024/demo/sipp/2024-data.html>
- SIPP technical documentation: <https://www.census.gov/programs-surveys/sipp/tech-documentation/complete-technical-documentation.html>

The Census datasets page lists SIPP data by year for `2018-2024` and by panel/wave for older panels. The 2024 data page lists the primary data file separately from replicate weights, longitudinal weights, and longitudinal replicate weights.

Expected starter layout:

```text
sipp/
|-- README.md
|-- code/
|   |-- 01_load_modern_primary.R
|   |-- 01_load_modern_primary.do
|   |-- 02_load_modern_weights.R
|   |-- 02_load_modern_weights.do
|   |-- 03_clean_modern_primary.R
|   |-- 03_clean_modern_primary.do
|   |-- 04_load_2014_panel_primary.R
|   |-- 04_load_2014_panel_primary.do
|   |-- 05_load_2014_panel_weights.R
|   |-- 05_load_2014_panel_weights.do
|   |-- 06_load_2014_ssa_supplement.R
|   |-- 06_load_2014_ssa_supplement.do
|   |-- 07_load_2008_legacy_core.R
|   |-- 07_load_2008_legacy_core.do
|   |-- 08_load_2008_legacy_weights.R
|   |-- 08_load_2008_legacy_weights.do
|   |-- 09_load_2008_topical_modules.R
|   |-- 09_load_2008_topical_modules.do
|   |-- 10_load_2008_recipiency_employment_history.R
|   |-- 10_load_2008_recipiency_employment_history.do
|   |-- 11_load_2008_disability_education_family_history.R
|   |-- 11_load_2008_disability_education_family_history.do
|   |-- 12_load_2008_welfare_retirement_pension.R
|   |-- 12_load_2008_welfare_retirement_pension.do
|   |-- 13_load_2008_assets_medical_child_wellbeing.R
|   |-- 13_load_2008_assets_medical_child_wellbeing.do
|   |-- 14_load_2008_childcare_work_schedule_tax.R
|   |-- 14_load_2008_childcare_work_schedule_tax.do
|   |-- 15_load_2008_wellbeing_disability_support_caregiving.R
|   |-- 15_load_2008_wellbeing_disability_support_caregiving.do
|   |-- 16_load_2008_certifications.R
|   `-- 16_load_2008_certifications.do
|-- docs/
|   `-- sipp_inventory.md
|-- data/
|   |-- 2008/
|   |-- 2014/
|   |-- 2018/
|   |   `-- pu2018_dta.zip
|   |-- 2019/
|   |   `-- pu2019_dta.zip
|   |-- ...
|   `-- 2024/
|       `-- pu2024_dta.zip
`-- output/
```

Keep downloaded `.zip`, `.dta.gz`, `.dat.gz`, `.sas`, metadata, and validation files under `sipp/data/`. The `data/` and `output/` folders are ignored by Git.

The Stata loaders for compressed `.dta.gz` and fixed-width `.dat.gz` files call the system `gzip` command to stream-decompress files into a temporary folder. The modern primary loaders also fall back to system `unzip` when R or Stata built-in zip readers cannot handle a valid large Census zip. These tools are available by default on macOS/Linux; Windows users may need to install command-line `gzip`/`unzip` utilities or run the R loaders where supported.

## Running the Starter Scripts

### 1. Load Modern Annual Primary Files

R:

```r
source("code/01_load_modern_primary.R")
```

Stata:

```stata
do code/01_load_modern_primary.do
```

Default build: `2024` only. The output is person-month level. The default is intentionally selected-year and selected-variable because modern SIPP files are large.

Outputs:

- R: `output/sipp_modern_primary_person_month.rds`
- Stata: `output/sipp_modern_primary_person_month.dta`

The loader keeps a broad starter set when the variables are available in the selected file:

- IDs and time: `ssuid`, `pnum`, `monthcode`, `shhadid`, `spanel`, `swave`
- design/weight fields: `ghlfsam`, `gvarstr`, `wpfinwgt`
- geography available in public use: interview/residence state, metro, and region fields when present
- household/family structure: household size, children, family size, family reference fields, tenure
- demographics: age, sex, Hispanic origin, race, education, marital status, relationship, nativity/citizenship
- labor market: monthly employment status, weeks/jobs/hours, earnings
- income/poverty: person, household, and family income, family poverty threshold, income-to-poverty ingredients
- transfer and program variables: Social Security, SSI, TANF, SNAP, WIC, general assistance, monthly receipt flags
- health insurance: monthly and annual coverage recodes
- assets/debts: selected home value, net worth, and credit-card debt measures

Availability notes:

- The default 2024 modern file contains the full modern starter set.
- In 2018-2020, `EHISPAN` and the annual health-insurance recodes (`RHICOVANN`, `RPRIVANN`, `RPUBANN`, `RMEDCAREANN`, `RMCAIDANN`, `RVACAREANN`) are not present. In 2021, `EHISPAN` is present but those annual health-insurance recodes are still absent. The loader warns and skips unavailable starter variables.
- `EORIGIN` is available across the modern years and is the cleaner's default Hispanic-origin yes/no source. `EHISPAN`, when present, is a more detailed Hispanic-origin field.

It also adds:

- `source_file`
- `sipp_file_year`
- `reference_year`

For example, the `2024` SIPP file covers the January-December 2023 reference period, so the loader sets `sipp_file_year = 2024` and `reference_year = 2023`.

To load selected years:

```r
sipp_modern_years <- c(2023, 2024)
source("code/01_load_modern_primary.R")
```

```stata
global sipp_modern_years "2023 2024"
do code/01_load_modern_primary.do
```

To try every modern local year and skip unreadable local zips:

```r
sipp_modern_years <- NULL
sipp_modern_skip_unreadable <- TRUE
source("code/01_load_modern_primary.R")
```

```stata
global sipp_modern_years "all"
global sipp_modern_skip_unreadable 1
do code/01_load_modern_primary.do
```

The 2022 primary zip uses compression that can fail in R/Stata built-in zip readers. The modern primary loaders now fall back to temporary extraction with system `unzip`; small R and Stata smokes passed for 2022.

For a small smoke run:

```r
sipp_modern_years <- c(2024)
sipp_modern_n_max <- 1000
sipp_output_dir <- "/private/tmp/sipp_smoke"
source("code/01_load_modern_primary.R")
```

```stata
global sipp_modern_years "2024"
global sipp_modern_n_max 1000
global sipp_output_dir "/private/tmp/sipp_smoke"
do code/01_load_modern_primary.do
```

### 2. Load Modern Weights

R:

```r
source("code/02_load_modern_weights.R")
```

Stata:

```stata
do code/02_load_modern_weights.do
```

Default build: `2024` cross-sectional replicate weights, keeping `repwgt0` through `repwgt4` only. Use all replicate weights when doing final survey-variance work.

Outputs depend on the selected family:

- `output/sipp_modern_replicate_weights_person_month.rds` or `.dta`
- `output/sipp_modern_longitudinal_weights_person.rds` or `.dta`
- `output/sipp_modern_longitudinal_replicate_weights_person.rds` or `.dta`

Examples:

```r
sipp_weight_years <- c(2023, 2024)
sipp_weight_families <- c("replicate")
sipp_replicate_numbers <- "all"
source("code/02_load_modern_weights.R")
```

```stata
global sipp_weight_years "2023 2024"
global sipp_weight_families "replicate"
global sipp_replicate_numbers "all"
do code/02_load_modern_weights.do
```

Longitudinal examples:

```r
sipp_weight_years <- c(2024)
sipp_weight_families <- c("longitudinal", "longitudinal_replicate")
sipp_longitudinal_horizons <- c(2, 3, 4)
source("code/02_load_modern_weights.R")
```

```stata
global sipp_weight_years "2024"
global sipp_weight_families "longitudinal longitudinal_replicate"
global sipp_longitudinal_horizons "2 3 4"
do code/02_load_modern_weights.do
```

Merge guidance:

- Cross-sectional replicate weights are person-month level. Merge to the primary file by `sipp_file_year`, `ssuid`, `pnum`, `spanel`, `swave`, and `monthcode`.
- Longitudinal final and replicate weights are person-level and horizon-specific. Merge by `sipp_file_year`, `ssuid`, `pnum`, `spanel`, and `longitudinal_horizon`, then use only the horizon that matches your longitudinal sample definition.
- The primary loader already keeps `wpfinwgt`. Use the separate replicate-weight loader when you need replicate-weight variance estimation.

### 3. Clean Modern Primary Files

R:

```r
source("code/03_clean_modern_primary.R")
```

Stata:

```stata
do code/03_clean_modern_primary.do
```

Default behavior runs the modern primary loader first using any selected-year, extra-variable, path, or row-limit settings already defined in your session.

Outputs:

- R: `output/sipp_modern_primary_clean_person_month.rds`
- Stata: `output/sipp_modern_primary_clean_person_month.dta`

The cleaner preserves raw variables and adds conservative starter fields, including `person_id`, `person_month_id`, `age`, `female`, `hispanic`, education flags, marital flags, broad employment status, housing-tenure flags, cleaned income/program amounts, health-insurance flags, family income-to-poverty, and public-use state/metro/region fields when present. These derived variables are starter conveniences, not a substitute for checking Census codebooks for your exact research design.

### 4. Load 2014 Panel Primary Files

R:

```r
source("code/04_load_2014_panel_primary.R")
```

Stata:

```stata
do code/04_load_2014_panel_primary.do
```

Default build: 2014 panel wave 4 only. Use selected waves when needed:

```r
sipp_2014_waves <- c(2, 3, 4)
sipp_2014_n_max <- 1000
source("code/04_load_2014_panel_primary.R")
```

```stata
global sipp_2014_waves "2 3 4"
global sipp_2014_n_max 1000
do code/04_load_2014_panel_primary.do
```

The local wave 1 Stata gzip still fails validation, but `sipp/data/2014/panel_wave1/pu2014w1.csv.gz` passes and the R/Stata loaders fall back to that pipe-delimited file. Re-download the Stata gzip only if you specifically need the `.dta.gz` copy.

The 2014 panel loader uses a broad starter list parallel to the modern loader, but some modern annual fields are not present in the 2014 panel files. In particular, annual health-insurance recodes, detailed `EHISPAN`, several modern program amount/receipt fields, and `TPEARN_ALT` are skipped when unavailable.

### 5. Load 2014 Panel Weights

R:

```r
source("code/05_load_2014_panel_weights.R")
```

Stata:

```stata
do code/05_load_2014_panel_weights.do
```

Default build: 2014 wave 4 cross-sectional replicate weights, keeping `repwt1` through `repwt4`. The 2014 panel replicate-weight files use `repwt1` through `repwt240`; there is no `repwt0`. The loader also supports `longitudinal` final weights and `longitudinal_replicate` weights.

```r
sipp_2014_weight_waves <- c(4)
sipp_2014_weight_families <- c("replicate", "longitudinal", "longitudinal_replicate")
sipp_2014_replicate_numbers <- 1:4
source("code/05_load_2014_panel_weights.R")
```

```stata
global sipp_2014_weight_waves "4"
global sipp_2014_weight_families "replicate longitudinal longitudinal_replicate"
global sipp_2014_replicate_numbers "1 2 3 4"
do code/05_load_2014_panel_weights.do
```

### 6. Load 2014 SSA Supplement

R:

```r
source("code/06_load_2014_ssa_supplement.R")
```

Stata:

```stata
do code/06_load_2014_ssa_supplement.do
```

Default build: SSA primary file only. To include replicate weights:

```r
sipp_ssa_families <- c("primary", "replicate")
sipp_ssa_replicate_numbers <- 1:4
source("code/06_load_2014_ssa_supplement.R")
```

```stata
global sipp_ssa_families "primary replicate"
global sipp_ssa_replicate_numbers "1 2 3 4"
do code/06_load_2014_ssa_supplement.do
```

The SSA primary file is distributed locally as a zip archive with a `.dta.gz` suffix. The scripts handle that explicitly.

### 7. Load 2008 Legacy Core Waves

R:

```r
source("code/07_load_2008_legacy_core.R")
```

Stata:

```stata
do code/07_load_2008_legacy_core.do
```

Default build: 2008 wave 16 core file only. These are fixed-width files, so the starter keeps a documented core set from the shared local SAS layout and creates standardized `pnum` and `eeduc` aliases from legacy names.

To load selected waves:

```r
sipp_2008_waves <- c(1, 10, 16)
source("code/07_load_2008_legacy_core.R")
```

```stata
global sipp_2008_waves "1 10 16"
do code/07_load_2008_legacy_core.do
```

### 8. Load 2008 Legacy Weights

R:

```r
source("code/08_load_2008_legacy_weights.R")
```

Stata:

```stata
do code/08_load_2008_legacy_weights.do
```

Default build: 2008 wave 16 cross-sectional replicate weights, keeping `repwgt1` through `repwgt4`. The loader also supports the panel longitudinal final weight file and panel-year or calendar-year longitudinal replicate weights.

```r
sipp_2008_weight_families <- c("replicate", "longitudinal", "longitudinal_replicate")
sipp_2008_weight_waves <- c(16)
sipp_2008_replicate_numbers <- 1:4
sipp_2008_lrw_type <- "panel_year"
sipp_2008_lrw_indices <- c(5)
source("code/08_load_2008_legacy_weights.R")
```

```stata
global sipp_2008_weight_families "replicate longitudinal longitudinal_replicate"
global sipp_2008_weight_waves "16"
global sipp_2008_replicate_numbers "1 2 3 4"
global sipp_2008_lrw_type "panel_year"
global sipp_2008_lrw_indices "5"
do code/08_load_2008_legacy_weights.do
```

Important 2008 note: topical modules are loaded as separate wave outputs. Treat those outputs as module-specific source files, not as a harmonized panel, until a project checks the exact topical codebooks.

### 9. Load 2008 Topical Module Waves

R:

```r
source("code/09_load_2008_topical_modules.R")
```

Stata:

```stata
do code/09_load_2008_topical_modules.do
```

Default build: 2008 wave 13, the Professional Certificates and Certifications topical module. Topical files are available locally for waves `1-11` and `13`; wave 12 and waves 14-16 have no topical modules in the Census release schedule.

Outputs are written separately by wave:

- R: `output/sipp_2008_topical_wave13.rds`
- Stata: `output/sipp_2008_topical_wave13.dta`

The default keeps all non-allocation variables and skips `FILLER` fields. Use allocation flags when needed for imputation diagnostics:

```r
sipp_2008_tm_waves <- c(4, 7, 10)
sipp_2008_tm_allocs <- TRUE
sipp_2008_tm_n_max <- 1000
source("code/09_load_2008_topical_modules.R")
```

```stata
global sipp_2008_tm_waves "4 7 10"
global sipp_2008_tm_allocs 1
global sipp_2008_tm_n_max 1000
do code/09_load_2008_topical_modules.do
```

Do not append topical wave outputs without a wave-specific harmonization plan. Waves 4, 7, and 10 repeat broad asset/medical/child-wellbeing themes, while waves 5 and 8 repeat child care, work schedule, annual income, and taxes themes, but even recurring modules should be checked against the exact topical codebooks before combining.

### 10. Optional 2008 Topical Topic-Family Extracts

The files `10_load_2008_*` through `16_load_2008_*` are convenience launchers over the same topical fixed-width reader. They are useful when a project wants a PSID-supplement-style entry point for one topical family without editing the generic wave loader.

| Topic-family script | Default waves | What it starts from |
|---|---:|---|
| `10_load_2008_recipiency_employment_history.*` | 1 | Recipiency history, employment history, and tax rebates |
| `11_load_2008_disability_education_family_history.*` | 2 | Disability, education, marital, migration, fertility, household-relationship history, and tax rebates |
| `12_load_2008_welfare_retirement_pension.*` | 3, 11 | Welfare reform and retirement/pension-plan coverage |
| `13_load_2008_assets_medical_child_wellbeing.*` | 4, 7, 10 | Assets/liabilities, medical expenses/health-care utilization, and child well-being where present |
| `14_load_2008_childcare_work_schedule_tax.*` | 5, 8 | Child care, work schedule, annual income, retirement accounts, and taxes |
| `15_load_2008_wellbeing_disability_support_caregiving.*` | 6, 9 | Adult well-being, disability/support, employer health benefits, and caregiving |
| `16_load_2008_certifications.*` | 13 | Professional certificates and certifications |

Example R family extract:

```r
sipp_output_dir <- "/private/tmp/sipp_smoke"
sipp_2008_assets_medical_child_wellbeing_n_max <- 1000
source("code/13_load_2008_assets_medical_child_wellbeing.R")
```

Example Stata family extract:

```stata
global sipp_output_dir "/private/tmp/sipp_smoke"
global sipp_2008_tm_n_max 1000
do code/13_load_2008_assets_medical_child_wellbeing.do
```

These launchers add `topical_family`, `topical_family_label`, and `topical_family_note` columns and write family-tagged files such as `output/sipp_2008_topical_assets_medical_child_wellbeing_wave4.rds` or `.dta`. They still write one output per wave. That is intentional: wave 4 and wave 10 both contain child well-being content while wave 7 does not, and recurring topics can still differ in universe, reference period, coding, or allocation behavior. Treat these as safer starting extracts, not as completed topical harmonizers.

## Adding Variables

Use raw extras when variable names are stable for the years you selected:

```r
sipp_modern_extra_vars <- c("TSSSAMT")
source("code/01_load_modern_primary.R")
```

```stata
global sipp_modern_extra_vars "TSSSAMT"
do code/01_load_modern_primary.do
```

Use alias families when a concept has changed names or may have alternate names across years:

```r
sipp_modern_extra_var_families <- list(
  person_earnings_custom = c("TPEARN", "TPERSONEARN")
)
source("code/01_load_modern_primary.R")
```

```stata
global sipp_modern_extra_var_families `" "person_earnings_custom:TPEARN TPERSONEARN" "'
do code/01_load_modern_primary.do
```

Alias families select variables by name only and create a standardized copy when a matching raw variable is present. If universes, time references, imputations, or coding differ across SIPP releases, harmonize them deliberately after loading.

## Path Overrides

All scripts auto-detect the `sipp/` folder when run from `sipp/`, `sipp/code/`, or the repo root.

Manual R override:

```r
sipp_root_manual <- "/path/to/econ-data-starters/sipp"
source("/path/to/econ-data-starters/sipp/code/01_load_modern_primary.R")
```

or:

```r
Sys.setenv(SIPP_ROOT = "/path/to/econ-data-starters/sipp")
source("/path/to/econ-data-starters/sipp/code/01_load_modern_primary.R")
```

Manual Stata override:

```stata
global sipp_root "/path/to/econ-data-starters/sipp"
do "$sipp_root/code/01_load_modern_primary.do"
```

Optional output overrides:

```r
sipp_output_dir <- "/private/tmp/sipp_smoke"
source("code/01_load_modern_primary.R")
```

```stata
global sipp_output_dir "/private/tmp/sipp_smoke"
do code/01_load_modern_primary.do
```

Use the same path and output overrides with the other SIPP scripts by changing the script name.

## Planned Later Phases

The broad starter loaders are complete. Later project-specific work should stay split:

- module-specific topical cleaners or harmonizers for a chosen research question, built after checking the exact topical codebooks and the variables selected from the family extracts above

See `docs/sipp_inventory.md` for the local inventory and build-order notes.

## Citation

When using SIPP data, cite the Census Bureau and the exact SIPP year/file products used.

## Useful Documentation

- SIPP home: <https://www.census.gov/sipp/>
- SIPP datasets: <https://www.census.gov/programs-surveys/sipp/data/datasets.html>
- 2024 SIPP data: <https://www.census.gov/data/datasets/2024/demo/sipp/2024-data.html>
- SIPP technical documentation: <https://www.census.gov/programs-surveys/sipp/tech-documentation/complete-technical-documentation.html>
