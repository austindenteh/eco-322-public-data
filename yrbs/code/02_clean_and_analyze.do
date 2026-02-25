********************************************************************************
* 02_clean_and_analyze.do
*
* Purpose: Clean and create analysis-ready variables from the YRBS combined
*          dataset. Covers demographics, mental health outcomes, substance
*          use, and other health behaviors. Includes descriptive statistics
*          and example regressions.
*
* Input:   output/yrbs_combined.dta  (from 01_load_and_prepare.do)
* Output:  output/yrbs_clean.dta
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

global yrbs_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/yrbs"
cd "$yrbs_root"

local in_dta   "output/yrbs_combined.dta"
local out_dta  "output/yrbs_clean.dta"

* ============================================================================
* 2. LOAD DATA
* ============================================================================

display as text _newline "============================================"
display as text "   LOADING YRBS COMBINED DATA"
display as text "============================================"

use "`in_dta'", clear
display as text "Loaded: " _N " observations, " c(k) " variables."

* ============================================================================
* 3. DEMOGRAPHICS
* ============================================================================
* The YRBS uses simple integer coding for demographics:
*   sex:   1 = Female, 2 = Male
*   age:   1 = <=12, 2 = 13, 3 = 14, 4 = 15, 5 = 16, 6 = 17, 7 = 18+
*   grade: 1 = 9th, 2 = 10th, 3 = 11th, 4 = 12th
*   race4: 1 = White, 2 = Black/African American,
*          3 = Hispanic/Latino, 4 = All other races
*
* IMPORTANT: sex==1 is FEMALE in the YRBS (confirmed from CDC codebook).

display as text _newline "============================================"
display as text "   CLEANING DEMOGRAPHICS"
display as text "============================================"

* --- Sex ---
gen female = (sex == 1) if !missing(sex)
label var female "Female indicator (1=Female, 0=Male)"

* --- Age dummies ---
* Create individual age indicators for flexibility in analysis.
gen age12 = (age == 1) if !missing(age)
gen age13 = (age == 2) if !missing(age)
gen age14 = (age == 3) if !missing(age)
gen age15 = (age == 4) if !missing(age)
gen age16 = (age == 5) if !missing(age)
gen age17 = (age == 6) if !missing(age)
gen age18 = (age == 7) if !missing(age)

label var age12 "Age 12 or younger"
label var age13 "Age 13"
label var age14 "Age 14"
label var age15 "Age 15"
label var age16 "Age 16"
label var age17 "Age 17"
label var age18 "Age 18 or older"

* Age in years (approximate, for continuous regressions)
gen age_years = .
replace age_years = 12 if age == 1
replace age_years = 13 if age == 2
replace age_years = 14 if age == 3
replace age_years = 15 if age == 4
replace age_years = 16 if age == 5
replace age_years = 17 if age == 6
replace age_years = 18 if age == 7
label var age_years "Age in years (approximate)"

* --- Race/ethnicity dummies ---
gen white    = (race4 == 1) if !missing(race4)
gen black    = (race4 == 2) if !missing(race4)
gen hispanic = (race4 == 3) if !missing(race4)
gen otherrace = (race4 == 4) if !missing(race4)

label var white    "White (non-Hispanic)"
label var black    "Black/African American (non-Hispanic)"
label var hispanic "Hispanic/Latino"
label var otherrace "Other race (non-Hispanic)"

* --- Grade dummies ---
gen grade9  = (grade == 1) if !missing(grade)
gen grade10 = (grade == 2) if !missing(grade)
gen grade11 = (grade == 3) if !missing(grade)
gen grade12 = (grade == 4) if !missing(grade)

label var grade9  "9th grade"
label var grade10 "10th grade"
label var grade11 "11th grade"
label var grade12 "12th grade"

* ============================================================================
* 4. MENTAL HEALTH OUTCOMES
* ============================================================================
* Key mental health questions (question numbers stable 1999-2023):
*   Q26: "During the past 12 months, did you ever feel so sad or hopeless
*         almost every day for two weeks or more in a row that you stopped
*         doing some usual activities?"
*   Q27: "During the past 12 months, did you ever seriously consider
*         attempting suicide?"
*   Q28: "During the past 12 months, did you make a plan about how you
*         would attempt suicide?"
*   Q29: "During the past 12 months, how many times did you actually
*         attempt suicide?"
*   Q30: "If you attempted suicide during the past 12 months, did any
*         attempt result in an injury, poisoning, or overdose that had
*         to be treated by a doctor or nurse?"
*
* NOTE: q26-q30 are STRING variables in the combined .dta file.
*       Values: "1", "2", "3", etc. corresponding to response options.

display as text _newline "============================================"
display as text "   CREATING MENTAL HEALTH OUTCOMES"
display as text "============================================"

* --- Q26: Felt sad or hopeless (available 1999-2023) ---
* "1" = Yes, "2" = No
gen felt_sad = .
replace felt_sad = 1 if q26 == "1"
replace felt_sad = 0 if q26 == "2"
label var felt_sad "Felt sad/hopeless >=2 weeks (past 12 months)"

* --- Q27: Considered suicide (available 1991-2023) ---
* "1" = Yes, "2" = No
gen considered_suicide = .
replace considered_suicide = 1 if q27 == "1"
replace considered_suicide = 0 if q27 == "2"
label var considered_suicide "Seriously considered suicide (past 12 months)"

* --- Q28: Made a suicide plan (available 1991-2023) ---
* "1" = Yes, "2" = No
gen made_suicide_plan = .
replace made_suicide_plan = 1 if q28 == "1"
replace made_suicide_plan = 0 if q28 == "2"
label var made_suicide_plan "Made a suicide plan (past 12 months)"

* --- Q29: Attempted suicide (available 1991-2023) ---
* "1" = 0 times, "2" = 1 time, "3" = 2-3 times, "4" = 4-5 times, "5" = 6+
* Binary: any attempt (>=1 time) vs. no attempt
gen attempted_suicide = .
replace attempted_suicide = 0 if q29 == "1"
replace attempted_suicide = 1 if inlist(q29, "2", "3", "4", "5")
label var attempted_suicide "Attempted suicide at least once (past 12 months)"

* --- Q30: Injury from suicide attempt (available 1991-2023) ---
* "1" = Did not attempt (→ not in denominator)
* "2" = Yes (injury), "3" = No (no injury)
* Defined only among those who attempted suicide.
gen injury_suicide_attempt = .
replace injury_suicide_attempt = 1 if q30 == "2"
replace injury_suicide_attempt = 0 if q30 == "3"
label var injury_suicide_attempt "Injured on suicide attempt (among attempters)"

* ============================================================================
* 5. SUBSTANCE USE
* ============================================================================
* Selected substance use questions for additional analysis.
*
*   Q33: "During the past 30 days, on how many days did you smoke cigarettes?"
*   Q42: "During the past 30 days, on how many days did you have at least
*         one drink of alcohol?"
*   Q48: "During the past 30 days, how many times did you use marijuana?"

display as text _newline "============================================"
display as text "   CREATING SUBSTANCE USE OUTCOMES"
display as text "============================================"

* --- Q33: Current cigarette smoking ---
* "1" = 0 days, "2"-"7" = 1+ days
gen current_cigarettes = .
replace current_cigarettes = 0 if q33 == "1"
replace current_cigarettes = 1 if inlist(q33, "2", "3", "4", "5", "6", "7")
label var current_cigarettes "Smoked cigarettes (past 30 days)"

* --- Q42: Current alcohol use ---
* "1" = 0 days, "2"-"7" = 1+ days
gen current_alcohol = .
replace current_alcohol = 0 if q42 == "1"
replace current_alcohol = 1 if inlist(q42, "2", "3", "4", "5", "6", "7")
label var current_alcohol "Drank alcohol (past 30 days)"

* --- Q48: Current marijuana use ---
* "1" = 0 times, "2"-"6" = 1+ times
gen current_marijuana = .
replace current_marijuana = 0 if q48 == "1"
replace current_marijuana = 1 if inlist(q48, "2", "3", "4", "5", "6")
label var current_marijuana "Used marijuana (past 30 days)"

* ============================================================================
* 6. ADDITIONAL HEALTH BEHAVIORS (OPTIONAL)
* ============================================================================
* These variables are included as examples. Add others as needed from
* the questionnaire content document in docs/.
*
*   Q14: "During the past 30 days, on how many days did you not go to school
*         because you felt you would be unsafe at school or on your way
*         to or from school?"

display as text _newline "============================================"
display as text "   CREATING ADDITIONAL HEALTH BEHAVIOR OUTCOMES"
display as text "============================================"

* --- Q14: Unsafe at school ---
* "1" = 0 days, "2"-"6" = 1+ days
gen unsafe_at_school = .
replace unsafe_at_school = 0 if q14 == "1"
replace unsafe_at_school = 1 if inlist(q14, "2", "3", "4", "5", "6")
label var unsafe_at_school "Missed school due to feeling unsafe (past 30 days)"

* ============================================================================
* 7. CDC QN-PREFIX CROSS-VALIDATION
* ============================================================================
* The combined dataset includes CDC-computed binary indicators with the
* "qn" prefix (e.g., qn26, qn27). These are coded: 1 = Yes, 2 = No.
* We cross-check our hand-coded variables against these.

display as text _newline "============================================"
display as text "   CROSS-VALIDATING AGAINST CDC QN VARIABLES"
display as text "============================================"

* Create temporary CDC versions for comparison
foreach v in 26 27 28 {
    capture confirm variable qn`v'
    if _rc == 0 {
        gen byte _cdc_qn`v' = .
        replace _cdc_qn`v' = 1 if qn`v' == 1
        replace _cdc_qn`v' = 0 if qn`v' == 2
    }
}

* Compare felt_sad (q26)
capture confirm variable _cdc_qn26
if _rc == 0 {
    quietly count if felt_sad == _cdc_qn26 & !missing(felt_sad) & !missing(_cdc_qn26)
    local n_match = r(N)
    quietly count if felt_sad != _cdc_qn26 & !missing(felt_sad) & !missing(_cdc_qn26)
    local n_mismatch = r(N)
    display as text "[CHECK] felt_sad vs qn26: `n_match' matches, `n_mismatch' mismatches"
    drop _cdc_qn26
}

* Compare considered_suicide (q27)
capture confirm variable _cdc_qn27
if _rc == 0 {
    quietly count if considered_suicide == _cdc_qn27 & !missing(considered_suicide) & !missing(_cdc_qn27)
    local n_match = r(N)
    quietly count if considered_suicide != _cdc_qn27 & !missing(considered_suicide) & !missing(_cdc_qn27)
    local n_mismatch = r(N)
    display as text "[CHECK] considered_suicide vs qn27: `n_match' matches, `n_mismatch' mismatches"
    drop _cdc_qn27
}

* Compare made_suicide_plan (q28)
capture confirm variable _cdc_qn28
if _rc == 0 {
    quietly count if made_suicide_plan == _cdc_qn28 & !missing(made_suicide_plan) & !missing(_cdc_qn28)
    local n_match = r(N)
    quietly count if made_suicide_plan != _cdc_qn28 & !missing(made_suicide_plan) & !missing(_cdc_qn28)
    local n_mismatch = r(N)
    display as text "[CHECK] made_suicide_plan vs qn28: `n_match' matches, `n_mismatch' mismatches"
    drop _cdc_qn28
}

* ============================================================================
* 8. SAVE CLEANED DATASET
* ============================================================================

display as text _newline "============================================"
display as text "   SAVING CLEANED DATASET"
display as text "============================================"

sort year sitetype sitecode
compress

save "`out_dta'", replace
display as text "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 9. DESCRIPTIVE STATISTICS
* ============================================================================

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

* --- 9a. Sample sizes by year ---
display as text _newline "--- Sample sizes by year ---"
tab year

* --- 9b. Sample sizes by site type ---
display as text _newline "--- Sample sizes by site type ---"
tab sitetype

* --- 9c. Demographics ---
display as text _newline "--- Demographics (all observations) ---"
summarize female age_years white black hispanic otherrace grade9 grade10 grade11 grade12

* --- 9d. Mental health outcomes ---
display as text _newline "--- Mental health outcomes ---"
summarize felt_sad considered_suicide made_suicide_plan attempted_suicide injury_suicide_attempt

* --- 9e. Substance use ---
display as text _newline "--- Substance use outcomes ---"
summarize current_cigarettes current_alcohol current_marijuana

* --- 9f. Mental health trends over time (national data) ---
display as text _newline "--- Mental health trends (national data only) ---"
preserve
keep if sitetype == "National"
table year, statistic(mean felt_sad considered_suicide attempted_suicide) statistic(count felt_sad) nformat(%9.3f)
restore

* --- 9g. Mental health by sex (national data) ---
display as text _newline "--- Mental health by sex (national data) ---"
preserve
keep if sitetype == "National"
table female, statistic(mean felt_sad considered_suicide attempted_suicide) statistic(count felt_sad) nformat(%9.3f)
restore

* --- 9h. State-level participation ---
display as text _newline "--- State-level data: observations per state ---"
preserve
keep if sitetype == "State"
tab sitecode
display as text "Number of unique states: " r(r)
restore

* ============================================================================
* 10. EXAMPLE REGRESSIONS
* ============================================================================

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSIONS"
display as text "============================================"

* --- 10a. OLS: Considered suicide ~ demographics (national, unweighted) ---
display as text _newline "--- OLS: Considered suicide ~ demographics (national, unweighted) ---"
reg considered_suicide female age_years black hispanic otherrace ///
    i.year if sitetype == "National"

* --- 10b. Weighted OLS: Considered suicide ~ demographics (national) ---
display as text _newline "--- Weighted OLS: Considered suicide ~ demographics (national) ---"
reg considered_suicide female age_years black hispanic otherrace ///
    i.year if sitetype == "National" [pweight=weight]

* --- 10c. Weighted OLS: Felt sad ~ demographics (national) ---
display as text _newline "--- Weighted OLS: Felt sad ~ demographics (national) ---"
reg felt_sad female age_years black hispanic otherrace ///
    i.year if sitetype == "National" & year >= 1999 [pweight=weight]

* --- 10d. State-level regression with state FE ---
display as text _newline "--- State-level: Considered suicide ~ demographics + state FE ---"
encode sitecode, gen(state_n)
reg considered_suicide female age_years black hispanic otherrace ///
    i.year i.state_n if sitetype == "State" [pweight=weight]

display as text _newline "============================================"
display as text "   DONE"
display as text "============================================"

********************************************************************************
* NOTES:
*
* 1. QUESTION NUMBER STABILITY:
*    The mental health questions (Q26-Q30) have been at these question
*    numbers since 1999 (Q26 = felt sad) or 1991 (Q27-Q30).
*    However, the CDC occasionally renumbers questions. Always check the
*    questionnaire content document for your specific years of interest.
*
* 2. QN-PREFIX VARIABLES:
*    The combined dataset includes CDC-computed binary indicators (qn26,
*    qn27, etc.) coded 1/2 (1=Yes, 2=No/Otherwise). These can be used
*    as an alternative to hand-coding from the q-variables, but you lose
*    the ability to see the original categorical responses.
*
* 3. WEIGHTS:
*    The `weight` variable provides survey weights for the combined sample.
*    Use [pweight=weight] for weighted analyses. For proper variance
*    estimation accounting for the complex survey design, consider the
*    PSU and stratum variables (if available) with svyset.
*
* 4. FILTERING BY SITE TYPE:
*    - For nationally representative estimates: keep if sitetype == "National"
*    - For state-level analyses (e.g., DID): keep if sitetype == "State"
*    - For urban district analyses: keep if sitetype == "District"
*
* 5. MISSING DATA:
*    Q29/Q30 handling is particularly important:
*    - Q29 (attempted_suicide): "1" = 0 times is a valid response (= 0)
*    - Q30 (injury from attempt): "1" = did not attempt is set to missing
*      because these respondents are not in the denominator for this question.
*
* 6. TREND BREAKS:
*    The 2021 survey was the first post-COVID administration. Comparisons
*    between 2019 and 2021+ should be interpreted with caution.
*
* 7. STATE PARTICIPATION:
*    States participate voluntarily. Not all states have data in every year.
*    The participation history document (in docs/) lists coverage by year.
*    This creates an unbalanced panel for state-level analyses.
*
* 8. CITATION:
*    Centers for Disease Control and Prevention (CDC). Youth Risk Behavior
*    Surveillance System (YRBSS). https://www.cdc.gov/yrbs/
*    When using specific years, cite: "[Year] Youth Risk Behavior Survey Data."
********************************************************************************
