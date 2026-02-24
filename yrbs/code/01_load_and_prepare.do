********************************************************************************
* 01_load_and_prepare.do
*
* Purpose: Build the YRBS combined dataset from raw CDC SAS files (if needed),
*          then load it, verify its structure, and save a working copy.
*
*          Step 1: If sadc_2023_combined_all.dta does not yet exist in
*                  data/raw/, this script imports the 9 separate CDC SAS
*                  files from data/raw/ and appends them into one combined file.
*          Step 2: Loads the combined file, validates, and saves to output/.
*
* Input:   data/raw/sadc_2023_*.sas7bdat
*          (9 files: 1 national + 1 district + 7 state chunks)
* Output:  data/raw/sadc_2023_combined_all.dta   (~837 MB, created once)
*          output/yrbs_combined.dta
*
* Data:    Youth Risk Behavior Surveillance System (YRBSS / YRBS).
*          Biennial school-based survey of US high school students (grades
*          9-12) conducted by the CDC since 1991. Covers health behaviors
*          including mental health, substance use, sexual behavior, nutrition,
*          physical activity, and unintentional injury. The combined dataset
*          pools national, state, and district surveys across all available
*          years (1991-2023, biennial).
*
*          Source: CDC Division of Adolescent and School Health (DASH).
*          Downloaded from: https://www.cdc.gov/yrbs/data/index.html
*
* Usage:   Set the global yrbs_root path below, then:
*            cd "/path/to/yrbs"
*            do code/01_load_and_prepare.do
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================
* Set the working directory to the yrbs/ folder.
* Users should update this path to match their system.

global yrbs_root "/Users/audenteh/Library/CloudStorage/GoogleDrive-audenteh@davidson.edu/My Drive/davidson/econ_322/spring_2026/data_overview_for_studentss/yrbs"
cd "$yrbs_root"

local raw_sas_dir "data/raw"
local raw_dta     "data/raw/sadc_2023_combined_all.dta"
local out_dta     "output/yrbs_combined.dta"

* ============================================================================
* 2. BUILD COMBINED FILE FROM RAW SAS FILES (if not already built)
* ============================================================================
* The CDC distributes the YRBS combined high school data as 9 separate SAS
* files: 1 national, 1 district, and 7 state chunks (alphabetical ranges).
* This section imports each SAS file into Stata, appends them all, and saves
* the combined .dta. It only runs if the combined file does not already exist.

capture confirm file "`raw_dta'"
if _rc != 0 {
    display as text _newline "============================================"
    display as text "   BUILDING COMBINED FILE FROM RAW SAS DATA"
    display as text "============================================"
    display as text _newline "Combined file not found. Importing from SAS files..."

    * --- Import national dataset ---
    display as text _newline "Importing: sadc_2023_national.sas7bdat"
    import sas "`raw_sas_dir'/sadc_2023_national.sas7bdat", clear case(preserve)
    display as text "  Rows: " _N
    tempfile combined
    save `combined', replace

    * --- Import district dataset ---
    display as text "Importing: sadc_2023_district.sas7bdat"
    import sas "`raw_sas_dir'/sadc_2023_district.sas7bdat", clear case(preserve)
    display as text "  Rows: " _N
    append using `combined'
    save `combined', replace

    * --- Import 7 state chunks ---
    local state_chunks "a_d e_h i_l m n_p q_t u_z"
    foreach chunk of local state_chunks {
        display as text "Importing: sadc_2023_state_`chunk'.sas7bdat"
        import sas "`raw_sas_dir'/sadc_2023_state_`chunk'.sas7bdat", clear case(preserve)
        display as text "  Rows: " _N
        append using `combined'
        save `combined', replace
    }

    * --- Save the combined file ---
    display as text _newline "Saving combined file: `raw_dta'"
    display as text "Total observations: " _N
    compress
    save "`raw_dta'", replace
    display as text "Combined file created successfully."
}
else {
    display as text _newline "[INFO] Combined file already exists: `raw_dta'"
    display as text "       Skipping SAS import. Delete this file to rebuild."
}

* ============================================================================
* 3. LOAD COMBINED DATA
* ============================================================================
* The combined file includes national, state, and district survey data
* from 1991-2023 (biennial). Each row is one student respondent.

display as text _newline "============================================"
display as text "   LOADING YRBS COMBINED DATA"
display as text "============================================"

use "`raw_dta'", clear
display as text "Loaded: " _N " observations, " c(k) " variables."

* ============================================================================
* 4. STANDARDIZE VARIABLE NAMES
* ============================================================================
* Variable names in the raw file use mixed case. Lowercase everything
* for easier coding.

rename *, lower

* ============================================================================
* 5. EXAMINE KEY IDENTIFIERS
* ============================================================================
* The combined file has three key identifier variables:
*   sitetype  = "National", "State", or "District"
*   sitecode  = 2-letter state code (e.g., "AL") or district ID (e.g., "FT")
*   sitename  = Full name of state/district
*   year      = Survey year (biennial: 1991, 1993, ..., 2023)

display as text _newline "============================================"
display as text "   DATA STRUCTURE"
display as text "============================================"

display as text _newline "--- Site type distribution ---"
tab sitetype

display as text _newline "--- Survey years ---"
tab year

display as text _newline "--- Years by site type ---"
tab year sitetype

* ============================================================================
* 6. FIX KNOWN STATE CODE ISSUES
* ============================================================================
* Some state codes have alternate versions:
*   AZB = Arizona (alternate coding)
*   NYA = New York (alternate coding)
* Recode these to the standard 2-letter abbreviation.

replace sitecode = "AZ" if sitecode == "AZB"
replace sitecode = "NY" if sitecode == "NYA"

* ============================================================================
* 7. SORT AND SAVE
* ============================================================================

sort year sitetype sitecode
compress

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 8. VALIDATION CHECKS
* ============================================================================

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

* --- 7a. Check year range ---
quietly summarize year
if r(min) == 1991 & r(max) == 2023 {
    display as text "[PASS] Year range: " r(min) " to " r(max)
}
else {
    display as error "[WARN] Expected 1991-2023, found " r(min) " to " r(max)
}

* --- 7b. Check biennial pattern ---
* Years should be odd numbers only
quietly levelsof year, local(years)
local all_odd = 1
foreach y of local years {
    if mod(`y', 2) == 0 {
        local all_odd = 0
        display as error "[WARN] Even year found: `y'"
    }
}
if `all_odd' == 1 {
    display as text "[PASS] All survey years are odd (biennial pattern)"
}

* --- 7c. Check site types ---
quietly tab sitetype
display as text "[INFO] Site types present: " r(r) " categories"

* --- 7d. Check total is plausible ---
* Typical combined file: ~4-6 million observations across all years
if _N > 1000000 & _N < 10000000 {
    display as text "[PASS] Total observations (" _N ") is plausible"
}
else {
    display as error "[WARN] Total observations (" _N ") seems unusual"
}

* --- 7e. Check key variables exist ---
local key_vars "year sitetype sitecode sitename sex age race4 grade weight q26 q27 q28 q29 q30"
local all_exist = 1
local missing_vars ""
foreach v of local key_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local all_exist = 0
        local missing_vars "`missing_vars' `v'"
    }
}
if `all_exist' == 1 {
    display as text "[PASS] All key variables present"
}
else {
    display as error "[FAIL] Missing variable(s):`missing_vars'"
}

* --- 7f. Check weight variable ---
quietly summarize weight
if r(N) > 0 & r(mean) > 0 {
    display as text "[PASS] Survey weight has non-missing, positive values"
    display as text "       Weight N=" r(N) ", mean=" %10.4f r(mean)
}
else {
    display as error "[FAIL] Survey weight has issues: N=" r(N) ", mean=" r(mean)
}

* --- 7g. Check key demographics ---
display as text _newline "--- Quick demographic summary ---"
display as text "Sex distribution:"
tab sex, missing

display as text "Age distribution:"
tab age, missing

display as text "Race distribution (race4):"
tab race4, missing

display as text "Grade distribution:"
tab grade, missing

* --- 7h. Check state counts ---
display as text _newline "--- States in state-level data ---"
preserve
keep if sitetype == "State"
quietly levelsof sitecode, local(states) clean
display as text "[INFO] Number of unique state codes: " `: word count `states''
display as text "[INFO] States: `states'"
restore

* --- 7i. Quick summary of key variables ---
display as text _newline "--- Quick summary ---"
summarize year age weight

display as text _newline "============================================"
display as text "   VALIDATION COMPLETE"
display as text "============================================"
display as text _newline "Next step: run 02_clean_and_analyze.do"

********************************************************************************
* NOTES ON THE COMBINED DATASET:
*
* 1. SITE TYPES:
*    - "National" = nationally representative sample (~15,000-17,000 per year)
*    - "State" = state-level representative samples (not all states every year)
*    - "District" = large urban school district samples (optional participation)
*
*    For most analyses, you will want to filter by sitetype. Use "National" for
*    nationally representative estimates. Use "State" for state-level analyses
*    (e.g., difference-in-differences across states).
*
* 2. SURVEY TIMING:
*    The YRBS is biennial (every 2 years), conducted in odd years:
*    1991, 1993, 1995, ..., 2019, 2021, 2023.
*    There was NO 2020 survey due to COVID-19.
*
* 3. QUESTION NUMBERS:
*    Many key variables are named q1, q2, ..., q99 (or qn1, qn2, etc.)
*    These correspond to question numbers on the YRBS questionnaire.
*    Question numbers can shift across years as the CDC adds/removes items.
*    Always consult the questionnaire content document (in docs/) to confirm
*    what each question measures in each survey year.
*
* 4. STRING VS. NUMERIC:
*    In the combined .dta file, many question variables (q26, q27, etc.)
*    are stored as STRING variables with values like "1", "2", "3".
*    The qn-prefix variables (qn26, qn27, etc.) are CDC-computed binary
*    indicators stored as NUMERIC (1 = response of interest, 2 = otherwise).
*    The 02_clean script handles both formats.
*
* 5. WEIGHTS:
*    The variable `weight` provides survey weights for the combined sample.
*    Use [pweight=weight] in Stata for weighted analyses.
*
* 6. PARTICIPATION:
*    Not all states participate in every survey year. The participation
*    history document (in docs/) shows which states have data in which years.
*    This creates an unbalanced panel at the state level.
*
* 7. AGE AND GRADE:
*    age: 1=12 or younger, 2=13, 3=14, 4=15, 5=16, 6=17, 7=18 or older
*    grade: 1=9th, 2=10th, 3=11th, 4=12th
*    Note: Most respondents are ages 14-18 (grades 9-12).
*
* 8. DOWNLOADING THE DATA:
*    The combined dataset can be downloaded from:
*    https://www.cdc.gov/yrbs/data/index.html
*    Select "Combined Datasets" → download the SAS or ASCII files.
*    The SAS files (.sas7bdat) can be converted to .dta using:
*      import sas filename.sas7bdat, clear
*    Or use the pre-built combined .dta file if available.
********************************************************************************
