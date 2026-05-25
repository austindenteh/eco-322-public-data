********************************************************************************
* 03_load_linkable_modules.do
*
* Purpose: Load selected PSID linkable modules that use 1968 family/person IDs.
*          These files are separate from the main family/person-year starter.
*
* Outputs: output/psid_parent_id.dta
*          output/psid_marriage_history.dta
*          output/psid_childbirth_adoption_history.dta
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
* do "$psid_root/code/03_load_linkable_modules.do"
*
* Output and module options:
* global psid_output_dir "/private/tmp/psid_modules_smoke"
* global psid_output_basename "psid_modules"
* global psid_write_csv_export 1
* global psid_linkable_modules "parent_id marriage_history"
* global psid_linkable_modules "all"
* global psid_linkable_keep_all 0
* global psid_parent_extra_vars "PID23"
* global psid_marriage_extra_vars "MH1"
* global psid_childbirth_extra_vars "CAH103 CAH110 CAH112"

local cwd "`c(pwd)'"
if "$psid_root" != "" & fileexists("$psid_root/code/03_load_linkable_modules.do") {
    global psid_root "$psid_root"
}
else if fileexists("code/03_load_linkable_modules.do") & fileexists("README.md") {
    global psid_root "`cwd'"
}
else if fileexists("03_load_linkable_modules.do") & fileexists("../README.md") {
    global psid_root "`cwd'/.."
}
else if fileexists("psid/code/03_load_linkable_modules.do") & fileexists("psid/README.md") {
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

local modules "parent_id marriage_history childbirth_adoption"
if "$psid_linkable_modules" != "" {
    local requested = lower("$psid_linkable_modules")
    if "`requested'" == "all" {
        local modules "parent_id marriage_history childbirth_adoption"
    }
    else {
        local modules "`requested'"
    }
}

foreach m of local modules {
    if !inlist("`m'", "parent_id", "marriage_history", "childbirth_adoption") {
        display as error "Invalid PSID linkable module: `m'"
        display as error "Choose parent_id, marriage_history, childbirth_adoption, or all."
        error 198
    }
}

local keep_all = 1
if "$psid_linkable_keep_all" == "0" {
    local keep_all = 0
}

local write_csv_export = 0
if "$psid_write_csv_export" == "1" {
    local write_csv_export = 1
}

display as text "Using PSID root: $psid_root"
display as text "Selected PSID linkable modules: `modules'"

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

capture program drop psid_load_parent_id
program define psid_load_parent_id
    args output_dir output_basename keep_all write_csv_export
    local raw_dir "data/parent_identification/pid23"
    local setup_path "`raw_dir'/PID23.do"
    local txt_path "`raw_dir'/PID23.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing parent identification files."
        error 601
    }

    display as text "Reading PSID linkable module: parent_id"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    if !`keep_all' {
        local keep_vars "pid1 pid2 pid3 pid4 pid5 pid6 pid7 pid8 pid9 pid23 pid24 pid25 pid26 pid27 pid28"
        foreach raw of global psid_parent_extra_vars {
            local raw_l = lower("`raw'")
            capture confirm variable `raw_l'
            if !_rc local keep_vars "`keep_vars' `raw_l'"
        }
        local keep_vars: list uniq keep_vars
        keep `keep_vars'
    }

    psid_rename_if_exists pid1 release_number
    psid_rename_if_exists pid2 individual_1968_family_id
    psid_rename_if_exists pid3 individual_person_number
    psid_rename_if_exists pid4 birth_mother_1968_family_id
    psid_rename_if_exists pid5 birth_mother_person_number
    psid_rename_if_exists pid6 adoptive_mother1_1968_family_id
    psid_rename_if_exists pid7 adoptive_mother1_person_number
    psid_rename_if_exists pid8 adoptive_mother2_1968_family_id
    psid_rename_if_exists pid9 adoptive_mother2_person_number
    psid_rename_if_exists pid23 birth_father_1968_family_id
    psid_rename_if_exists pid24 birth_father_person_number
    psid_rename_if_exists pid25 adoptive_father1_1968_family_id
    psid_rename_if_exists pid26 adoptive_father1_person_number
    psid_rename_if_exists pid27 adoptive_father2_1968_family_id
    psid_rename_if_exists pid28 adoptive_father2_person_number

    gen str32 source_module = "parent_identification"
    gen str12 source_file = "PID23"
    order source_module source_file
    compress
    save "`output_dir'/`output_basename'_parent_id.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_parent_id.csv", replace
    }
    display as text "Saved parent_id: `output_dir'/`output_basename'_parent_id.dta"
end

capture program drop psid_load_marriage_history
program define psid_load_marriage_history
    args output_dir output_basename keep_all write_csv_export
    local raw_dir "data/marriage_history/mh85_23"
    local setup_path "`raw_dir'/MH85_23.do"
    local txt_path "`raw_dir'/MH85_23.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing marriage history files."
        error 601
    }

    display as text "Reading PSID linkable module: marriage_history"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    if !`keep_all' {
        local keep_vars "mh1 mh2 mh3 mh4 mh5 mh6 mh7 mh8 mh9 mh10 mh11 mh12 mh13 mh14 mh15 mh16 mh17 mh18 mh19 mh20"
        foreach raw of global psid_marriage_extra_vars {
            local raw_l = lower("`raw'")
            capture confirm variable `raw_l'
            if !_rc local keep_vars "`keep_vars' `raw_l'"
        }
        local keep_vars: list uniq keep_vars
        keep `keep_vars'
    }

    psid_rename_if_exists mh1 release_number
    psid_rename_if_exists mh2 individual_1968_family_id
    psid_rename_if_exists mh3 individual_person_number
    psid_rename_if_exists mh4 sex
    psid_rename_if_exists mh5 birth_month
    psid_rename_if_exists mh6 birth_year
    psid_rename_if_exists mh7 spouse_1968_family_id
    psid_rename_if_exists mh8 spouse_person_number
    psid_rename_if_exists mh9 marriage_order
    psid_rename_if_exists mh10 month_married
    psid_rename_if_exists mh11 year_married
    psid_rename_if_exists mh12 marriage_status
    psid_rename_if_exists mh13 month_widowed_or_divorced
    psid_rename_if_exists mh14 year_widowed_or_divorced
    psid_rename_if_exists mh15 month_separated
    psid_rename_if_exists mh16 year_separated
    psid_rename_if_exists mh17 year_most_recently_reported
    psid_rename_if_exists mh18 number_of_marriages
    psid_rename_if_exists mh19 last_known_marital_status
    psid_rename_if_exists mh20 number_of_marriage_records

    gen str32 source_module = "marriage_history"
    gen str12 source_file = "MH85_23"
    order source_module source_file
    compress
    save "`output_dir'/`output_basename'_marriage_history.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_marriage_history.csv", replace
    }
    display as text "Saved marriage_history: `output_dir'/`output_basename'_marriage_history.dta"
end

capture program drop psid_load_childbirth_adoption
program define psid_load_childbirth_adoption
    args output_dir output_basename keep_all write_csv_export
    local raw_dir "data/childbirth_adaoption_history/cah85_23"
    local setup_path "`raw_dir'/CAH85_23.do"
    local txt_path "`raw_dir'/CAH85_23.txt"
    if !fileexists("`setup_path'") | !fileexists("`txt_path'") {
        display as error "Missing childbirth/adoption history files."
        error 601
    }

    display as text "Reading PSID linkable module: childbirth_adoption"
    psid_run_setup "`setup_path'" "`raw_dir'"
    rename _all, lower

    if !`keep_all' {
        local keep_vars "cah1 cah2 cah3 cah4 cah5 cah6 cah7 cah8 cah9 cah10 cah11 cah12 cah13 cah15 cah16 cah22 cah23 cah24 cah25 cah26 cah27 cah28 cah29 cah30 cah35 cah36 cah37 cah54 cah75 cah103 cah110 cah112 cah114 cah115 cah116 cah117 cah118"
        foreach raw of global psid_childbirth_extra_vars {
            local raw_l = lower("`raw'")
            capture confirm variable `raw_l'
            if !_rc local keep_vars "`keep_vars' `raw_l'"
        }
        local keep_vars: list uniq keep_vars
        keep `keep_vars'
    }

    psid_rename_if_exists cah1 release_number
    psid_rename_if_exists cah2 record_type
    psid_rename_if_exists cah3 parent_1968_family_id
    psid_rename_if_exists cah4 parent_person_number
    psid_rename_if_exists cah5 parent_sex
    psid_rename_if_exists cah6 parent_birth_month
    psid_rename_if_exists cah7 parent_birth_year
    psid_rename_if_exists cah8 mother_marital_status_at_birth
    psid_rename_if_exists cah9 birth_order
    psid_rename_if_exists cah10 child_1968_family_id
    psid_rename_if_exists cah11 child_person_number
    psid_rename_if_exists cah12 child_sex
    psid_rename_if_exists cah13 child_birth_month
    psid_rename_if_exists cah15 child_birth_year
    psid_rename_if_exists cah16 child_birth_weight_ounces
    psid_rename_if_exists cah22 child_birth_state
    psid_rename_if_exists cah23 child_birth_county
    psid_rename_if_exists cah24 child_last_reported_location
    psid_rename_if_exists cah25 child_moved_out_or_died_month
    psid_rename_if_exists cah26 child_moved_out_or_died_year
    psid_rename_if_exists cah27 child_hispanicity
    psid_rename_if_exists cah28 child_race_1
    psid_rename_if_exists cah29 child_race_2
    psid_rename_if_exists cah30 child_race_3
    psid_rename_if_exists cah35 multiple_birth_checkpoint
    psid_rename_if_exists cah36 part_of_multiple_birth
    psid_rename_if_exists cah37 multiple_birth_type
    psid_rename_if_exists cah54 gestation_weeks
    psid_rename_if_exists cah75 prenatal_visits
    psid_rename_if_exists cah103 wanted_to_become_pregnant
    psid_rename_if_exists cah110 pregnancy_wanted_by_mother
    psid_rename_if_exists cah112 pregnancy_wanted_by_father
    psid_rename_if_exists cah114 year_reported_number_of_kids
    psid_rename_if_exists cah115 year_reported_this_child
    psid_rename_if_exists cah116 num_natural_or_adopted_children
    psid_rename_if_exists cah117 relationship_to_adoptive_parent
    psid_rename_if_exists cah118 number_birth_or_adoption_records

    gen str32 source_module = "childbirth_adoption_history"
    gen str12 source_file = "CAH85_23"
    order source_module source_file
    compress
    save "`output_dir'/`output_basename'_childbirth_adoption_history.dta", replace
    if `write_csv_export' {
        export delimited using "`output_dir'/`output_basename'_childbirth_adoption_history.csv", replace
    }
    display as text "Saved childbirth_adoption: `output_dir'/`output_basename'_childbirth_adoption_history.dta"
end

foreach m of local modules {
    if "`m'" == "parent_id" {
        psid_load_parent_id "`output_dir'" "`output_basename'" `keep_all' `write_csv_export'
    }
    else if "`m'" == "marriage_history" {
        psid_load_marriage_history "`output_dir'" "`output_basename'" `keep_all' `write_csv_export'
    }
    else if "`m'" == "childbirth_adoption" {
        psid_load_childbirth_adoption "`output_dir'" "`output_basename'" `keep_all' `write_csv_export'
    }
}
