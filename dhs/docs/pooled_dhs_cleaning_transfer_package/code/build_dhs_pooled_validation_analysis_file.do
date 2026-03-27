set more off
clear all

capture noisily do "code/pipeline_config.do"
if (_rc != 0) do "pipeline_config.do"

args premerge_input_override output_dir_override gps_source_override

local default_premerge "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_rebuild/ghana_dhs_2008_pooled_common_surface_premerge.dta"
local default_output_dir "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_rebuild"
local default_gps_source "${PIPELINE_ACTIVE_EMPIRICS_ROOT}/GPS20082014_HFVisitData.dta"

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

capture confirm file "`premergeFile'"
if _rc {
    di as err "Missing pooled pre-merge file: `premergeFile'"
    exit 601
}

capture confirm file "`gpsSource'"
if _rc {
    di as err "Missing women-only empirical source file: `gpsSource'"
    exit 601
}

quietly pipeline_ensure_dir, path("`outputDir'")

capture log close
log using "`outputDir'/dhs_pooled_analysis_build.log", text replace

tempfile exposure_lookup
tempfile exposure_lookup_candidates
tempfile exposure_lookup_selected

tempfile gps_trimmed women_raw_bridge

use "`gpsSource'", clear
keep if Year == 2008
keep v001 v002 v003 District District1 DistrictDum MonthNHIS YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population
sort v001 v002 v003
save "`gps_trimmed'", replace

use "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2008_standard_dhs/GHIR5ADT/GHIR5AFL.DTA", clear
keep v001 v002 v003 v024 sdist
merge 1:1 v001 v002 v003 using "`gps_trimmed'", keep(match) nogen
rename v024 region_raw
rename sdist district_raw
rename District district_name
rename District1 district_id

contract region_raw district_raw district_name district_id DistrictDum ///
         MonthNHIS YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population
bysort region_raw district_raw: egen total_obs = total(_freq)
bysort region_raw district_raw: egen max_obs = max(_freq)
bysort region_raw district_raw: gen candidate_count = _N
gen candidate_share = _freq / total_obs
gen byte is_modal_candidate = (_freq == max_obs)
bysort region_raw district_raw: egen tied_modal_count = total(is_modal_candidate)
gsort region_raw district_raw -_freq district_id
by region_raw district_raw: gen modal_rank = _n

save "`exposure_lookup_candidates'", replace

export delimited using "`outputDir'/women_only_nhis_lookup_candidates.csv", replace

preserve
keep if modal_rank == 1
gen byte lookup_ambiguous = (candidate_count > 1)
gen byte lookup_modal_tie = (tied_modal_count > 1)
rename candidate_share lookup_modal_share
keep region_raw district_raw district_name district_id DistrictDum MonthNHIS ///
     YearNHIS OnlineSearch Hospitals Beds Doctors Nurses Population ///
     total_obs max_obs lookup_modal_share lookup_ambiguous lookup_modal_tie
save "`exposure_lookup_selected'", replace
export delimited using "`outputDir'/women_only_nhis_lookup_selected.csv", replace
restore

use "`exposure_lookup_selected'", clear
save "`exposure_lookup'", replace

use "`premergeFile'", clear

* Keep pooled age support aligned with the women's sample.
drop if age_years > 49

merge m:1 region_raw district_raw using "`exposure_lookup'", keep(master match) nogen

preserve
keep if missing(district_id)
if _N > 0 {
    collapse (count) N=female, by(region_raw district_raw)
    export delimited using "`outputDir'/dhs_pooled_missing_lookup_keys.csv", replace
}
restore

count if missing(district_id)
local missing_lookup_n = r(N)
if `missing_lookup_n' > 0 {
    di as txt "Validation note: dropping `missing_lookup_n' pooled observations without a women-only NHIS lookup."
    drop if missing(district_id)
}

gen MonthsImpNHIS = ((interview_year * 12 + interview_month) - (YearNHIS * 12 + MonthNHIS) - 2) / 12
gen MonthsImpNHIS_sq = MonthsImpNHIS^2

gen DistrictDum_pooled = DistrictDum

* Harmonized pooled validation covariates.
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

order female source_sample cluster_id household_id respondent_id ///
    interview_month interview_year district_name district_id DistrictDum_pooled ///
    MonthNHIS YearNHIS lookup_modal_share lookup_ambiguous lookup_modal_tie ///
    MonthsImpNHIS MonthsImpNHIS_sq OnlineSearch ///
    Insured ValidNHISCard NHISCardReportedValid Married Rural Literate ///
    Age26_34 Age35_40 Age41_49 PrimaryEduc SecondaryEduc HigherEduc ///
    Catholic Christian Muslim Traditional Akan GaEweGuan MoleDagbani ///
    wealth_raw Hospitals Beds Doctors Nurses Population

compress
save "`outputDir'/ghana_dhs_2008_pooled_analysis_file.dta", replace
export delimited using "`outputDir'/ghana_dhs_2008_pooled_analysis_file.csv", replace

preserve
collapse (count) N=Insured ///
         (mean) mean_insured=Insured ///
                mean_valid_card=ValidNHISCard ///
                mean_months_nhis=MonthsImpNHIS ///
                mean_lookup_modal_share=lookup_modal_share ///
                mean_lookup_ambiguous=lookup_ambiguous ///
                mean_married=Married ///
                mean_rural=Rural ///
                mean_literate=Literate, by(female source_sample)
export delimited using "`outputDir'/ghana_dhs_2008_pooled_analysis_summary.csv", replace
restore

di as txt "Saved pooled validation analysis file to:"
di as txt "  `outputDir'/ghana_dhs_2008_pooled_analysis_file.dta"
di as txt "Saved pooled validation analysis summary to:"
di as txt "  `outputDir'/ghana_dhs_2008_pooled_analysis_summary.csv"

log close
