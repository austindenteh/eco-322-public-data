# Panel Study of Income Dynamics Starter

> Data download required. The raw PSID files are too large for GitHub. Download the main family files and the cross-year individual file from the PSID Data Center, then place them under `psid/data/` using the layout below.

## Overview

The Panel Study of Income Dynamics (PSID) is a long-running U.S. household panel survey conducted by the University of Michigan. The main PSID files follow families and individuals over time and include family structure, income, employment, demographics, housing, health, and many other topics.

This starter starts with the main PSID core files:

- single-year family files, one file for each PSID interview wave
- the current cross-year individual file

The official PSID file-structure guide describes these as the two main PSID file types. It also explains the key merge rule: keep each selected year's family interview number from the cross-year individual file and merge it to that year's family file.

Optional modules and supplemental studies are loaded by separate scripts. They are not merged into the main person-year file by default because they differ in unit of observation, sample universe, wave timing, and merge keys.

## Data Version Checked

| Item | Local file checked | Detail |
|---|---|---|
| Family files | `psid/data/family_files/` | 43 wave folders: 1968-1997 annually, then 1999-2023 biennially |
| Cross-year individual file | `psid/data/cross_year_individual/ind2023er/IND2023ER.txt` | 1968-2023 individual file |
| 2023 family header | `FAM2023ER.do` | 9,152 family records, 3,813 columns, ASCII file date May 23, 2025 |
| Cross-year individual header | `IND2023ER.do` | 85,536 person records, 2,771 columns, ASCII file date December 2, 2025 |

## How to Obtain the Data

Option A: Download the prepared PSID folder from the shared Dropbox folder: <https://www.dropbox.com/scl/fo/ue84w3i69kg9zojmejeuz/ADoTxg4WFHWtBnLhoefCppw?rlkey=dnmu4hkh31j0wx7jzfsl0q207&st=8192q4x1&dl=0>. Place the extracted files under `psid/data/`.

Option B: Download directly from the PSID Data Center:

1. Create or sign in to a PSID account: <https://psidonline.isr.umich.edu/>.
2. Go to the PSID Data Center and download the packaged **Core/Immigrant Family Files, 2023**.
3. Download the packaged **Core/Immigrant Individual Files, 2023**.
4. Extract the files into this folder so the structure is:

```text
psid/
|-- README.md
|-- code/
|   |-- 01_load_main.R
|   |-- 01_load_main.do
|   |-- 02_clean_main.R
|   |-- 02_clean_main.do
|   |-- 03_load_linkable_modules.R
|   |-- 03_load_linkable_modules.do
|   |-- 04_load_additional_modules.R
|   |-- 04_load_additional_modules.do
|   |-- 05_load_cds_index.R
|   |-- 05_load_cds_index.do
|   |-- 06_load_cds_child_caregiver.R
|   |-- 06_load_cds_child_caregiver.do
|   |-- 07_load_cds_time_diary.R
|   |-- 07_load_cds_time_diary.do
|   |-- 08_load_cds_assessments.R
|   |-- 08_load_cds_assessments.do
|   |-- 09_load_tas_index.R
|   |-- 09_load_tas_index.do
|   |-- 10_load_dust.R
|   |-- 10_load_dust.do
|   |-- 11_load_intergenerational_transfers.R
|   |-- 11_load_intergenerational_transfers.do
|   |-- 12_load_web_mixed_mode.R
|   `-- 12_load_web_mixed_mode.do
|-- data/
|   |-- family_files/
|   |   |-- fam1968/
|   |   |-- fam1969/
|   |   |-- ...
|   |   `-- fam2023er/
|   |-- cross_year_individual/
|   |   `-- ind2023er/
|   |       |-- IND2023ER.txt
|   |       |-- IND2023ER.do
|   |       `-- IND2023ER_codebook.pdf
|   |-- parent_identification/
|   |-- marriage_history/
|   |-- childbirth_adaoption_history/
|   |-- family_relation_matrix/
|   |-- pregnancy_intentions/
|   |-- active_savings/
|   `-- supplemental_studies/
|       |-- child_development_supplement/
|       |-- transition_into_adulthood/
|       |-- disability_and_time_use/
|       |-- intergenerational_transfers/
|       `-- web_mixed_mode_supplement/
`-- output/
```

The scripts use the PSID-provided `.do` setup files as the machine-readable source for fixed-width column positions and labels. Keep the `.txt` and `.do` files together in each raw-data folder.

## Running the Starter Scripts

### 1. Load Main PSID Core Files

R:

```r
source("code/01_load_main.R")
```

Stata:

```stata
do code/01_load_main.do
```

Default build: `2019`, `2021`, and `2023`. This keeps the first run quick while exercising the modern biennial file structure. To load every main PSID family wave:

```r
psid_years <- NULL
source("code/01_load_main.R")
```

```stata
global psid_years "all"
do code/01_load_main.do
```

To load selected years:

```r
psid_years <- c(1993, 1994, 2023)
source("code/01_load_main.R")
```

```stata
global psid_years "1993 1994 2023"
do code/01_load_main.do
```

Outputs:

- R: `output/psid_family_year.rds`
- R: `output/psid_person_year.rds`
- Stata: `output/psid_family_year.dta`
- Stata: `output/psid_person_year.dta`

The family-year file has one row per selected family wave. The person-year file starts from the cross-year individual file, keeps people with a nonzero family interview number in the selected year by default, and merges selected family-year columns onto those person-year records.

The selected-year main loader is the recommended student route. The R implementation reads only selected fixed-width columns. The Stata implementation uses PSID's provided setup files and trims to the starter variables after import, so Stata may need more memory even when you select only a few years. Start with one wave before expanding a Stata build.

### 2. Clean Starter Variables

R:

```r
source("code/02_clean_main.R")
```

Stata:

```stata
do code/02_clean_main.do
```

Outputs:

- R: `output/psid_person_year_clean.rds`
- Stata: `output/psid_person_year_clean.dta`

The cleaner preserves the raw starter variables from the loader and adds conservative cleaned/derived columns when the needed inputs exist. Examples include `age_individual_clean`, `head_age_clean`, `family_size_clean`, `children_in_fu_clean`, `education_years_clean`, `total_family_income_clean`, `female`, `head_female`, `married_or_partnered`, `has_children_in_fu`, `homeowner`, `renter`, `respondent`, `employed`, `unemployed`, `not_in_labor_force`, `adult`, `is_reference_person`, `is_spouse_partner`, and `family_record_status`.

These are starter convenience variables, not a full PSID harmonization layer. The cleaner uses broad, transparent coding rules and common missing-value sentinels, while leaving the original raw variables in place for project-specific codebook checks.

Example summaries are off by default:

```r
psid_run_examples <- TRUE
source("code/02_clean_main.R")
```

```stata
global psid_run_examples 1
do code/02_clean_main.do
```

To keep only the original lightweight reference-person/spouse flags:

```r
psid_create_core_clean_vars <- FALSE
source("code/02_clean_main.R")
```

```stata
global psid_create_core_clean_vars 0
do code/02_clean_main.do
```

### 3. Load Linkable History Modules

The Phase 2 optional loader imports three PSID modules that link to people by 1968 family interview number and person number:

- Parent Identification File 2023
- Marriage History File 1985-2023
- Childbirth and Adoption History 1985-2023

R:

```r
source("code/03_load_linkable_modules.R")
```

Stata:

```stata
do code/03_load_linkable_modules.do
```

Outputs:

- R: `output/psid_parent_id.rds`
- R: `output/psid_marriage_history.rds`
- R: `output/psid_childbirth_adoption_history.rds`
- Stata: `output/psid_parent_id.dta`
- Stata: `output/psid_marriage_history.dta`
- Stata: `output/psid_childbirth_adoption_history.dta`

To load a subset:

```r
psid_linkable_modules <- c("parent_id", "marriage_history")
source("code/03_load_linkable_modules.R")
```

```stata
global psid_linkable_modules "parent_id marriage_history"
do code/03_load_linkable_modules.do
```

The default keeps all columns because these modules are much smaller than the main PSID family and individual files. To keep only starter linkage fields plus extras:

```r
psid_linkable_keep_all_vars <- FALSE
psid_childbirth_extra_vars <- c("CAH103", "CAH110", "CAH112")
source("code/03_load_linkable_modules.R")
```

```stata
global psid_linkable_keep_all 0
global psid_childbirth_extra_vars "CAH103 CAH110 CAH112"
do code/03_load_linkable_modules.do
```

The linkable module outputs are not automatically merged into `psid_person_year`. Merge them deliberately using `individual_1968_family_id` and `individual_person_number` for person-level modules, or the corresponding parent/child/spouse ID fields for relationship records.

### 4. Load Additional Optional Modules

The Phase 3 optional loader imports three remaining modules observed in the local data folder:

- Family Relationship Matrix 1968-2023
- Pregnancy Intentions 2013-2023
- Active Savings 1989 and 1994

R:

```r
source("code/04_load_additional_modules.R")
```

Stata:

```stata
do code/04_load_additional_modules.do
```

Outputs:

- R: `output/psid_family_relation_matrix.rds`
- R: `output/psid_pregnancy_intentions.rds`
- R: `output/psid_active_savings.rds`
- Stata: `output/psid_family_relation_matrix.dta`
- Stata: `output/psid_pregnancy_intentions.dta`
- Stata: `output/psid_active_savings.dta`

The family relationship matrix is much larger than the other optional modules: 3,485,034 rows before filtering. To keep the starter run quick, both R and Stata default to the 2023 relationship matrix rows only. Select years explicitly:

```r
psid_additional_modules <- c("family_relation_matrix")
psid_family_relation_years <- c(2019, 2021, 2023)
source("code/04_load_additional_modules.R")
```

```stata
global psid_additional_modules "family_relation_matrix"
global psid_family_relation_years "2019 2021 2023"
do code/04_load_additional_modules.do
```

Use all relationship-matrix years only when you actually need the full matrix:

```r
psid_family_relation_years <- NULL
source("code/04_load_additional_modules.R")
```

```stata
global psid_family_relation_years "all"
do code/04_load_additional_modules.do
```

To load only the smaller optional modules:

```r
psid_additional_modules <- c("pregnancy_intentions", "active_savings")
source("code/04_load_additional_modules.R")
```

```stata
global psid_additional_modules "pregnancy_intentions active_savings"
do code/04_load_additional_modules.do
```

### 5. Load the CDS Index

The first supplement-specific starter imports the Child Development Supplement cumulative ID map and builds a compact long-format wave index. It does not load the child, caregiver, assessment, or time-diary questionnaires.

R:

```r
source("code/05_load_cds_index.R")
```

Stata:

```stata
do code/05_load_cds_index.do
```

Outputs:

- R: `output/psid_cds_cumulative_id_map.rds`
- R: `output/psid_cds_wave_index.rds`
- Stata: `output/psid_cds_cumulative_id_map.dta`
- Stata: `output/psid_cds_wave_index.dta`

The long wave index uses:

- `psid_1968_family_id`
- `person_number`
- `survey_year`
- CDS household and sequence identifiers
- same-wave core family interview and sequence identifiers
- primary caregiver and other caregiver identifiers when available
- file-presence flags for demographic, caregiver, and child files

Default index waves are `1997`, `2002`, `2007`, `2014`, `2019`, and `2021`. Use `NULL` in R or `all` in Stata to load all available index waves, or select a subset:

```r
psid_cds_waves <- c(2014, 2019, 2021)
source("code/05_load_cds_index.R")
```

```stata
global psid_cds_waves "2014 2019 2021"
do code/05_load_cds_index.do
```

The 2020 COVID-era CDS files are real local data files, but `CDSIND2021` only includes 2020 component flags rather than a full standalone index block. Load 2020 questionnaire components with the component-specific starters below.

### 6. Load CDS Child, Caregiver, Roster, and Support Files

The CDS child/caregiver loader imports selected child interviews, primary-caregiver files, other-caregiver files, demographic/interview-information files, household rosters, wave ID maps, and the 2020 COVID health file. It saves each raw component separately.

R:

```r
source("code/06_load_cds_child_caregiver.R")
```

Stata:

```stata
do code/06_load_cds_child_caregiver.do
```

Default waves: `2019`, `2020`, and `2021`.

Example outputs:

- `output/psid_cds_child_caregiver_2019_child.rds`
- `output/psid_cds_child_caregiver_2019_pcg_child.rds`
- `output/psid_cds_child_caregiver_2020_covid_health.rds`
- matching Stata `.dta` files

To load every local child/caregiver/support component:

```r
psid_cds_child_caregiver_waves <- NULL
source("code/06_load_cds_child_caregiver.R")
```

```stata
global psid_cds_child_caregiver_waves "all"
do code/06_load_cds_child_caregiver.do
```

To select waves and component files or file groups:

```r
psid_cds_child_caregiver_waves <- c(1997, 2020)
psid_cds_child_caregiver_files <- c("pcg_child", "covid_health")
source("code/06_load_cds_child_caregiver.R")
```

```stata
global psid_cds_child_caregiver_waves "1997 2020"
global psid_cds_child_caregiver_files "pcg_child covid_health"
do code/06_load_cds_child_caregiver.do
```

Selection names can be file keys such as `child`, `pcg_child`, `pcg_household`, `ocg_child`, `household_roster`, `id_map`, and `covid_health`, or broader file groups such as `primary_caregiver_child`, `other_caregiver_household`, `demographic`, `household_roster`, and `support`.

### 7. Load CDS Time-Diary Files

The CDS time-diary loader imports activity, aggregate, media, follow-up, questionnaire, and 1997 school/care diary files as separate outputs.

R:

```r
source("code/07_load_cds_time_diary.R")
```

Stata:

```stata
do code/07_load_cds_time_diary.do
```

Default waves: `2019` and `2020`.

Example outputs:

- `output/psid_cds_time_diary_2019_activity.rds`
- `output/psid_cds_time_diary_2019_activity_aggregate.rds`
- `output/psid_cds_time_diary_2020_questionnaire.rds`
- matching Stata `.dta` files

To load all local time-diary components:

```r
psid_cds_time_diary_waves <- NULL
source("code/07_load_cds_time_diary.R")
```

```stata
global psid_cds_time_diary_waves "all"
do code/07_load_cds_time_diary.do
```

To select waves and files:

```r
psid_cds_time_diary_waves <- c(1997, 2020)
psid_cds_time_diary_files <- c("activity", "media")
source("code/07_load_cds_time_diary.R")
```

```stata
global psid_cds_time_diary_waves "1997 2020"
global psid_cds_time_diary_files "activity media"
do code/07_load_cds_time_diary.do
```

Selection names include `activity`, `activity_aggregate`, `media`, `followup`, `questionnaire`, and `school_care_diary`.

### 8. Load CDS Assessment, School, Teacher, and Provider Files

The CDS assessment loader imports child assessment files and related school, teacher, administrator, and provider files. The 1997 `CHILD97` file is treated here as an assessment file because its PSID label is "1997 CDS Child Assessments File"; later `CHILD*` interview files are in the child/caregiver loader.

R:

```r
source("code/08_load_cds_assessments.R")
```

Stata:

```stata
do code/08_load_cds_assessments.do
```

Default waves: `2014` and `2019`.

Example outputs:

- `output/psid_cds_assessments_2014_assessment.rds`
- `output/psid_cds_assessments_2019_assessment.rds`
- matching Stata `.dta` files

To load all local assessment/school/provider files:

```r
psid_cds_assessment_waves <- NULL
source("code/08_load_cds_assessments.R")
```

```stata
global psid_cds_assessment_waves "all"
do code/08_load_cds_assessments.do
```

To select waves and files:

```r
psid_cds_assessment_waves <- c(1997, 2019)
psid_cds_assessment_files <- c("assessment", "teacher")
source("code/08_load_cds_assessments.R")
```

```stata
global psid_cds_assessment_waves "1997 2019"
global psid_cds_assessment_files "assessment teacher"
do code/08_load_cds_assessments.do
```

Selection names include `assessment`, `teacher`, `school_administrator`, `provider`, and specific file keys such as `child_assessment`, `elementary_middle_school_teacher`, and `preschool_daycare_administrator`.

### 9. Load the TAS Index

The Transition into Adulthood Supplement has one large questionnaire file per wave, with thousands of variables and names that change across waves. The starter therefore builds a compact index rather than appending the full questionnaires.

R:

```r
source("code/09_load_tas_index.R")
```

Stata:

```stata
do code/09_load_tas_index.do
```

Default years: `2019`, `2021`, and `2023`.

Outputs:

- R: `output/psid_tas_wave_index.rds`
- Stata: `output/psid_tas_wave_index.dta`

The TAS index keeps:

- `survey_year`
- `tas_interview_id`
- `family_interview_id`
- `sequence_number`
- `reference_status`
- interview mode and interview timing fields
- same-year PSID interview timing fields
- `tas_weight`
- `tas_long_weight` when PSID provides a longitudinal TAS weight

To load all available local TAS waves:

```r
psid_tas_years <- NULL
source("code/09_load_tas_index.R")
```

```stata
global psid_tas_years "all"
do code/09_load_tas_index.do
```

To load selected years or keep raw extras:

```r
psid_tas_years <- c(2005, 2017, 2023)
psid_tas_extra_vars <- c("TA230015")
source("code/09_load_tas_index.R")
```

```stata
global psid_tas_years "2005 2017 2023"
global psid_tas_extra_vars "TA230015"
do code/09_load_tas_index.do
```

Raw TAS extras are selected by source variable name. If the same concept has different names across TAS waves, harmonize it deliberately after loading.

### 10. Load DUST Files

The Disability and Use of Time Supplement has multiple file groups with different units of observation. The starter saves each selected file group separately instead of appending unlike files.

R:

```r
source("code/10_load_dust.R")
```

Stata:

```stata
do code/10_load_dust.do
```

Default years: `2009` and `2013`. Default file groups: `household`, `flat`, `observations`, `activity`, and `parent_child` where available. The parent-child file is available only for 2013.

Outputs:

- R: `output/psid_dust_2009_household.rds`, `output/psid_dust_2009_flat.rds`, `output/psid_dust_2009_observations.rds`, `output/psid_dust_2009_activity.rds`
- R: `output/psid_dust_2013_household.rds`, `output/psid_dust_2013_flat.rds`, `output/psid_dust_2013_observations.rds`, `output/psid_dust_2013_activity.rds`, `output/psid_dust_2013_parent_child.rds`
- Stata: matching `.dta` files

To load a subset:

```r
psid_dust_years <- c(2013)
psid_dust_files <- c("flat", "activity")
source("code/10_load_dust.R")
```

```stata
global psid_dust_years "2013"
global psid_dust_files "flat activity"
do code/10_load_dust.do
```

DUST outputs keep all public variables because the files are modestly sized, but they add `source_module`, `source_file`, `supplement_year`, and `file_group` so users can trace each file's unit and source.

### 11. Load Intergenerational Transfer Files

The intergenerational transfer starter imports the 1988 Time and Money Transfers file and the two 2013 Rosters and Transfers files as separate outputs.

R:

```r
source("code/11_load_intergenerational_transfers.R")
```

Stata:

```stata
do code/11_load_intergenerational_transfers.do
```

Outputs:

- R: `output/psid_intergen_tmt88.rds`
- R: `output/psid_intergen_rt13_family.rds`
- R: `output/psid_intergen_rt13_parent_child.rds`
- Stata: matching `.dta` files

To load a subset:

```r
psid_intergen_files <- c("rt13_family", "rt13_parent_child")
source("code/11_load_intergenerational_transfers.R")
```

```stata
global psid_intergen_files "rt13_family rt13_parent_child"
do code/11_load_intergenerational_transfers.do
```

The 1988 and 2013 transfer files are different products, not repeated waves of one harmonized instrument. Merge or harmonize them only after checking the relevant codebooks.

### 12. Load Web/Mixed-Mode Supplements

The web/mixed-mode starter imports the local one-off public-use supplements:

- `crcs14`: Childhood Retrospective Circumstances Study, 2014
- `wb2016`: Wellbeing and Daily Life Supplement, 2016

R:

```r
source("code/12_load_web_mixed_mode.R")
```

Stata:

```stata
do code/12_load_web_mixed_mode.do
```

Outputs:

- R: `output/psid_web_crcs14.rds`
- R: `output/psid_web_wb2016.rds`
- Stata: matching `.dta` files

To load a subset:

```r
psid_web_supplements <- "crcs14"
source("code/12_load_web_mixed_mode.R")
```

```stata
global psid_web_supplements "crcs14"
do code/12_load_web_mixed_mode.do
```

These are one-off supplements with their own questionnaires and samples. The starter keeps the full public files separately and adds source metadata rather than merging them into the main PSID person-year file.

## Path Overrides

All scripts auto-detect the `psid/` folder when run from `psid/`, `psid/code/`, or the repo root.

Manual R override:

```r
psid_root_manual <- "/path/to/econ-data-starters/psid"
source("/path/to/econ-data-starters/psid/code/01_load_main.R")
```

or:

```r
Sys.setenv(PSID_ROOT = "/path/to/econ-data-starters/psid")
source("/path/to/econ-data-starters/psid/code/01_load_main.R")
```

Manual Stata override:

```stata
global psid_root "/path/to/econ-data-starters/psid"
do "$psid_root/code/01_load_main.do"
```

Optional output overrides:

```r
psid_output_dir <- "/private/tmp/psid_smoke"
psid_output_basename <- "psid_smoke"
source("code/01_load_main.R")
```

```stata
global psid_output_dir "/private/tmp/psid_smoke"
global psid_output_basename "psid_smoke"
do code/01_load_main.do
```

## Main Loader Options

The main loader has a few common switches. R options are set before `source()`;
Stata options are set with `global` before `do`.

| Purpose | R option | Stata option |
|---|---|---|
| Select years | `psid_years <- c(2019, 2021, 2023)` or `NULL` for all | `global psid_years "2019 2021 2023"` or `"all"` |
| Output folder | `psid_output_dir <- "/private/tmp/psid_smoke"` | `global psid_output_dir "/private/tmp/psid_smoke"` |
| Output basename | `psid_output_basename <- "psid_smoke"` | `global psid_output_basename "psid_smoke"` |
| Optional cross-tool export | `psid_write_dta_export <- TRUE` | `global psid_write_csv_export 1` |
| Keep nonresponse person-years | `psid_keep_nonresponse_person_years <- TRUE` | `global psid_keep_nonresp_person_years 1` |
| Skip label-detected family concepts | `psid_include_default_family_concepts <- FALSE` | `global psid_include_default_concepts 0` |
| Add raw family variables | `psid_family_extra_vars <- c("ER85812")` | `global psid_family_extra_vars "ER85812"` |
| Add raw individual variables | `psid_individual_extra_vars <- c("ER32000")` | `global psid_individual_extra_vars "ER32000"` |
| Add family alias families | `psid_family_extra_var_families <- list(...)` | `global psid_family_extra_var_families ...` |
| Add individual alias families | `psid_individual_extra_var_families <- list(...)` | `global psid_indiv_extra_var_families ...` |

Stata macro names are shorter for a few options because very long global names are invalid in Stata. For compatibility with earlier drafts, Stata accepts both `psid_individual_extra_vars` and `psid_indiv_extra_vars` for raw individual extras.

## Adding Variables

The loader always keeps the merge keys. It also tries to keep a broad starter set of common label-detected family concepts when available in the selected family files:

- `family_size`
- `head_age`
- `head_sex`
- `marital_status`
- `children_in_fu`
- `age_youngest_child`
- `housing_tenure`
- `current_state`
- `current_region`
- `metro_nonmetro`
- `beale_rural_urban`
- `head_total_work_hours`
- `head_labor_income`
- `food_expenditure`
- `total_family_income`
- `family_weight`

The cross-year individual file also contributes a default person-year surface when labels are available:

- `sex`
- `sample_status`
- `family_interview_id`
- `sequence_number`
- `relation_to_head`
- `age_individual`
- `month_individual_born`
- `year_individual_born`
- `marital_pairs_indicator`
- `moved_in_out`
- `month_moved_in_out`
- `year_moved_in_out`
- `respondent_status`
- `employment_status`
- `years_completed_education`
- `individual_weight`

PSID labels changed over time. Recent files use "Reference Person" rather than "Head"; the starter keeps output names such as `head_age`, `head_sex`, and `relation_to_head` for continuity, but those fields refer to the PSID reference person in 2017 and later waves. Some concepts are not available in every wave, and some historically similar labels can differ in coding, universe, time reference, and imputation rules. Treat these fields as starter pulls and check full historical harmonization against the relevant wave codebooks.

Because PSID variable names change across waves, use raw extras only when a variable name is stable for the files you selected:

```r
psid_family_extra_vars <- c("ER85812")
psid_individual_extra_vars <- c("ER32000")
source("code/01_load_main.R")
```

```stata
global psid_family_extra_vars "ER85812"
global psid_individual_extra_vars "ER32000"
do code/01_load_main.do
```

For concepts whose raw names vary by year, use alias families. The loader keeps the alias that exists in each selected wave and renames it to the family name you provide:

```r
psid_family_extra_var_families <- list(
  total_family_income_custom = c("ER16462", "ER46935", "ER85629")
)
source("code/01_load_main.R")
```

```stata
global psid_family_extra_var_families `" "total_family_income_custom:ER16462 ER46935 ER85629" "'
do code/01_load_main.do
```

Alias families select variables by name only. If the coding, time reference, universe, or imputation rules change across waves, do the substantive harmonization in your cleaning or analysis code after reading the PSID codebooks.

## Public-Use Geography

The PSID public-release files mainly include generalized geography. The official PSID FAQ says the public files contain generalized identifiers such as region and state of residence, with collapsed Beale rural-urban codes available for some years. Users who need specialized geographic detail for Census or neighborhood-context linkage should request restricted Geocode Match files.

In the local public-use family files, examples include:

- `CURRENT STATE`
- `PSID STATE OF RESIDENCE CODE`
- `CURRENT REGION`
- `METRO/NONMETRO INDICATOR`
- `BEALE RURAL-URBAN CODE`
- `RURAL-URBAN CODE (BEALE-COLLAPSED)` in some years
- `SIZE LARGEST CITY IN COUNTY`
- `CURRENT COUNTY` and `FIPS COUNTY CODE` in some older waves
- grew-up geography fields for the Reference Person/Head and Spouse/Partner in some years

Availability is not uniform across waves. In the local files, recent family waves include state, region, metro/nonmetro, Beale rural-urban, and largest-city-in-county measures; older waves include additional county-style fields. Precise Census tract, block-group, block, and detailed geocode match identifiers are restricted-use PSID geospatial data. The restricted geospatial files are the appropriate route for linking PSID residences to detailed Census or neighborhood-context data.

The main loader now keeps common public-use geography by default when the selected family wave labels are available: `current_state`, `current_region`, `metro_nonmetro`, and `beale_rural_urban`. Add less common geography fields, or force a particular raw-variable choice, with raw extras or alias families. Recent examples:

```r
psid_years <- c(2019, 2021, 2023)
psid_family_extra_var_families <- list(
  current_state = c("ER72004", "ER78004", "ER82004"),
  current_region = c("ER77591", "ER81918", "ER85772"),
  metro_nonmetro = c("ER77592", "ER81919", "ER85773"),
  beale_rural_urban = c("ER77593", "ER81920", "ER85774")
)
source("code/01_load_main.R")
```

```stata
global psid_years "2019 2021 2023"
global psid_family_extra_var_families ///
    `" "current_state:ER72004 ER78004 ER82004" "' ///
    `" "current_region:ER77591 ER81918 ER85772" "' ///
    `" "metro_nonmetro:ER77592 ER81919 ER85773" "' ///
    `" "beale_rural_urban:ER77593 ER81920 ER85774" "'
do code/01_load_main.do
```

## Working With PSID Merges

PSID person-year merging depends on annual family interview numbers:

- The cross-year individual file is uniquely identified by 1968 family interview number and person number.
- For each later wave, the cross-year individual file contains that person's family interview number for that wave.
- Each single-year family file is identified by the family interview number for that same wave.
- A value of `0` in the cross-year individual family interview number usually means the person was not associated with a responding family in that wave.

The person-year starter output uses:

- `psid_1968_family_id`
- `person_number`
- `survey_year`
- `family_interview_id`

By default, the loader drops person-year rows with missing or zero `family_interview_id`. Set `psid_keep_nonresponse_person_years <- TRUE` in R or `global psid_keep_nonresp_person_years 1` in Stata to keep them.

Some cross-year individual records can still have a nonzero family interview number that does not merge to a selected family file. This is most visible for 1968 because later sample additions are present in the cross-year individual file but do not all have a 1968 family-file record. The loader keeps `has_family_record` so users can decide whether to keep or drop those rows.

For 1968, the family-file merge key is `V3` (`FAMILY NUMBER`), not `V2` (`INTERVIEW NUMBER 68`). A local raw-file check found that all 4,802 1968 family-file `V3` identifiers overlap the cross-year individual `ER30001` identifier, while only 810 `V2` identifiers do.

## Supplemental Studies and Modules

Do not treat all PSID supplements as interchangeable extra columns. They differ in unit of observation, sample universe, wave timing, access rules, and merge keys.

Recommended handling:

| Component | Local folder observed | Starter status | Suggested next step |
|---|---|---|---|
| Marriage History | `data/marriage_history/mh85_23/` | Optional loader: `03_load_linkable_modules.*` | Merge only when relationship histories are needed |
| Childbirth and Adoption History | `data/childbirth_adaoption_history/cah85_23/` | Optional loader: `03_load_linkable_modules.*` | Merge only when fertility, birth, or adoption histories are needed |
| Parent Identification | `data/parent_identification/pid23/` | Optional loader: `03_load_linkable_modules.*` | Merge only when parent-child links are needed |
| Family Relationship Matrix | `data/family_relation_matrix/MX23REL/` | Optional loader: `04_load_additional_modules.*` | Select years before loading full matrix |
| Pregnancy Intentions | `data/pregnancy_intentions/pregint23/` | Optional loader: `04_load_additional_modules.*` | Merge by 1968 family/person IDs when needed |
| Active Savings | `data/active_savings/ActSavings89_94/` | Optional loader: `04_load_additional_modules.*` | Merge by family interview ID and survey year |
| Child Development Supplement index | `data/supplemental_studies/child_development_supplement/cdsind2021/` | CDS index loader: `05_load_cds_index.*` | Cumulative ID map and compact wave index |
| CDS child/caregiver/support files | `data/supplemental_studies/child_development_supplement/` | Component loader: `06_load_cds_child_caregiver.*` | Local files cover 1997, 2002, 2007, 2014, 2019, 2020, and 2021; outputs remain split by component |
| CDS time-diary files | `data/supplemental_studies/child_development_supplement/` | Component loader: `07_load_cds_time_diary.*` | Local files cover 1997, 2002, 2007, 2014, 2019, and 2020; outputs remain split by component |
| CDS assessment/school files | `data/supplemental_studies/child_development_supplement/` | Component loader: `08_load_cds_assessments.*` | Local files cover 1997, 2002, 2007, 2014, and 2019; outputs remain split by component |
| Transition into Adulthood Supplement | `data/supplemental_studies/transition_into_adulthood/` | TAS index loader: `09_load_tas_index.*` | Local files cover 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, and 2023; full questionnaire harmonization should remain separate |
| Disability and Time Use Supplement | `data/supplemental_studies/disability_and_time_use/` | DUST loader: `10_load_dust.*` | Local files cover 2009 and 2013; outputs remain split by file group |
| Intergenerational Transfers | `data/supplemental_studies/intergenerational_transfers/` | Transfer loader: `11_load_intergenerational_transfers.*` | Local files cover TMT88 and RT13; outputs remain split by product/file |
| Childhood Retrospective Circumstances Study | `data/supplemental_studies/web_mixed_mode_supplement/CRCS14/` | Web/mixed-mode loader: `12_load_web_mixed_mode.*` | One-off 2014 public-use supplement |
| Wellbeing and Daily Life Supplement | `data/supplemental_studies/web_mixed_mode_supplement/WB2016/` | Web/mixed-mode loader: `12_load_web_mixed_mode.*` | One-off 2016 public-use supplement |

The official CDS-TAS documentation describes CDS and TAS as embedded longitudinal studies with their own sample designs and study contents. They should be documented and loaded separately rather than silently merged into the main PSID core starter.

See `docs/supplemental_studies_inventory.md` for the local supplement inventory and download-status notes.

## Citation

When using PSID data, cite the PSID and the exact data products used. A general citation is:

> Panel Study of Income Dynamics, public use dataset. Produced and distributed by the Survey Research Center, Institute for Social Research, University of Michigan, Ann Arbor, MI.

Also cite any supplemental study or module separately when you use it.

## Useful Documentation

- PSID home: <https://psidonline.isr.umich.edu/>
- PSID file structure and merging guide: <https://psidonline.isr.umich.edu/Guide/FileStructure.pdf>
- PSID documentation page: <https://psidonline.isr.umich.edu/Guide/documents.aspx>
- PSID FAQ on public versus restricted geography: <https://psidonline.isr.umich.edu/Guide/FAQ.aspx?Type=ALL>
- PSID restricted geospatial data overview: <https://simba.isr.umich.edu/restricted/Geospatial.aspx>
- CDS-TAS getting started: <https://psidonline.isr.umich.edu/CDS/GettingStarted.aspx>
- CDS-TAS study design: <https://psidonline.isr.umich.edu/CDS/Guide/StudyDesign.aspx>
- PSID supplement overview: <https://psidonline.isr.umich.edu/GettingStarted.aspx>
