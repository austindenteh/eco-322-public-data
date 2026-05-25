********************************************************************************
* 04_load_additional_modules.do
*
* Purpose: Load additional optional PSID modules that should not be merged into
*          the main starter by default.
*
* Outputs: output/psid_family_relation_matrix.dta
*          output/psid_pregnancy_intentions.dta
*          output/psid_active_savings.dta
********************************************************************************

clear all
set more off
set maxvar 32767

* ============================================================================
* 1. USER SETTINGS
* ============================================================================
*
* Optional manual path override:
* global psid_root "/Users/yourname/path/to/econ-data-starters/psid"
* do "$psid_root/code/04_load_additional_modules.do"
*
* Output and module options:
* global psid_output_dir "/private/tmp/psid_additional_smoke"
* global psid_output_basename "psid_additional"
* global psid_write_csv_export 1
* global psid_additional_modules "pregnancy_intentions active_savings"
* global psid_additional_modules "all"
* global psid_family_relation_years "2019 2021 2023"
* global psid_family_relation_years "all"
* global psid_pregnancy_extra_vars "PGINT9"
* global psid_active_savings_extra_vars "ACT89V3"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/04_load_additional_modules.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/04_load_additional_modules.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("04_load_additional_modules.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/04_load_additional_modules.do") & fileexists("psid/README.md") {
    global psid_root "`cwd'/psid"
}
else {
    display as error "Could not locate the psid/ directory."
    display as error "Run from psid/, psid/code/, repo root, or set global psid_root."
    error 601
}

cd "$psid_root"
capture mkdir "output"

local output_dir "output"
if "$psid_output_dir" != "" {
    local output_dir "$psid_output_dir"
    capture mkdir "`output_dir'"
}

local output_basename "psid"
if "$psid_output_basename" != "" {
    local output_basename "$psid_output_basename"
}

local modules "pregnancy_intentions active_savings family_relation_matrix"
if "$psid_additional_modules" != "" {
    local requested = lower("$psid_additional_modules")
    if "`requested'" == "all" {
        local modules "pregnancy_intentions active_savings family_relation_matrix"
    }
    else {
        local modules "`requested'"
    }
}

foreach m of local modules {
    if !inlist("`m'", "family_relation_matrix", "pregnancy_intentions", "active_savings") {
        display as error "Invalid PSID additional module: `m'"
        display as error "Choose family_relation_matrix, pregnancy_intentions, active_savings, or all."
        error 198
    }
}

* Default to the latest family relationship matrix year. Use "all" for all years.
local relation_years "2023"
if "$psid_family_relation_years" != "" {
    local relation_years = lower("$psid_family_relation_years")
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected PSID additional modules: `modules'"

capture program drop psid_run_setup
program define psid_run_setup
    args setup_path raw_dir
    tempfile setup_tmp
    file open rin using "`setup_path'", read
    file open rout using "`setup_tmp'", write replace
    file read rin line
    while r(eof) == 0 {
        local line = subinstr(`"`line'"', `"using [path]\"', `"using "`raw_dir'/"', .)
        local line = subinstr(`"`line'"', `"using [path]/"', `"using "`raw_dir'/"', .)
        local line = subinstr(`"`line'"', `".txt, clear"', `".txt", clear"', .)
        file write rout `"`line'"' _n
        file read rin line
    }
    file close rin
    file close rout
    do "`setup_tmp'"
end

capture program drop psid_rename_if_exists
program define psid_rename_if_exists
    args old new
    capture confirm variable `old'
    if !_rc {
        capture confirm variable `new'
        if _rc {
            rename `old' `new'
        }
    }
end

capture program drop psid_load_family_relation_matrix
program define psid_load_family_relation_matrix
    args output_dir output_basename relation_years write_csv_export
    local raw_dir "data/family_relation_matrix/MX23REL"
    local setup_path "`raw_dir'/MX23REL.do"
    local txt_path "`raw_dir'/MX23REL.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing family relationship matrix files."
        error 601
    }

    display as text "Reading PSID additional module: family_relation_matrix"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower
    psid_rename_if_exists mx1 release_number
    psid_rename_if_exists mx2 interview_year
    psid_rename_if_exists mx3 family_interview_id
    psid_rename_if_exists mx4 ego_sequence_number
    psid_rename_if_exists mx5 ego_1968_family_id
    psid_rename_if_exists mx6 ego_person_number
    psid_rename_if_exists mx7 ego_relation_to_reference
    psid_rename_if_exists mx8 ego_relation_to_alter
    psid_rename_if_exists mx9 alter_sequence_number
    psid_rename_if_exists mx10 alter_1968_family_id
    psid_rename_if_exists mx11 alter_person_number
    psid_rename_if_exists mx12 alter_relation_to_reference

    if "`relation_years'" != "all" {
        local keep_expression "0"
        foreach y of local relation_years {
            local keep_expression "`keep_expression' | interview_year == `y'"
        }
        keep if `keep_expression'
    }

    gen str32 source_module = "family_relation_matrix"
    gen str12 source_file = "MX23REL"
    order source_module source_file
    compress
    save "`output_dir'/`output_basename'_family_relation_matrix.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_family_relation_matrix.csv", replace
    }
    display as text "Saved family_relation_matrix: `output_dir'/`output_basename'_family_relation_matrix.dta"
end

capture program drop psid_load_pregnancy_intentions
program define psid_load_pregnancy_intentions
    args output_dir output_basename write_csv_export
    local raw_dir "data/pregnancy_intentions/pregint23"
    local setup_path "`raw_dir'/PREGINT23.do"
    local txt_path "`raw_dir'/PREGINT23.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing pregnancy intentions files."
        error 601
    }

    display as text "Reading PSID additional module: pregnancy_intentions"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower
    local keep_vars "pgint1 pgint2 pgint3 pgint4 pgint5 pgint6 pgint7 pgint8 pgint9 pgint10 pgint11 pgint12"
    local pregnancy_extra_vars = lower("$psid_pregnancy_extra_vars")
    foreach extra of local pregnancy_extra_vars {
        capture confirm variable `extra'
        if !_rc {
            local keep_vars "`keep_vars' `extra'"
        }
        else {
            display as text "Requested pregnancy extra variable not found; skipping: `extra'"
        }
    }
    keep `keep_vars'
    psid_rename_if_exists pgint1 release_number
    psid_rename_if_exists pgint2 individual_1968_family_id
    psid_rename_if_exists pgint3 individual_person_number
    psid_rename_if_exists pgint4 report_year
    psid_rename_if_exists pgint5 reporter_sex
    psid_rename_if_exists pgint6 newborn_parent_checkpoint
    psid_rename_if_exists pgint7 wants_another_child
    psid_rename_if_exists pgint8 wants_or_not_another_child
    psid_rename_if_exists pgint9 current_partner_checkpoint
    psid_rename_if_exists pgint10 partner_wants_another_child
    psid_rename_if_exists pgint11 more_children_intended
    psid_rename_if_exists pgint12 contraception_last_3_months
    gen str32 source_module = "pregnancy_intentions"
    gen str12 source_file = "PREGINT23"
    order source_module source_file
    compress
    save "`output_dir'/`output_basename'_pregnancy_intentions.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_pregnancy_intentions.csv", replace
    }
    display as text "Saved pregnancy_intentions: `output_dir'/`output_basename'_pregnancy_intentions.dta"
end

capture program drop psid_load_active_savings_one
program define psid_load_active_savings_one
    args year temp_out
    local raw_dir "data/active_savings/ActSavings89_94"
    if "`year'" == "1989" {
        local base "ACT89"
        local prefix "act89v"
    }
    else {
        local base "ACT94"
        local prefix "act94v"
    }

    psid_run_setup "`raw_dir'/`base'.do" "`raw_dir'"
    rename _all, lower
    rename `prefix'1 release_number
    rename `prefix'2 family_interview_id
    rename `prefix'3 put_into_annuity
    rename `prefix'4 cash_in_annuity
    rename `prefix'5 buy_real_estate
    rename `prefix'6 sell_real_estate
    rename `prefix'7 home_improvement
    rename `prefix'8 buy_business
    rename `prefix'9 sell_business
    rename `prefix'10 assets_move_out
    rename `prefix'11 debts_move_out
    rename `prefix'12 assets_brought_in
    rename `prefix'13 debts_brought_in
    rename `prefix'14 gift_inheritance_1
    rename `prefix'15 gift_inheritance_2
    if "`year'" == "1989" {
        rename `prefix'16 net_into_stock
        gen gift_inheritance_3 = .
        gen sell_main_home = .
    }
    else {
        rename `prefix'16 gift_inheritance_3
        rename `prefix'17 net_into_stock
        rename `prefix'18 sell_main_home
    }
    gen survey_year = `year'
    gen str12 source_file = "`base'"
    save "`temp_out'", replace
end

capture program drop psid_load_active_savings
program define psid_load_active_savings
    args output_dir output_basename write_csv_export
    display as text "Reading PSID additional module: active_savings"
    tempfile act89 act94
    psid_load_active_savings_one 1989 "`act89'"
    psid_load_active_savings_one 1994 "`act94'"
    use "`act89'", clear
    append using "`act94'"
    gen str32 source_module = "active_savings"
    order source_module source_file survey_year family_interview_id
    compress
    save "`output_dir'/`output_basename'_active_savings.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_active_savings.csv", replace
    }
    display as text "Saved active_savings: `output_dir'/`output_basename'_active_savings.dta"
end

foreach m of local modules {
    if "`m'" == "family_relation_matrix" {
        psid_load_family_relation_matrix "`output_dir'" "`output_basename'" "`relation_years'" `write_csv_export'
    }
    else if "`m'" == "pregnancy_intentions" {
        psid_load_pregnancy_intentions "`output_dir'" "`output_basename'" `write_csv_export'
    }
    else if "`m'" == "active_savings" {
        psid_load_active_savings "`output_dir'" "`output_basename'" `write_csv_export'
    }
}
