# PSID Supplemental Studies Inventory

Checked on 2026-05-25 against the local `psid/data/` folder and PSID public documentation.

## Main Rule

Do not treat PSID supplemental studies as one pool of extra variables. They differ in sample universe, unit of observation, fielding year, file structure, weights, and merge keys. Starter code should be built as separate supplement-specific loaders.

The PSID FAQ also warns that supplemental files can have fewer observations than main family files because many supplements are sub-samples. Fewer rows are not by itself evidence of a bad download.

## Official Supplement Availability Checked

| Supplement | Official years/docs observed | Local status | Download action |
|---|---:|---|---|
| Child Development Supplement (CDS) | 1997, 2002, 2007, 2014, 2019, 2020, 2021; 2024 questionnaires listed | Data files present for 1997, 2002, 2007, 2014, 2019, 2020, 2021, plus cumulative `cdsind2021` | Current local CDS download looks sufficient for CDS index and component starters. Do not treat absent CDS 2024 data as a problem unless PSID releases public data files. |
| Transition into Adulthood Supplement (TAS) | 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023; 2025 questionnaire listed | Data files present for 2005-2023 public-use waves | Current local TAS download looks sufficient for a separate TAS starter. Do not treat absent 2025 data as a problem unless PSID releases public data files. |
| Disability and Use of Time Supplement (DUST) | 2009 and 2013 | Data files present for 2009 and 2013 | Current local DUST download looks sufficient for a separate DUST starter. |
| Childhood Retrospective Circumstances Study (CRCS) | 2014 web/mixed-mode supplement | Data files present for 2014 | Current local CRCS download looks sufficient for a separate web/mixed-mode supplement starter. |
| Wellbeing and Daily Life Supplement (WB) | 2016 web/mixed-mode supplement | Data files present for 2016 | Current local WB download looks sufficient for a separate web/mixed-mode supplement starter. |
| Intergenerational Transfers: Time and Money Transfer | 1988 | Data files present for 1988 | Current local TMT88 download looks sufficient for a separate intergenerational transfers starter. |
| Intergenerational Transfers: Family Rosters and Transfers | 2013 | Family and parent/child files present for 2013 | Current local RT13 download looks sufficient for a separate intergenerational transfers starter. |

## Local CDS Files Observed

The local CDS folder is substantial and should be handled as its own starter. File groups vary by wave, which is expected.

| Local folder | `.do` setup files observed | Notes |
|---|---:|---|
| `child_development_supplement/1997/` | 22 | Original CDS-I; includes child/assessment, PCG, OCG, fathers outside household, school/daycare, ID map, demographic, and time-diary files. |
| `child_development_supplement/2002/` | 14 | Original CDS-II; includes assessment, child, PCG, OCG, teacher, ID/generational maps, demographic, and time-diary files. |
| `child_development_supplement/2007/` | 13 | Original CDS-III; includes assessment, child, PCG, OCG, ID/generational maps, demographic, and time-diary files. |
| `child_development_supplement/2014/` | 11 | Ongoing CDS; includes ID map, interview information, household roster, PCG, child/assessment, and time-diary files. |
| `child_development_supplement/2019/` | 11 | Ongoing CDS; includes CDSIND, interview information, household roster, PCG, child/assessment, and time-diary files. |
| `child_development_supplement/2020/` | 10 | COVID-era CDS follow-up files; includes COVID health, 2019 CDSIND/demographic/roster carryover files, PCG, and time-diary files. |
| `child_development_supplement/2021/` | 6 | CDS 2021 follow-up; includes CDSIND, interview information, household roster, PCG, and child interview files. |
| `child_development_supplement/cdsind2021/` | 1 | Standalone cumulative CDS ID map file, 1997-2021. |

## Local Non-CDS Supplement Files Observed

| Local folder | `.do` setup files observed | Rows in setup headers | Notes |
|---|---:|---|---|
| `transition_into_adulthood/ta2005/` | 1 | 745 | TAS 2005 public-use file. |
| `transition_into_adulthood/ta2007/` | 1 | 1,115 | TAS 2007 public-use file. |
| `transition_into_adulthood/ta2009/` | 1 | 1,554 | TAS 2009 public-use file. |
| `transition_into_adulthood/ta2011/` | 1 | 1,907 | TAS 2011 public-use file. |
| `transition_into_adulthood/ta2013/` | 1 | 1,804 | TAS 2013 public-use file. |
| `transition_into_adulthood/ta2015/` | 1 | 1,641 | TAS 2015 public-use file. |
| `transition_into_adulthood/TA2017/` | 1 | 2,526 | TAS 2017 public-use file. |
| `transition_into_adulthood/TA2019/` | 1 | 2,595 | TAS 2019 public-use file. |
| `transition_into_adulthood/TA2021/` | 1 | 2,362 | TAS 2021 public-use file. |
| `transition_into_adulthood/TA2023/` | 1 | 2,434 | TAS 2023 public-use file; ASCII file date November 21, 2025. |
| `disability_and_time_use/dust09/` | 4 | HH 952; flat 755; observations 1,506; activity 36,898 | DUST 2009 household, flat, interviewer-observation, and time-diary activity files. |
| `disability_and_time_use/dust13/` | 5 | HH 2,668; flat 1,776; observations 3,505; activity 81,488; WHO 3,843 | DUST 2013 adds a parent/child file. |
| `web_mixed_mode_supplement/CRCS14/` | 1 | 8,072 | Childhood Retrospective Circumstances Study 2014. |
| `web_mixed_mode_supplement/WB2016/` | 1 | 8,341 | Wellbeing and Daily Life Supplement 2016. |
| `intergenerational_transfers/tmt88/` | 1 | 32,850 | 1988 Time and Money Transfers file. |
| `intergenerational_transfers/RT13/` | 2 | family 9,063; parent/child 23,967 | 2013 Rosters and Transfers family-level and parent/child files. |

## Suggested Build Order

1. Implemented: `05_load_cds_index.*`.
   - Load only the CDS ID map / demographic / household roster linkage surface.
   - Expose wave selection.
   - Keep merge keys back to main PSID individual IDs.
   - Avoid silently appending unlike instruments.

2. Implemented: narrow CDS component loaders as separate files.
   - `06_load_cds_child_caregiver.*` loads child, caregiver, roster, demographic, support, and 2020 COVID-health files as separate outputs.
   - `07_load_cds_time_diary.*` loads time-diary activity, aggregate, media, follow-up, questionnaire, and 1997 school/care diary files as separate outputs.
   - `08_load_cds_assessments.*` loads assessment, school, teacher, administrator, and provider files as separate outputs.

3. Implemented: `09_load_tas_index.*`.
   - Load selected TAS waves into a compact cross-wave index.
   - Keep common ID, interview metadata, and weight fields verified across waves.
   - Do not append the full TAS questionnaires without explicit harmonization.

4. Implemented: `10_load_dust.*`.
   - Support 2009/2013 and file-group selection: household, flat, observation, activity, and 2013 WHO.
   - Save file groups separately rather than appending unlike units of observation.

5. Implemented: `11_load_intergenerational_transfers.*` and `12_load_web_mixed_mode.*`.
   - `11_load_intergenerational_transfers.*` loads TMT88 and RT13 as separate product/file outputs.
   - `12_load_web_mixed_mode.*` loads CRCS14 and WB2016 as separate one-off supplement outputs.
   - These should not be merged into the main core starter.

## Documentation Used

- PSID CDS/TAS study design: <https://psidonline.isr.umich.edu/CDS/Guide/StudyDesign.aspx>
- PSID CDS/TAS FAQ: <https://psidonline.isr.umich.edu/CDS/Guide/FAQ.aspx>
- PSID questionnaires and supporting documentation: <https://psidonline.isr.umich.edu/Guide/documents.aspx>
- PSID getting started supplement overview: <https://psidonline.isr.umich.edu/GettingStarted.aspx>
- PSID FAQ on supplemental sub-samples: <https://psidonline.isr.umich.edu/Guide/FAQ.aspx?Type=1>
