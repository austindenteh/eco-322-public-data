********************************************************************************
* 14_load_2008_childcare_work_schedule_tax.do
*
* Purpose: Load 2008 SIPP topical waves with child care, work schedule, annual
*          income, retirement-account, and tax content.
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
* Waves 5 and 8 repeat child care, work schedule, annual income, and tax themes.
* global sipp_tm_childcare_tax_waves "5 8"
*
* Optional settings passed to the shared topical loader:
* global sipp_2008_tm_n_max 1000
* global sipp_2008_tm_allocs 1
* global sipp_2008_tm_extra_vars "AWSEMPCT"

if "$sipp_tm_childcare_tax_waves" == "" {
    global sipp_tm_childcare_tax_waves "5 8"
}

global sipp_2008_tm_waves "$sipp_tm_childcare_tax_waves"
global sipp_2008_tm_family_tag "childcare_work_schedule_tax"
global sipp_2008_tm_family_label "Child care, work schedule, annual income, retirement accounts, and taxes"
global sipp_2008_tm_family_note "Family-tagged topical extract for waves 5 and 8; it is not a harmonized cleaner."

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
