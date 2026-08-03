# BRFSS Pre-2011 Inventory

This note records the source-file and value-level checks used to build the public BRFSS pre-2011 starter. It covers the landline/post-stratification era available in this folder, 2000-2010.

The 2011-plus workflow remains separate because the 2011 BRFSS added cell-phone interviews and changed from post-stratification to raking weights. The starter does not silently pool across that design break.

## Raw Data Files

Place these CDC SAS Transport archives in `brfss/data/raw/`. The loaders also accept an already extracted `CDBRFSYY.XPT`; archive names and member names are matched without regard to case.

| Year | Local archive | XPT inside archive | Rows | Raw variables |
|---:|---|---|---:|---:|
| 2000 | `CDBRFS00XPT.ZIP` | `CDBRFS00.XPT` | 184,450 | 289 |
| 2001 | `CDBRFS01XPT.zip` | `CDBRFS01.XPT` | 212,510 | 291 |
| 2002 | `CDBRFS02XPT.ZIP` | `cdbrfs02.xpt` | 247,964 | 310 |
| 2003 | `CDBRFS03XPT.ZIP` | `cdbrfs03.xpt` | 264,684 | 294 |
| 2004 | `CDBRFS04XPT.zip` | `CDBRFS04.XPT` | 303,822 | 293 |
| 2005 | `CDBRFS05XPT.zip` | `CDBRFS05.XPT` | 356,112 | 325 |
| 2006 | `CDBRFS06XPT.ZIP` | `CDBRFS06.XPT` | 355,710 | 302 |
| 2007 | `CDBRFS07XPT.ZIP` | `CDBRFS07.XPT` | 430,912 | 362 |
| 2008 | `CDBRFS08XPT.ZIP` | `CDBRFS08.XPT` | 414,509 | 291 |
| 2009 | `CDBRFS09XPT.ZIP` | `CDBRFS09.XPT` | 432,607 | 405 |
| 2010 | `CDBRFS10XPT.zip` | `CDBRFS10.XPT` | 451,075 | 397 |

The 11 annual files contain 3,654,355 records. The full-width 2000-2003 append contains 563 unioned raw columns; `_MSACODE` and `MRACEORG` change between numeric and character storage, so the R loader promotes only mixed-storage fields to character before binding.

## Documentation Files Present

The local `brfss/docs/` folder includes codebooks, layouts, overviews, calculated-variable notes, and Summary Data Quality Reports for every year.

| Year | Codebook | Variable layout | Overview | Calculated variables / summary | Data quality report |
|---:|---|---|---|---|---|
| 2000 | `codebook_00.pdf` | `varLayout_00.pdf` | `Overview_00.pdf` | `riskfactor_00.pdf` | `2000SummaryDataQualityReport.pdf` |
| 2001 | `codebook_01.pdf` | `varLayout_01.pdf` | `overview_01.pdf` | `riskfactor_01.pdf` | `2001SummaryDataQualityReport.pdf` |
| 2002 | `codebook_02.pdf` | `varLayout_02.pdf` | `overview_02.pdf` | `RiskFactor_02.pdf`, `summary_matrix_02.pdf` | `2002SummaryDataQualityReport.pdf` |
| 2003 | `Codebook_03.pdf` | `varLayout_03.pdf` | `overview_03.pdf` | `riskfactor_03.pdf`, `summary_matrix_03.pdf` | `2003SummaryDataQualityReport.pdf` |
| 2004 | `Codebook_04.pdf` | `VarLayout_04.pdf` | `overview_04.pdf` | `Summary_matrix_04.pdf` | `2004SummaryDataQualityReport.pdf` |
| 2005 | `Codebook_05.pdf` | `VarLayout_05.pdf` | `overview_05.pdf` | `riskfactor_05.pdf` | `2005SummaryDataQualityReport.pdf` |
| 2006 | `codebook_06.pdf` | `CDC - BRFSS - BRFSS - Variable Layout - 2006 Survey Data.pdf` | `overview_06.pdf` | `calcvar_06.pdf` | `2006SummaryDataQualityReport.pdf` |
| 2007 | `codebook_07.pdf` | `CDC - BRFSS BRFSS - Variable Layout - 2007 Survey Data.pdf` | `overview_07.pdf` | `calcvar_07.pdf` | `2007SummaryDataQualityReport.pdf` |
| 2008 | `codebook08.pdf` | `CDC - BRFSS - Variable Layout - 2008 Survey Data.pdf` | `overview_08.pdf` | `CalcVar_08.pdf` | `2008_Summary_Data_Quality_Report.pdf` |
| 2009 | `codebook_09.pdf` | `CDC - BRFSS - BRFSS - Variable Layout - 2009 Survey Data.pdf` | `overview_09.pdf` | `calcvar_09.pdf` | `2009_Summary_Data_Quality_Report.pdf` |
| 2010 | `codebook_10.pdf` | `CDC - BRFSS - 2010 BRFSS Variable Layout.pdf` | `overview_10.pdf` | `calcvar_10.pdf` | `2010_Summary_Data_Quality_Report.pdf` |

## Core Variable Availability and Transitions

| Concept | Pre-2011 source variables used by the starter |
|---|---|
| State / survey design | `_STATE`, `_PSU`, `_STSTR`, `_FINALWT`, and `_POSTSTR` when available |
| County | `CTYCODE`; `_IMPCTY` fallback in 2007; `CPCOUNTY` fallback in 2009-2010 |
| Interview timing | `IMONTH`, `IYEAR` when present |
| Age | `_IMPAGE`, then `AGE`; `_AGEG5YR` for grouped age |
| Sex | `SEX` |
| Race/ethnicity | `_RACEGR` in 2000; `_RACEGR2` in 2001-2010; documented `_RACEG2`, `_RACEG3_`, and `HISPANC2` fallbacks |
| Education / family / work | `EDUCA`, `MARITAL`, `INCOME2`, `EMPLOY` |
| Insurance / access | `HLTHPLAN`, `PERSDOC` in 2000, `PERSDOC2` in 2001-2010, `MEDCOST`, `CHECKUP` or `CHECKUP1` |
| General and healthy-days outcomes | `GENHLTH`, `MENTHLTH`, `PHYSHLTH` |
| BMI | `_BMI2` in 2000-2002, `_BMI3` in 2003, `_BMI4` in 2004-2010, plus the matching `*CAT` fields |
| Smoking | `_SMOKER2` and `_SMOKER3`, depending on year |
| Diabetes | `DIABETES` in 2000-2003; `DIABETE2` in 2004-2010 |
| Asthma | `ASTHMA` in 2000; `ASTHMA2` in 2001-2010; `ASTHNOW` when present |
| Heart attack | `CVDINFAR`, `CVDINFR2`, `CVDINFR3`, or `CVDINFR4` |
| Coronary heart disease | `CVDCORHD`, `CVDCRHD2`, `CVDCRHD3`, or `CVDCRHD4` |
| Stroke | `CVDSTROK`, `CVDSTRK2`, or `CVDSTRK3` |

COPD is not available as a comparable core variable in the 2000-2010 headers, so the pre-2011 cleaner does not create one. The full-width cleaners preserve raw `AGE`, `DIABETES`, and `HISPANIC` fields under unambiguous names before creating harmonized fields that would otherwise collide.

The early BMI fields require year-specific scaling verified against the annual codebooks: `_BMI2 / 10` in 2000, `_BMI2 / 10000` in 2001, `_BMI2 / 100` in 2002, and `_BMI3`/`_BMI4 / 100` thereafter. Their calculated BMI category is a three-level field (`1` neither overweight nor obese, `2` overweight, `3` obese), not the four-level 2011-plus `_BMI5CAT` definition.

## County Code Caveats

The table reports the usable county rows produced by the cleaner after its documented fallbacks, not just raw `CTYCODE` availability.

| Year | County sources present | Usable county rows |
|---:|---|---:|
| 2000 | `CTYCODE` | 139,614 |
| 2001 | `CTYCODE` | 163,086 |
| 2002 | `CTYCODE` | 197,674 |
| 2003 | `CTYCODE` | 215,110 |
| 2004 | `CTYCODE` | 256,735 |
| 2005 | `CTYCODE` | 307,349 |
| 2006 | `CTYCODE` | 296,300 |
| 2007 | `CTYCODE`, `_IMPCTY` | 430,228 |
| 2008 | `CTYCODE` | 375,346 |
| 2009 | `CTYCODE`, `CPCOUNTY` | 390,791 |
| 2010 | `CTYCODE`, `CPCOUNTY` | 408,682 |

The cleaner accepts only numeric county codes `1`-`840` and excludes `777`, `888`, and `999`. This matters because `CPCOUNTY` can contain non-county character values. It creates:

- `county_code_raw`: first valid value from `CTYCODE`, `_IMPCTY`, then `CPCOUNTY`
- `county_code_source`: source used for that row
- `countyfips`: `statefips * 1000 + county_code_raw`

This identifier does not guarantee adequate county sample sizes or complete disclosure. County analyses should consult annual codebooks and data-quality reports and consider SMART BRFSS products.

## Dual / Multiple Questionnaire Files

In several late pre-2011 years, participating states could rotate two or three questionnaire versions. The unchanged core was asked on every version, while an optional module could appear on only one version. CDC supplied `QSTVER`, version-specific weights, and separate version data sets to make module analysis clearer.

Those files are not additional annual samples and must not be appended to `CDBRFSYY.XPT`; doing so would duplicate respondents already represented in the annual file. They are therefore outside this core starter. A project studying a version-specific optional module should use the CDC multiple-questionnaire documentation and either its version-specific file or the corresponding `QSTVER` subset and version-specific final weight. The low-memory starter intentionally keeps the standard core analysis weight only.

## Validation Completed

The cleaners check expected ranges and binary domains, then reconstruct core clean variables independently from the raw fields. They verify weights/design copies, county-source priority, demographic and health recodes, year-specific BMI scaling, and all early variable-name transitions.

| Workflow | Years | Rows | Appended width | Result |
|---|---:|---:|---:|---|
| R low-memory loader + cleaner | 2000-2003 | 909,608 | 54 unioned fields | Passed all range and source-recode checks |
| Stata low-memory loader + cleaner | 2000-2003 | 909,608 | 54 unioned fields | Passed all range and source-recode checks |
| R full-width loader + cleaner | 2000-2003 | 909,608 | 563 unioned fields | Passed all range and source-recode checks |
| Stata full-width loader + cleaner | 2000-2003 | 909,608 | 563 unioned fields | Passed all range and source-recode checks |
| R low-memory loader + cleaner | 2000-2010 | 3,654,355 | 67 unioned fields | Passed all range and source-recode checks |
| Stata low-memory loader + cleaner | 2000-2010 | 3,654,355 | 67 unioned fields | Passed all range and source-recode checks |
| R full-width loader + cleaner | 2009-2010 default | 883,682 | 515 unioned fields | Passed all range and source-recode checks |
| Stata full-width loader + cleaner | 2009-2010 default | 883,682 | 515 unioned fields | Passed all range and source-recode checks |

R and Stata outputs were compared at the value level for both 2000-2003 full-width builds and the complete 2000-2010 low-memory builds. The nominal key `surveyyear + statefips + seqno` is not unique in 2000-2003: 2,773 rows belong to duplicated-key groups in each language. After deterministic multiset sorting, every compared weight/design, county, demographic, access-to-care, healthy-days, BMI, smoking, diabetes, asthma, cardiovascular, and source-tracking field had zero mismatches.

## Design Break

The 2000-2010 files are primarily landline-era files using post-stratification weights. The 2011-plus files use a dual-frame landline/cell-phone design and raking weights. An analysis spanning 2010 and 2011 needs an explicit bridge strategy, documented outcome comparability checks, and careful interpretation of any level change at the redesign.
