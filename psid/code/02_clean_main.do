********************************************************************************
* 02_clean_main.do
*
* Purpose: Add conservative cleaned starter variables and flags to the PSID
*          person-year file created by 01_load_main.do.
*
* Input:   output/psid_person_year.dta
* Output:  output/psid_person_year_clean.dta
********************************************************************************

clear all
set more off

* ============================================================================
* 1. USER SETTINGS
* ============================================================================
*
* Optional manual path override:
* global psid_root "/Users/yourname/path/to/econ-data-starters/psid"
*
* Output overrides:
* global psid_output_dir "/private/tmp/psid_smoke"
* global psid_output_basename "psid_smoke"
*
* Starter cleaning options:
* global psid_create_core_clean_vars 0
* global psid_run_examples 1

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/02_clean_main.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/02_clean_main.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("02_clean_main.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/02_clean_main.do") & fileexists("psid/README.md") {
    global psid_root "`cwd'/psid"
}
else {
    display as error "Could not locate the psid/ directory."
    display as error "Run from psid/, psid/code/, repo root, or set global psid_root."
    error 601
}

cd "$psid_root"

local output_dir "output"
if "$psid_output_dir" != "" {
    local output_dir "$psid_output_dir"
}

local output_basename "psid"
if "$psid_output_basename" != "" {
    local output_basename "$psid_output_basename"
}

local person_in "`output_dir'/`output_basename'_person_year.dta"
local person_out "`output_dir'/`output_basename'_person_year_clean.dta"

local create_core_clean_vars = 1
if "$psid_create_core_clean_vars" == "0" {
    local create_core_clean_vars = 0
}

if !fileexists("`person_in'") {
    display as error "Could not find `person_in'."
    display as error "Run code/01_load_main.do first, or set psid_output_dir / psid_output_basename."
    error 601
}

use "`person_in'", clear

if `create_core_clean_vars' {
    capture drop sequence_number_clean relation_to_head_clean family_size_clean
    capture drop head_age_clean age_individual_clean children_in_fu_clean
    capture drop age_youngest_child_clean birth_month_clean birth_year_clean
    capture drop marital_pairs_indicator_clean move_month_clean move_year_clean
    capture drop education_years_clean current_state_clean current_region_clean
    capture drop metro_nonmetro_clean beale_rural_urban_clean
    capture drop head_total_work_hours_clean head_labor_income_clean
    capture drop food_expenditure_clean total_family_income_clean
    capture drop is_reference_person is_spouse_partner female head_female
    capture drop married_or_partnered has_children_in_fu homeowner renter
    capture drop respondent changed_family_membership employed unemployed
    capture drop not_in_labor_force adult has_positive_family_weight
    capture drop has_positive_individual_weight

    capture confirm variable sequence_number
    if !_rc {
        gen double sequence_number_clean = sequence_number
        replace sequence_number_clean = . if sequence_number_clean < 1 | sequence_number_clean > 99
    }
    else gen double sequence_number_clean = .

    capture confirm variable relation_to_head
    if !_rc {
        gen double relation_to_head_clean = relation_to_head
        replace relation_to_head_clean = . if relation_to_head_clean < 0 | relation_to_head_clean > 99
    }
    else gen double relation_to_head_clean = .

    capture confirm variable family_size
    if !_rc {
        gen double family_size_clean = family_size
        replace family_size_clean = . if family_size_clean < 1 | family_size_clean > 50 | inlist(family_size_clean, 98, 99)
    }
    else gen double family_size_clean = .

    capture confirm variable head_age
    if !_rc {
        gen double head_age_clean = head_age
        replace head_age_clean = . if head_age_clean < 0 | head_age_clean > 125 | inlist(head_age_clean, 998, 999)
    }
    else gen double head_age_clean = .

    capture confirm variable age_individual
    if !_rc {
        gen double age_individual_clean = age_individual
        replace age_individual_clean = . if age_individual_clean < 0 | age_individual_clean > 125 | inlist(age_individual_clean, 998, 999)
    }
    else gen double age_individual_clean = .

    capture confirm variable children_in_fu
    if !_rc {
        gen double children_in_fu_clean = children_in_fu
        replace children_in_fu_clean = . if children_in_fu_clean < 0 | children_in_fu_clean > 30 | inlist(children_in_fu_clean, 98, 99)
    }
    else gen double children_in_fu_clean = .

    capture confirm variable age_youngest_child
    if !_rc {
        gen double age_youngest_child_clean = age_youngest_child
        replace age_youngest_child_clean = . if age_youngest_child_clean < 0 | age_youngest_child_clean > 30 | inlist(age_youngest_child_clean, 98, 99)
    }
    else gen double age_youngest_child_clean = .

    capture confirm variable month_individual_born
    if !_rc {
        gen double birth_month_clean = month_individual_born
        replace birth_month_clean = . if birth_month_clean < 1 | birth_month_clean > 12 | inlist(birth_month_clean, 98, 99)
    }
    else gen double birth_month_clean = .

    capture confirm variable year_individual_born
    if !_rc {
        gen double birth_year_clean = year_individual_born
        replace birth_year_clean = . if birth_year_clean < 1800 | birth_year_clean > 2026 | inlist(birth_year_clean, 9998, 9999)
    }
    else gen double birth_year_clean = .

    capture confirm variable marital_pairs_indicator
    if !_rc {
        gen double marital_pairs_indicator_clean = marital_pairs_indicator
        replace marital_pairs_indicator_clean = . if marital_pairs_indicator_clean < 0 | marital_pairs_indicator_clean > 99
    }
    else gen double marital_pairs_indicator_clean = .

    capture confirm variable month_moved_in_out
    if !_rc {
        gen double move_month_clean = month_moved_in_out
        replace move_month_clean = . if move_month_clean < 1 | move_month_clean > 12 | inlist(move_month_clean, 98, 99)
    }
    else gen double move_month_clean = .

    capture confirm variable year_moved_in_out
    if !_rc {
        gen double move_year_clean = year_moved_in_out
        replace move_year_clean = . if move_year_clean < 1800 | move_year_clean > 2026 | inlist(move_year_clean, 9998, 9999)
    }
    else gen double move_year_clean = .

    capture confirm variable years_completed_education
    if !_rc {
        gen double education_years_clean = years_completed_education
        replace education_years_clean = . if education_years_clean < 0 | education_years_clean > 25 | inlist(education_years_clean, 98, 99)
    }
    else gen double education_years_clean = .

    capture confirm variable current_state
    if !_rc {
        gen double current_state_clean = current_state
        replace current_state_clean = . if current_state_clean < 1 | current_state_clean > 99
    }
    else gen double current_state_clean = .

    capture confirm variable current_region
    if !_rc {
        gen double current_region_clean = current_region
        replace current_region_clean = . if current_region_clean < 1 | current_region_clean > 9
    }
    else gen double current_region_clean = .

    capture confirm variable metro_nonmetro
    if !_rc {
        gen double metro_nonmetro_clean = metro_nonmetro
        replace metro_nonmetro_clean = . if metro_nonmetro_clean < 1 | metro_nonmetro_clean > 9
    }
    else gen double metro_nonmetro_clean = .

    capture confirm variable beale_rural_urban
    if !_rc {
        gen double beale_rural_urban_clean = beale_rural_urban
        replace beale_rural_urban_clean = . if beale_rural_urban_clean < 1 | beale_rural_urban_clean > 9
    }
    else gen double beale_rural_urban_clean = .

    capture confirm variable head_total_work_hours
    if !_rc {
        gen double head_total_work_hours_clean = head_total_work_hours
        replace head_total_work_hours_clean = . if head_total_work_hours_clean < 0 | head_total_work_hours_clean > 8784 | inlist(head_total_work_hours_clean, 9998, 9999)
    }
    else gen double head_total_work_hours_clean = .

    capture confirm variable head_labor_income
    if !_rc {
        gen double head_labor_income_clean = head_labor_income
        replace head_labor_income_clean = . if inlist(head_labor_income_clean, 9999998, 9999999, 99999998, 99999999, 999999998, 999999999)
    }
    else gen double head_labor_income_clean = .

    capture confirm variable food_expenditure
    if !_rc {
        gen double food_expenditure_clean = food_expenditure
        replace food_expenditure_clean = . if food_expenditure_clean < 0 | inlist(food_expenditure_clean, 9999998, 9999999, 99999998, 99999999, 999999998, 999999999)
    }
    else gen double food_expenditure_clean = .

    capture confirm variable total_family_income
    if !_rc {
        gen double total_family_income_clean = total_family_income
        replace total_family_income_clean = . if inlist(total_family_income_clean, 9999998, 9999999, 99999998, 99999999, 999999998, 999999999)
    }
    else gen double total_family_income_clean = .

    gen byte is_reference_person = sequence_number_clean == 1 if !missing(sequence_number_clean)
    gen byte is_spouse_partner = sequence_number_clean == 2 if !missing(sequence_number_clean)

    capture confirm variable sex
    if !_rc gen byte female = sex == 2 if inlist(sex, 1, 2)
    else gen byte female = .

    capture confirm variable head_sex
    if !_rc gen byte head_female = head_sex == 2 if inlist(head_sex, 1, 2)
    else gen byte head_female = .

    capture confirm variable marital_status
    if !_rc gen byte married_or_partnered = marital_status == 1 if inlist(marital_status, 1, 2, 3, 4, 5)
    else gen byte married_or_partnered = .

    gen byte has_children_in_fu = children_in_fu_clean > 0 if !missing(children_in_fu_clean)

    capture confirm variable housing_tenure
    if !_rc {
        gen byte homeowner = housing_tenure == 1 if inlist(housing_tenure, 1, 5, 8)
        gen byte renter = housing_tenure == 5 if inlist(housing_tenure, 1, 5, 8)
    }
    else {
        gen byte homeowner = .
        gen byte renter = .
    }

    capture confirm variable respondent_status
    if !_rc gen byte respondent = respondent_status == 1 if inlist(respondent_status, 1, 5)
    else gen byte respondent = .

    capture confirm variable moved_in_out
    if !_rc gen byte changed_family_membership = inlist(moved_in_out, 1, 2, 5, 6, 7, 8) if inlist(moved_in_out, 0, 1, 2, 5, 6, 7, 8)
    else gen byte changed_family_membership = .

    capture confirm variable employment_status
    if !_rc {
        gen byte employed = employment_status == 1 if inrange(employment_status, 1, 8)
        gen byte unemployed = inlist(employment_status, 2, 3) if inrange(employment_status, 1, 8)
        gen byte not_in_labor_force = inrange(employment_status, 4, 8) if inrange(employment_status, 1, 8)
    }
    else {
        gen byte employed = .
        gen byte unemployed = .
        gen byte not_in_labor_force = .
    }

    gen byte adult = age_individual_clean >= 18 if !missing(age_individual_clean)

    capture confirm variable family_weight
    if !_rc gen byte has_positive_family_weight = family_weight > 0 if !missing(family_weight)
    else gen byte has_positive_family_weight = .

    capture confirm variable individual_weight
    if !_rc gen byte has_positive_individual_weight = individual_weight > 0 if !missing(individual_weight)
    else gen byte has_positive_individual_weight = .
}
else {
    capture confirm variable sequence_number
    if !_rc {
        gen byte is_reference_person = sequence_number == 1 if !missing(sequence_number)
        gen byte is_spouse_partner = sequence_number == 2 if !missing(sequence_number)
    }
    else {
        gen byte is_reference_person = .
        gen byte is_spouse_partner = .
    }
}

capture confirm variable has_family_record
if !_rc {
    gen str28 family_record_status = "matched family record" if has_family_record == 1
    replace family_record_status = "no selected family record" if has_family_record == 0
}
else {
    gen str28 family_record_status = "not checked"
}

compress
save "`person_out'", replace
display as text "Saved cleaned PSID person-year file: `person_out'"
display as text "Rows: " _N

if "$psid_run_examples" == "1" {
    tab survey_year family_record_status, missing
    tab survey_year is_reference_person, missing
}
