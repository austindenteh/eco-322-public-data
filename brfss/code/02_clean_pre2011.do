********************************************************************************
* 02_clean_pre2011.do
*
* Purpose: Clean and harmonize BRFSS pre-2011 landline-era variables for 2000-2010.
*          Consumes output from either pre-2011 Stata loader and creates
*          stable starter variables for public-use analysis.
*
* Input:   output/brfss_pre2011_appended.dta
* Output:  output/brfss_pre2011_clean.dta
*
* Usage:   Run from brfss/, brfss/code/, the repo root, or set global
*          brfss_root explicitly before running.
********************************************************************************

clear all
set more off
set varabbrev off

* ============================================================================
* USER SETTINGS
* ============================================================================
* Optional manual root override:
* global brfss_root "/path/to/econ-data-starters/brfss"

* Optional output directory override for smoke tests or scratch builds:
* global brfss_pre2011_output_dir "/private/tmp/brfss_pre2011_output"

* ============================================================================
* 1. DEFINE PATHS
* ============================================================================

local cwd `"`c(pwd)'"'
if "$brfss_root" != "" & fileexists("$brfss_root/code/02_clean_pre2011.do") {
    global brfss_root "$brfss_root"
}
else if fileexists("code/02_clean_pre2011.do") & fileexists("README.md") {
    global brfss_root "`cwd'"
}
else if fileexists("02_clean_pre2011.do") & fileexists("../README.md") {
    global brfss_root "`cwd'/.."
}
else if fileexists("brfss/code/02_clean_pre2011.do") & fileexists("brfss/README.md") {
    global brfss_root "`cwd'/brfss"
}
else {
    display as error "Could not locate the brfss/ directory."
    display as error "Run from brfss/, brfss/code/, the repo root, or set global brfss_root first."
    exit 198
}

cd "$brfss_root"
display as text "Using BRFSS root: $brfss_root"

if "$brfss_pre2011_output_dir" != "" {
    local out_dir "$brfss_pre2011_output_dir"
}
else {
    local out_dir "output"
}

local in_dta  "`out_dir'/brfss_pre2011_appended.dta"
local out_dta "`out_dir'/brfss_pre2011_clean.dta"

capture confirm file "`in_dta'"
if _rc != 0 {
    display as error "Input file not found: `in_dta'"
    display as error "Run 01_load_pre2011.do or 01_load_pre2011_optional_low_memory.do first."
    exit 601
}

* ============================================================================
* 2. LOAD APPENDED DATA
* ============================================================================

use "`in_dta'", clear
quietly rename *, lower
display as text "Loaded: " _N " observations, " c(k) " variables"

levelsof surveyyear, local(years_present)
foreach y of local years_present {
    if !inrange(`y', 2000, 2010) {
        display as error "This cleaner supports 2000-2010 only. Invalid year in input: `y'"
        exit 198
    }
}

* Preserve raw AGE before creating clean age.
capture confirm variable age
if _rc == 0 {
    rename age age_raw
}
else {
    gen double age_raw = .
}

* DIABETES is the raw fixed-core name in 2000-2003. Preserve it before
* creating the harmonized diabetes indicator below.
capture confirm variable diabetes
if _rc == 0 {
    rename diabetes diabetes_pre2004
}

* HISPANIC is also a raw questionnaire field in some full-width early files.
* Preserve it before creating the harmonized regression indicator below.
capture confirm variable hispanic
if _rc == 0 {
    rename hispanic hispanic_raw
}

local support_vars "_state _psu _ststr _finalwt _poststr"
local support_vars "`support_vars' ctycode _impcty cpcounty"
local support_vars "`support_vars' imonth iyear age_raw _impage _ageg5yr"
local support_vars "`support_vars' sex _racegr _racegr2 _raceg2 _raceg3_ race2 hispanc2"
local support_vars "`support_vars' educa marital income2 employ"
local support_vars "`support_vars' genhlth menthlth physhlth"
local support_vars "`support_vars' hlthplan persdoc persdoc2 medcost checkup checkup1"
local support_vars "`support_vars' diabetes_pre2004 diabete2 asthma asthma2 asthnow"
local support_vars "`support_vars' cvdinfar cvdcorhd cvdstrok"
local support_vars "`support_vars' cvdinfr2 cvdinfr3 cvdinfr4"
local support_vars "`support_vars' cvdcrhd2 cvdcrhd3 cvdcrhd4"
local support_vars "`support_vars' cvdstrk2 cvdstrk3"
local support_vars "`support_vars' _bmi2 _bmi2cat _rfbmi2 _bmi3 _bmi3cat _rfbmi3"
local support_vars "`support_vars' _bmi4 _bmi4cat _rfbmi4 _smoker2 _smoker3"

local added_placeholder_vars ""
foreach v of local support_vars {
    capture confirm variable `v'
    if _rc != 0 {
        gen double `v' = .
        local added_placeholder_vars "`added_placeholder_vars' `v'"
    }
}

foreach v of local support_vars {
    capture confirm variable `v'
    if _rc == 0 {
        capture confirm numeric variable `v'
        if _rc != 0 {
            quietly destring `v', replace force
        }
    }
}

* ============================================================================
* 3. CLEAN AND HARMONIZE
* ============================================================================

display as text "Creating harmonized pre-2011 variables..."

* Survey design and geography.
gen double statefips = _state
label var statefips "State FIPS code"

gen double psu = _psu
label var psu "Primary sampling unit"

gen double strata = _ststr
label var strata "Stratum"

gen double analysis_weight = _finalwt
label var analysis_weight "pre-2011 BRFSS final weight (_FINALWT)"

gen double final_weight = _finalwt
label var final_weight "pre-2011 BRFSS final weight (_FINALWT)"

gen double poststrat_weight = _poststr
label var poststrat_weight "pre-2011 BRFSS post-stratification weight component"

gen str40 design_era = "pre2011_landline_poststratification"
label var design_era "BRFSS design era"

gen double county_code_raw = .
gen str12 county_code_source = ""
foreach v in ctycode _impcty cpcounty {
    replace county_code_raw = `v' if missing(county_code_raw) & !missing(`v') & inrange(`v', 1, 840) & !inlist(`v', 777, 888, 999)
    replace county_code_source = "`v'" if county_code_source == "" & !missing(`v') & inrange(`v', 1, 840) & !inlist(`v', 777, 888, 999)
}
label var county_code_raw "Raw BRFSS county code from first available valid source"
label var county_code_source "Source variable used for county_code_raw"

gen double countyfips = statefips * 1000 + county_code_raw if !missing(statefips, county_code_raw) & inrange(county_code_raw, 1, 840)
label var countyfips "County FIPS from state FIPS and BRFSS county code"

gen double month = imonth if inrange(imonth, 1, 12)
label var month "Interview month"

gen double year = iyear
label var year "Interview year"

* Demographics.
gen double age = .
replace age = _impage if inrange(_impage, 18, 99)
replace age = age_raw if missing(age) & inrange(age_raw, 18, 99)
label var age "Age in years"

gen double age_cat = _ageg5yr if inrange(_ageg5yr, 1, 14)
label var age_cat "Age category, CDC calculated"

gen double female = .
replace female = 1 if sex == 2
replace female = 0 if sex == 1
label var female "Female"

gen double race_eth = .
replace race_eth = 1 if _racegr == 1
replace race_eth = 2 if _racegr == 2
replace race_eth = 3 if _racegr == 3
replace race_eth = 4 if _racegr == 4
replace race_eth = 1 if _racegr2 == 1
replace race_eth = 2 if _racegr2 == 2
replace race_eth = 3 if _racegr2 == 5
replace race_eth = 4 if inlist(_racegr2, 3, 4)
replace race_eth = 1 if missing(race_eth) & _raceg2 == 1
replace race_eth = 2 if missing(race_eth) & _raceg2 == 2
replace race_eth = 4 if missing(race_eth) & inlist(_raceg2, 3, 4)
replace race_eth = 1 if missing(race_eth) & _raceg3_ == 1
replace race_eth = 2 if missing(race_eth) & _raceg3_ == 2
replace race_eth = 4 if missing(race_eth) & inlist(_raceg3_, 3, 4, 5)
replace race_eth = 3 if missing(race_eth) & hispanc2 == 1
label var race_eth "Race/ethnicity category"
label define race_eth_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" 4 "Other/Multi NH", replace
label values race_eth race_eth_lbl

gen white = (race_eth == 1) if !missing(race_eth)
gen black = (race_eth == 2) if !missing(race_eth)
gen hispanic = (race_eth == 3) if !missing(race_eth)
gen raceother = (race_eth == 4) if !missing(race_eth)

gen double educ_cat = .
replace educ_cat = 1 if inrange(educa, 1, 3)
replace educ_cat = 2 if educa == 4
replace educ_cat = 3 if educa == 5
replace educ_cat = 4 if educa == 6
label var educ_cat "Education category"
label define educ_cat_lbl 1 "Less than high school" 2 "High school/GED" 3 "Some college" 4 "College graduate", replace
label values educ_cat educ_cat_lbl

gen hsdropout = (educ_cat == 1) if !missing(educ_cat)
gen hsgraduate = (educ_cat == 2) if !missing(educ_cat)
gen somecollege = (educ_cat == 3) if !missing(educ_cat)
gen college = (educ_cat == 4) if !missing(educ_cat)

gen double marital_cat = .
replace marital_cat = 1 if inlist(marital, 1, 6)
replace marital_cat = 2 if inlist(marital, 2, 4)
replace marital_cat = 3 if marital == 3
replace marital_cat = 4 if marital == 5
label var marital_cat "Marital status category"
label define marital_cat_lbl 1 "Married/partnered" 2 "Divorced/separated" 3 "Widowed" 4 "Never married", replace
label values marital_cat marital_cat_lbl

gen married = (marital_cat == 1) if !missing(marital_cat)
gen divorced = (marital_cat == 2) if !missing(marital_cat)
gen widowed = (marital_cat == 3) if !missing(marital_cat)
gen nevermarried = (marital_cat == 4) if !missing(marital_cat)

gen double income_cat = income2 if inrange(income2, 1, 8)
label var income_cat "Income category (INCOME2)"

gen double working = .
replace working = 1 if inlist(employ, 1, 2)
replace working = 0 if inrange(employ, 3, 8)
label var working "Currently employed or self-employed"

gen double student = .
replace student = 1 if employ == 6
replace student = 0 if inrange(employ, 1, 8) & employ != 6
label var student "Student"

* Health and access.
gen double genhealth = genhlth if inrange(genhlth, 1, 5)
label var genhealth "General health"

gen fair_or_poor = (genhealth >= 4) if !missing(genhealth)
label var fair_or_poor "Fair or poor health"

gen double mental_days = .
replace mental_days = menthlth if inrange(menthlth, 1, 30)
replace mental_days = 0 if menthlth == 88
label var mental_days "Poor mental health days in past 30 days"

gen double physical_days = .
replace physical_days = physhlth if inrange(physhlth, 1, 30)
replace physical_days = 0 if physhlth == 88
label var physical_days "Poor physical health days in past 30 days"

gen double insured = .
replace insured = 1 if hlthplan == 1
replace insured = 0 if hlthplan == 2
label var insured "Has any health care coverage"

gen double personal_doctor_raw = .
foreach v in persdoc2 persdoc {
    replace personal_doctor_raw = `v' if missing(personal_doctor_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double has_personal_doctor = .
replace has_personal_doctor = 1 if inlist(personal_doctor_raw, 1, 2)
replace has_personal_doctor = 0 if personal_doctor_raw == 3
label var has_personal_doctor "Has at least one personal doctor"

gen double cost_barrier = .
replace cost_barrier = 1 if medcost == 1
replace cost_barrier = 0 if medcost == 2
label var cost_barrier "Could not see doctor due to cost"

gen double checkup_raw = .
foreach v in checkup checkup1 {
    replace checkup_raw = `v' if missing(checkup_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double checkup_within_year = .
replace checkup_within_year = 1 if checkup_raw == 1
replace checkup_within_year = 0 if inlist(checkup_raw, 2, 3, 4, 8)
label var checkup_within_year "Routine checkup within past year"

gen double bmi_raw = .
gen str8 bmi_source = ""
foreach v in _bmi4 _bmi3 _bmi2 {
    replace bmi_raw = `v' if missing(bmi_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
    replace bmi_source = "`v'" if bmi_source == "" & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double bmi = .
replace bmi = _bmi4 / 100 if inrange(_bmi4, 1, 9998)
replace bmi = _bmi3 / 100 if missing(bmi) & inrange(_bmi3, 1, 9998)
replace bmi = _bmi2 / 100 if missing(bmi) & surveyyear == 2002 & inrange(_bmi2, 1, 9998)
replace bmi = _bmi2 / 10000 if missing(bmi) & surveyyear == 2001 & inrange(_bmi2, 1, 999998)
replace bmi = _bmi2 / 10 if missing(bmi) & surveyyear == 2000 & inrange(_bmi2, 1, 998)
label var bmi "Body mass index"

gen double bmi_cat_raw = .
foreach v in _bmi4cat _bmi3cat _bmi2cat {
    replace bmi_cat_raw = `v' if missing(bmi_cat_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double bmi_cat = bmi_cat_raw if inrange(bmi_cat_raw, 1, 3)
label var bmi_cat "BMI category, CDC calculated"
label define bmi_cat_lbl 1 "Neither overweight nor obese" 2 "Overweight" 3 "Obese", replace
label values bmi_cat bmi_cat_lbl

gen double smoker = .
replace smoker = _smoker3 if inrange(_smoker3, 1, 4)
replace smoker = _smoker2 if missing(smoker) & inrange(_smoker2, 1, 4)
label var smoker "Smoking status, CDC calculated"

gen double current_smoker = inlist(smoker, 1, 2) if !missing(smoker)
label var current_smoker "Current smoker"

gen double diabetes_raw = .
foreach v in diabete2 diabetes_pre2004 {
    replace diabetes_raw = `v' if missing(diabetes_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double diabetes = .
replace diabetes = 1 if diabete2 == 1
replace diabetes = 0 if inlist(diabete2, 2, 3, 4)
replace diabetes = 1 if missing(diabetes) & missing(diabete2) & diabetes_pre2004 == 1
replace diabetes = 0 if missing(diabetes) & missing(diabete2) & inlist(diabetes_pre2004, 2, 3)
label var diabetes "Diabetes, excluding pregnancy-only and borderline reports"

gen double asthma_ever_raw = .
foreach v in asthma2 asthma {
    replace asthma_ever_raw = `v' if missing(asthma_ever_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double asthma_ever = .
replace asthma_ever = 1 if asthma_ever_raw == 1
replace asthma_ever = 0 if asthma_ever_raw == 2
label var asthma_ever "Ever told have asthma"

gen double asthma_current = .
replace asthma_current = 1 if asthnow == 1
replace asthma_current = 0 if asthnow == 2
label var asthma_current "Currently has asthma"

gen double heartattack_raw = .
foreach v in cvdinfr4 cvdinfr3 cvdinfr2 cvdinfar {
    replace heartattack_raw = `v' if missing(heartattack_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double heartattack = .
replace heartattack = 1 if heartattack_raw == 1
replace heartattack = 0 if heartattack_raw == 2
label var heartattack "Ever told had heart attack"

gen double heartdisease_raw = .
foreach v in cvdcrhd4 cvdcrhd3 cvdcrhd2 cvdcorhd {
    replace heartdisease_raw = `v' if missing(heartdisease_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double heartdisease = .
replace heartdisease = 1 if heartdisease_raw == 1
replace heartdisease = 0 if heartdisease_raw == 2
label var heartdisease "Ever told had coronary heart disease"

gen double stroke_raw = .
foreach v in cvdstrk3 cvdstrk2 cvdstrok {
    replace stroke_raw = `v' if missing(stroke_raw) & !missing(`v') & !inlist(`v', 777, 888, 999)
}
gen double stroke = .
replace stroke = 1 if stroke_raw == 1
replace stroke = 0 if stroke_raw == 2
label var stroke "Ever told had stroke"

if trim("`added_placeholder_vars'") != "" {
    drop `added_placeholder_vars'
}

sort surveyyear statefips countyfips
compress

* ============================================================================
* 4. SAVE AND VALIDATE
* ============================================================================

save "`out_dta'", replace
display as text _newline "Saved: `out_dta'"
display as text "Total observations: " _N
display as text "Total variables: " c(k)

display as text _newline "============================================"
display as text "   VALIDATION CHECKS"
display as text "============================================"

local required_clean_vars "surveyyear statefips analysis_weight psu strata"
local required_clean_vars "`required_clean_vars' county_code_raw countyfips age female race_eth educ_cat income_cat"
local required_clean_vars "`required_clean_vars' insured genhealth bmi current_smoker diabetes"

local missing_clean ""
foreach v of local required_clean_vars {
    capture confirm variable `v'
    if _rc != 0 {
        local missing_clean "`missing_clean' `v'"
    }
}
if trim("`missing_clean'") == "" {
    display as text "[PASS] Required clean variables present: `required_clean_vars'"
}
else {
    display as error "[FAIL] Missing clean variable(s):`missing_clean'"
    exit 459
}

local range_vars surveyyear statefips county_code_raw month age age_cat race_eth educ_cat marital_cat income_cat genhealth mental_days physical_days bmi bmi_cat smoker
local range_min  2000       1         1               1     18  1       1        1        1           1          1         0           0             0   1       1
local range_max  2010       99        840             12    99  14      4        4        4           8          5         30          30            100 3       4
local n_range : word count `range_vars'
forvalues i = 1/`n_range' {
    local v  : word `i' of `range_vars'
    local lo : word `i' of `range_min'
    local hi : word `i' of `range_max'
    quietly count if !missing(`v') & (`v' < `lo' | `v' > `hi')
    if r(N) > 0 {
        display as error "[FAIL] `v' has " r(N) " value(s) outside [`lo', `hi']."
        exit 459
    }
    display as text "[PASS] `v' values are within [`lo', `hi'] when non-missing."
}

local binary_vars white black hispanic raceother hsdropout hsgraduate somecollege college
local binary_vars "`binary_vars' married divorced widowed nevermarried working student fair_or_poor"
local binary_vars "`binary_vars' insured has_personal_doctor cost_barrier checkup_within_year"
local binary_vars "`binary_vars' current_smoker diabetes asthma_ever asthma_current heartattack heartdisease stroke"
foreach v of local binary_vars {
    quietly count if !missing(`v') & !inlist(`v', 0, 1)
    if r(N) > 0 {
        display as error "[FAIL] `v' has " r(N) " non-binary value(s)."
        exit 459
    }
    display as text "[PASS] `v' uses only 0/1 when non-missing."
}

quietly count if !(statefips == _state | (missing(statefips) & missing(_state)))
if r(N) > 0 {
    display as error "[FAIL] statefips does not match _STATE in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] statefips matches _STATE."

quietly count if !(psu == _psu | (missing(psu) & missing(_psu)))
if r(N) > 0 {
    display as error "[FAIL] psu does not match _PSU in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] psu matches _PSU."

quietly count if !(strata == _ststr | (missing(strata) & missing(_ststr)))
if r(N) > 0 {
    display as error "[FAIL] strata does not match _STSTR in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] strata matches _STSTR."

quietly count if !(analysis_weight == _finalwt | (missing(analysis_weight) & missing(_finalwt)))
if r(N) > 0 {
    display as error "[FAIL] analysis_weight does not match _FINALWT in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] analysis_weight matches _FINALWT."

tempvar expected_county_raw expected_county_source expected_countyfips
gen double `expected_county_raw' = .
gen str12 `expected_county_source' = ""
foreach v in ctycode _impcty cpcounty {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_county_raw' = `v' if missing(`expected_county_raw') & !missing(`v') & inrange(`v', 1, 840) & !inlist(`v', 777, 888, 999)
        replace `expected_county_source' = "`v'" if `expected_county_source' == "" & !missing(`v') & inrange(`v', 1, 840) & !inlist(`v', 777, 888, 999)
    }
}
gen double `expected_countyfips' = statefips * 1000 + `expected_county_raw' if !missing(statefips, `expected_county_raw') & inrange(`expected_county_raw', 1, 840)

quietly count if !(county_code_raw == `expected_county_raw' | (missing(county_code_raw) & missing(`expected_county_raw')))
if r(N) > 0 {
    display as error "[FAIL] county_code_raw does not match the first-valid county rule in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] county_code_raw matches CTYCODE/_IMPCTY/CPCOUNTY first-valid rule."

quietly count if !(county_code_source == `expected_county_source' | (missing(county_code_source) & missing(`expected_county_source')))
if r(N) > 0 {
    display as error "[FAIL] county_code_source does not identify the first valid county source in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] county_code_source identifies the first valid county source."

quietly count if !(countyfips == `expected_countyfips' | (missing(countyfips) & missing(`expected_countyfips')))
if r(N) > 0 {
    display as error "[FAIL] countyfips does not equal statefips * 1000 + county code in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] countyfips equals statefips * 1000 + county code."

tempvar expected_age
gen double `expected_age' = .
capture confirm variable _impage
if _rc == 0 {
    replace `expected_age' = _impage if inrange(_impage, 18, 99)
}
replace `expected_age' = age_raw if missing(`expected_age') & inrange(age_raw, 18, 99)
quietly count if !(age == `expected_age' | (missing(age) & missing(`expected_age')))
if r(N) > 0 {
    display as error "[FAIL] age does not follow _IMPAGE then AGE fallback in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] age follows _IMPAGE then AGE fallback."

tempvar expected_female expected_race expected_genhealth expected_mental expected_physical expected_insured expected_doctor_raw expected_doctor expected_cost
gen double `expected_female' = .
replace `expected_female' = 1 if sex == 2
replace `expected_female' = 0 if sex == 1
quietly count if !(female == `expected_female' | (missing(female) & missing(`expected_female')))
if r(N) > 0 {
    display as error "[FAIL] female does not follow SEX in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] female follows SEX."

gen double `expected_race' = .
capture replace `expected_race' = 1 if _racegr == 1
capture replace `expected_race' = 2 if _racegr == 2
capture replace `expected_race' = 3 if _racegr == 3
capture replace `expected_race' = 4 if _racegr == 4
capture replace `expected_race' = 1 if missing(`expected_race') & _racegr2 == 1
capture replace `expected_race' = 2 if missing(`expected_race') & _racegr2 == 2
capture replace `expected_race' = 3 if missing(`expected_race') & _racegr2 == 5
capture replace `expected_race' = 4 if missing(`expected_race') & inlist(_racegr2, 3, 4)
capture replace `expected_race' = 1 if missing(`expected_race') & _raceg2 == 1
capture replace `expected_race' = 2 if missing(`expected_race') & _raceg2 == 2
capture replace `expected_race' = 4 if missing(`expected_race') & inlist(_raceg2, 3, 4)
capture replace `expected_race' = 1 if missing(`expected_race') & _raceg3_ == 1
capture replace `expected_race' = 2 if missing(`expected_race') & _raceg3_ == 2
capture replace `expected_race' = 4 if missing(`expected_race') & inlist(_raceg3_, 3, 4, 5)
capture replace `expected_race' = 3 if missing(`expected_race') & hispanc2 == 1
quietly count if !(race_eth == `expected_race' | (missing(race_eth) & missing(`expected_race')))
if r(N) > 0 {
    display as error "[FAIL] race_eth does not follow documented race aliases in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] race_eth follows _RACEGR/_RACEGR2 and documented fallbacks."

gen double `expected_genhealth' = genhlth if inrange(genhlth, 1, 5)
quietly count if !(genhealth == `expected_genhealth' | (missing(genhealth) & missing(`expected_genhealth')))
if r(N) > 0 {
    display as error "[FAIL] genhealth does not follow GENHLTH 1-5 in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] genhealth follows GENHLTH 1-5."

gen double `expected_mental' = .
replace `expected_mental' = menthlth if inrange(menthlth, 1, 30)
replace `expected_mental' = 0 if menthlth == 88
quietly count if !(mental_days == `expected_mental' | (missing(mental_days) & missing(`expected_mental')))
if r(N) > 0 {
    display as error "[FAIL] mental_days does not follow MENTHLTH coding in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] mental_days follows MENTHLTH coding."

gen double `expected_physical' = .
replace `expected_physical' = physhlth if inrange(physhlth, 1, 30)
replace `expected_physical' = 0 if physhlth == 88
quietly count if !(physical_days == `expected_physical' | (missing(physical_days) & missing(`expected_physical')))
if r(N) > 0 {
    display as error "[FAIL] physical_days does not follow PHYSHLTH coding in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] physical_days follows PHYSHLTH coding."

gen double `expected_insured' = .
replace `expected_insured' = 1 if hlthplan == 1
replace `expected_insured' = 0 if hlthplan == 2
quietly count if !(insured == `expected_insured' | (missing(insured) & missing(`expected_insured')))
if r(N) > 0 {
    display as error "[FAIL] insured does not follow HLTHPLAN in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] insured follows HLTHPLAN."

gen double `expected_doctor_raw' = .
foreach v in persdoc2 persdoc {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_doctor_raw' = `v' if missing(`expected_doctor_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
quietly count if !(personal_doctor_raw == `expected_doctor_raw' | (missing(personal_doctor_raw) & missing(`expected_doctor_raw')))
if r(N) > 0 {
    display as error "[FAIL] personal_doctor_raw does not follow PERSDOC2/PERSDOC in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] personal_doctor_raw follows PERSDOC2 then PERSDOC."

gen double `expected_doctor' = .
replace `expected_doctor' = 1 if inlist(`expected_doctor_raw', 1, 2)
replace `expected_doctor' = 0 if `expected_doctor_raw' == 3
quietly count if !(has_personal_doctor == `expected_doctor' | (missing(has_personal_doctor) & missing(`expected_doctor')))
if r(N) > 0 {
    display as error "[FAIL] has_personal_doctor does not follow PERSDOC2 in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] has_personal_doctor follows PERSDOC2/PERSDOC."

gen double `expected_cost' = .
replace `expected_cost' = 1 if medcost == 1
replace `expected_cost' = 0 if medcost == 2
quietly count if !(cost_barrier == `expected_cost' | (missing(cost_barrier) & missing(`expected_cost')))
if r(N) > 0 {
    display as error "[FAIL] cost_barrier does not follow MEDCOST in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] cost_barrier follows MEDCOST."

tempvar expected_checkup_raw expected_checkup expected_bmi_raw expected_bmi_source expected_bmi_cat_raw expected_bmi_cat expected_bmi expected_smoker expected_current_smoker expected_diabetes_raw expected_diabetes expected_asthma_raw expected_asthma
gen double `expected_checkup_raw' = .
foreach v in checkup checkup1 {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_checkup_raw' = `v' if missing(`expected_checkup_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
gen double `expected_checkup' = .
replace `expected_checkup' = 1 if `expected_checkup_raw' == 1
replace `expected_checkup' = 0 if inlist(`expected_checkup_raw', 2, 3, 4, 8)
quietly count if !(checkup_within_year == `expected_checkup' | (missing(checkup_within_year) & missing(`expected_checkup')))
if r(N) > 0 {
    display as error "[FAIL] checkup_within_year does not follow CHECKUP/CHECKUP1 in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] checkup_within_year follows CHECKUP/CHECKUP1."

gen double `expected_bmi_raw' = .
gen str8 `expected_bmi_source' = ""
foreach v in _bmi4 _bmi3 _bmi2 {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_bmi_raw' = `v' if missing(`expected_bmi_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
        replace `expected_bmi_source' = "`v'" if `expected_bmi_source' == "" & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
quietly count if !(bmi_raw == `expected_bmi_raw' | (missing(bmi_raw) & missing(`expected_bmi_raw')))
if r(N) > 0 {
    display as error "[FAIL] bmi_raw does not follow _BMI4/_BMI3/_BMI2 in " r(N) " row(s)."
    exit 459
}
quietly count if !(bmi_source == `expected_bmi_source' | (missing(bmi_source) & missing(`expected_bmi_source')))
if r(N) > 0 {
    display as error "[FAIL] bmi_source does not identify the first available BMI source in " r(N) " row(s)."
    exit 459
}

gen double `expected_bmi' = .
capture replace `expected_bmi' = _bmi4 / 100 if inrange(_bmi4, 1, 9998)
capture replace `expected_bmi' = _bmi3 / 100 if missing(`expected_bmi') & inrange(_bmi3, 1, 9998)
capture replace `expected_bmi' = _bmi2 / 100 if missing(`expected_bmi') & surveyyear == 2002 & inrange(_bmi2, 1, 9998)
capture replace `expected_bmi' = _bmi2 / 10000 if missing(`expected_bmi') & surveyyear == 2001 & inrange(_bmi2, 1, 999998)
capture replace `expected_bmi' = _bmi2 / 10 if missing(`expected_bmi') & surveyyear == 2000 & inrange(_bmi2, 1, 998)
quietly count if !(abs(bmi - `expected_bmi') <= 1e-8 | (missing(bmi) & missing(`expected_bmi')))
if r(N) > 0 {
    display as error "[FAIL] bmi does not apply the documented year-specific implied decimals in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] bmi applies the documented year-specific implied decimals."

gen double `expected_bmi_cat_raw' = .
foreach v in _bmi4cat _bmi3cat _bmi2cat {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_bmi_cat_raw' = `v' if missing(`expected_bmi_cat_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
gen double `expected_bmi_cat' = `expected_bmi_cat_raw' if inrange(`expected_bmi_cat_raw', 1, 3)
quietly count if !(bmi_cat == `expected_bmi_cat' | (missing(bmi_cat) & missing(`expected_bmi_cat')))
if r(N) > 0 {
    display as error "[FAIL] bmi_cat does not follow _BMI4CAT/_BMI3CAT/_BMI2CAT in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] bmi_cat follows the three-level CDC BMI category aliases."

gen double `expected_smoker' = .
capture confirm variable _smoker3
if _rc == 0 {
    replace `expected_smoker' = _smoker3 if inrange(_smoker3, 1, 4)
}
capture confirm variable _smoker2
if _rc == 0 {
    replace `expected_smoker' = _smoker2 if missing(`expected_smoker') & inrange(_smoker2, 1, 4)
}
quietly count if !(smoker == `expected_smoker' | (missing(smoker) & missing(`expected_smoker')))
if r(N) > 0 {
    display as error "[FAIL] smoker does not follow _SMOKER3 then _SMOKER2 in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] smoker follows _SMOKER3 then _SMOKER2."

gen double `expected_current_smoker' = inlist(`expected_smoker', 1, 2) if !missing(`expected_smoker')
quietly count if !(current_smoker == `expected_current_smoker' | (missing(current_smoker) & missing(`expected_current_smoker')))
if r(N) > 0 {
    display as error "[FAIL] current_smoker does not follow smoker 1/2 in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] current_smoker follows smoker 1/2."

gen double `expected_diabetes_raw' = .
foreach v in diabete2 diabetes_pre2004 {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_diabetes_raw' = `v' if missing(`expected_diabetes_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
quietly count if !(diabetes_raw == `expected_diabetes_raw' | (missing(diabetes_raw) & missing(`expected_diabetes_raw')))
if r(N) > 0 {
    display as error "[FAIL] diabetes_raw does not follow DIABETE2/DIABETES in " r(N) " row(s)."
    exit 459
}

gen double `expected_diabetes' = .
capture confirm variable diabete2
if _rc == 0 {
    replace `expected_diabetes' = 1 if diabete2 == 1
    replace `expected_diabetes' = 0 if inlist(diabete2, 2, 3, 4)
}
capture confirm variable diabetes_pre2004
if _rc == 0 {
    replace `expected_diabetes' = 1 if missing(`expected_diabetes') & diabetes_pre2004 == 1
    replace `expected_diabetes' = 0 if missing(`expected_diabetes') & inlist(diabetes_pre2004, 2, 3)
}
quietly count if !(diabetes == `expected_diabetes' | (missing(diabetes) & missing(`expected_diabetes')))
if r(N) > 0 {
    display as error "[FAIL] diabetes does not follow DIABETE2/DIABETES in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] diabetes follows DIABETE2/DIABETES documented codes."

gen double `expected_asthma_raw' = .
foreach v in asthma2 asthma {
    capture confirm variable `v'
    if _rc == 0 {
        replace `expected_asthma_raw' = `v' if missing(`expected_asthma_raw') & !missing(`v') & !inlist(`v', 777, 888, 999)
    }
}
gen double `expected_asthma' = .
replace `expected_asthma' = 1 if `expected_asthma_raw' == 1
replace `expected_asthma' = 0 if `expected_asthma_raw' == 2
quietly count if !(asthma_ever_raw == `expected_asthma_raw' | (missing(asthma_ever_raw) & missing(`expected_asthma_raw')))
if r(N) > 0 {
    display as error "[FAIL] asthma_ever_raw does not follow ASTHMA2/ASTHMA in " r(N) " row(s)."
    exit 459
}
quietly count if !(asthma_ever == `expected_asthma' | (missing(asthma_ever) & missing(`expected_asthma')))
if r(N) > 0 {
    display as error "[FAIL] asthma_ever does not follow ASTHMA2/ASTHMA in " r(N) " row(s)."
    exit 459
}
display as text "[PASS] asthma_ever follows ASTHMA2/ASTHMA yes/no codes."

display as text _newline "[INFO] Observations per survey year:"
tab surveyyear

quietly count if !missing(countyfips)
display as text "[INFO] Non-missing countyfips rows: " r(N)

display as text _newline "[INFO] Non-missing counts for key clean variables:"
foreach v in countyfips age female race_eth educ_cat income_cat insured genhealth bmi current_smoker diabetes {
    quietly count if !missing(`v')
    display as text "  `v': " r(N)
}

quietly count if !missing(analysis_weight)
if r(N) == 0 {
    display as error "[FAIL] analysis_weight is missing for all rows."
    exit 459
}
else {
    display as text "[PASS] analysis_weight has non-missing values."
}

display as text _newline "============================================"
display as text "   COMPLETE"
display as text "============================================"
display as text "Clean pre-2011 file: `out_dta'"
