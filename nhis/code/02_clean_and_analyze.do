********************************************************************************
* 02_clean_and_analyze.do
*
* Purpose: Clean and create analysis-ready variables from the NHIS combined
*          adult file spanning ALL years (2004-2024). Handles the 2019
*          redesign break with era-specific coding logic.
*
*          Covers: demographics, health insurance, health status, chronic
*          conditions, health care utilization, mental health, and BMI.
*
*          The key challenge is that variable CODING differs across eras:
*            - Pre-2019: insurance 1=mentioned, 2=probed yes, 3=no
*            - Post-2019: insurance 1=yes, 2=no
*          Variable NAMES have been harmonized in 01_load_and_append.do
*          (e.g., age_p -> agep_a, sex -> sex_a), but coding must be
*          handled here using the era_post2019 indicator.
*
* Input:   output/nhis_adult.dta  (from 01_load_and_append.do)
* Output:  output/nhis_adult_clean.dta
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================

global nhis_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/nhis"
cd "$nhis_root"

local in_dta  "output/nhis_adult.dta"
local out_dta "output/nhis_adult_clean.dta"

* ============================================================================
* 2. LOAD DATA
* ============================================================================

display as text _newline "============================================"
display as text "   LOADING NHIS ADULT DATA"
display as text "============================================"

use "`in_dta'", clear
display as text "Loaded: " _N " observations"

* ============================================================================
* 3. DEMOGRAPHICS
* ============================================================================
* Variable names have been harmonized to 2019+ convention:
*   agep_a     : Age in years (both eras)
*   sex_a      : Sex (both eras: 1=Male, 2=Female)
*   hisp_a     : Hispanic origin (both eras: 1=Hispanic, 2=Not Hispanic)
*   raceallp_a : Race (CODING DIFFERS — see below)
*   educ_a     : Education (CODING DIFFERS — see below)
*   citizenp_a : Citizenship (similar coding)
*
* RACE CODING:
*   Pre-2019 (racerpi2): 1=White, 2=Black/AA, 3=AIAN, 4-15=various Asian/PI
*   Post-2019 (raceallp_a): 1=White, 2=Black, 3=AIAN, 4=Asian,
*                           5=Not releasable, 6=Multiple
*   → For broad categories (White, Black), codes match across eras.
*     For Asian: pre-2019 uses various codes 4-15; post-2019 uses 4.
*
* EDUCATION CODING:
*   Pre-2019 (educ1): 00=Never, 01-12=Grade 1-12, 13=HS grad, 14=GED,
*                     15-17=Some college/AA, 18=Bachelor's, 19-21=Graduate
*   Post-2019 (educ_a): 00=Never, 01-09=Less than HS, 10=HS/GED,
*                        11-12=Some college/AA, 13=Bachelor's, 14-16=Graduate

display as text _newline "============================================"
display as text "   CLEANING DEMOGRAPHICS"
display as text "============================================"

* --- Sex ---
gen female = (sex_a == 2) if !missing(sex_a)
label var female "Female indicator (1=Female, 0=Male)"

* --- Age categories ---
gen age_cat = .
replace age_cat = 1 if agep_a >= 18 & agep_a <= 25
replace age_cat = 2 if agep_a >= 26 & agep_a <= 34
replace age_cat = 3 if agep_a >= 35 & agep_a <= 44
replace age_cat = 4 if agep_a >= 45 & agep_a <= 54
replace age_cat = 5 if agep_a >= 55 & agep_a <= 64
replace age_cat = 6 if agep_a >= 65 & agep_a <= 74
replace age_cat = 7 if agep_a >= 75 & agep_a < .
label define age_cat 1 "18-25" 2 "26-34" 3 "35-44" 4 "45-54" ///
                     5 "55-64" 6 "65-74" 7 "75+"
label values age_cat age_cat
label var age_cat "Age category"

* --- Race/ethnicity (era-aware) ---
gen race_eth = .
* Hispanic (any race) — same coding across eras
replace race_eth = 3 if hisp_a == 1

* White NH — code 1 in both eras
replace race_eth = 1 if raceallp_a == 1 & hisp_a == 2

* Black NH — code 2 in both eras
replace race_eth = 2 if raceallp_a == 2 & hisp_a == 2

* Asian NH — code 4 in post-2019; codes 4-14 in pre-2019
replace race_eth = 4 if raceallp_a == 4 & hisp_a == 2 & era_post2019 == 1
replace race_eth = 4 if inrange(raceallp_a, 4, 14) & hisp_a == 2 & era_post2019 == 0

* Other NH — everything else
replace race_eth = 5 if !inlist(race_eth, 1, 2, 3, 4) & !missing(raceallp_a) & !missing(hisp_a)

label define race_eth 1 "White NH" 2 "Black NH" 3 "Hispanic" ///
                      4 "Asian NH" 5 "Other NH"
label values race_eth race_eth
label var race_eth "Race/ethnicity (5 categories)"

* --- Education (era-aware) ---
gen educ_cat = .
* Pre-2019 coding (educ1 stored as educ_a)
replace educ_cat = 1 if educ_a <= 12 & era_post2019 == 0       // Less than HS
replace educ_cat = 2 if inlist(educ_a, 13, 14) & era_post2019 == 0  // HS/GED
replace educ_cat = 3 if inlist(educ_a, 15, 16, 17) & era_post2019 == 0  // Some college/AA
replace educ_cat = 4 if educ_a == 18 & era_post2019 == 0       // Bachelor's
replace educ_cat = 5 if inlist(educ_a, 19, 20, 21) & era_post2019 == 0  // Graduate

* Post-2019 coding
replace educ_cat = 1 if educ_a <= 9 & era_post2019 == 1        // Less than HS
replace educ_cat = 2 if educ_a == 10 & era_post2019 == 1       // HS/GED
replace educ_cat = 3 if inlist(educ_a, 11, 12) & era_post2019 == 1  // Some college/AA
replace educ_cat = 4 if educ_a == 13 & era_post2019 == 1       // Bachelor's
replace educ_cat = 5 if inlist(educ_a, 14, 15, 16) & era_post2019 == 1  // Graduate

label define educ_cat 1 "Less than HS" 2 "HS/GED" 3 "Some college/AA" ///
                      4 "Bachelor's" 5 "Graduate"
label values educ_cat educ_cat
label var educ_cat "Education category (harmonized)"

* --- Citizenship/Immigration ---
capture confirm variable citizenp_a
if _rc == 0 {
    gen us_born = .
    * Pre-2019: geobrth_a 1=US, 2=territory, 3+=elsewhere
    replace us_born = 1 if inlist(citizenp_a, 1, 2, 3) & citizenp_a < 7
    replace us_born = 0 if inlist(citizenp_a, 4, 5) & citizenp_a < 7
    label var us_born "Born in US or territory (1=Yes)"

    gen citizen = (inlist(citizenp_a, 1, 2, 3, 4)) if citizenp_a < 7
    label var citizen "US citizen (1=Yes, includes naturalized)"

    gen noncitizen = (citizenp_a == 5) if citizenp_a < 7
    label var noncitizen "Non-citizen (1=Yes)"
}

* ============================================================================
* 4. HEALTH INSURANCE (ERA-AWARE CODING)
* ============================================================================
* CRITICAL: Insurance variables use DIFFERENT coding by era.
*
* Pre-2019: 1=Mentioned/Yes, 2=Probed yes, 3=No, >3=missing
*   For notcov: 1=Not covered, 2=Covered, >2=missing
*   For other insurance vars: 1 or 2 = Yes, 3 = No
*
* Post-2019: 1=Yes, 2=No, >2=missing
*   For notcov_a: 1=Not covered, 2=Covered

display as text _newline "============================================"
display as text "   CLEANING HEALTH INSURANCE"
display as text "============================================"

* --- Uninsured ---
capture confirm variable notcov_a
if _rc == 0 {
    gen uninsured = .
    * Both eras: 1=Not covered, 2=Covered
    replace uninsured = 1 if notcov_a == 1
    replace uninsured = 0 if notcov_a == 2
    label var uninsured "Currently uninsured (1=Yes)"
}

* --- Medicare ---
capture confirm variable medicare_a
if _rc == 0 {
    gen has_medicare = .
    * Pre-2019: 1 or 2 = Yes, 3 = No
    replace has_medicare = 1 if inlist(medicare_a, 1, 2) & era_post2019 == 0
    replace has_medicare = 0 if medicare_a == 3 & era_post2019 == 0
    * Post-2019: 1 = Yes, 2 = No
    replace has_medicare = 1 if medicare_a == 1 & era_post2019 == 1
    replace has_medicare = 0 if medicare_a == 2 & era_post2019 == 1
    label var has_medicare "Has Medicare (1=Yes)"
}

* --- Medicaid ---
capture confirm variable medicaid_a
if _rc == 0 {
    gen has_medicaid = .
    replace has_medicaid = 1 if inlist(medicaid_a, 1, 2) & era_post2019 == 0
    replace has_medicaid = 0 if medicaid_a == 3 & era_post2019 == 0
    replace has_medicaid = 1 if medicaid_a == 1 & era_post2019 == 1
    replace has_medicaid = 0 if medicaid_a == 2 & era_post2019 == 1
    label var has_medicaid "Has Medicaid (1=Yes)"
}

* --- Private ---
capture confirm variable private_a
if _rc == 0 {
    gen has_private = .
    replace has_private = 1 if inlist(private_a, 1, 2) & era_post2019 == 0
    replace has_private = 0 if private_a == 3 & era_post2019 == 0
    replace has_private = 1 if private_a == 1 & era_post2019 == 1
    replace has_private = 0 if private_a == 2 & era_post2019 == 1
    label var has_private "Has private insurance (1=Yes)"
}

* --- Insurance hierarchy (mutually exclusive) ---
gen insur_type = .
capture confirm variable has_medicare
if _rc == 0 replace insur_type = 1 if has_medicare == 1
capture confirm variable has_private
if _rc == 0 replace insur_type = 2 if has_private == 1 & insur_type == .
capture confirm variable has_medicaid
if _rc == 0 replace insur_type = 3 if has_medicaid == 1 & insur_type == .
capture confirm variable uninsured
if _rc == 0 replace insur_type = 4 if uninsured == 1 & insur_type == .
replace insur_type = 5 if insur_type == . & !missing(uninsured)
label define insur_type 1 "Medicare" 2 "Private" 3 "Medicaid" ///
                        4 "Uninsured" 5 "Other public"
label values insur_type insur_type
label var insur_type "Insurance type (hierarchy)"

* ============================================================================
* 5. HEALTH STATUS
* ============================================================================
* phstat_a: Self-rated health (both eras)
*   1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor
*   Same coding across eras — no adjustment needed.

display as text _newline "============================================"
display as text "   CLEANING HEALTH STATUS"
display as text "============================================"

capture confirm variable phstat_a
if _rc == 0 {
    gen health_status = phstat_a if phstat_a >= 1 & phstat_a <= 5
    label define health_status 1 "Excellent" 2 "Very good" 3 "Good" ///
                               4 "Fair" 5 "Poor"
    label values health_status health_status
    label var health_status "Self-rated health (1=Excellent to 5=Poor)"

    gen fair_poor_health = (health_status >= 4) if !missing(health_status)
    label var fair_poor_health "Fair or poor health (1=Yes)"

    gen excellent_vgood = (health_status <= 2) if !missing(health_status)
    label var excellent_vgood "Excellent or very good health (1=Yes)"
}

* ============================================================================
* 6. CHRONIC CONDITIONS (ERA-AWARE)
* ============================================================================
* Pre-2019 (from samadult): 1=Yes, 2=No, >2=missing
* Post-2019: 1=Yes, 2=No, 7/8/9=missing
* Same Yes/No coding — just different missing codes.

display as text _newline "============================================"
display as text "   CLEANING CHRONIC CONDITIONS"
display as text "============================================"

foreach v in hypev chlev chdev angev miev strev asev canev dibev copdev arthev depev anxev {
    capture confirm variable `v'_a
    if _rc == 0 {
        gen `v' = .
        replace `v' = 1 if `v'_a == 1
        replace `v' = 0 if `v'_a == 2
        * Leave >2 as missing (handles both eras)
        label var `v' "Ever had `v' (1=Yes)"
    }
}

* ============================================================================
* 7. HEALTH CARE UTILIZATION
* ============================================================================
* pdmed12m_a: Delayed medical care, past 12 months
* pnmed12m_a: Needed but did not get medical care
* Same coding across eras: 1=Yes, 2=No

display as text _newline "============================================"
display as text "   CLEANING UTILIZATION"
display as text "============================================"

capture confirm variable pdmed12m_a
if _rc == 0 {
    gen delayed_care = (pdmed12m_a == 1) if pdmed12m_a <= 2
    label var delayed_care "Delayed medical care, past 12 months"
}

capture confirm variable pnmed12m_a
if _rc == 0 {
    gen foregone_care = (pnmed12m_a == 1) if pnmed12m_a <= 2
    label var foregone_care "Needed but did not get medical care"
}

* ============================================================================
* 8. MENTAL HEALTH (2019+ ONLY)
* ============================================================================
* PHQ-8 and GAD-7 are only available in 2019+ (post-redesign).
* These variables will be missing for pre-2019 observations.

display as text _newline "============================================"
display as text "   CLEANING MENTAL HEALTH SCREENERS"
display as text "============================================"

capture confirm variable phqcat_a
if _rc == 0 {
    gen depression_moderate = (phqcat_a >= 2) if phqcat_a >= 0 & phqcat_a <= 4
    label var depression_moderate "Moderate+ depression (PHQ-8 >= 10, 2019+ only)"
}

capture confirm variable gadcat_a
if _rc == 0 {
    gen anxiety_moderate = (gadcat_a >= 2) if gadcat_a >= 0 & gadcat_a <= 4
    label var anxiety_moderate "Moderate+ anxiety (GAD-7 >= 10, 2019+ only)"
}

* ============================================================================
* 9. BMI (2019+ ONLY)
* ============================================================================

capture confirm variable bmicat_a
if _rc == 0 {
    gen bmi_cat = bmicat_a if bmicat_a >= 1 & bmicat_a <= 4
    label define bmi_cat 1 "Underweight" 2 "Normal" 3 "Overweight" 4 "Obese"
    label values bmi_cat bmi_cat
    label var bmi_cat "BMI category"

    gen obese = (bmicat_a == 4) if bmicat_a >= 1 & bmicat_a <= 4
    label var obese "Obese (BMI >= 30)"
}

* ============================================================================
* 10. INCOME / POVERTY RATIO
* ============================================================================
* ratcat_a: Ratio of family income to poverty threshold (14 categories)
*   Same coding in both eras (harmonized in 01_load_and_append):
*     01=Under 0.50, 02=0.50-0.74, 03=0.75-0.99, 04=1.00-1.24,
*     05=1.25-1.49, 06=1.50-1.74, 07=1.75-1.99, 08=2.00-2.49,
*     09=2.50-2.99, 10=3.00-3.49, 11=3.50-3.99, 12=4.00-4.49,
*     13=4.50-4.99, 14=5.00+
*   Pre-2019 also has 15-17 (NFS=No Further Specificity) and 96/99.
*   Post-2019 has 98=Not ascertained.
*
* incgrp_a: Total combined family income (grouped)
*   Both eras: 1=$0-$34,999, 2=$35,000-$49,999, 3=$50,000-$74,999,
*              4=$75,000-$99,999, 5=$100,000+
*   Pre-2019 also has 6-7 (NFS categories), 96/99.
*   Post-2019: only available in 2019-2020, dropped in 2021+.
*
* ernyr_a: Total personal earnings last year (pre-2019 only)
*   11 categories: 01=$1-$4,999 through 11=$75,000+
*   Not available in post-2019.
*
* povrattc_a: Continuous poverty ratio (post-2019 only, from main file)
*   Available in 2019+ main adult file (top-coded).
*   For precise analysis, use multiple imputation files (adultinc).

display as text _newline "============================================"
display as text "   CLEANING INCOME / POVERTY"
display as text "============================================"

* --- Poverty ratio categories (broad groups, comparable across eras) ---
capture confirm variable ratcat_a
if _rc == 0 {
    gen pov_cat = .
    * Below poverty (FPL ratio < 1.00): codes 01-03
    replace pov_cat = 1 if ratcat_a >= 1 & ratcat_a <= 3
    * 1.00-1.99 FPL: codes 04-07
    replace pov_cat = 2 if ratcat_a >= 4 & ratcat_a <= 7
    * 2.00-3.99 FPL: codes 08-11
    replace pov_cat = 3 if ratcat_a >= 8 & ratcat_a <= 11
    * 4.00+ FPL: codes 12-14
    replace pov_cat = 4 if ratcat_a >= 12 & ratcat_a <= 14
    * NFS codes (pre-2019 only): 15-17 → leave as missing

    label define pov_cat 1 "Below poverty (<100% FPL)" ///
                         2 "100-199% FPL" ///
                         3 "200-399% FPL" ///
                         4 "400%+ FPL"
    label values pov_cat pov_cat
    label var pov_cat "Poverty ratio category (4 groups)"

    * Binary: below poverty
    gen below_poverty = (pov_cat == 1) if !missing(pov_cat)
    label var below_poverty "Below federal poverty level (1=Yes)"

    * Binary: low income (below 200% FPL)
    gen low_income = (pov_cat <= 2) if !missing(pov_cat)
    label var low_income "Low income, below 200% FPL (1=Yes)"
}

* --- Income group (5 categories) ---
capture confirm variable incgrp_a
if _rc == 0 {
    gen income_cat = .
    replace income_cat = 1 if incgrp_a == 1
    replace income_cat = 2 if incgrp_a == 2
    replace income_cat = 3 if incgrp_a == 3
    replace income_cat = 4 if incgrp_a == 4
    replace income_cat = 5 if incgrp_a == 5
    * NFS codes (pre-2019: 6-7), 96/99 → missing

    label define income_cat 1 "$0-$34,999" 2 "$35,000-$49,999" ///
                            3 "$50,000-$74,999" 4 "$75,000-$99,999" ///
                            5 "$100,000+"
    label values income_cat income_cat
    label var income_cat "Family income category (5 groups)"
}

* --- Personal earnings (pre-2019 only) ---
capture confirm variable ernyr_a
if _rc == 0 {
    gen earn_cat = .
    replace earn_cat = 1 if inrange(ernyr_a, 1, 3)     // Under $15,000
    replace earn_cat = 2 if inrange(ernyr_a, 4, 5)     // $15,000-$24,999
    replace earn_cat = 3 if inrange(ernyr_a, 6, 7)     // $25,000-$44,999
    replace earn_cat = 4 if inrange(ernyr_a, 8, 9)     // $45,000-$64,999
    replace earn_cat = 5 if inrange(ernyr_a, 10, 11)   // $65,000+

    label define earn_cat 1 "Under $15,000" 2 "$15,000-$24,999" ///
                          3 "$25,000-$44,999" 4 "$45,000-$64,999" ///
                          5 "$65,000+"
    label values earn_cat earn_cat
    label var earn_cat "Personal earnings category (pre-2019 only)"
}

* ============================================================================
* 11. SURVEY DESIGN
* ============================================================================

display as text _newline "============================================"
display as text "   SETTING SURVEY DESIGN"
display as text "============================================"

* Create pooled weight: divide by number of years
* Count the number of unique years in the dataset
quietly tab srvy_yr
local n_years = r(r)
gen wtfa_adj = wtfa_a / `n_years'
label var wtfa_adj "Pooled weight (wtfa_a / `n_years' years)"

capture confirm variable pstrat
if _rc == 0 {
    capture confirm variable ppsu
    if _rc == 0 {
        svyset ppsu [pweight=wtfa_adj], strata(pstrat)
        display as text "[INFO] Survey design set with pooled weight"
    }
}

* ============================================================================
* 12. SAVE CLEANED DATASET
* ============================================================================

display as text _newline "============================================"
display as text "   SAVING CLEANED DATASET"
display as text "============================================"

sort srvy_yr hhx
compress
save "`out_dta'", replace
display as text "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 13. DESCRIPTIVE STATISTICS
* ============================================================================

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

* 13a. Year distribution
tab srvy_yr

* 13b. Era distribution
tab era_post2019

* 13c. Demographics
display as text _newline "--- Demographics ---"
summarize agep_a female
tab race_eth
tab age_cat
capture tab educ_cat

* 13d. Insurance by era
display as text _newline "--- Health insurance by era ---"
tab insur_type if era_post2019 == 0
tab insur_type if era_post2019 == 1

* 13e. Insurance trends over time
display as text _newline "--- Uninsured rate by year ---"
capture table srvy_yr, statistic(mean uninsured) statistic(count uninsured) nformat(%9.3f)

* 13f. Uninsured by race/ethnicity
display as text _newline "--- Uninsured rate by race/ethnicity ---"
capture table race_eth, statistic(mean uninsured) statistic(count uninsured) nformat(%9.3f)

* 13g. Health status
display as text _newline "--- Self-rated health ---"
capture tab health_status
capture summarize fair_poor_health excellent_vgood

* 13h. Chronic conditions
display as text _newline "--- Chronic conditions (ever diagnosed) ---"
foreach v in hypev chlev dibev depev anxev asev copdev arthev {
    capture summarize `v'
}

* 13i. Income / poverty
display as text _newline "--- Income / poverty ---"
capture tab pov_cat
capture summarize below_poverty low_income
capture tab income_cat
capture tab pov_cat if era_post2019 == 0, missing
capture tab pov_cat if era_post2019 == 1, missing

* ============================================================================
* 14. EXAMPLE REGRESSIONS
* ============================================================================

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSIONS"
display as text "============================================"

* 14a. OLS: Uninsured ~ demographics (unweighted)
display as text _newline "--- OLS: Uninsured ~ demographics (unweighted) ---"
capture reg uninsured female agep_a i.race_eth i.educ_cat i.srvy_yr

* 14b. Weighted OLS
display as text _newline "--- Weighted OLS: Uninsured ~ demographics ---"
capture reg uninsured female agep_a i.race_eth i.educ_cat i.pov_cat i.srvy_yr [pweight=wtfa_adj]

* 14c. Survey-weighted: Fair/poor health ~ demographics
display as text _newline "--- Svy: Fair/poor health ~ demographics ---"
capture svy: reg fair_poor_health female agep_a i.race_eth i.educ_cat i.pov_cat i.srvy_yr

display as text _newline "============================================"
display as text "   DONE"
display as text "============================================"

********************************************************************************
* NOTES:
*
* 1. ERA-SPECIFIC CODING:
*    The most critical difference between eras is insurance variable coding:
*      Pre-2019: 1=mentioned, 2=probed yes, 3=no (both 1 and 2 mean Yes)
*      Post-2019: 1=yes, 2=no
*    The era_post2019 indicator is used throughout to apply correct recoding.
*
* 2. VARIABLE AVAILABILITY:
*    Some variables are only available in certain years:
*      PHQ-8 / GAD-7: 2019+ only
*      BMI category: 2019+ only
*      Chronic conditions: available in most years (from samadult)
*      SNAP (fsnap): 2011+ (ffdstyn in 2004-2010)
*      Personal earnings (ernyr_a): pre-2019 only
*      Income group (incgrp_a): all pre-2019 + 2019-2020 only
*      Poverty ratio category (ratcat_a): all years
*      Continuous poverty ratio (povrattc_a): 2019+ main file
*
* 2b. INCOME/POVERTY:
*    The poverty ratio category (ratcat_a → pov_cat) is the most
*    harmonizable income measure across all years. It uses the same
*    14-category coding in both eras.
*    For continuous family income or more detailed poverty ratios,
*    use the multiple imputation files (INCMIMP pre-2019, adultinc
*    post-2019) with proper MI techniques (Rubin's rules).
*
* 3. RACE HARMONIZATION:
*    Pre-2019 has more detailed Asian race codes (4-15 in racerpi2).
*    Post-2019 collapses to a single Asian category (4 in raceallp_a).
*    Our race_eth variable uses 5 broad categories that are comparable
*    across eras (White NH, Black NH, Hispanic, Asian NH, Other NH).
*
* 4. WEIGHTS:
*    wtfa_a = final annual sample adult weight (renamed from wtfa_sa pre-2019)
*    wtfa_adj = wtfa_a / N_years (for pooled analysis)
*    For proper variance estimation, use svyset with pstrat and ppsu.
*
* 5. 2020 COVID DISRUPTION:
*    Consider sensitivity analyses excluding 2020.
*
* 6. CHILD FILE:
*    To clean the child file, adapt this script using:
*      - input: output/nhis_child.dta
*      - variable suffix: _c instead of _a (for post-2019)
*      - weight: wtfa_c instead of wtfa_a
*      - child-specific health variables from samchild
*    The original RDC research scripts provide a template for child
*    health outcomes (access, utilization, school days lost, etc.)
*
* 7. CITATION:
*    National Center for Health Statistics. National Health Interview
*    Survey, [year]. Hyattsville, Maryland.
*    https://www.cdc.gov/nchs/nhis/index.htm
********************************************************************************
