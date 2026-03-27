set more off
clear all

capture noisily do "code/pipeline_config.do"
if (_rc != 0) do "pipeline_config.do"

args output_dir_override

local rawRoot "${PIPELINE_FUTURE_EMPIRICAL_ROOT}/dhs_fullsample_rebuild/ghana_2008_standard_dhs"
local womenFile "`rawRoot'/GHIR5ADT/GHIR5AFL.DTA"
local menFile   "`rawRoot'/GHMR5ADT/GHMR5AFL.DTA"

local outputDir "${PIPELINE_FUTURE_VALIDATION_ROOT}/dhs_pooled_rebuild"
if "`output_dir_override'" != "" {
    quietly pipeline_resolve_dir, path("`output_dir_override'")
    local outputDir "`r(resolved)'"
}

capture confirm file "`womenFile'"
if _rc {
    di as err "Missing women recode: `womenFile'"
    exit 601
}

capture confirm file "`menFile'"
if _rc {
    di as err "Missing men recode: `menFile'"
    exit 601
}

quietly pipeline_ensure_dir, path("`outputDir'")

capture log close
log using "`outputDir'/dhs_pooled_rebuild.log", text replace

tempfile women_common men_common pooled_summary

program drop _all

program define build_common_surface
    version 16.1
    syntax , SEX(integer)

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
        gen nhis_report_raw = v481c
        gen nhis_valid_card_raw = s1015d
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
        gen nhis_report_raw = mv481c
        gen nhis_valid_card_raw = sm815d
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

    order female source_sample cluster_id household_id respondent_id district_raw interview_month interview_year age_years ///
        region_raw residence_raw educ_level_raw educ_attain_raw literacy_raw ///
        wealth_raw marital_status_raw ever_married_raw working_now_raw ///
        religion_raw ethnicity_raw any_insurance_raw nhis_report_raw ///
        nhis_valid_card_raw Insured ValidNHISCard NHISCardReportedValid

    keep female source_sample cluster_id household_id respondent_id district_raw interview_month interview_year age_years ///
        region_raw residence_raw educ_level_raw educ_attain_raw literacy_raw ///
        wealth_raw marital_status_raw ever_married_raw working_now_raw ///
        religion_raw ethnicity_raw any_insurance_raw nhis_report_raw ///
        nhis_valid_card_raw Insured ValidNHISCard NHISCardReportedValid
end

use "`womenFile'", clear
quietly build_common_surface, sex(1)
save "`women_common'", replace

use "`menFile'", clear
quietly build_common_surface, sex(0)
save "`men_common'", replace

use "`women_common'", clear
append using "`men_common'"

sort female cluster_id household_id respondent_id
compress

save "`outputDir'/ghana_dhs_2008_pooled_common_surface_premerge.dta", replace
export delimited using "`outputDir'/ghana_dhs_2008_pooled_common_surface_premerge.csv", replace

preserve
collapse (count) N=Insured ///
         (mean) mean_insured=Insured ///
                mean_valid_card=ValidNHISCard ///
                mean_reported_valid_card=NHISCardReportedValid, by(female source_sample)
export delimited using "`outputDir'/ghana_dhs_2008_pooled_common_surface_summary.csv", replace
restore

di as txt "Saved pooled pre-merge validation surface to:"
di as txt "  `outputDir'/ghana_dhs_2008_pooled_common_surface_premerge.dta"
di as txt "Saved pooled summary to:"
di as txt "  `outputDir'/ghana_dhs_2008_pooled_common_surface_summary.csv"

log close
