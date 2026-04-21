********************************************************************************
* 02_clean_demographics.do
*
* Purpose: Load the ACS working dataset and demonstrate cleaning of:
*          (1) Demographics: race/ethnicity, sex, age, marital status
*          (2) Education: years of education, degree indicators
*          (3) Employment and income
*          (4) Health insurance (if available; 2008+ only)
*          (5) Immigration and citizenship (if available)
*          (6) Optional descriptive statistics and simple weighted regressions
*
* Input:   output/acs_working.dta  (from 01_load_and_subset.do)
* Output:  Cleaned variables in memory; optional example output to console
*
* Usage:   Run from ipums_acs_1_year_sample/, ipums_acs_1_year_sample/code/,
*          or the repo root:
*            do code/02_clean_demographics.do
*          You can also set global acs_root first.
*
* Notes:   This is a STARTER script. It demonstrates how to clean key
*          variables. Users should extend this for their own analysis.
*          Health insurance and immigration are optional sections.
*          Core sections are skipped if their source variables are absent.
*
* Author:  Austin Denteh (adapted from Kuka et al. 2020 replication code)
* Date:    February 2026
********************************************************************************

clear all
set more off

* ============================================================================
* 1. DEFINE PATHS AND LOAD DATA
* ============================================================================
* Auto-detect the dataset root from the current working directory.
*
* Optional manual override if auto-detection fails:
* global acs_root "/path/to/ipums_acs_1_year_sample"

local cwd `"`c(pwd)'"'

if "$acs_root" != "" & fileexists("$acs_root/code/02_clean_demographics.do") {
    global acs_root "$acs_root"
}
else if fileexists("code/02_clean_demographics.do") & fileexists("README.md") {
    global acs_root "`cwd'"
}
else if fileexists("02_clean_demographics.do") & fileexists("../README.md") {
    global acs_root "`cwd'/.."
}
else if fileexists("ipums_acs_1_year_sample/code/02_clean_demographics.do") ///
    & fileexists("ipums_acs_1_year_sample/README.md") {
    global acs_root "`cwd'/ipums_acs_1_year_sample"
}
else {
    display as error "Could not locate the ipums_acs_1_year_sample/ directory."
    display as error "Run from the dataset folder, its code/ folder, the repo root,"
    display as error "or set global acs_root first."
    exit 198
}

cd "$acs_root"
display as text "Using ACS root: $acs_root"

use "output/acs_working.dta", clear
display as text "Loaded " _N " observations."

* --- Quick check: common starter variables ---
local core_vars "year age sex race hispan empstat incwage poverty"
local missing_core ""
foreach v of local core_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local missing_core "`missing_core' `v'"
    }
}
capture confirm variable educd
local has_educd = 0
if _rc == 0 local has_educd = 1
capture confirm variable educ
local has_educ = 0
if _rc == 0 local has_educ = 1
if `has_educd' == 0 & `has_educ' == 0 {
    local missing_core "`missing_core' educd/educ"
}
if "`missing_core'" != "" {
    display as error "WARNING: The following common starter variables are not in your extract:"
    display as error " `missing_core'"
    display as error "Affected sections will be skipped."
}

* ============================================================================
* 2. DEMOGRAPHICS: RACE AND ETHNICITY
* ============================================================================

local has_race_section 1
foreach v in race hispan {
    capture confirm variable `v'
    if _rc != 0 local has_race_section 0
}

if `has_race_section' {
    gen byte hisp = (hispan != 0) if hispan != .
    gen byte white = (race == 1 & hisp == 0) if race != . & hisp != .
    gen byte black = (race == 2 & hisp == 0) if race != . & hisp != .
    gen byte asian = (inlist(race, 4, 5, 6) & hisp == 0) if race != . & hisp != .
    gen byte other = (hisp == 0 & white == 0 & black == 0 & asian == 0) ///
        if hisp != . & white != . & black != . & asian != .

    gen byte race_eth = .
    replace race_eth = 1 if white == 1
    replace race_eth = 2 if black == 1
    replace race_eth = 3 if hisp == 1
    replace race_eth = 4 if asian == 1
    replace race_eth = 5 if other == 1
    label define race_eth_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" ///
        4 "Asian/PI NH" 5 "Other NH", replace
    label values race_eth race_eth_lbl

    display as text _newline "--- Race/ethnicity ---"
    tab race_eth
}
else {
    display as text _newline "[SKIP] Race/ethnicity: requires race and hispan."
}

* ============================================================================
* 3. DEMOGRAPHICS: SEX, AGE, MARITAL STATUS
* ============================================================================

local has_sex_age_section 1
foreach v in sex age {
    capture confirm variable `v'
    if _rc != 0 local has_sex_age_section 0
}

if `has_sex_age_section' {
    gen byte female = (sex == 2) if sex != .

    capture confirm variable marst
    if _rc == 0 {
        gen byte married = inlist(marst, 1, 2) if marst != .
    }

    gen byte age_18_24 = (age >= 18 & age <= 24) if age != .
    gen byte age_25_34 = (age >= 25 & age <= 34) if age != .
    gen byte age_35_44 = (age >= 35 & age <= 44) if age != .
    gen byte age_45_54 = (age >= 45 & age <= 54) if age != .
    gen byte age_55_64 = (age >= 55 & age <= 64) if age != .
    gen byte age_65plus = (age >= 65) if age != .

    display as text _newline "--- Age distribution ---"
    summarize age, detail

    display as text _newline "--- Sex ---"
    tab female
}
else {
    display as text _newline "[SKIP] Sex/age: requires sex and age."
}

* ============================================================================
* 4. EDUCATION
* ============================================================================
* Use the detailed EDUCD codes when available. Grouped lower-schooling
* categories are mapped to rounded midpoint years. If only EDUC is available,
* fall back to the coarser general version.

if `has_educd' {
    gen double yrsed = .
    replace yrsed = 0  if inlist(educd, 0, 2)
    replace yrsed = 2  if educd == 10
    replace yrsed = 0  if inlist(educd, 11, 12)
    replace yrsed = 3  if educd == 13
    replace yrsed = 1  if educd == 14
    replace yrsed = 2  if educd == 15
    replace yrsed = 3  if educd == 16
    replace yrsed = 4  if educd == 17
    replace yrsed = 7  if educd == 20
    replace yrsed = 6  if educd == 21
    replace yrsed = 5  if educd == 22
    replace yrsed = 6  if educd == 23
    replace yrsed = 8  if educd == 24
    replace yrsed = 7  if educd == 25
    replace yrsed = 8  if educd == 26
    replace yrsed = 9  if educd == 30
    replace yrsed = 10 if educd == 40
    replace yrsed = 11 if educd == 50
    replace yrsed = 12 if inlist(educd, 60, 61, 62, 63, 64)
    replace yrsed = 13 if inlist(educd, 65, 70, 71)
    replace yrsed = 14 if inlist(educd, 80, 81, 82, 83)
    replace yrsed = 15 if educd == 90
    replace yrsed = 16 if inlist(educd, 100, 101)
    replace yrsed = 17 if educd == 110
    replace yrsed = 18 if inlist(educd, 111, 114)
    replace yrsed = 19 if inlist(educd, 112, 115)
    replace yrsed = 20 if educd == 113
    replace yrsed = 21 if educd == 116

    gen byte hs = .
    replace hs = 1 if inlist(educd, 62, 63, 64, 65, 70, 71, 80, 81, 82, 83) ///
        | inlist(educd, 90, 100, 101) | inrange(educd, 110, 116)
    replace hs = . if inlist(educd, 1, 999)
    replace hs = 0 if educd != . & !inlist(educd, 1, 999) & hs == .

    gen byte some_college = .
    replace some_college = 1 if inlist(educd, 65, 70, 71, 80, 81, 82, 83, 90, 100, 101) ///
        | inrange(educd, 110, 116)
    replace some_college = . if inlist(educd, 1, 999)
    replace some_college = 0 if educd != . & !inlist(educd, 1, 999) & some_college == .

    gen byte college = .
    replace college = 1 if educd == 101 | inrange(educd, 110, 116)
    replace college = . if inlist(educd, 1, 999)
    replace college = 0 if educd != . & !inlist(educd, 1, 999) & college == .
}
else if `has_educ' {
    gen double yrsed = .
    replace yrsed = 0  if educ == 0
    replace yrsed = 2  if educ == 1
    replace yrsed = 7  if educ == 2
    replace yrsed = 9  if educ == 3
    replace yrsed = 10 if educ == 4
    replace yrsed = 11 if educ == 5
    replace yrsed = 12 if educ == 6
    replace yrsed = 13 if educ == 7
    replace yrsed = 14 if educ == 8
    replace yrsed = 15 if educ == 9
    replace yrsed = 16 if educ == 10
    replace yrsed = 18 if educ == 11

    gen byte hs = (educ >= 6) if educ != . & educ != 99
    gen byte some_college = (educ >= 7) if educ != . & educ != 99
    gen byte college = (educ >= 10) if educ != . & educ != 99

    display as text _newline "[INFO] educd not found. Education indicators use the coarser educ variable."
}
else {
    display as text _newline "[SKIP] Education: requires educd or educ."
}

capture confirm variable yrsed
if _rc == 0 {
    display as text _newline "--- Years of education ---"
    tab yrsed, missing

    display as text _newline "--- Education attainment ---"
    tab hs
    tab some_college
    tab college
}

* ============================================================================
* 5. EMPLOYMENT
* ============================================================================

capture confirm variable empstat
if _rc == 0 {
    gen byte employed = (empstat == 1) if empstat != . & empstat != 0
    gen byte unemployed = (empstat == 2) if empstat != . & empstat != 0
    gen byte in_lf = inlist(empstat, 1, 2) if empstat != . & empstat != 0

    display as text _newline "--- Employment status ---"
    capture confirm variable age
    if _rc == 0 {
        summarize employed unemployed in_lf if age >= 16
    }
    else {
        summarize employed unemployed in_lf
    }
}
else {
    display as text _newline "[SKIP] Employment: requires empstat."
}

* ============================================================================
* 6. INCOME AND POVERTY
* ============================================================================

capture confirm variable poverty
if _rc == 0 {
    gen byte inpov = (poverty <= 100 & poverty != 0) if poverty != . & poverty != 0
    gen double finc_to_pov = poverty / 100 if poverty != . & poverty != 0

    display as text _newline "--- Poverty status ---"
    tab inpov
}
else {
    display as text _newline "[SKIP] Poverty: requires poverty."
}

capture confirm variable incwage
if _rc == 0 {
    gen double wage = incwage if incwage < 999998

    display as text _newline "--- Wage income (conditional on positive) ---"
    summarize wage if wage > 0, detail
}
else {
    display as text _newline "[SKIP] Wage income: requires incwage."
}

* ============================================================================
* 7. HEALTH INSURANCE (if available)
* ============================================================================

capture confirm variable hcovany
if _rc == 0 {
    gen byte any_insurance = (hcovany == 2) if hcovany != .
    gen byte uninsured = (hcovany == 1) if hcovany != .

    capture confirm variable hcovpriv
    if _rc == 0 gen byte priv_ins = (hcovpriv == 2) if hcovpriv != .

    capture confirm variable hcovpub
    if _rc == 0 gen byte pub_ins = (hcovpub == 2) if hcovpub != .

    capture confirm variable hinscaid
    if _rc == 0 gen byte medicaid = (hinscaid == 2) if hinscaid != .

    capture confirm variable hinscare
    if _rc == 0 gen byte medicare = (hinscare == 2) if hinscare != .

    display as text _newline "--- Health insurance (2008+) ---"
    summarize any_insurance uninsured if year >= 2008
}
else {
    display as text _newline "[SKIP] Health insurance: hcovany not in extract."
}

* ============================================================================
* 8. IMMIGRATION AND CITIZENSHIP (if available)
* ============================================================================

capture confirm variable citizen
if _rc == 0 {
    gen byte noncitizen = (citizen == 3) if citizen != . & citizen != 0
    gen byte usborn = inlist(citizen, 4, 5) if citizen != . & citizen != 0
    gen byte naturalized = (citizen == 2) if citizen != . & citizen != 0

    display as text _newline "--- Citizenship ---"
    summarize usborn naturalized noncitizen
}
else {
    display as text _newline "[SKIP] Citizenship: citizen not in extract."
}

capture confirm variable bpl
if _rc == 0 {
    gen byte bpl_us = (bpl >= 1 & bpl <= 120) if bpl != .
    gen byte bpl_mexico = (bpl == 200) if bpl != .
    gen byte bpl_centam = (bpl >= 210 & bpl <= 300) if bpl != .
    gen byte bpl_asia = (bpl >= 500 & bpl < 600) if bpl != .
    gen byte bpl_europe = (bpl >= 400 & bpl < 500) if bpl != .
}

* ============================================================================
* 9. DESCRIPTIVE STATISTICS
* ============================================================================
* Optional teaching examples are kept here but not run by default.
* Uncomment this block if you want descriptive tables and example regressions.
/*

display as text _newline "============================================"
display as text "   DESCRIPTIVE STATISTICS"
display as text "============================================"

local demo_vars ""
foreach v in female age hisp white black asian {
    capture confirm variable `v'
    if _rc == 0 local demo_vars "`demo_vars' `v'"
}
if "`demo_vars'" != "" {
    display as text _newline "--- Key demographic variables ---"
    summarize `demo_vars'
}
else {
    display as text _newline "[SKIP] Key demographic variables: required variables not available."
}

local educ_vars ""
foreach v in yrsed hs some_college college {
    capture confirm variable `v'
    if _rc == 0 local educ_vars "`educ_vars' `v'"
}
if "`educ_vars'" != "" {
    display as text _newline "--- Education variables ---"
    summarize `educ_vars'
}
else {
    display as text _newline "[SKIP] Education variables: required variables not available."
}

local econ_vars ""
foreach v in employed in_lf wage inpov finc_to_pov {
    capture confirm variable `v'
    if _rc == 0 local econ_vars "`econ_vars' `v'"
}
if "`econ_vars'" != "" {
    display as text _newline "--- Employment and income ---"
    summarize `econ_vars'
}
else {
    display as text _newline "[SKIP] Employment and income: required variables not available."
}

capture confirm variable uninsured
if _rc == 0 {
    display as text _newline "--- Uninsured rate by year (2008+) ---"
    capture confirm variable perwt
    if _rc == 0 {
        capture noisily mean uninsured [pw=perwt] if year >= 2008, over(year)
    }
    else {
        capture noisily mean uninsured if year >= 2008, over(year)
    }

    capture confirm variable race_eth
    if _rc == 0 {
        display as text _newline "--- Uninsured rate by race/ethnicity (2008+) ---"
        capture confirm variable perwt
        if _rc == 0 {
            capture noisily mean uninsured [pw=perwt] if year >= 2008, over(race_eth)
        }
        else {
            capture noisily mean uninsured if year >= 2008, over(race_eth)
        }
    }
}

* ============================================================================
* 10. EXAMPLE REGRESSION
* ============================================================================
* Simple weighted regressions for starter use.

display as text _newline "============================================"
display as text "   EXAMPLE REGRESSION"
display as text "============================================"

local can_uninsured_reg 1
foreach v in uninsured female age race_eth hs college year perwt {
    capture confirm variable `v'
    if _rc != 0 local can_uninsured_reg 0
}

if `can_uninsured_reg' {
    display as text _newline "--- Weighted OLS: Uninsured on demographics (2008+, ages 18-64) ---"
    capture noisily reg uninsured female age i.race_eth hs college ///
        i.year [pw=perwt] if year >= 2008 & age >= 18 & age <= 64, robust
}
else {
    local can_wage_reg 1
    foreach v in wage female age race_eth hs college year perwt {
        capture confirm variable `v'
        if _rc != 0 local can_wage_reg 0
    }

    if `can_wage_reg' {
        display as text _newline "--- Weighted OLS: Wage income on demographics ---"
        capture noisily reg wage female age i.race_eth hs college ///
            i.year [pw=perwt] if wage > 0, robust
    }
	    else {
	        display as text _newline "[SKIP] Weighted regression: required variables not available."
	    }
	}
*/
	
	display as text _newline "============================================"
	display as text "   CLEANING COMPLETE"
display as text "============================================"
display as text "Variables created when source data are available: race_eth, female,"
display as text "  yrsed, hs, college, employed, in_lf, wage, inpov, and more."
display as text _newline "This is a starter script -- extend for your own analysis."

********************************************************************************
* NOTES:
*
* 1. CUSTOM EXTRACTS:
*    Core sections are skipped if their source variables are absent.
*    Optional sections (health insurance, immigration) are also skipped when
*    those source variables are not in the extract.
*
* 2. SAMPLE RESTRICTIONS:
*    This script does not restrict the sample further. For specific analyses:
*    - Working-age adults: keep if age >= 18 & age <= 64
*    - Children: keep if age < 18
*    - Non-institutionalized: keep if gq != 3 & gq != 4
*
* 3. SURVEY WEIGHTS:
*    The starter regression examples use person weights directly:
*      reg ... [pw=perwt], robust
*    For design-based standard errors, use survey or replicate-weight methods
*    when your application needs them.
*
* 4. EDUCATION CODING:
*    When educd is available, grouped lower-schooling categories are mapped to
*    rounded midpoint years. Degree indicators rely on educd directly so that
*    bachelor's and postgraduate degrees remain distinct. If educd is absent,
*    the script falls back to the coarser educ variable.
*
* 5. RACE LABELS:
*    The starter's asian indicator uses IPUMS race codes 4, 5, and 6, where
*    code 6 includes other Asian or Pacific Islander.
*
* 6. INSURANCE VARIABLES:
*    Health insurance variables (hcovany, hcovpriv, hcovpub, etc.) are only
*    available from 2008 onwards.
*
* 7. IMMIGRATION:
*    - citizen == 3 identifies non-citizens
*    - bpl gives detailed birthplace codes
********************************************************************************
