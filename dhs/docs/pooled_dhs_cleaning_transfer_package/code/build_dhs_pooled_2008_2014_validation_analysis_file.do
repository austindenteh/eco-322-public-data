set more off
clear all

capture noisily do "code/pipeline_config.do"
if (_rc != 0) do "pipeline_config.do"

args premerge_input_override output_dir_override gps_source_override women2008_override women2014_override

local default_premerge "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_2008_2014_rebuild/ghana_dhs_2008_2014_pooled_common_surface_premerge.dta"
local default_output_dir "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_2008_2014_rebuild"
local default_gps_source "${PIPELINE_ACTIVE_EMPIRICS_ROOT}/GPS20082014_HFVisitData.dta"
local default_women2008 "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2008_standard_dhs/GHIR5ADT/GHIR5AFL.DTA"
local default_women2014 "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2014_standard_dhs/GHIR72DT/GHIR72FL.DTA"

if "`premerge_input_override'" == "" local premergeFile "`default_premerge'"
else {
    quietly pipeline_resolve_dir, path("`premerge_input_override'")
    local premergeFile "`r(resolved)'"
}

if "`output_dir_override'" == "" local outputDir "`default_output_dir'"
else {
    quietly pipeline_resolve_dir, path("`output_dir_override'")
    local outputDir "`r(resolved)'"
}

if "`gps_source_override'" == "" local gpsSource "`default_gps_source'"
else {
    quietly pipeline_resolve_dir, path("`gps_source_override'")
    local gpsSource "`r(resolved)'"
}

if "`women2008_override'" == "" local women2008 "`default_women2008'"
else {
    quietly pipeline_resolve_dir, path("`women2008_override'")
    local women2008 "`r(resolved)'"
}

if "`women2014_override'" == "" local women2014 "`default_women2014'"
else {
    quietly pipeline_resolve_dir, path("`women2014_override'")
    local women2014 "`r(resolved)'"
}

capture confirm file "`premergeFile'"
if _rc {
    di as err "Missing 2008+2014 pooled pre-merge file: `premergeFile'"
    exit 601
}

capture confirm file "`gpsSource'"
if _rc {
    di as err "Missing women-only empirical source file: `gpsSource'"
    exit 601
}

capture confirm file "`women2008'"
if _rc {
    di as err "Missing 2008 women recode: `women2008'"
    exit 601
}

capture confirm file "`women2014'"
if _rc {
    di as err "Missing 2014 women recode: `women2014'"
    di as err "Stage GHIR72FL.DTA under data/empirical/dhs_fullsample_rebuild/ghana_2014_standard_dhs/ or pass an explicit override."
    exit 601
}

quietly pipeline_ensure_dir, path("`outputDir'")

capture log close
log using "`outputDir'/dhs_pooled_2008_2014_analysis_build.log", text replace

tempfile exposure_lookup
tempfile exposure_lookup_candidates
tempfile exposure_lookup_selected

tempfile gps_trimmed women_raw_bridge women2008_bridge women2014_bridge

use "`gpsSource'", clear
keep if inlist(Year, 2008, 2014)
rename Year survey_wave_year
keep survey_wave_year v001 v002 v003 District District1 DistrictDum MonthNHIS YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population
sort survey_wave_year v001 v002 v003
save "`gps_trimmed'", replace

use "`women2008'", clear
gen survey_wave_year = 2008
keep survey_wave_year v001 v002 v003 v024 sdist
save "`women2008_bridge'", replace

use "`women2014'", clear
gen survey_wave_year = 2014
keep survey_wave_year v001 v002 v003 v024 sdist
save "`women2014_bridge'", replace

use "`women2008_bridge'", clear
append using "`women2014_bridge'"
save "`women_raw_bridge'", replace

use "`women_raw_bridge'", clear
merge 1:1 survey_wave_year v001 v002 v003 using "`gps_trimmed'", keep(match) nogen
rename v024 region_raw
rename sdist district_raw
rename District district_name
rename District1 district_id

contract survey_wave_year region_raw district_raw district_name district_id DistrictDum ///
         MonthNHIS YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population
bysort survey_wave_year region_raw district_raw: egen total_obs = total(_freq)
bysort survey_wave_year region_raw district_raw: egen max_obs = max(_freq)
bysort survey_wave_year region_raw district_raw: gen candidate_count = _N
gen candidate_share = _freq / total_obs
gen byte is_modal_candidate = (_freq == max_obs)
bysort survey_wave_year region_raw district_raw: egen tied_modal_count = total(is_modal_candidate)
gsort survey_wave_year region_raw district_raw -_freq district_id
by survey_wave_year region_raw district_raw: gen modal_rank = _n

save "`exposure_lookup_candidates'", replace
export delimited using "`outputDir'/women_only_nhis_lookup_candidates_2008_2014.csv", replace

preserve
keep if modal_rank == 1
gen byte lookup_ambiguous = (candidate_count > 1)
gen byte lookup_modal_tie = (tied_modal_count > 1)
rename candidate_share lookup_modal_share
keep survey_wave_year region_raw district_raw district_name district_id DistrictDum MonthNHIS ///
     YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population ///
     total_obs max_obs lookup_modal_share lookup_ambiguous lookup_modal_tie
save "`exposure_lookup_selected'", replace
export delimited using "`outputDir'/women_only_nhis_lookup_selected_2008_2014.csv", replace
restore

use "`exposure_lookup_selected'", clear
save "`exposure_lookup'", replace

use "`premergeFile'", clear

drop if age_years > 49

merge m:1 survey_wave_year region_raw district_raw using "`exposure_lookup'", keep(master match) nogen

preserve
keep if missing(district_id)
if _N > 0 {
    collapse (count) N=female, by(survey_wave_year region_raw district_raw)
    export delimited using "`outputDir'/dhs_pooled_2008_2014_missing_lookup_keys.csv", replace
}
restore

count if missing(district_id)
local missing_lookup_n = r(N)
if `missing_lookup_n' > 0 {
    di as txt "Validation note: dropping `missing_lookup_n' stacked pooled observations without a women-only NHIS lookup."
    drop if missing(district_id)
}

gen MonthsImpNHIS = ((interview_year * 12 + interview_month) - (YearNHIS * 12 + MonthNHIS) - 2) / 12
gen MonthsImpNHIS_sq = MonthsImpNHIS^2

gen DistrictDum_pooled = DistrictDum
gen Survey2014 = (survey_wave_year == 2014) if !missing(survey_wave_year)

gen Married = (marital_status_raw == 1) if !missing(marital_status_raw)
gen Rural = (residence_raw == 2) if !missing(residence_raw)
gen Literate = inlist(literacy_raw, 1, 2, 3) if !missing(literacy_raw)

gen Age26_34 = inrange(age_years, 26, 34) if !missing(age_years)
gen Age35_40 = inrange(age_years, 35, 40) if !missing(age_years)
gen Age41_49 = inrange(age_years, 41, 49) if !missing(age_years)

gen PrimaryEduc = (educ_level_raw == 1) if !missing(educ_level_raw)
gen SecondaryEduc = (educ_level_raw == 2) if !missing(educ_level_raw)
gen HigherEduc = (educ_level_raw == 3) if !missing(educ_level_raw)

gen Catholic = (religion_raw == 1) if !missing(religion_raw)
gen Christian = inlist(religion_raw, 2, 3, 4, 5, 6) if !missing(religion_raw)
gen Muslim = (religion_raw == 7) if !missing(religion_raw)
gen Traditional = (religion_raw == 8) if !missing(religion_raw)

gen Akan = (ethnicity_raw == 1) if !missing(ethnicity_raw)
gen GaEweGuan = inlist(ethnicity_raw, 2, 3, 4) if !missing(ethnicity_raw)
gen MoleDagbani = (ethnicity_raw == 5) if !missing(ethnicity_raw)

label var survey_wave_year "Survey wave year"
label var Survey2014 "Survey wave is 2014"
label var district_name "District name from women-only NHIS lookup"
label var district_id "District code from women-only NHIS lookup"
label var DistrictDum_pooled "District clustering code from women-only NHIS lookup"
label var MonthNHIS "District NHIS rollout month"
label var YearNHIS "District NHIS rollout year"
label var OnlineSearch "Online-search district marker from women-only source"
label var Hospitals "Hospitals per 1,000 population"
label var Beds "Beds per 1,000 population"
label var Doctors "Doctors per 1,000 population"
label var Nurses "Nurses per 1,000 population"
label var Population "Population"
label var lookup_modal_share "Modal-share strength of women-only district crosswalk"
label var lookup_ambiguous "Women-only district crosswalk had multiple candidate mappings"
label var lookup_modal_tie "Women-only district crosswalk had a modal tie"
label var MonthsImpNHIS "Years of NHIS exposure"
label var MonthsImpNHIS_sq "Squared years of NHIS exposure"
label var Married "Currently married"
label var Rural "Rural residence"
label var Literate "Can read part/all sentence or no card with required language"
label var Age26_34 "Age 26 to 34 years"
label var Age35_40 "Age 35 to 40 years"
label var Age41_49 "Age 41 to 49 years"
label var PrimaryEduc "Primary education"
label var SecondaryEduc "Secondary education"
label var HigherEduc "Higher education"
label var Catholic "Catholic"
label var Christian "Other Christian"
label var Muslim "Muslim"
label var Traditional "Traditional/spiritualist"
label var Akan "Akan"
label var GaEweGuan "Ga/Dangme, Ewe, or Guan"
label var MoleDagbani "Mole-Dagbani"

order survey_wave_year Survey2014 female source_sample cluster_id household_id respondent_id ///
    interview_month interview_year district_name district_id DistrictDum_pooled ///
    MonthNHIS YearNHIS lookup_modal_share lookup_ambiguous lookup_modal_tie ///
    MonthsImpNHIS MonthsImpNHIS_sq OnlineSearch ///
    Insured ValidNHISCard NHISCardReportedValid Married Rural Literate ///
    Age26_34 Age35_40 Age41_49 PrimaryEduc SecondaryEduc HigherEduc ///
    Catholic Christian Muslim Traditional Akan GaEweGuan MoleDagbani ///
    wealth_raw Hospitals Beds Doctors Nurses Population

compress
save "`outputDir'/ghana_dhs_2008_2014_pooled_analysis_file.dta", replace
export delimited using "`outputDir'/ghana_dhs_2008_2014_pooled_analysis_file.csv", replace

preserve
collapse (count) N=Insured ///
         (mean) mean_insured=Insured ///
                mean_valid_card=ValidNHISCard ///
                mean_months_nhis=MonthsImpNHIS ///
                mean_lookup_modal_share=lookup_modal_share ///
                mean_lookup_ambiguous=lookup_ambiguous ///
                mean_married=Married ///
                mean_rural=Rural ///
                mean_literate=Literate, by(survey_wave_year female source_sample)
export delimited using "`outputDir'/ghana_dhs_2008_2014_pooled_analysis_summary.csv", replace
restore

di as txt "Saved 2008+2014 pooled validation analysis file to:"
di as txt "  `outputDir'/ghana_dhs_2008_2014_pooled_analysis_file.dta"
di as txt "Saved 2008+2014 pooled validation analysis summary to:"
di as txt "  `outputDir'/ghana_dhs_2008_2014_pooled_analysis_summary.csv"

log close
