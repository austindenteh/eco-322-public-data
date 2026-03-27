set more off
clear all

capture noisily do "code/pipeline_config.do"
if (_rc != 0) do "pipeline_config.do"

args output_dir_override women2008_override men2008_override women2014_override men2014_override

local rawRoot2008 "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2008_standard_dhs"
local rawRoot2014 "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2014_standard_dhs"

local womenFile2008 "`rawRoot2008'/GHIR5ADT/GHIR5AFL.DTA"
local menFile2008   "`rawRoot2008'/GHMR5ADT/GHMR5AFL.DTA"
local womenFile2014 "`rawRoot2014'/GHIR72DT/GHIR72FL.DTA"
local menFile2014   "`rawRoot2014'/GHMR71DT/GHMR71FL.DTA"

if "`women2008_override'" != "" {
    quietly pipeline_resolve_dir, path("`women2008_override'")
    local womenFile2008 "`r(resolved)'"
}
if "`men2008_override'" != "" {
    quietly pipeline_resolve_dir, path("`men2008_override'")
    local menFile2008 "`r(resolved)'"
}
if "`women2014_override'" != "" {
    quietly pipeline_resolve_dir, path("`women2014_override'")
    local womenFile2014 "`r(resolved)'"
}
if "`men2014_override'" != "" {
    quietly pipeline_resolve_dir, path("`men2014_override'")
    local menFile2014 "`r(resolved)'"
}

local outputDir "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_2008_2014_rebuild"
if "`output_dir_override'" != "" {
    quietly pipeline_resolve_dir, path("`output_dir_override'")
    local outputDir "`r(resolved)'"
}

capture confirm file "`womenFile2008'"
if _rc {
    di as err "Missing 2008 women recode: `womenFile2008'"
    exit 601
}

capture confirm file "`menFile2008'"
if _rc {
    di as err "Missing 2008 men recode: `menFile2008'"
    exit 601
}

capture confirm file "`womenFile2014'"
if _rc {
    di as err "Missing 2014 women recode: `womenFile2014'"
    di as err "Stage GHIR72FL.DTA under data/empirical/dhs_fullsample_rebuild/ghana_2014_standard_dhs/ or pass an explicit override."
    exit 601
}

capture confirm file "`menFile2014'"
if _rc {
    di as err "Missing 2014 men recode: `menFile2014'"
    di as err "Stage GHMR71FL.DTA under data/empirical/dhs_fullsample_rebuild/ghana_2014_standard_dhs/ or pass an explicit override."
    exit 601
}

quietly pipeline_ensure_dir, path("`outputDir'")

capture log close
log using "`outputDir'/dhs_pooled_2008_2014_rebuild.log", text replace

tempfile women2008_common men2008_common women2014_common men2014_common pooled_summary

program drop _all

program define build_common_surface
    version 16.1
    syntax , SEX(integer) SURVEYYEAR(integer)

    gen survey_wave_year = `surveyyear'

    if `sex' == 1 {
        gen byte female = 1
        gen str5 source_sample = "women"

        gen cluster_id = v001
        gen household_id = v002
        gen respondent_id = v003
        gen district_raw = sdist
        gen interview_month = v006
        gen interview_year = v007
        gen age_years = v012
        gen region_raw = v024
        gen residence_raw = v025
        gen educ_level_raw = v106
        gen educ_attain_raw = v149
        gen literacy_raw = v155
        gen wealth_raw = v190
        gen marital_status_raw = v501
        gen ever_married_raw = v502
        gen working_now_raw = v714
        gen religion_raw = v130
        gen ethnicity_raw = v131
        gen any_insurance_raw = v481
        if `surveyyear' == 2008 {
            gen nhis_report_raw = v481c
        }
        else if `surveyyear' == 2014 {
            gen nhis_report_raw = v481e
        }
        else {
            di as err "Unsupported women survey year for NHIS report mapping: `surveyyear'"
            exit 111
        }
        capture confirm variable s1015d
        if _rc == 0 gen nhis_valid_card_raw = s1015d
        else {
            capture confirm variable s1015
            if _rc != 0 {
                di as err "Could not find a women NHIS valid-card variable for survey year `surveyyear'."
                exit 111
            }
            gen nhis_valid_card_raw = s1015
        }
    }
    else {
        gen byte female = 0
        gen str3 source_sample = "men"

        gen cluster_id = mv001
        gen household_id = mv002
        gen respondent_id = mv003
        gen district_raw = smdist
        gen interview_month = mv006
        gen interview_year = mv007
        gen age_years = mv012
        gen region_raw = mv024
        gen residence_raw = mv025
        gen educ_level_raw = mv106
        gen educ_attain_raw = mv149
        gen literacy_raw = mv155
        gen wealth_raw = mv190
        gen marital_status_raw = mv501
        gen ever_married_raw = mv502
        gen working_now_raw = mv714
        gen religion_raw = mv130
        gen ethnicity_raw = mv131
        gen any_insurance_raw = mv481
        if `surveyyear' == 2008 {
            gen nhis_report_raw = mv481c
        }
        else if `surveyyear' == 2014 {
            gen nhis_report_raw = mv481e
        }
        else {
            di as err "Unsupported men survey year for NHIS report mapping: `surveyyear'"
            exit 111
        }
        capture confirm variable sm815d
        if _rc == 0 gen nhis_valid_card_raw = sm815d
        else {
            capture confirm variable sm818
            if _rc != 0 {
                di as err "Could not find a men NHIS valid-card variable for survey year `surveyyear'."
                exit 111
            }
            gen nhis_valid_card_raw = sm818
        }
    }

    foreach v in any_insurance_raw nhis_report_raw nhis_valid_card_raw {
        replace `v' = . if `v' == 9
    }

    gen byte Insured = .
    replace Insured = 1 if nhis_report_raw == 1
    replace Insured = 0 if nhis_report_raw == 0

    gen byte NHISCardReportedValid = .
    replace NHISCardReportedValid = 1 if inlist(nhis_valid_card_raw, 1, 2)
    replace NHISCardReportedValid = 0 if nhis_valid_card_raw == 0
    replace NHISCardReportedValid = 0 if Insured == 0

    gen byte ValidNHISCard = .
    replace ValidNHISCard = 1 if nhis_valid_card_raw == 1
    replace ValidNHISCard = 0 if inlist(nhis_valid_card_raw, 0, 2)
    replace ValidNHISCard = 0 if Insured == 0

    label var survey_wave_year "Survey wave year"
    label var female "Female respondent indicator"
    label var cluster_id "Survey cluster id"
    label var household_id "Survey household id"
    label var respondent_id "Survey respondent line number"
    label var district_raw "Raw DHS district code"
    label var interview_month "Interview month"
    label var interview_year "Interview year"
    label var age_years "Current age in years"
    label var region_raw "Region raw code"
    label var residence_raw "Residence raw code"
    label var educ_level_raw "Highest educational level raw code"
    label var educ_attain_raw "Educational attainment raw code"
    label var literacy_raw "Literacy raw code"
    label var wealth_raw "Wealth raw code"
    label var marital_status_raw "Current marital status raw code"
    label var ever_married_raw "Ever-married grouping raw code"
    label var working_now_raw "Currently working raw code"
    label var religion_raw "Religion raw code"
    label var ethnicity_raw "Ethnicity raw code"
    label var any_insurance_raw "Any health insurance raw code"
    label var nhis_report_raw "NHIS self-report raw code"
    label var nhis_valid_card_raw "NHIS valid-card raw code"
    label var Insured "Reported NHIS coverage"
    label var ValidNHISCard "Validated NHIS coverage (card seen)"
    label var NHISCardReportedValid "Valid NHIS card reported (seen or not seen)"

    order survey_wave_year female source_sample cluster_id household_id respondent_id district_raw interview_month interview_year age_years ///
        region_raw residence_raw educ_level_raw educ_attain_raw literacy_raw ///
        wealth_raw marital_status_raw ever_married_raw working_now_raw ///
        religion_raw ethnicity_raw any_insurance_raw nhis_report_raw ///
        nhis_valid_card_raw Insured ValidNHISCard NHISCardReportedValid

    keep survey_wave_year female source_sample cluster_id household_id respondent_id district_raw interview_month interview_year age_years ///
        region_raw residence_raw educ_level_raw educ_attain_raw literacy_raw ///
        wealth_raw marital_status_raw ever_married_raw working_now_raw ///
        religion_raw ethnicity_raw any_insurance_raw nhis_report_raw ///
        nhis_valid_card_raw Insured ValidNHISCard NHISCardReportedValid
end

use "`womenFile2008'", clear
quietly build_common_surface, sex(1) surveyyear(2008)
save "`women2008_common'", replace

use "`menFile2008'", clear
quietly build_common_surface, sex(0) surveyyear(2008)
save "`men2008_common'", replace

use "`womenFile2014'", clear
quietly build_common_surface, sex(1) surveyyear(2014)
save "`women2014_common'", replace

use "`menFile2014'", clear
quietly build_common_surface, sex(0) surveyyear(2014)
save "`men2014_common'", replace

use "`women2008_common'", clear
append using "`men2008_common'"
append using "`women2014_common'"
append using "`men2014_common'"

sort survey_wave_year female cluster_id household_id respondent_id
compress

save "`outputDir'/ghana_dhs_2008_2014_pooled_common_surface_premerge.dta", replace
export delimited using "`outputDir'/ghana_dhs_2008_2014_pooled_common_surface_premerge.csv", replace

preserve
collapse (count) N=Insured ///
         (mean) mean_insured=Insured ///
                mean_valid_card=ValidNHISCard ///
                mean_reported_valid_card=NHISCardReportedValid, by(survey_wave_year female source_sample)
export delimited using "`outputDir'/ghana_dhs_2008_2014_pooled_common_surface_summary.csv", replace
restore

di as txt "Saved 2008+2014 pooled pre-merge validation surface to:"
di as txt "  `outputDir'/ghana_dhs_2008_2014_pooled_common_surface_premerge.dta"
di as txt "Saved 2008+2014 pooled summary to:"
di as txt "  `outputDir'/ghana_dhs_2008_2014_pooled_common_surface_summary.csv"

log close
