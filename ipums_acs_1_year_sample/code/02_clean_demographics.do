********************************************************************************
* 02_clean_demographics.do
*
* Purpose: Load the ACS working dataset and demonstrate cleaning of:
*          (1) Demographics: race/ethnicity, sex, age, marital status
*          (2) Education: years of education, degree indicators
*          (3) Employment and income
*          (4) Health insurance
*          (5) Immigration and citizenship
*          (6) Poverty and public assistance
*          (7) Descriptive statistics and simple regressions
*
* Input:   output/acs_working.dta  (from 01_load_and_subset.do)
* Output:  Descriptive statistics and regression output to console
*
* Usage:   Update the global acs_root path below, then:
*            cd "/path/to/ipums_acs_1_year_sample"
*            do code/02_clean_demographics.do
*
* Notes:   This is a STARTER script. It demonstrates how to clean key
*          variables. Users should extend this for their own analysis.
*          Variable coding follows the Kuka et al. (2020) replication code.
*
* Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. DEFINE PATHS AND LOAD DATA
* ============================================================================

global acs_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/ipums_acs_1_year_sample"
cd "$acs_root"

use "output/acs_working.dta", clear
display as text "Loaded " _N " observations."

* ============================================================================
* 2. DEMOGRAPHICS: RACE AND ETHNICITY
* ============================================================================
* Create mutually exclusive race/ethnicity categories.
* Hispanic ethnicity takes precedence over race (following Kuka et al.).

* --- Hispanic indicator ---
gen hisp = (hispan != 0) if hispan != .

* --- Race indicators (non-Hispanic only) ---
gen white   = (race == 1 & hisp == 0)
gen black   = (race == 2 & hisp == 0)
gen asian   = (inlist(race, 4, 5, 6) & hisp == 0)
gen other   = (hisp == 0 & white == 0 & black == 0 & asian == 0)

* --- Mutually exclusive race/ethnicity variable ---
gen race_eth = .
replace race_eth = 1 if white == 1
replace race_eth = 2 if black == 1
replace race_eth = 3 if hisp == 1
replace race_eth = 4 if asian == 1
replace race_eth = 5 if other == 1
label define race_eth_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" ///
                          4 "Asian NH" 5 "Other NH"
label values race_eth race_eth_lbl

display as text _newline "--- Race/ethnicity ---"
tab race_eth

* ============================================================================
* 3. DEMOGRAPHICS: SEX, AGE, MARITAL STATUS
* ============================================================================

* --- Female indicator ---
gen female = (sex == 2)

* --- Marital status ---
gen married = (marst == 1 | marst == 2)

* --- Age group indicators ---
gen age_18_24 = (age >= 18 & age <= 24)
gen age_25_34 = (age >= 25 & age <= 34)
gen age_35_44 = (age >= 35 & age <= 44)
gen age_45_54 = (age >= 45 & age <= 54)
gen age_55_64 = (age >= 55 & age <= 64)
gen age_65plus = (age >= 65) if age != .

display as text _newline "--- Age distribution ---"
summarize age, detail

display as text _newline "--- Sex ---"
tab female

display as text _newline "--- Marital status ---"
tab married

* ============================================================================
* 4. EDUCATION
* ============================================================================
* Map detailed IPUMS education codes (educd) to years of education.
* Then create degree attainment indicators.
* Coding follows Kuka et al. (2020) Appendix.

gen yrsed = .
replace yrsed = 0  if educd == 2                             /* no school     */
replace yrsed = 2  if educd == 14                            /* nursery-4th   */
replace yrsed = 4  if educd == 15 | educd == 13              /* 1st-4th grade */
replace yrsed = 5  if educd == 16                            /* 5th-6th grade */
replace yrsed = 6  if educd == 17                            /* 5th-6th grade */
replace yrsed = 7  if educd == 22                            /* 7th-8th grade */
replace yrsed = 8  if educd == 23                            /* 7th-8th grade */
replace yrsed = 9  if educd == 25                            /* 9th grade     */
replace yrsed = 10 if educd == 26                            /* 10th grade    */
replace yrsed = 11 if educd == 30                            /* 11th grade    */
replace yrsed = 12 if inlist(educd, 40, 50, 61, 63, 64)     /* 12th / HS / GED */
replace yrsed = 13 if educd == 65                            /* some college <1yr */
replace yrsed = 14 if inlist(educd, 70, 71)                  /* some college 1+yr / associate's */
replace yrsed = 16 if educd == 101                           /* bachelor's    */
replace yrsed = 18 if educd == 114                           /* master's      */
replace yrsed = 19 if educd == 115                           /* professional  */
replace yrsed = 21 if educd == 116                           /* doctorate     */

* --- Degree indicators ---
gen hs          = (yrsed >= 12 & yrsed != .) if educd != 61  /* HS+ (excl 12th no diploma) */
gen some_college = (yrsed > 12 & yrsed != .)
gen college     = (yrsed >= 16 & yrsed != .)

display as text _newline "--- Years of education ---"
tab yrsed

display as text _newline "--- Education attainment ---"
tab hs
tab some_college
tab college

* ============================================================================
* 5. EMPLOYMENT
* ============================================================================
* empstat: 0 = N/A (under 16), 1 = employed, 2 = unemployed, 3 = NILF

gen employed    = (empstat == 1)             if empstat != 0
gen unemployed  = (empstat == 2)             if empstat != 0
gen in_lf       = (empstat == 1 | empstat == 2) if empstat != 0

display as text _newline "--- Employment status (ages 16+) ---"
tab employed if age >= 16

* ============================================================================
* 6. INCOME AND POVERTY
* ============================================================================

* --- Poverty status ---
* IPUMS poverty: income-to-poverty ratio * 100 (e.g., 100 = at poverty line)
* poverty == 0 means not determined (group quarters, etc.)
gen inpov = (poverty <= 100 & poverty != 0) if poverty != 0
gen finc_to_pov = poverty / 100 if poverty != 0

* --- Wage income ---
* incwage: 999998 = missing, 999999 = N/A
gen wage = incwage if incwage < 999998

display as text _newline "--- Poverty status ---"
tab inpov

display as text _newline "--- Wage income (conditional on positive) ---"
summarize wage if wage > 0, detail

* ============================================================================
* 7. HEALTH INSURANCE
* ============================================================================
* hcovany: 1 = no coverage, 2 = with coverage (available 2008+)
* hcovpriv/hcovpub: private/public coverage

gen any_insurance = (hcovany == 2)     if hcovany != .
gen priv_ins      = (hcovpriv == 2)    if hcovpriv != .
gen pub_ins       = (hcovpub == 2)     if hcovpub != .
gen medicaid      = (hinscaid == 2)    if hinscaid != .
gen medicare      = (hinscare == 2)    if hinscare != .
gen uninsured     = (hcovany == 1)     if hcovany != .

display as text _newline "--- Health insurance (2008+) ---"
tab any_insurance if year >= 2008
tab uninsured    if year >= 2008

* ============================================================================
* 8. IMMIGRATION AND CITIZENSHIP
* ============================================================================

* --- Citizenship status ---
* citizen: 0 = N/A, 1 = born abroad of US parents, 2 = naturalized,
*          3 = not a citizen, 4 = born in US, 5 = born in US territories
gen noncitizen  = (citizen == 3)       if citizen != 0
gen usborn      = inlist(citizen, 4, 5) if citizen != 0
gen naturalized = (citizen == 2)       if citizen != 0

* --- Birthplace regions ---
gen bpl_us       = (bpl >= 1 & bpl <= 120)
gen bpl_mexico   = (bpl == 200)
gen bpl_centam   = (bpl >= 210 & bpl <= 300)
gen bpl_asia     = (bpl >= 500 & bpl < 600)
gen bpl_europe   = (bpl >= 400 & bpl < 500)
gen bpl_africa   = (bpl >= 800 & bpl < 900)

* --- Year and age at immigration ---
gen ageimmig = yrimmig - birthyr if yrimmig > 0
replace ageimmig = . if ageimmig < 0

* --- Language ---
gen english    = (language == 1)       if language != .
gen spanish    = (language == 12)      if language != .
gen nonfluent  = inlist(speakeng, 1, 6) if speakeng != .

display as text _newline "--- Citizenship ---"
tab noncitizen

display as text _newline "--- Birthplace region ---"
tab bpl_us

* ============================================================================
* 9. PUBLIC ASSISTANCE
* ============================================================================

* --- Food stamps / SNAP ---
gen foodstamp = (foodstmp == 2) if foodstmp != .

display as text _newline "--- Food stamps/SNAP ---"
tab foodstamp

* ============================================================================
* 10. DESCRIPTIVE STATISTICS
* ============================================================================

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

* --- 10a. Summary of key variables ---
display as text _newline "--- Key demographic variables ---"
summarize female age married hisp white black asian

display as text _newline "--- Education variables ---"
summarize yrsed hs some_college college

display as text _newline "--- Employment and income ---"
summarize employed in_lf wage inpov finc_to_pov

display as text _newline "--- Insurance variables (2008+) ---"
summarize any_insurance priv_ins pub_ins uninsured if year >= 2008

display as text _newline "--- Immigration variables ---"
summarize noncitizen usborn naturalized bpl_us bpl_mexico

* --- 10b. Insurance coverage trends ---
display as text _newline "--- Uninsured rate by year (2008+) ---"
capture table year if year >= 2008, ///
    statistic(mean uninsured) statistic(count uninsured) nformat(%9.3f)

* --- 10c. Uninsured rate by race/ethnicity ---
display as text _newline "--- Uninsured rate by race/ethnicity (2008+) ---"
capture table race_eth if year >= 2008, ///
    statistic(mean uninsured) statistic(count uninsured) nformat(%9.3f)

* ============================================================================
* 11. EXAMPLE REGRESSION
* ============================================================================
* Simple OLS: uninsured = f(demographics, education)
* This is just a demonstration — not a causal model.

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSION"
display as text "============================================"

display as text _newline "--- OLS: Uninsured on demographics (2008+, ages 18-64) ---"
reg uninsured female age i.race_eth hs college married noncitizen ///
    i.year [pw=perwt] if year >= 2008 & age >= 18 & age <= 64, robust

display as text _newline "============================================"
display as text "   CLEANING COMPLETE"
display as text "============================================"
display as text "Variables created: race_eth, female, married, yrsed, hs,"
display as text "  some_college, college, employed, in_lf, wage, inpov,"
display as text "  any_insurance, uninsured, noncitizen, usborn, and more."
display as text _newline "This is a starter script — extend for your own analysis."

********************************************************************************
* NOTES:
*
* 1. SAMPLE RESTRICTIONS:
*    This script does not restrict the sample. For specific analyses:
*    - Working-age adults: keep if age >= 18 & age <= 64
*    - Children: keep if age < 18
*    - Non-institutionalized: keep if gq != 3 & gq != 4
*
* 2. SURVEY WEIGHTS:
*    Always use perwt for person-level estimates:
*      [pw=perwt]     for regressions
*      [fw=perwt]     for tabulations (approximate)
*    For proper standard errors, use replicate weights with svyset.
*
* 3. EDUCATION CODING:
*    The yrsed variable follows the Kuka et al. mapping from IPUMS
*    detailed education codes (educd). Some rare categories may be
*    unmapped (yrsed will be missing for those observations).
*
* 4. INSURANCE VARIABLES:
*    Health insurance variables (hcovany, hcovpriv, hcovpub, etc.)
*    are only available from 2008 onwards.
*
* 5. IMMIGRATION:
*    - citizen == 3 identifies non-citizens
*    - yrimmig gives year of immigration (0 = born in US)
*    - bpl gives detailed birthplace codes
*
* 6. COMMON RESEARCH APPLICATIONS:
*    - Insurance coverage (ACA effects, Medicaid expansion)
*    - Immigration (DACA, citizenship status, assimilation)
*    - Education attainment and returns to education
*    - Labor market outcomes (employment, wages)
*    - Poverty and public assistance
*    - Disability and health
********************************************************************************
