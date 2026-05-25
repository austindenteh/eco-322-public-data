********************************************************************************
* 03_clean_modern_primary.do
*
* Purpose: Create a starter analysis-ready person-month file from the modern
*          SIPP annual primary public-use loader.
*
* Input:  output/sipp_modern_primary_person_month.dta
* Output: output/sipp_modern_primary_clean_person_month.dta
********************************************************************************

clear all
set more off
set maxvar 32767

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
* do "$sipp_root/code/03_clean_modern_primary.do"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* The default runs 01_load_modern_primary.do first, using any loader settings
* already defined in your Stata session.
* global sipp_clean_run_loader 1
*
* Used only when sipp_clean_run_loader is 0.
* global sipp_clean_input_path "/path/to/sipp_modern_primary_person_month.dta"

********************************************************************************
* PATHS AND OPTIONS
********************************************************************************

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/03_clean_modern_primary.do") {
    global sipp_root "$sipp_root"
}
else if fileexists("code/03_clean_modern_primary.do") & fileexists("README.md") {
    global sipp_root "`cwd'"
}
else if fileexists("03_clean_modern_primary.do") & fileexists("../README.md") {
    global sipp_root "`cwd'/.."
}
else if fileexists("sipp/code/03_clean_modern_primary.do") & fileexists("sipp/README.md") {
    global sipp_root "`cwd'/sipp"
}
else {
    display as error "Could not locate the sipp/ directory."
    display as error "Run from sipp/, sipp/code/, repo root, or set global sipp_root."
    error 601
}

cd "$sipp_root"
capture mkdir "output"

local output_dir "output"
if "$sipp_output_dir" != "" {
    local output_dir "$sipp_output_dir"
    capture mkdir "`output_dir'"
}

local output_basename "sipp"
if "$sipp_output_basename" != "" {
    local output_basename "$sipp_output_basename"
}

local run_loader = 1
if "$sipp_clean_run_loader" != "" {
    local run_loader = real("$sipp_clean_run_loader")
}

********************************************************************************
* LOAD
********************************************************************************

if `run_loader' {
    do "$sipp_root/code/01_load_modern_primary.do"
}
else {
    local input_path "`output_dir'/`output_basename'_modern_primary_person_month.dta"
    if "$sipp_clean_input_path" != "" {
        local input_path "$sipp_clean_input_path"
    }
    if !fileexists("`input_path'") {
        display as error "Could not find modern SIPP primary input: `input_path'"
        display as error "Run 01_load_modern_primary.do first or set global sipp_clean_run_loader 1."
        error 601
    }
    use "`input_path'", clear
}

********************************************************************************
* HELPERS
********************************************************************************

* Define helper programs after the optional loader call. The loader runs
* clear all, which drops programs but preserves the globals set above.
capture program drop sipp_clean_numeric_copy
program define sipp_clean_numeric_copy
    args old new
    capture confirm variable `old'
    if _rc {
        exit
    }
    capture confirm numeric variable `old'
    if _rc {
        exit
    }
    capture drop `new'
    gen double `new' = `old'
    replace `new' = . if `new' < 0
end

capture program drop sipp_clean_yes_flag
program define sipp_clean_yes_flag
    args old new
    capture confirm variable `old'
    if _rc {
        exit
    }
    capture confirm numeric variable `old'
    if _rc {
        exit
    }
    capture drop `new'
    gen byte `new' = (`old' == 1) if `old' >= 0 & !missing(`old')
end

capture program drop sipp_clean_state_fips
program define sipp_clean_state_fips
    args old new
    capture confirm variable `old'
    if _rc {
        exit
    }
    capture drop `new'
    capture confirm string variable `old'
    if !_rc {
        gen str2 `new' = strtrim(`old')
        replace `new' = "" if `new' == "."
        exit
    }
    gen str2 `new' = string(`old', "%02.0f") if !missing(`old') & `old' >= 0
end

********************************************************************************
* CLEAN
********************************************************************************

capture confirm variable ssuid
if !_rc {
    capture confirm variable pnum
    if !_rc {
        capture drop person_id
        egen person_id = concat(ssuid pnum), punct("_")
    }
}

capture confirm variable ssuid
if !_rc {
    capture confirm variable pnum
    if !_rc {
        capture confirm variable monthcode
        if !_rc {
            capture drop person_month_id
            egen person_month_id = concat(ssuid pnum monthcode), punct("_")
        }
    }
}

sipp_clean_numeric_copy tage age
sipp_clean_numeric_copy tage age_at_interview
capture confirm variable age
if !_rc {
    capture drop adult
    gen byte adult = (age >= 18) if !missing(age)
}

capture confirm variable esex
if !_rc {
    capture drop female
    gen byte female = (esex == 2) if esex >= 0 & !missing(esex)
}

sipp_clean_yes_flag eorigin hispanic

sipp_clean_numeric_copy erace race_code
sipp_clean_numeric_copy eeduc education_code
capture confirm variable education_code
if !_rc {
    capture drop high_school_or_more bachelor_or_more
    gen byte high_school_or_more = (education_code >= 38) if !missing(education_code)
    gen byte bachelor_or_more = (education_code >= 43) if !missing(education_code)
}

sipp_clean_numeric_copy ems marital_status_code
capture confirm variable marital_status_code
if !_rc {
    capture drop married never_married
    gen byte married = (marital_status_code == 1) if !missing(marital_status_code)
    gen byte never_married = (marital_status_code == 6) if !missing(marital_status_code)
}

sipp_clean_numeric_copy rmesr monthly_employment_status_code
capture confirm variable monthly_employment_status_code
if !_rc {
    capture drop employed_some_or_all_month
    gen byte employed_some_or_all_month = inrange(monthly_employment_status_code, 1, 3) if !missing(monthly_employment_status_code)
}

sipp_clean_numeric_copy etenure housing_tenure_code
capture confirm variable housing_tenure_code
if !_rc {
    capture drop owner_occupied renter_occupied occupied_without_cash_rent
    gen byte owner_occupied = (housing_tenure_code == 1) if !missing(housing_tenure_code)
    gen byte renter_occupied = (housing_tenure_code == 2) if !missing(housing_tenure_code)
    gen byte occupied_without_cash_rent = (housing_tenure_code == 3) if !missing(housing_tenure_code)
}

sipp_clean_numeric_copy rhnumper household_persons
sipp_clean_numeric_copy rhnumu18 household_children
sipp_clean_numeric_copy rhnum65over household_older_adults
sipp_clean_numeric_copy rfpersons family_persons
sipp_clean_numeric_copy rfrelu18 family_children
sipp_clean_numeric_copy tpearn person_earnings
sipp_clean_numeric_copy tpearn_alt person_earnings_alt
sipp_clean_numeric_copy tptotinc person_total_income
sipp_clean_numeric_copy thtotinc household_total_income
sipp_clean_numeric_copy tftotinc family_total_income
sipp_clean_numeric_copy rfpov family_poverty_threshold
sipp_clean_numeric_copy tsssamt social_security_income
sipp_clean_numeric_copy tssi_amt ssi_income
sipp_clean_numeric_copy ttanf_amt tanf_amount
sipp_clean_numeric_copy tsnap_amt snap_amount
sipp_clean_numeric_copy twic_amt wic_amount
sipp_clean_numeric_copy tga_amt general_assistance_amount
sipp_clean_numeric_copy thval_home household_home_value
sipp_clean_numeric_copy tnetworth person_net_worth
sipp_clean_numeric_copy thnetworth household_net_worth
sipp_clean_numeric_copy tdebt_cc person_credit_card_debt
sipp_clean_numeric_copy thdebt_cc household_credit_card_debt
sipp_clean_numeric_copy tmwkhrs person_monthly_work_hours
sipp_clean_numeric_copy rmwkwjb monthly_weeks_with_job
sipp_clean_numeric_copy rmnumjobs monthly_number_jobs

capture confirm variable family_total_income
if !_rc {
    capture confirm variable family_poverty_threshold
    if !_rc {
        capture drop family_income_to_poverty family_below_poverty
        gen double family_income_to_poverty = family_total_income / family_poverty_threshold if family_poverty_threshold > 0 & !missing(family_total_income)
        gen byte family_below_poverty = (family_income_to_poverty < 1) if !missing(family_income_to_poverty)
    }
}

sipp_clean_yes_flag rhlthmth any_health_insurance_month
sipp_clean_yes_flag rhicovann any_health_insurance_annual
sipp_clean_yes_flag rprivann private_health_insurance_annual
sipp_clean_yes_flag rpubann public_health_insurance_annual
sipp_clean_yes_flag rmedcareann medicare_annual
sipp_clean_yes_flag rmcaidann medicaid_annual
sipp_clean_yes_flag rvacareann va_health_care_annual
sipp_clean_yes_flag rsnap_mnyn snap_month
sipp_clean_yes_flag rtanf_mnyn tanf_month
sipp_clean_yes_flag rssi_mnyn ssi_month
sipp_clean_yes_flag rwic_mnyn wic_month

sipp_clean_state_fips tst_intv state_fips_interview
sipp_clean_state_fips tehc_st state_fips_residence_ehc
sipp_clean_numeric_copy rregion_intv region_interview_code
sipp_clean_numeric_copy tmetro_intv metro_interview_code
sipp_clean_numeric_copy tehc_metro metro_residence_ehc_code

capture sort sipp_file_year ssuid pnum monthcode
compress
save "`output_dir'/`output_basename'_modern_primary_clean_person_month.dta", replace
display as text "Saved cleaned modern SIPP primary person-month file: `output_dir'/`output_basename'_modern_primary_clean_person_month.dta"
