********************************************************************************
* 01_load_selected_years.do
*
* Purpose: Standalone selected-years Ghana DHS loader. Reads selected raw
*          columns from selected Ghana IR/MR Stata recode files, harmonizes the
*          same starter surface used by the wave-specific 01_load_YYYY scripts,
*          and saves a combined selected-years working dataset.
*
* Input:   data/raw/ghana_YYYY/... DHS Stata recode folders
* Output:  output/ghana_dhs_selected_working.dta
*          optional output/ghana_dhs_YYYY_working.dta
*
* Usage:   Run from dhs/, dhs/code/, from the repo root, or set global dhs_root.
********************************************************************************

clear all
set more off
set maxvar 32767
version 16.1

* ============================================================================
* 1. PATHS AND USER SETTINGS
* ============================================================================
* Optional manual path override. Uncomment and edit if auto-detection fails:
* global dhs_root "/Users/yourname/path/to/econ-data-starters/dhs"
* Then run the script from that code folder or with an absolute path.

local cwd "`c(pwd)'"
if "$dhs_root" != "" & fileexists("$dhs_root/code/01_load_selected_years.do") {
    global dhs_root "$dhs_root"
}
else if fileexists("code/01_load_selected_years.do") & fileexists("README.md") {
    global dhs_root "`cwd'"
}
else if fileexists("01_load_selected_years.do") & fileexists("../README.md") {
    global dhs_root "`cwd'/.."
}
else if fileexists("dhs/code/01_load_selected_years.do") & fileexists("dhs/README.md") {
    global dhs_root "`cwd'/dhs"
}
else {
    display as error "Could not locate the dhs/ directory."
    display as error "Run from dhs/, dhs/code/, from the repo root, or set global dhs_root."
    display as error `"Manual override: global dhs_root "/path/to/dhs""'
    error 601
}

cd "$dhs_root"
local output_dir "output"
if "$dhs_output_dir" != "" {
    local output_dir "$dhs_output_dir"
}
capture mkdir "`output_dir'"

local selected_years "1988 1993 1998 2003 2008 2014 2022"
if "$dhs_years" != "" {
    local selected_years "$dhs_years"
}
local selected_years : list retok selected_years

local selected_samples "women men"
if "$dhs_samples" != "" {
    local selected_samples "$dhs_samples"
}
local selected_samples = lower("`selected_samples'")
local selected_samples : list retok selected_samples

local write_wave_outputs 1
if "$dhs_write_wave_outputs" != "" {
    local write_wave_outputs "$dhs_write_wave_outputs"
}

local combined_basename "ghana_dhs_selected_working"
if "$dhs_combined_basename" != "" {
    local combined_basename "$dhs_combined_basename"
}

local extra_keep_vars "$dhs_extra_keep_vars"
local extra_var_families `"$dhs_extra_var_families"'

* Examples:
* global dhs_years "2008 2022"
* global dhs_samples "women"
* global dhs_output_dir "/private/tmp/dhs_smoke"
* global dhs_write_wave_outputs "1"
* global dhs_extra_keep_vars "v133"
* global dhs_extra_var_families `" "insurance_type:v481c v481e mv481c mv481e" "'

capture log close
log using "`output_dir'/01_load_selected_years_log.txt", text replace

display as text "============================================================"
display as text "Ghana DHS selected-years loader (Stata)"
display as text "============================================================"
display as text "Using DHS root: $dhs_root"
display as text "Using output directory: `output_dir'"

* ============================================================================
* 2. HELPERS
* ============================================================================

capture program drop dhs_present_vars
program define dhs_present_vars, rclass
    syntax using/, Vars(string asis) [Required(string asis)]

    quietly describe using "`using'", varlist
    local file_vars "`r(varlist)'"
    local vars : subinstr local vars `"""' "", all
    local vars : list retok vars
    local required : subinstr local required `"""' "", all
    local required : list retok required

    local present
    foreach v of local vars {
        local has_var : list v in file_vars
        if `has_var' {
            local present "`present' `v'"
        }
    }
    local present : list retok present

    local missing_required
    foreach v of local required {
        local has_var : list v in file_vars
        if !`has_var' {
            local missing_required "`missing_required' `v'"
        }
    }
    local missing_required : list retok missing_required
    if trim("`missing_required'") != "" {
        display as error "Missing required raw variable(s) in `using': `missing_required'"
        error 111
    }

    return local present "`present'"
end

capture program drop dhs_coalesce_family
program define dhs_coalesce_family
    syntax, Name(name) Aliases(string asis)

    local aliases : subinstr local aliases `"""' "", all
    local aliases : list retok aliases
    local present
    foreach alias of local aliases {
        capture confirm variable `alias'
        if _rc == 0 {
            local present "`present' `alias'"
        }
    }
    local present : list retok present
    if trim("`present'") == "" {
        exit
    }

    local first_alias : word 1 of `present'
    capture confirm variable `name'
    if _rc != 0 {
        clonevar `name' = `first_alias'
    }

    foreach alias of local present {
        if "`alias'" != "`name'" {
            capture confirm string variable `name'
            if _rc == 0 {
                capture confirm string variable `alias'
                if _rc == 0 {
                    quietly replace `name' = `alias' if missing(`name') & !missing(`alias')
                }
            }
            else {
                capture confirm numeric variable `alias'
                if _rc == 0 {
                    quietly replace `name' = `alias' if missing(`name') & !missing(`alias')
                }
            }
        }
    }
end

local n_extra_families = 0
local extra_family_keep_vars
if trim(`"`extra_var_families'"') != "" {
    display as text "[INFO] extra_var_families only merge raw aliases into one column."
    display as text "[INFO] If coding or meanings change across waves, harmonize that added variable later."

    foreach family_def of local extra_var_families {
        gettoken family_name alias_vars : family_def, parse(":")
        local family_name = lower(trim("`family_name'"))
        local alias_vars : subinstr local alias_vars ":" "", all
        local alias_vars : list retok alias_vars

        if trim("`family_name'") == "" {
            display as error "Each extra_var_families entry needs a merged variable name."
            error 198
        }
        if trim("`alias_vars'") == "" {
            display as error "extra_var_families entry `family_name' is missing its alias list."
            error 198
        }

        local n_extra_families = `n_extra_families' + 1
        local extra_family_name`n_extra_families' "`family_name'"
        local extra_family_aliases`n_extra_families' "`alias_vars'"
        local extra_family_keep_vars "`extra_family_keep_vars' `family_name' `alias_vars'"
    }
}

* ============================================================================
* 3. RUN SELECTED WAVES
* ============================================================================

display as text "Selected years: `selected_years'"
display as text "Selected samples: `selected_samples'"
display as text "Extra vars: `extra_keep_vars'"
display as text "Write per-wave outputs: `write_wave_outputs'"

local has_1988 = 0
local has_pre2003 = 0
local has_2003plus = 0
local has_pre2008 = 0
local has_2008plus = 0
local has_2022 = 0
local has_pre2022 = 0
foreach guidance_year of local selected_years {
    if `guidance_year' == 1988 local has_1988 = 1
    if `guidance_year' < 2003 local has_pre2003 = 1
    if `guidance_year' >= 2003 local has_2003plus = 1
    if `guidance_year' < 2008 local has_pre2008 = 1
    if `guidance_year' >= 2008 local has_2008plus = 1
    if `guidance_year' == 2022 local has_2022 = 1
    if `guidance_year' < 2022 local has_pre2022 = 1
}
local sample_has_men = strpos(" `selected_samples' ", " men ") > 0

display _newline as text "=== Pooling Guidance ==="
display as text "This loader harmonizes a starter surface; it does not make every DHS concept fully comparable across waves."
display as text "Best-supported pooled windows:"
display as text "  - 2008, 2014: strongest NHIS window with the same 10-region geography."
display as text "  - 2008, 2014, 2022: useful for national NHIS/descriptive work; map 2022 regions before raw region comparisons."
display as text "  - 2003, 2008, 2014, 2022: wealth/literacy plus common demographics, but health insurance starts in 2008."
display as text "  - 1993 onward: basic demographics only; no wealth/literacy before 2003 and no insurance before 2008."
display as text "  - 1988: women only; use for women-only long-run comparisons."
if `has_1988' {
    display as text "[NOTE] 1988 has no men's recode. Requests for men are skipped for that wave."
}
if `has_pre2003' & `has_2003plus' {
    display as text "[NOTE] Wealth and literacy variables are not available before 2003; pooled columns are missing for 1988/1993/1998."
}
if `has_pre2008' & `has_2008plus' {
    display as text "[NOTE] Health insurance/NHIS variables are only available in 2008, 2014, and 2022."
}
if `has_2022' & `has_pre2022' {
    display as text "[NOTE] 2022 uses Ghana's 16-region post-2019 geography; earlier waves use 10 regions."
}
if `n_extra_families' > 0 {
    display as text "[NOTE] extra_var_families coalesce aliases by name only; check coding and meaning before analysis."
}
if `sample_has_men' & `has_1988' {
    display as text "[NOTE] Sex-pooled analyses including 1988 have an unbalanced sample frame because 1988 is women-only."
}
display as text "Wave-level flags in the combined output: region_scheme, has_men_recode, has_wealth_index, has_literacy, has_health_insurance."

tempfile combined_data
local have_combined = 0

foreach requested_sample of local selected_samples {
    if !inlist("`requested_sample'", "women", "men") {
        display as error "dhs_samples must contain only women and/or men."
        error 198
    }
}

foreach year of local selected_years {
    if !inlist(`year', 1988, 1993, 1998, 2003, 2008, 2014, 2022) {
        display as error "Unsupported DHS year: `year'"
        error 198
    }

    local valid_interview_years "`year'"
    local women_file
    local men_file
    local region_suffix "024"
    local residence_suffix "025"
    local educ_attain_suffix "149"
    local literacy_suffix "155"
    local wealth_suffix "190"
    local any_insurance_suffix
    local nhis_suffix

    if `year' == 1988 {
        local women_file "data/raw/ghana_1988/GHIR02DT/GHIR02FL.DTA"
        local men_file
        local valid_interview_years "1988"
        local region_suffix "101"
        local residence_suffix "102"
        local educ_attain_suffix
        local literacy_suffix
        local wealth_suffix
    }
    else if `year' == 1993 {
        local women_file "data/raw/ghana_1993/GHIR31DT/GHIR31FL.DTA"
        local men_file "data/raw/ghana_1993/GHMR31DT/GHMR31FL.DTA"
        local valid_interview_years "1993 1994"
        local literacy_suffix
        local wealth_suffix
    }
    else if `year' == 1998 {
        local women_file "data/raw/ghana_1998/GHIR41DT/GHIR41FL.DTA"
        local men_file "data/raw/ghana_1998/GHMR41DT/GHMR41FL.DTA"
        local valid_interview_years "1998 1999"
        local literacy_suffix
        local wealth_suffix
    }
    else if `year' == 2003 {
        local women_file "data/raw/ghana_2003/GHIR4BDT/GHIR4BFL.DTA"
        local men_file "data/raw/ghana_2003/GHMR4BDT/GHMR4BFL.DTA"
        local valid_interview_years "2003"
    }
    else if `year' == 2008 {
        local women_file "data/raw/ghana_2008/GHIR5ADT/GHIR5AFL.DTA"
        local men_file "data/raw/ghana_2008/GHMR5ADT/GHMR5AFL.DTA"
        local valid_interview_years "2008"
        local any_insurance_suffix "481"
        local nhis_suffix "481c"
    }
    else if `year' == 2014 {
        local women_file "data/raw/ghana_2014/GHIR72DT/GHIR72FL.DTA"
        local men_file "data/raw/ghana_2014/GHMR71DT/GHMR71FL.DTA"
        local valid_interview_years "2014 2015"
        local any_insurance_suffix "481"
        local nhis_suffix "481e"
    }
    else if `year' == 2022 {
        local women_file "data/raw/ghana_2022/GHIR8CDT/GHIR8CFL.DTA"
        local men_file "data/raw/ghana_2022/GHMR8CDT/GHMR8CFL.DTA"
        local valid_interview_years "2022 2023"
        local any_insurance_suffix "481"
        local nhis_suffix "481e"
    }

    display _newline as text "--- Ghana DHS `year' ---"
    tempfile wave_data
    local have_wave = 0

    foreach sample of local selected_samples {
        if "`sample'" == "men" & trim("`men_file'") == "" {
            display as text "[INFO] Ghana DHS `year' has no men's recode; skipping men."
            continue
        }

        local source_file "`women_file'"
        local prefix "v"
        local female_value = 1
        if "`sample'" == "men" {
            local source_file "`men_file'"
            local prefix "mv"
            local female_value = 0
        }

        capture confirm file "`source_file'"
        if _rc {
            display as error "Could not find `sample' recode for Ghana DHS `year': `source_file'"
            display as error "Download the DHS Stata recode file and preserve the DHS folder name."
            error 601
        }

        local v_cluster "`prefix'001"
        local v_household "`prefix'002"
        local v_respondent "`prefix'003"
        local v_weight "`prefix'005"
        local v_month "`prefix'006"
        local v_year "`prefix'007"
        local v_cmc "`prefix'008"
        local v_age "`prefix'012"
        local v_region "`prefix'`region_suffix'"
        local v_residence "`prefix'`residence_suffix'"
        local v_educ_level "`prefix'106"
        local v_religion "`prefix'130"
        local v_ethnicity "`prefix'131"
        local v_marital "`prefix'501"
        local v_ever_married "`prefix'502"
        local v_working "`prefix'714"

        local v_educ_attain
        if trim("`educ_attain_suffix'") != "" {
            local v_educ_attain "`prefix'`educ_attain_suffix'"
        }
        local v_literacy
        if trim("`literacy_suffix'") != "" {
            local v_literacy "`prefix'`literacy_suffix'"
        }
        local v_wealth
        if trim("`wealth_suffix'") != "" {
            local v_wealth "`prefix'`wealth_suffix'"
        }
        local v_any_insurance
        if trim("`any_insurance_suffix'") != "" {
            local v_any_insurance "`prefix'`any_insurance_suffix'"
        }
        local v_nhis
        if trim("`nhis_suffix'") != "" {
            local v_nhis "`prefix'`nhis_suffix'"
        }

        local required_raw "`v_cluster' `v_household' `v_respondent' `v_weight' `v_month' `v_year' `v_cmc' `v_age' `v_region' `v_residence' `v_educ_level' `v_religion' `v_ethnicity' `v_marital' `v_ever_married' `v_working'"
        local requested_raw "`required_raw' `v_educ_attain' `v_literacy' `v_wealth' `v_any_insurance' `v_nhis' `extra_keep_vars' `extra_family_keep_vars'"
        local requested_raw : list retok requested_raw

        dhs_present_vars using "`source_file'", vars("`requested_raw'") required("`required_raw'")
        local load_vars "`r(present)'"

        display as text "Loading `sample' recode with selected raw columns: `source_file'"
        display as text "  Requested raw variables: `: word count `requested_raw''"
        display as text "  Loading raw variables: `: word count `load_vars''"
        use `load_vars' using "`source_file'", clear
        display as text "  Observations: " _N
        display as text "  Loaded variables: " c(k)

        gen byte female = `female_value'
        gen str5 source_sample = "`sample'"
        gen cluster_id = `v_cluster'
        gen household_id = `v_household'
        gen respondent_id = `v_respondent'
        gen sample_weight = `v_weight' / 1000000
        gen interview_month = `v_month'
        gen interview_year = `v_year'
        replace interview_year = interview_year + 1900 if interview_year < 100 & interview_year < .
        gen interview_cmc = `v_cmc'
        gen age_years = `v_age'
        gen region = `v_region'
        gen residence = `v_residence'
        gen educ_level = `v_educ_level'

        if trim("`v_educ_attain'") != "" {
            gen educ_attain = `v_educ_attain'
        }
        else {
            gen educ_attain = .
        }
        if trim("`v_literacy'") != "" {
            gen literacy = `v_literacy'
        }
        else {
            gen literacy = .
        }
        if trim("`v_wealth'") != "" {
            gen wealth_index = `v_wealth'
        }
        else {
            gen wealth_index = .
        }

        gen religion = `v_religion'
        gen ethnicity = `v_ethnicity'
        gen marital_status = `v_marital'
        gen ever_married = `v_ever_married'
        gen working_now = `v_working'

        if trim("`v_any_insurance'") != "" {
            gen any_insurance = `v_any_insurance'
        }
        else {
            gen any_insurance = .
        }
        if trim("`v_nhis'") != "" {
            gen nhis_enrolled = `v_nhis'
        }
        else {
            gen nhis_enrolled = .
        }
        foreach v in any_insurance nhis_enrolled {
            replace `v' = . if inlist(`v', 9, 99)
        }

        forvalues family_i = 1/`n_extra_families' {
            dhs_coalesce_family, name(`extra_family_name`family_i'') aliases("`extra_family_aliases`family_i''")
        }

        local keep_vars "female source_sample cluster_id household_id respondent_id sample_weight interview_month interview_year interview_cmc age_years region residence educ_level educ_attain literacy wealth_index religion ethnicity marital_status ever_married working_now any_insurance nhis_enrolled"
        foreach extra of local extra_keep_vars {
            capture confirm variable `extra'
            if _rc == 0 {
                local keep_vars "`keep_vars' `extra'"
            }
        }
        forvalues family_i = 1/`n_extra_families' {
            capture confirm variable `extra_family_name`family_i''
            if _rc == 0 {
                local keep_vars "`keep_vars' `extra_family_name`family_i''"
            }
        }
        local keep_vars : list retok keep_vars
        keep `keep_vars'

        tempfile sample_data
        save `sample_data', replace

        if `have_wave' == 0 {
            save `wave_data', replace
            local have_wave = 1
        }
        else {
            use `wave_data', clear
            append using `sample_data'
            save `wave_data', replace
        }
    }

    if `have_wave' == 0 {
        display as error "No samples were loaded for Ghana DHS `year'."
        error 2000
    }

    use `wave_data', clear

    foreach extra of local extra_keep_vars {
        capture confirm variable `extra'
        if _rc != 0 {
            gen `extra' = .
        }
    }
    forvalues family_i = 1/`n_extra_families' {
        capture confirm variable `extra_family_name`family_i''
        if _rc != 0 {
            gen `extra_family_name`family_i'' = .
        }
    }

    gen int survey_year = `year'
    label var survey_year "DHS survey wave year"
    gen str9 region_scheme = "10_region"
    replace region_scheme = "16_region" if survey_year == 2022
    label var region_scheme "Region coding scheme for this DHS wave"
    gen byte has_men_recode = (survey_year != 1988)
    label var has_men_recode "Wave has a men's recode in this starter"
    gen byte has_wealth_index = (survey_year >= 2003)
    label var has_wealth_index "Wave has DHS wealth index in this starter"
    gen byte has_literacy = (survey_year >= 2003)
    label var has_literacy "Wave has literacy variable in this starter"
    gen byte has_health_insurance = inlist(survey_year, 2008, 2014, 2022)
    label var has_health_insurance "Wave has health insurance variables in this starter"
    sort female cluster_id household_id respondent_id

    count
    local total_n = r(N)
    count if female == 1
    local n_women = r(N)
    count if female == 0
    local n_men = r(N)

    local observed_years
    levelsof interview_year, local(observed_years)
    foreach observed_year of local observed_years {
        local valid_year : list observed_year in valid_interview_years
        if !`valid_year' {
            display as error "Unexpected interview year in Ghana DHS `year': `observed_year'"
            error 9
        }
    }
    assert sample_weight > 0 & sample_weight < .

    display as text "Validation summary for `year'"
    display as text "  Total observations: `total_n'"
    display as text "  Women: `n_women' | Men: `n_men'"
    display as text "  Interview years present: `observed_years'"

    compress
    if `write_wave_outputs' == 1 {
        save "`output_dir'/ghana_dhs_`year'_working.dta", replace
        display as text "Saved wave file: `output_dir'/ghana_dhs_`year'_working.dta"
    }

    tempfile wave_final
    save `wave_final', replace

    if `have_combined' == 0 {
        save `combined_data', replace
        local have_combined = 1
    }
    else {
        use `combined_data', clear
        append using `wave_final'
        save `combined_data', replace
    }
}

use `combined_data', clear
sort survey_year female cluster_id household_id respondent_id
compress
save "`output_dir'/`combined_basename'.dta", replace
display _newline as text "Saved combined selected-years file: `output_dir'/`combined_basename'.dta"
display as text "Combined N = " _N
levelsof survey_year, local(combined_years)
display as text "Survey years present: `combined_years'"

display _newline as text "============================================================"
display as text "Ghana DHS selected-years loader complete."
display as text "============================================================"

log close
