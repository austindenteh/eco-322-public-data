********************************************************************************
* 02_clean_demographics.do
*
* Purpose: Clean and create analysis-ready variables from CPS ASEC data.
*          Covers demographics, income, employment, health insurance,
*          education, immigration, and transfer programs.
*
* Input:   output/cps_asec.dta  (from 01_load_and_subset.do)
* Output:  output/cps_clean.dta
*
* Usage:   Run after 01_load_and_subset.do from the march_cps/ directory.
*
* Note:    The CPS ASEC uses IPUMS harmonized variables. IPUMS has already
*          done substantial cross-year harmonization, but some variables
*          still need cleaning (recoding missings, creating categories, etc.).
*
* Author:  Austin Denteh (legacy code and Claude Code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================

global cps_root "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/eco-322-public-data/march_cps"
cd "$cps_root"

local in_dta   "output/cps_asec.dta"
local out_dta  "output/cps_clean.dta"

* ============================================================================
* 2. LOAD DATA
* ============================================================================

use "`in_dta'", clear
display as text "Loaded: " _N " observations."

* ============================================================================
* 3. DEMOGRAPHICS
* ============================================================================

* --- 3a. Age ------------------------------------------------------------------
* AGE: age in years (0-90, top-coded at 90 in most years)
label var age "Age in years"

* Age group categories
gen age_cat = .
replace age_cat = 1 if age >= 0 & age <= 17
replace age_cat = 2 if age >= 18 & age <= 25
replace age_cat = 3 if age >= 26 & age <= 34
replace age_cat = 4 if age >= 35 & age <= 44
replace age_cat = 5 if age >= 45 & age <= 54
replace age_cat = 6 if age >= 55 & age <= 64
replace age_cat = 7 if age >= 65
label var age_cat "Age group"
label define age_cat_lbl 1 "0-17" 2 "18-25" 3 "26-34" 4 "35-44" ///
    5 "45-54" 6 "55-64" 7 "65+"
label values age_cat age_cat_lbl

* Working-age adult indicator
gen working_age = (age >= 18 & age <= 64)
label var working_age "Working-age adult (18-64)"

* --- 3b. Sex ------------------------------------------------------------------
* SEX: 1=Male, 2=Female
gen female = (sex == 2)
label var female "Female (1=yes, 0=no)"
label define female_lbl 0 "Male" 1 "Female"
label values female female_lbl

* --- 3c. Race/Ethnicity -------------------------------------------------------
* RACE: IPUMS harmonized (100=White, 200=Black, 300=AIAN, 651=Asian, etc.)
* HISPAN: Hispanic origin (0=Not Hispanic, 100-412=various Hispanic origins)

gen race_eth = .
replace race_eth = 3 if hispan >= 100 & hispan <= 412    // Hispanic (any race)
replace race_eth = 1 if race == 100 & hispan == 0         // White non-Hispanic
replace race_eth = 2 if race == 200 & hispan == 0         // Black non-Hispanic
replace race_eth = 4 if race_eth == . & hispan == 0        // Other non-Hispanic
label var race_eth "Race/ethnicity (4 categories)"
label define race_eth_lbl 1 "White non-Hispanic" 2 "Black non-Hispanic" ///
    3 "Hispanic" 4 "Other non-Hispanic"
label values race_eth race_eth_lbl

* Indicators
gen white    = (race_eth == 1) if !missing(race_eth)
gen black    = (race_eth == 2) if !missing(race_eth)
gen hispanic = (race_eth == 3) if !missing(race_eth)
gen raceother = (race_eth == 4) if !missing(race_eth)
label var white    "White non-Hispanic"
label var black    "Black non-Hispanic"
label var hispanic "Hispanic"
label var raceother "Other non-Hispanic"

* --- 3d. Marital Status -------------------------------------------------------
* MARST: 1=Married/spouse present, 2=Married/spouse absent,
*        3=Separated, 4=Divorced, 5=Widowed, 6=Never married
gen marital_cat = .
replace marital_cat = 1 if marst == 1 | marst == 2   // Married
replace marital_cat = 2 if marst == 3 | marst == 4   // Divorced/separated
replace marital_cat = 3 if marst == 5                  // Widowed
replace marital_cat = 4 if marst == 6                  // Never married
label var marital_cat "Marital status (4 categories)"
label define marital_cat_lbl 1 "Married" 2 "Divorced/separated" ///
    3 "Widowed" 4 "Never married"
label values marital_cat marital_cat_lbl

gen married = (marital_cat == 1) if !missing(marital_cat)
label var married "Currently married"

* --- 3e. State ----------------------------------------------------------------
label var statefip "State FIPS code"

* ============================================================================
* 4. EDUCATION
* ============================================================================
* EDUC: IPUMS harmonized education variable (detailed codes).
* EDUC99: Comparable across 1992+ (after education question redesign).
* We create a 4-category education variable.

gen educ_cat = .
* Less than HS (codes 2-71 in EDUC)
replace educ_cat = 1 if educ >= 2 & educ <= 71
* HS graduate/GED (code 73)
replace educ_cat = 2 if educ == 73
* Some college / Associate degree (codes 80-92)
replace educ_cat = 3 if educ >= 80 & educ <= 92
* Bachelor's degree or higher (codes 111+)
replace educ_cat = 4 if educ >= 111 & educ < 999

label var educ_cat "Education (4 categories)"
label define educ_cat_lbl 1 "Less than HS" 2 "HS graduate/GED" ///
    3 "Some college/Associate" 4 "Bachelor's or higher"
label values educ_cat educ_cat_lbl

gen hsdropout   = (educ_cat == 1) if !missing(educ_cat)
gen hsgraduate  = (educ_cat == 2) if !missing(educ_cat)
gen somecollege = (educ_cat == 3) if !missing(educ_cat)
gen college     = (educ_cat == 4) if !missing(educ_cat)

label var hsdropout   "Less than HS"
label var hsgraduate  "HS graduate/GED"
label var somecollege "Some college/Associate"
label var college     "Bachelor's or higher"

* Currently enrolled in school
capture gen enrolled = (schlcoll >= 1 & schlcoll <= 4) if schlcoll != 0
label var enrolled "Currently enrolled in school/college"

* ============================================================================
* 5. EMPLOYMENT AND LABOR FORCE
* ============================================================================
* EMPSTAT: 0=NIU, 1=Armed Forces, 10=Employed, 12=Employed with job not at work,
*          20-22=Unemployed, 30-36=Not in labor force
* LABFORCE: 0=NIU, 1=Not in labor force, 2=In labor force

gen employed = .
replace employed = 1 if empstat >= 10 & empstat <= 12
replace employed = 0 if empstat >= 20 & empstat <= 36
label var employed "Currently employed"

gen unemployed = .
replace unemployed = 1 if empstat >= 20 & empstat <= 22
replace unemployed = 0 if empstat >= 10 & empstat <= 12
label var unemployed "Currently unemployed (among labor force)"

gen in_labor_force = (labforce == 2) if labforce >= 1 & labforce <= 2
label var in_labor_force "In labor force"

gen nilf = (labforce == 1) if labforce >= 1 & labforce <= 2
label var nilf "Not in labor force"

* Full-time / part-time (among employed, last year)
capture gen fulltime_ly = (fullpart == 1) if fullpart >= 1 & fullpart <= 2
capture label var fulltime_ly "Full-time worker last year"

* Weeks worked last year
capture gen weeks_worked = wkswork1 if wkswork1 > 0 & wkswork1 < 99
capture label var weeks_worked "Weeks worked last year (continuous)"

* ============================================================================
* 6. INCOME
* ============================================================================
* IPUMS provides both nominal and inflation-adjusted income variables.
* We keep the nominal versions; users can deflate as needed.
*
* Note: INCTOT, INCWAGE, etc. use 9999999 (or similar) for NIU/missing.

* Total personal income
gen totalinc = inctot if inctot < 9999998
label var totalinc "Total personal income (nominal)"

* Wage/salary income
gen wageinc = incwage if incwage < 9999998 & incwage != 0
label var wageinc "Wage and salary income (nominal)"

* Has any wage income
gen has_wageinc = (incwage > 0 & incwage < 9999998)
label var has_wageinc "Has positive wage income"

* Business income
capture gen businc = incbus if incbus > -9999998 & incbus < 9999998
capture label var businc "Business/self-employment income"

* Social Security income
gen ssinc = incss if incss < 99999 & incss > 0
label var ssinc "Social Security income (if receiving)"

gen receives_ss = (incss > 0 & incss < 99999)
label var receives_ss "Receives Social Security"

* Supplemental Security Income (SSI)
gen ssiinc = incssi if incssi < 99999 & incssi > 0
label var ssiinc "SSI income (if receiving)"

gen receives_ssi = (incssi > 0 & incssi < 99999)
label var receives_ssi "Receives SSI"

* Welfare income (TANF/AFDC)
gen welfareinc = incwelfr if incwelfr < 99999 & incwelfr > 0
label var welfareinc "Welfare/TANF income (if receiving)"

gen receives_welfare = (incwelfr > 0 & incwelfr < 99999)
label var receives_welfare "Receives welfare/TANF"

* Unemployment insurance income
gen uiinc = incunemp if incunemp < 99999 & incunemp > 0
label var uiinc "Unemployment insurance income (if receiving)"

gen receives_ui = (incunemp > 0 & incunemp < 99999)
label var receives_ui "Receives unemployment insurance"

* Household income (IPUMS harmonized)
label var hhincome "Total household income"

* ============================================================================
* 7. FOOD STAMPS / SNAP
* ============================================================================
* FOODSTMP: 0=NIU, 1=No, 2=Yes (household received food stamps/SNAP)

gen snap = (foodstmp == 2) if foodstmp >= 1 & foodstmp <= 2
label var snap "Household received SNAP/food stamps"

* ============================================================================
* 8. HEALTH INSURANCE
* ============================================================================
* Health insurance variables have changed substantially across CPS redesigns.
* Key transitions:
*   - Pre-2014: Traditional questions (COVERGH, COVERPI, PHINSUR, HINSCARE, etc.)
*   - 2014+: ACA-era questions (HIMCAIDLY, HIMCARELY, GRPDEPLY, etc.)
*   - 2019+: Redesigned questions (ANYCOVLY, ANYCOVNW, HIMCAIDNW, etc.)
*
* We create harmonized indicators using what's available across years.

* --- 8a. Any health insurance coverage (prior year) --------------------------
* PHINSUR: 1=Has private insurance, 2=Does not (available most years)
capture gen has_private_ins = (phinsur == 1) if phinsur >= 1 & phinsur <= 2
capture label var has_private_ins "Has private health insurance"

* HIMCAIDLY: 1=Covered by Medicaid last year, 2=Not covered
capture gen medicaid = (himcaidly == 2) if himcaidly >= 1 & himcaidly <= 2
capture label var medicaid "Covered by Medicaid (last year)"

* HIMCARELY: 1=Covered by Medicare last year, 2=Not covered
capture gen medicare = (himcarely == 2) if himcarely >= 1 & himcarely <= 2
capture label var medicare "Covered by Medicare (last year)"

* COVERGH: 1=Covered by group health plan, 2=Not
capture gen employer_ins = (covergh == 1) if covergh >= 1 & covergh <= 2
capture label var employer_ins "Covered by employer/group health plan"

* ANYCOVLY: Any insurance coverage last year (2019+)
capture gen any_ins_ly = (anycovly == 2) if anycovly >= 1 & anycovly <= 2
capture label var any_ins_ly "Any health insurance coverage (last year, 2019+)"

* ANYCOVNW: Any insurance coverage now (2014+)
capture gen any_ins_now = (anycovnw == 1) if anycovnw >= 1 & anycovnw <= 2
capture label var any_ins_now "Any health insurance coverage (at time of interview)"

* Uninsured indicator (use available variables by year)
gen uninsured = .
* For years with ANYCOVLY (2019+)
capture replace uninsured = (anycovly == 1) if anycovly >= 1 & anycovly <= 2
* For earlier years, construct from components
capture replace uninsured = 1 if missing(uninsured) & phinsur == 2 & himcaidly == 1 & himcarely == 1
capture replace uninsured = 0 if missing(uninsured) & (phinsur == 1 | himcaidly == 2 | himcarely == 2)
label var uninsured "Uninsured (no health insurance coverage)"

* ============================================================================
* 9. IMMIGRATION
* ============================================================================
* Available 1994+ in the IPUMS extract.

* Nativity
capture gen foreign_born = (nativity == 5) if nativity >= 1 & nativity <= 5
capture label var foreign_born "Foreign-born"

* Citizenship
capture gen citizen = .
capture replace citizen = 1 if citizen == 1 | citizen == 2  // Born in US
capture replace citizen = 1 if citizen == 3                  // Naturalized
capture replace citizen = 0 if citizen == 4 | citizen == 5   // Not a citizen

* Since IPUMS uses 'citizen' as the variable name, create a separate indicator
capture gen noncitizen = (citizen >= 4 & citizen <= 5) if citizen >= 1 & citizen <= 5
capture label var noncitizen "Non-citizen"

capture gen naturalized = (citizen == 3) if citizen >= 1 & citizen <= 5
capture label var naturalized "Naturalized citizen"

* Birth place (foreign vs. domestic)
capture gen bpl_foreign = (bpl >= 15000) if bpl > 0
capture label var bpl_foreign "Born outside US/territories"

* Year of immigration
capture gen yrimm = yrimmig if yrimmig > 0 & yrimmig < 9999
capture label var yrimm "Year of immigration (if foreign-born)"

* ============================================================================
* 10. POVERTY
* ============================================================================
* IPUMS provides OFFPOV (official poverty status) and POVERTY
* (poverty threshold as % of poverty line)

capture gen poverty_ratio = poverty / 100 if poverty > 0 & poverty < 999
capture label var poverty_ratio "Family income as ratio of poverty line"

capture gen below_poverty = (poverty > 0 & poverty < 100) if poverty > 0 & poverty < 999
capture label var below_poverty "Below 100% FPL"

capture gen below_138fpl = (poverty > 0 & poverty < 138) if poverty > 0 & poverty < 999
capture label var below_138fpl "Below 138% FPL (Medicaid expansion threshold)"

capture gen below_200fpl = (poverty > 0 & poverty < 200) if poverty > 0 & poverty < 999
capture label var below_200fpl "Below 200% FPL"

capture gen below_400fpl = (poverty > 0 & poverty < 400) if poverty > 0 & poverty < 999
capture label var below_400fpl "Below 400% FPL (ACA marketplace subsidy threshold)"

* ============================================================================
* 11. SAVE
* ============================================================================

sort year serial pernum
compress

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Observations: " _N
display as text "Variables: " c(k)

* ============================================================================
* 12. DESCRIPTIVE STATISTICS
* ============================================================================

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

* --- 12a. Sample sizes ---
display as text _newline "--- Sample sizes by year ---"
tab year

* --- 12b. Demographics (unweighted) ---
display as text _newline "--- Age (working-age adults) ---"
summarize age if working_age, detail

display as text _newline "--- Gender ---"
tab female

display as text _newline "--- Race/ethnicity ---"
tab race_eth

display as text _newline "--- Education ---"
tab educ_cat

* --- 12c. Labor market ---
display as text _newline "--- Employment status (working-age adults) ---"
tab employed if working_age

* --- 12d. Income ---
display as text _newline "--- Total income (working-age adults with positive income) ---"
summarize totalinc if working_age & totalinc > 0, detail

* --- 12e. Health insurance ---
display as text _newline "--- Uninsured rate by year (working-age adults, unweighted) ---"
tab year uninsured if working_age, row nofreq

* --- 12f. Transfer programs ---
display as text _newline "--- Transfer program participation (all persons) ---"
summarize snap receives_ss receives_ssi receives_welfare receives_ui

* ============================================================================
* 13. EXAMPLE REGRESSIONS
* ============================================================================

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSIONS"
display as text "============================================"

* --- 13a. Unweighted OLS: log wage ~ demographics ---
display as text _newline "--- OLS: Log wage income (working-age adults, unweighted) ---"
gen lnwage = ln(wageinc) if wageinc > 0
regress lnwage female age i.race_eth i.educ_cat i.year if working_age

* --- 13b. Weighted regression ---
display as text _newline "--- Weighted OLS: Log wage income ---"
regress lnwage female age i.race_eth i.educ_cat i.year if working_age [pweight = asecwt]

* --- 13c. Uninsured probability (LPM) ---
display as text _newline "--- Weighted LPM: Uninsured probability ---"
regress uninsured female age i.race_eth i.educ_cat i.year if working_age [pweight = asecwt]

display as text _newline "============================================"
display as text "   DONE"
display as text "============================================"

********************************************************************************
* NOTES FOR USERS:
*
* 1. WEIGHTS: Use ASECWT for person-level estimates. For household-level
*    analyses, use HWTSUPP. IPUMS also provides replicate weights (REPWTP1-
*    REPWTP160) for variance estimation starting in 2005.
*
* 2. INCOME REFERENCE PERIOD: CPS ASEC income and insurance questions
*    typically refer to the PRIOR calendar year. Example: YEAR=2025 data
*    contains income for calendar year 2024. Some current-status variables
*    (EMPSTAT, LABFORCE) refer to the survey week.
*
* 3. HEALTH INSURANCE REDESIGN: The CPS ASEC redesigned health insurance
*    questions in 2014 and again in 2019. Cross-year comparisons of
*    insurance rates should account for these breaks. See IPUMS documentation.
*
* 4. IPUMS HARMONIZATION: IPUMS has already harmonized many variables
*    across years (RACE, EDUC, EMPSTAT, etc.). The IPUMS codebook and
*    comparability documentation should be your first reference.
*
* 5. POVERTY VARIABLES: OFFPOV and POVERTY use the official Census Bureau
*    poverty thresholds. The 138% FPL threshold is used for ACA Medicaid
*    expansion eligibility. The 400% FPL threshold is the ACA marketplace
*    subsidy cutoff.
*
* 6. SURVEY DESIGN: For correct standard errors with CPS data, you can use:
*      - Replicate weights: svyset [pw=asecwt], sdr(repwtp*) vce(sdr)
*      - Or approximate with clustering: [pw=asecwt], cluster(statefip)
*    See IPUMS documentation for details.
*
* 7. LINKING ACROSS YEARS: CPS households are in the sample for 4 months,
*    out for 8 months, then in for 4 more months. Use CPSIDP to link
*    individuals across the two March supplements they appear in.
*
* 8. IPUMS CITATION: When using this data, always cite:
*    Sarah Flood et al. IPUMS CPS: Version 13.0 [dataset].
*    Minneapolis, MN: IPUMS, 2026. https://doi.org/10.18128/D030.V13.0
********************************************************************************
