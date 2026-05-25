********************************************************************************
* 11_load_2008_disability_education_family_history.do
*
* Purpose: Load the 2008 SIPP topical wave for disability, education, marital,
*          migration, fertility, household-relationship history, and tax rebates.
********************************************************************************

********************************************************************************
* USER SETTINGS
********************************************************************************

* Optional manual path override:
* global sipp_root "/Users/yourname/path/to/econ-data-starters/sipp"
*
* Optional output override:
* global sipp_output_dir "/private/tmp/sipp_smoke"
* global sipp_output_basename "sipp_smoke"
*
* Wave 2 contains multiple life-history modules.
* global sipp_tm_lifehist_waves "2"
*
* Optional settings passed to the shared topical loader:
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_allocs 1
* global sipp_2008_tm_extra_vars "ALMTVER"

if "$sipp_tm_lifehist_waves" == "" {
    global sipp_tm_lifehist_waves "2"
}

global sipp_2008_tm_waves "$sipp_tm_lifehist_waves"
global sipp_2008_tm_family_tag "disability_education_family_history"
global sipp_2008_tm_family_label "Disability, education, marital, migration, fertility, household-relationship history, and tax rebates"
global sipp_2008_tm_family_note "Family-tagged topical extract for wave 2; it is not a harmonized cleaner."

local cwd "`c(pwd)'"
if "$sipp_root" != "" & fileexists("$sipp_root/code/09_load_2008_topical_modules.do") {
    local loader "$sipp_root/code/09_load_2008_topical_modules.do"
}
else if fileexists("code/09_load_2008_topical_modules.do") {
    local loader "code/09_load_2008_topical_modules.do"
}
else if fileexists("09_load_2008_topical_modules.do") {
    local loader "09_load_2008_topical_modules.do"
}
else if fileexists("sipp/code/09_load_2008_topical_modules.do") {
    local loader "sipp/code/09_load_2008_topical_modules.do"
}
else {
    display as error "Could not locate 09_load_2008_topical_modules.do. Run from sipp/, sipp/code/, repo root, or set sipp_root."
    error 601
}

do "`loader'"
