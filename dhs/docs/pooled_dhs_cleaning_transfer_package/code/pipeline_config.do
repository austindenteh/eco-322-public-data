set more off

* Shared path and runner configuration for the active pipeline surface.
global PIPELINE_PROJECT_ROOT "/Users/audenteh/Library/CloudStorage/Dropbox/research-db/github/incomplete-verification"
global PIPELINE_CODE_PATH "${PIPELINE_PROJECT_ROOT}/code"
global PIPELINE_DOCS_ROOT "${PIPELINE_PROJECT_ROOT}/docs"
global PIPELINE_DATA_ROOT "${PIPELINE_PROJECT_ROOT}/data"
global PIPELINE_PAPER_ROOT "${PIPELINE_PROJECT_ROOT}/paper"
global PIPELINE_RESULTS_DIR "${PIPELINE_PROJECT_ROOT}/results"
global PIPELINE_LEGACY_ROOT "${PIPELINE_PROJECT_ROOT}/legacy"

* Active bridge roots that still match the current live workflow.
global PIPELINE_ACTIVE_RESULTS_ROOT "${PIPELINE_PROJECT_ROOT}/simulation_results/paper_results"
global PIPELINE_ACTIVE_VALIDATION_ROOT "${PIPELINE_ACTIVE_RESULTS_ROOT}/validation"
global PIPELINE_ACTIVE_EMPIRICS_ROOT "${PIPELINE_PROJECT_ROOT}/empirics"
global PIPELINE_ACTIVE_OVERLEAF_ROOT "${PIPELINE_PROJECT_ROOT}/overleaf-project"

* Future target roots used during the path-aware transition.
global PIPELINE_FUTURE_RESULTS_ROOT "${PIPELINE_RESULTS_DIR}/paper_results"
global PIPELINE_FUTURE_VALIDATION_ROOT "${PIPELINE_RESULTS_DIR}/validation"
global PIPELINE_FUTURE_EMPIRICAL_ROOT "${PIPELINE_DATA_ROOT}/empirical"
global PIPELINE_FUTURE_SIMULATION_ROOT "${PIPELINE_DATA_ROOT}/simulations"
global PIPELINE_FUTURE_TABLES_ROOT "${PIPELINE_PAPER_ROOT}/tables"

* Backward-compatible aliases for the active path layer.
global PIPELINE_RESULTS_ROOT "$PIPELINE_ACTIVE_RESULTS_ROOT"
global PIPELINE_VALIDATION_ROOT "$PIPELINE_ACTIVE_VALIDATION_ROOT"
global PIPELINE_EMPIRICS_ROOT "$PIPELINE_ACTIVE_EMPIRICS_ROOT"
global PIPELINE_OVERLEAF_ROOT "$PIPELINE_ACTIVE_OVERLEAF_ROOT"

capture program drop pipeline_resolve_dir
program define pipeline_resolve_dir, rclass
    version 16.1
    syntax , PATH(string)

    if "`path'" == "" {
        return local resolved ""
    }
    else if substr("`path'", 1, 1) == "/" {
        return local resolved "`path'"
    }
    else {
        return local resolved "${PIPELINE_PROJECT_ROOT}/`path'"
    }
end

capture program drop pipeline_future_results_dir
program define pipeline_future_results_dir, rclass
    version 16.1
    syntax , PATH(string)

    if "`path'" == "" {
        return local resolved ""
        exit
    }

    local activeValidation "$PIPELINE_ACTIVE_VALIDATION_ROOT"
    local activeResults "$PIPELINE_ACTIVE_RESULTS_ROOT"
    local futureValidation "$PIPELINE_FUTURE_VALIDATION_ROOT"
    local futureResults "$PIPELINE_FUTURE_RESULTS_ROOT"

    if strpos("`path'", "`activeValidation'") == 1 {
        local suffix = substr("`path'", length("`activeValidation'") + 1, .)
        return local resolved "`futureValidation'`suffix'"
    }
    else if strpos("`path'", "`activeResults'") == 1 {
        local suffix = substr("`path'", length("`activeResults'") + 1, .)
        return local resolved "`futureResults'`suffix'"
    }
    else if strpos("`path'", "`futureValidation'") == 1 | strpos("`path'", "`futureResults'") == 1 {
        return local resolved "`path'"
    }
    else {
        return local resolved ""
    }
end

capture program drop pipeline_ensure_dir
program define pipeline_ensure_dir
    version 16.1
    syntax , PATH(string)

    local dirpath "`path'"
    if "`dirpath'" == "" exit

    local dirpath = subinstr("`dirpath'", "\", "/", .)
    local current ""

    if substr("`dirpath'", 1, 1) == "/" {
        local current "/"
        local dirpath = substr("`dirpath'", 2, .)
    }

    while "`dirpath'" != "" {
        gettoken piece dirpath : dirpath, parse("/")
        if "`piece'" == "/" continue
        if "`piece'" == "" {
            if substr("`dirpath'", 1, 1) == "/" local dirpath = substr("`dirpath'", 2, .)
            continue
        }

        if "`current'" == "/" local current "/`piece'"
        else if "`current'" == "" local current "`piece'"
        else local current "`current'/`piece'"

        capture mkdir "`current'"

        if substr("`dirpath'", 1, 1) == "/" local dirpath = substr("`dirpath'", 2, .)
    }
end
