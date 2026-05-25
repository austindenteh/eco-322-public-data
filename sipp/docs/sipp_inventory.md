# SIPP Inventory

Checked locally on 2026-05-25.

## Main Rule

Do not treat all SIPP files as one append. The local folder spans two major design eras and several file families:

- 2008 panel/wave fixed-width files with SAS layouts
- 2014 redesigned panel waves and the 2014 SSA supplement
- 2018-2024 redesigned annual primary public-use files
- cross-sectional replicate weights
- longitudinal weights and longitudinal replicate weights

Starter code should be built by era and file family.

## Official Structure

The Census SIPP datasets page separates access by year for 2018-2024 and by panel/wave for 1984-2014. The 2024 data page lists separate primary data, replicate weights, longitudinal weights, and longitudinal replicate weights.

Useful official pages:

- <https://www.census.gov/programs-surveys/sipp/data/datasets.html>
- <https://www.census.gov/data/datasets/2024/demo/sipp/2024-data.html>
- <https://www.census.gov/programs-surveys/sipp/tech-documentation/complete-technical-documentation.html>

## Local Data Coverage

| Local folder | Approx size | Local status | Starter status |
|---|---:|---|---|
| `data/2008/` | 3.4G | 2008 panel waves 1-16, topical modules for waves 1-11 and 13, replicate weights, longitudinal weights | Legacy core, weight, and selected topical wave loaders support selected use |
| `data/2014/` | 4.1G | 2014 panel waves 1-4 plus SSA supplement; local wave 1 Stata gzip is truncated but pipe-delimited `pu2014w1.csv.gz` passes validation | 2014 panel primary loader falls back to CSV for wave 1; 2014 panel weights and SSA supplement loaders support selected use |
| `data/2018/` | 1.1G | Primary zip and replicate weights present; metadata smoke readable | Modern primary loader, cleaner, and replicate-weight loader support selected use |
| `data/2019/` | 827M | Primary zip readable; stale `.download` artifact also present locally; longitudinal year-2 weights present | Modern primary, cleaner, replicate weights, and longitudinal weights support selected use |
| `data/2020/` | 1.0G | Primary zip and weight files present; metadata smoke readable | Modern primary, cleaner, replicate weights, and longitudinal weights support selected use |
| `data/2021/` | 1.1G | Primary zip, DSTR extract, and weight files present; metadata smoke readable | Modern primary, cleaner, replicate weights, and longitudinal weights support selected use |
| `data/2022/` | 741M | Primary Stata zip passes system integrity checks; R/Stata built-in zip readers need system-unzip fallback | Modern primary loader and cleaner support selected use with extraction fallback |
| `data/2023/` | 795M | Primary zip and weight files present; metadata smoke readable | Modern primary, cleaner, replicate weights, and longitudinal weights support selected use |
| `data/2024/` | 730M | Primary zip and weight files present; metadata smoke readable | Default modern smoke target |

## Modern Primary File Notes

The modern primary file is person-month level. The loader adds:

- `source_file`
- `sipp_file_year`
- `reference_year`

For modern annual SIPP releases, `sipp_file_year` is the release/data-year label used in the file name, while `reference_year` is the prior calendar year. For example, the 2024 SIPP file covers the January-December 2023 reference period.

The full default modern starter variable set is present in local 2022-2024 primary files. In local 2018-2020 primary files, `EHISPAN` and annual health-insurance recodes are absent; in local 2021, `EHISPAN` is present but annual health-insurance recodes are absent. The loader warns and skips unavailable starter variables. The 2014 panel primary files use a parallel starter surface, but several modern annual variables are unavailable there as well.

## Suggested Build Order

1. Implemented: `01_load_modern_primary.*`.
   - Load selected 2018-2024 primary files.
   - Default to 2024.
   - Keep a broad starter variable surface plus user-requested extras and alias families.
   - Validate unreadable local years clearly.

2. Implemented: `02_load_modern_weights.*`.
   - Separate cross-sectional replicate weights from longitudinal weights and longitudinal replicate weights.
   - Document merge keys and appropriate weight choice.
   - Default to a small replicate-column set for starter use, with an explicit option for all replicate weights.

3. Implemented: `03_clean_modern_primary.*`.
   - Preserve raw loader variables.
   - Add conservative starter fields for IDs, demographics, education, labor market, income/poverty, programs, health insurance, housing, and public-use geography.

4. Implemented: `04_load_2014_panel_primary.*`.
   - Keep 2014 panel waves separate from annual 2018-2024 SIPP.
   - Default to wave 4 and support selected waves.
   - Prefer Stata `.dta.gz` files, with pipe-delimited CSV fallback for wave 1 when the local Stata gzip is truncated.

5. Implemented: `05_load_2014_panel_weights.*`.
   - Separate 2014 replicate, longitudinal final, and longitudinal replicate weights.
   - Default to a small replicate-column set with an explicit all-replicate option.

6. Implemented: `06_load_2014_ssa_supplement.*`.
   - Load the SSA Supplement primary file.
   - Optionally load the fixed-width SSA replicate-weight file.
   - Handle the local SSA primary file's misleading `.dta.gz` suffix; it is a zip archive.

7. Implemented: `07_load_2008_legacy_core.*`.
   - Use the shared local 2008 SAS layout for fixed-width core waves.
   - Default to wave 16 and support selected waves 1-16.
   - Create standardized `pnum` and `eeduc` aliases from legacy names.

8. Implemented: `08_load_2008_legacy_weights.*`.
   - Load 2008 cross-sectional replicate weights, longitudinal final weights, and panel-year or calendar-year longitudinal replicate weights.
   - Use local SAS/PDF-derived fixed-width layouts.

9. Implemented: `09_load_2008_topical_modules.*`.
   - Load selected 2008 topical module waves.
   - Write one output per wave by default instead of appending unlike topical modules.
   - Default to all non-allocation variables and skip `FILLER` fields, with options to keep allocation flags or force specific extras.
   - Use the local SAS layouts dynamically, including large recurring topical waves such as assets/medical/child well-being.

10. Implemented: `10_load_2008_*` through `16_load_2008_*` topical topic-family launchers.
   - Provide PSID-supplement-style entry points for all available 2008 topical waves.
   - Families are recipiency/employment history, disability/education/family history, welfare/retirement/pension, assets/medical/child well-being, child care/work schedule/taxes, well-being/disability/support/caregiving, and certifications.
   - Each launcher passes a curated default wave set into the shared topical reader and writes family-tagged outputs with `topical_family`, `topical_family_label`, and `topical_family_note`.
   - These are source extracts, not cleaned/harmonized analytical files. Recurring families still need codebook checks before combining concepts across waves.

11. Remaining later expansion: module-specific topical cleaners or harmonizers.
   - Build concept-specific cleaners only after choosing a research question and checking the exact topical codebooks, universes, reference periods, and coding for the selected family extracts.
