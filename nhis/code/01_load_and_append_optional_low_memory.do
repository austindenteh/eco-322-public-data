********************************************************************************
* 01_load_and_append_optional_low_memory.do
*
* Purpose: Optional low-memory entry point for the NHIS starter.
*          Runs 01_load_and_append.do with starter-variable mode enabled, so
*          full 2004-2024 builds keep only the columns needed by
*          02_clean_and_analyze.do plus user-requested extras.
*
* Important: This script reuses the main NHIS loader and harmonization logic.
*            It does NOT import every raw variable. If you need most raw NHIS
*            columns, use 01_load_and_append.do without low-memory mode.
*
* Input:   data/NHIS YYYY/ folders
* Output:  output/nhis_adult.dta
*          output/nhis_child.dta
*
* Usage:   Run from nhis/, from nhis/code/, from the repo root, or set
*          global nhis_root.
*
* Author:  Austin Denteh (legacy code), Claude Code, and Codex
* Date:    May 2026
********************************************************************************

clear all
set more off

* Optional manual path override. Uncomment and edit if auto-detection fails:
* global nhis_root "/Users/yourname/path/to/econ-data-starters/nhis"
* Then run: do "$nhis_root/code/01_load_and_append_optional_low_memory.do"

local cwd "`c(pwd)'"
if "$nhis_root" != "" & fileexists("$nhis_root/code/01_load_and_append_optional_low_memory.do") {
    global nhis_root "$nhis_root"
}
else if fileexists("code/01_load_and_append_optional_low_memory.do") & fileexists("README.md") {
    global nhis_root "`cwd'"
}
else if fileexists("01_load_and_append_optional_low_memory.do") & fileexists("../README.md") {
    global nhis_root "`cwd'/.."
}
else if fileexists("nhis/code/01_load_and_append_optional_low_memory.do") & fileexists("nhis/README.md") {
    global nhis_root "`cwd'/nhis"
}
else {
    display as error "Could not locate the nhis/ directory."
    display as error "Run from nhis/, nhis/code/, from the repo root, or set global nhis_root."
    display as error `"Manual override: global nhis_root "/path/to/nhis""'
    error 601
}

* Default to the full NHIS span in the optional low-memory entry point.
* Override these globals before running this script if you want a smaller test.
if "$nhis_lm_default_years" == "" {
    global nhis_lm_default_years "1"
}
if "$nhis_lm_default_years" != "0" & "$nhis_pre2019_years" == "" {
    global nhis_pre2019_years "2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018"
}
if "$nhis_lm_default_years" != "0" & "$nhis_post2019_years" == "" {
    global nhis_post2019_years "2019 2020 2021 2022 2023 2024"
}

* Enable low-memory mode in the main loader. Add stable-name extras or alias
* families before running this script. Examples:
*
*   global nhis_extra_keep_vars "regionbr_a plborn_a"
*
*   global nhis_extra_var_families ///
*       `" "health_status_raw:phstat_a phstat_c phstat" "'
*
* Alias families merge columns by name only. If coding or meanings differ
* across eras, harmonize that added variable later.
global nhis_keep_starter_vars_only 1
local _extra_keep_vars "$nhis_extra_keep_vars"
if trim(`"`_extra_keep_vars'"') == "" {
    global nhis_extra_keep_vars ""
}
local _extra_var_families `"$nhis_extra_var_families"'
if trim(`"`_extra_var_families'"') == "" {
    global nhis_extra_var_families ""
}

do "$nhis_root/code/01_load_and_append.do"
