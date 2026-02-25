********************************************************************************
* 02_clean_and_harmonize.do
*
* Purpose: Clean and harmonize BRFSS variables across survey years.
*          Creates consistent demographic, health, and survey design variables
*          that can be used for pooled cross-year analysis.
*          Works with any year range from 2011-2024 (default: 2023-2024).
*
* Input:   output/brfss_appended.dta  (from 01_load_and_append.do)
* Output:  output/brfss_clean.dta
*
* Usage:   Run after 01_load_and_append.do from the brfss/ directory:
*            cd "/path/to/brfss"
*            do code/02_clean_and_harmonize.do
*
* Key harmonization issues:
*   - Race/ethnicity: _RACEGR3 (2011-2021) vs. _RACEGR4 (2022+)
*   - Income: INCOME2 (2011-2020) vs. INCOME3 (2021+)
*   - Sex/gender: SEX (2011-2021) vs. SEXVAR/BIRTHSEX (2022+)
*   - Calculated BMI: _BMI5 available throughout, but coding may shift
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================

global brfss_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/brfss"
cd "$brfss_root"

local in_dta   "output/brfss_appended.dta"
local out_dta  "output/brfss_clean.dta"

* ============================================================================
* 2. LOAD APPENDED DATA
* ============================================================================

use "`in_dta'", clear
display as text "Loaded appended BRFSS: " _N " observations, " c(k) " variables."

* ============================================================================
* 3. SURVEY DESIGN VARIABLES
* ============================================================================
* The BRFSS uses a complex survey design with stratification and clustering.
* For correct standard errors, you MUST use survey commands (svyset).
*
* Key variables:
*   _PSU    = Primary Sampling Unit
*   _STSTR  = Sample design stratification variable
*   _LLCPWT = Final weight (landline and cell phone combined)

* Set survey design for all subsequent analyses
svyset _psu [pweight = _llcpwt], strata(_ststr)

display as text "Survey design set: svyset _psu [pw=_llcpwt], strata(_ststr)"

* ============================================================================
* 4. HARMONIZE DEMOGRAPHICS
* ============================================================================

* --- 4a. State FIPS code -----------------------------------------------------
gen statefips = _state
label var statefips "State FIPS code"

* --- 4b. Interview month and year -------------------------------------------
* imonth/iyear are string in some years, numeric in others.
capture destring imonth, replace
capture destring iyear, replace

gen month = imonth if imonth >= 1 & imonth <= 12
label var month "Interview month (1-12)"

gen year = iyear
label var year "Interview year"

* --- 4c. Age -----------------------------------------------------------------
* _AGE80: Imputed age, top-coded at 80
* _AGEG5YR: Age in five-year categories (calculated variable)
gen age = _age80
label var age "Age in years (imputed, top-coded at 80)"

gen age_cat = _ageg5yr
label var age_cat "Age in 5-year categories (CDC calculated)"

* --- 4d. Sex / Gender -------------------------------------------------------
* SEX was used through 2021. Starting in 2022, the BRFSS uses SEXVAR
* (sex assigned at birth) and/or BIRTHSEX.
* We harmonize to a single 'female' indicator.

gen female = .
* 2011-2021: SEX variable (1=Male, 2=Female)
* (capture protects against SEX not existing when only 2022+ data loaded)
capture replace female = (sex == 2) if surveyyear <= 2021 & !missing(sex)
capture replace female = 0 if sex == 1 & surveyyear <= 2021
* 2022+: Look for SEXVAR or BIRTHSEX
capture replace female = (sexvar == 2) if surveyyear >= 2022 & !missing(sexvar)
capture replace female = 0 if sexvar == 1 & surveyyear >= 2022
* Fallback: if BIRTHSEX exists
capture replace female = (birthsex == 2) if missing(female) & !missing(birthsex)
capture replace female = 0 if birthsex == 1 & missing(female)

label var female "Female (1=yes, 0=no)"
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

* --- 4e. Race/Ethnicity -----------------------------------------------------
* _RACEGR3 (2011-2021): 1=White NH, 2=Black NH, 3=Other NH, 4=Multiracial NH, 5=Hispanic
* _RACEGR4 (2022+): recategorized (1=White NH, 2=Black NH, 3=Asian NH, 4=AIAN NH, 5=Hispanic, 6=Other/Multi)
*
* We create a harmonized 4-category variable.

gen race_eth = .
label var race_eth "Race/ethnicity (harmonized)"

* For years using _RACEGR3 (2011-2021)
* (capture protects against _RACEGR3 not existing when only 2022+ data loaded)
capture replace race_eth = 1 if _racegr3 == 1 & surveyyear <= 2021           // White NH
capture replace race_eth = 2 if _racegr3 == 2 & surveyyear <= 2021           // Black NH
capture replace race_eth = 3 if _racegr3 == 5 & surveyyear <= 2021           // Hispanic
capture replace race_eth = 4 if (_racegr3 == 3 | _racegr3 == 4) & surveyyear <= 2021  // Other/Multi NH

* For years using _RACEGR4 (2022+)
capture replace race_eth = 1 if _racegr4 == 1 & surveyyear >= 2022   // White NH
capture replace race_eth = 2 if _racegr4 == 2 & surveyyear >= 2022   // Black NH
capture replace race_eth = 3 if _racegr4 == 5 & surveyyear >= 2022   // Hispanic
capture replace race_eth = 4 if (_racegr4 == 3 | _racegr4 == 4 | _racegr4 == 6) & surveyyear >= 2022  // Other/Multi/Asian/AIAN NH

label define race_eth_lbl 1 "White non-Hispanic" 2 "Black non-Hispanic" ///
    3 "Hispanic" 4 "Other/Multiracial non-Hispanic"
label values race_eth race_eth_lbl

* Also create indicator variables (useful for regressions)
gen white    = (race_eth == 1) if !missing(race_eth)
gen black    = (race_eth == 2) if !missing(race_eth)
gen hispanic = (race_eth == 3) if !missing(race_eth)
gen raceother = (race_eth == 4) if !missing(race_eth)

label var white    "White non-Hispanic"
label var black    "Black non-Hispanic"
label var hispanic "Hispanic"
label var raceother "Other/Multiracial non-Hispanic"

* --- 4f. Education -----------------------------------------------------------
* EDUCA: 1=Never/kindergarten, 2=Elementary, 3=Some HS, 4=HS grad/GED,
*        5=Some college, 6=College grad, 9=Refused
gen educ_cat = .
replace educ_cat = 1 if educa >= 1 & educa <= 3    // Less than HS
replace educ_cat = 2 if educa == 4                   // HS grad/GED
replace educ_cat = 3 if educa == 5                   // Some college
replace educ_cat = 4 if educa == 6                   // College graduate
label var educ_cat "Education (4 categories)"
label define educ_cat_lbl 1 "Less than HS" 2 "HS graduate/GED" ///
    3 "Some college" 4 "College graduate"
label values educ_cat educ_cat_lbl

* Indicators
gen hsdropout   = (educ_cat == 1) if !missing(educ_cat)
gen hsgraduate  = (educ_cat == 2) if !missing(educ_cat)
gen somecollege = (educ_cat == 3) if !missing(educ_cat)
gen college     = (educ_cat == 4) if !missing(educ_cat)

label var hsdropout   "Less than HS"
label var hsgraduate  "HS graduate/GED"
label var somecollege "Some college/technical school"
label var college     "College graduate"

* --- 4g. Marital Status ------------------------------------------------------
* MARITAL: 1=Married, 2=Divorced, 3=Widowed, 4=Separated, 5=Never married,
*          6=Unmarried couple, 9=Refused
gen marital_cat = .
replace marital_cat = 1 if marital == 1 | marital == 6  // Married/partnered
replace marital_cat = 2 if marital == 2 | marital == 4  // Divorced/separated
replace marital_cat = 3 if marital == 3                  // Widowed
replace marital_cat = 4 if marital == 5                  // Never married
label var marital_cat "Marital status (4 categories)"
label define marital_cat_lbl 1 "Married/partnered" 2 "Divorced/separated" ///
    3 "Widowed" 4 "Never married"
label values marital_cat marital_cat_lbl

gen married       = (marital_cat == 1) if !missing(marital_cat)
gen divorced      = (marital_cat == 2) if !missing(marital_cat)
gen widowed       = (marital_cat == 3) if !missing(marital_cat)
gen nevermarried  = (marital_cat == 4) if !missing(marital_cat)

label var married      "Married or partnered"
label var divorced     "Divorced or separated"
label var widowed      "Widowed"
label var nevermarried "Never married"

* --- 4h. Income --------------------------------------------------------------
* INCOME2 (2011-2020): 8 categories (1=<$10K ... 8=$75K+), 77=Don't know, 99=Refused
* INCOME3 (2021+): expanded to 11 categories (1=<$10K ... 11=$200K+)
*
* We harmonize to the 8-category INCOME2 scale for cross-year comparability.
* Users needing finer 2021+ categories can use INCOME3 directly.

gen income_cat = .
* For years with INCOME2
* (capture protects against INCOME2 not existing when only 2021+ data loaded)
capture replace income_cat = income2 if surveyyear <= 2020 & income2 >= 1 & income2 <= 8
* For years with INCOME3 — collapse to 8 categories
capture replace income_cat = income3 if surveyyear >= 2021 & income3 >= 1 & income3 <= 8
capture replace income_cat = 8 if surveyyear >= 2021 & income3 > 8 & income3 < 77

label var income_cat "Household income (8 categories, harmonized)"
label define income_cat_lbl 1 "< $10,000" 2 "$10-15,000" 3 "$15-20,000" ///
    4 "$20-25,000" 5 "$25-35,000" 6 "$35-50,000" 7 "$50-75,000" 8 "$75,000+"
label values income_cat income_cat_lbl

* --- 4i. Employment ----------------------------------------------------------
* EMPLOY1: 1=Employed for wages, 2=Self-employed, 3=Unemployed 1yr+,
*          4=Unemployed <1yr, 5=Homemaker, 6=Student, 7=Retired, 8=Unable to work
gen working = (employ1 == 1 | employ1 == 2) if employ1 >= 1 & employ1 <= 8
gen student = (employ1 == 6) if employ1 >= 1 & employ1 <= 8
label var working "Currently employed (wages or self-employed)"
label var student "Student"

* ============================================================================
* 5. HEALTH OUTCOMES
* ============================================================================

* --- 5a. General health ------------------------------------------------------
* GENHLTH: 1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor, 7=DK, 9=Refused
gen genhealth = genhlth if genhlth >= 1 & genhlth <= 5
label var genhealth "Self-rated health (1=Excellent ... 5=Poor)"
label define genhealth_lbl 1 "Excellent" 2 "Very good" 3 "Good" 4 "Fair" 5 "Poor"
label values genhealth genhealth_lbl

gen fair_or_poor = (genhealth >= 4) if !missing(genhealth)
label var fair_or_poor "Fair or poor self-rated health"

* --- 5b. Mental health days --------------------------------------------------
* MENTHLTH: "For how many days during the past 30 days was your mental
*           health not good?" 1-30 = days, 88 = none, 77 = DK, 99 = Refused
gen mental_days = .
replace mental_days = menthlth if menthlth >= 1 & menthlth <= 30
replace mental_days = 0 if menthlth == 88
label var mental_days "Days mental health not good (past 30 days)"

* --- 5c. Physical health days ------------------------------------------------
* PHYSHLTH: Same coding as MENTHLTH
gen physical_days = .
replace physical_days = physhlth if physhlth >= 1 & physhlth <= 30
replace physical_days = 0 if physhlth == 88
label var physical_days "Days physical health not good (past 30 days)"

* --- 5d. BMI -----------------------------------------------------------------
* _BMI5: BMI * 100 (e.g., 2500 = BMI of 25.0), CDC calculated variable
capture gen bmi = _bmi5 / 100 if _bmi5 < 9999
label var bmi "Body mass index (continuous)"

* _BMI5CAT: BMI category (1=Underweight, 2=Normal, 3=Overweight, 4=Obese)
capture gen bmi_cat = _bmi5cat if _bmi5cat >= 1 & _bmi5cat <= 4
label var bmi_cat "BMI category (CDC calculated)"
label define bmi_cat_lbl 1 "Underweight" 2 "Normal weight" 3 "Overweight" 4 "Obese"
capture label values bmi_cat bmi_cat_lbl

* --- 5e. Smoking status ------------------------------------------------------
* _SMOKER3: 1=Current daily, 2=Current some days, 3=Former, 4=Never, 9=DK/Missing
capture gen smoker = _smoker3 if _smoker3 >= 1 & _smoker3 <= 4
label var smoker "Smoking status (CDC calculated)"
label define smoker_lbl 1 "Current daily" 2 "Current some days" ///
    3 "Former smoker" 4 "Never smoked"
capture label values smoker smoker_lbl

capture gen current_smoker = (smoker == 1 | smoker == 2) if !missing(smoker)
label var current_smoker "Current smoker (daily or some days)"

* --- 5f. Chronic conditions --------------------------------------------------
* These use a consistent coding: 1=Yes, 2=No, 7=DK, 9=Refused

* Diabetes
capture gen diabetes = (diabete4 == 1) if diabete4 == 1 | diabete4 == 3
capture replace diabetes = 0 if diabete4 == 3
label var diabetes "Ever told have diabetes"

* Asthma
capture gen asthma_ever = (asthma3 == 1) if asthma3 == 1 | asthma3 == 2
label var asthma_ever "Ever told have asthma"

capture gen asthma_current = (asthnow == 1) if asthnow == 1 | asthnow == 2
label var asthma_current "Still have asthma"

* COPD
capture gen copd = (chccopd == 1) if chccopd == 1 | chccopd == 2
* Older years may use chccopd1 or chccopd2
capture replace copd = (chccopd1 == 1) if missing(copd) & (chccopd1 == 1 | chccopd1 == 2)
label var copd "Ever told have COPD/emphysema/chronic bronchitis"

* Heart disease (angina or coronary heart disease)
capture gen heartdisease = (cvdcrhd4 == 1) if cvdcrhd4 == 1 | cvdcrhd4 == 2
label var heartdisease "Ever told have angina or coronary heart disease"

* Heart attack
capture gen heartattack = (cvdinfr4 == 1) if cvdinfr4 == 1 | cvdinfr4 == 2
label var heartattack "Ever told have heart attack (MI)"

* ============================================================================
* 6. LABEL AND SAVE
* ============================================================================

label var surveyyear "BRFSS survey year"

sort surveyyear statefips
compress

save "`out_dta'", replace
display as text "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 7. DESCRIPTIVE STATISTICS
* ============================================================================

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

* --- 7a. Sample sizes by year ------------------------------------------------
display as text _newline "--- Sample sizes by year ---"
tab surveyyear

* --- 7b. Demographics (unweighted) -------------------------------------------
display as text _newline "--- Age distribution ---"
summarize age, detail

display as text _newline "--- Gender ---"
tab female

display as text _newline "--- Race/ethnicity ---"
tab race_eth

display as text _newline "--- Education ---"
tab educ_cat

* --- 7c. Health outcomes (unweighted) ----------------------------------------
display as text _newline "--- Self-rated health ---"
tab genhealth

display as text _newline "--- Mental health days (past 30) ---"
summarize mental_days, detail

display as text _newline "--- BMI ---"
summarize bmi, detail

* --- 7d. Survey-weighted example ---------------------------------------------
display as text _newline "--- Survey-weighted mean: fair/poor health by year ---"
svy: tab surveyyear fair_or_poor, row percent format(%9.1f)

* ============================================================================
* 8. EXAMPLE REGRESSIONS
* ============================================================================
* These examples demonstrate how to use the survey design for analysis.
* They are not meant to be definitive models — just starting points.

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSIONS"
display as text "============================================"

* --- 8a. Unweighted OLS: mental health days ~ demographics -------------------
display as text _newline "--- OLS: Mental health days (unweighted) ---"
regress mental_days female age i.race_eth i.educ_cat i.surveyyear

* --- 8b. Survey-weighted regression ------------------------------------------
display as text _newline "--- Survey-weighted: Mental health days ---"
svy: regress mental_days female age i.race_eth i.educ_cat i.surveyyear

* --- 8c. Survey-weighted logit: fair/poor health -----------------------------
display as text _newline "--- Survey-weighted logit: Fair/poor health ---"
svy: logit fair_or_poor female age i.race_eth i.educ_cat i.surveyyear

display as text _newline "============================================"
display as text "   DONE"
display as text "============================================"

********************************************************************************
* NOTES FOR USERS:
*
* 1. SURVEY WEIGHTS ARE ESSENTIAL: The BRFSS uses a complex survey design.
*    ALWAYS use -svy- commands for population-representative estimates.
*    Unweighted analyses are shown only for comparison / quick checks.
*
* 2. CROSS-YEAR COMPARABILITY: Variables harmonized here (race_eth,
*    income_cat, female) are designed to be comparable across all years.
*    For variables NOT harmonized, check the codebook for each year.
*
* 3. VARIABLE NAMING CHANGES IN 2022+:
*    - _RACEGR3 -> _RACEGR4 (race categories expanded)
*    - INCOME2 -> INCOME3 (income categories expanded to 11)
*    - SEX -> SEXVAR/BIRTHSEX (gender identity questions added)
*    This script handles all three changes.
*
* 4. CALCULATED VARIABLES: Variables starting with _ (underscore) are
*    CDC-calculated variables derived from survey responses. These include
*    _BMI5, _SMOKER3, _AGE80, _AGEG5YR, _RACEGR3/_RACEGR4, etc.
*    Documentation: see docs/20XX-calculated-variables-*.pdf
*
* 5. STATE FIPS CODES: _STATE contains FIPS codes. Codes > 56 are
*    territories (Guam, Puerto Rico, etc.). Filter to <= 56 for 50 states + DC.
*
* 6. OPTIONAL MODULES: The BRFSS includes optional modules that vary by
*    state and year (e.g., cannabis use, ACEs, social determinants).
*    These are in the data but not cleaned here. Check the module analysis
*    documents in docs/ for which states asked which modules.
*
* 7. INCOME HARMONIZATION: We collapse INCOME3 (2021+) to the 8-category
*    INCOME2 scale. If you need the finer 2021+ categories ($100-150K,
*    $150-200K, $200K+), use INCOME3 directly for those years.
********************************************************************************
