# Pooled DHS Cleaning Transfer Package

This package contains only the Stata code used to clean and prepare the pooled
Ghana DHS validation datasets from raw DHS recodes. It does not include any
estimation, diagnostics, or manuscript-facing code.

## Included files

- `code/pipeline_config.do`
- `code/build_dhs_pooled_validation_surface.do`
- `code/build_dhs_pooled_validation_analysis_file.do`
- `code/build_dhs_pooled_2008_2014_validation_surface.do`
- `code/build_dhs_pooled_2008_2014_validation_analysis_file.do`

## What each script does

- `build_dhs_pooled_validation_surface.do`
  - builds the pooled 2008 men-plus-women common pre-merge surface from the
    raw DHS recodes
- `build_dhs_pooled_validation_analysis_file.do`
  - merges the pooled 2008 pre-merge surface to the women-only NHIS exposure
    lookup and creates the pooled 2008 regression-ready analysis file
- `build_dhs_pooled_2008_2014_validation_surface.do`
  - builds the stacked 2008 + 2014 men-plus-women common pre-merge surface
    from the raw DHS recodes
- `build_dhs_pooled_2008_2014_validation_analysis_file.do`
  - merges the stacked 2008 + 2014 pre-merge surface to the women-only NHIS
    exposure lookup and creates the stacked regression-ready analysis file

## Raw input expectations

The scripts expect the raw DHS recodes to be staged under:

- `data/empirical/dhs_fullsample_rebuild/ghana_2008_standard_dhs/`
- `data/empirical/dhs_fullsample_rebuild/ghana_2014_standard_dhs/`

The analysis-file builders also expect the women-only empirical source file:

- `empirics/GPS20082014_HFVisitData.dta`

## Run order

For the 2008 pooled build:

1. `do code/build_dhs_pooled_validation_surface.do`
2. `do code/build_dhs_pooled_validation_analysis_file.do`

For the stacked 2008 + 2014 pooled build:

1. `do code/build_dhs_pooled_2008_2014_validation_surface.do`
2. `do code/build_dhs_pooled_2008_2014_validation_analysis_file.do`

## Notes

- `pipeline_config.do` still contains this repo's absolute root path. If you
  move this package to another machine, update that root path first.
- This package intentionally excludes all pooled estimation files such as:
  - `dhs_data_code_pooled_validation.do`
  - `dhs_data_code_pooled_2008_2014_validation.do`
  - `dhs_pooled_sequential_controls.do`
  - `dhs_pooled_2008_2014_sequential_controls.do`
