pipeline_fixture_paths <- function() list(manifest = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_manifest.csv"), facilities = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_facilities.csv"), root = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_runs"))
pipeline_manifest <- function() utils::read.csv(pipeline_fixture_paths()$manifest, stringsAsFactors = FALSE)
pipeline_facilities <- function() utils::read.csv(pipeline_fixture_paths()$facilities, stringsAsFactors = FALSE)
pipeline_manifest_row <- function() {
  facilities <- simulate_facility_network(test_cfg)
  build_hysplit_run_manifest(facilities, test_cfg, facilities$facility_id[1])[1, , drop = FALSE]
}

testthat::test_that("target definitions parse and keep execution isolated", {
  testthat::expect_silent(parse(file.path(repo_root, "_targets.R")))
  testthat::expect_silent(parse(file.path(repo_root, "_targets_hysplit.R")))
  old <- getwd(); setwd(repo_root); on.exit(setwd(old), add = TRUE)
  manifest <- targets::tar_manifest(script = "_targets.R")
  execution <- targets::tar_manifest(script = "_targets_hysplit.R")
  testthat::expect_false(anyDuplicated(manifest$name) > 0)
  testthat::expect_false("execute_selected_hysplit" %in% manifest$name)
  testthat::expect_true("execute_selected_hysplit" %in% execution$name)
  testthat::expect_false(any(grepl("run_hysplit_manifest_row", manifest$command, fixed = TRUE)))
})

testthat::test_that("simulated and file input modes validate cleanly", {
  simulated <- read_facility_exchange_inputs(test_cfg)
  testthat::expect_equal(nrow(simulated$facilities), 120)
  cfg <- test_cfg; cfg$inputs$mode <- "files"; cfg$inputs$facilities_file <- file.path(repo_root, "tests", "testthat", "fixtures", "multirun_facilities.csv"); cfg$inputs$observations_file <- file.path(repo_root, "tests", "testthat", "fixtures", "pipeline_observations.csv")
  supplied <- read_facility_exchange_inputs(cfg)
  testthat::expect_equal(nrow(supplied$facilities), 8); testthat::expect_equal(nrow(supplied$simulation_truth), 0)
  cfg$inputs$facilities_file <- tempfile("missing-facilities-")
  testthat::expect_error(read_facility_exchange_inputs(cfg), "do not exist")
})

testthat::test_that("explicit run selection is safe and manifest ordered", {
  manifest <- data.frame(run_id = c("A", "B", "C"), value = 1:3)
  testthat::expect_equal(nrow(build_pipeline_run_selection(manifest, "")), 0)
  testthat::expect_equal(build_pipeline_run_selection(manifest, "C,A")$run_id, c("A", "C"))
  testthat::expect_error(build_pipeline_run_selection(manifest, "A,A"), "duplicates")
  testthat::expect_error(build_pipeline_run_selection(manifest, "Z"), "Unknown")
})

testthat::test_that("execution confirmation blocks the core before invocation", {
  row <- pipeline_manifest_row(); called <- FALSE; fake <- function(...) { called <<- TRUE }
  testthat::expect_error(run_selected_hysplit_case(row, test_cfg, "false", fake), "requires")
  testthat::expect_false(called)
})

testthat::test_that("partial and zero-run branches remain structured", {
  paths <- pipeline_fixture_paths(); inventory <- discover_parsed_run_inventory(pipeline_manifest(), paths$root)
  parsed <- load_completed_parsed_run(inventory[inventory$run_id == "R001", ], test_cfg)
  missing <- load_completed_parsed_run(inventory[inventory$run_id == "R008", ], test_cfg)
  testthat::expect_equal(parsed$status, "parsed"); testthat::expect_equal(missing$status, "skipped")
  empty <- assemble_pipeline_receptor_results(list(list(run_id = "none", status = "skipped", extraction = NULL, error_message = NA_character_)), pipeline_facilities(), test_cfg)
  testthat::expect_equal(empty$assembly_metadata$status, "empty"); testthat::expect_equal(nrow(empty$combined_exchange_table), 0)
})

testthat::test_that("status writer creates CSV RDS and JSON for zero success", {
  inventory <- discover_parsed_run_inventory(pipeline_manifest(), pipeline_fixture_paths()$root); inventory$available_for_processing <- FALSE
  empty <- assemble_pipeline_receptor_results(list(), pipeline_facilities(), test_cfg); out <- tempfile("pipeline-status-")
  status <- write_pipeline_status_summary(test_cfg, pipeline_manifest(), inventory, list(), list(), empty, out, file.path(repo_root, "config", "facility_exchange_demo.yml"))
  testthat::expect_true(all(file.exists(status$files))); testthat::expect_equal(status$summary$exchange_row_count, 0)
})

testthat::test_that("configured targets store is ignored and dependency boundaries are visible", {
  testthat::expect_match(test_cfg$pipeline$targets_store, "^local/")
  ignore <- readLines(file.path(repo_root, ".gitignore")); testthat::expect_true(any(ignore %in% c("/local", "local/")))
  old <- getwd(); setwd(repo_root); on.exit(setwd(old), add = TRUE); graph <- targets::tar_manifest(script = "_targets.R")
  receptor_command <- graph$command[graph$name == "receptor_extractions"]
  testthat::expect_match(receptor_command, "cfg")
  testthat::expect_match(graph$command[graph$name == "input_bundle"], "read_facility_exchange_inputs")
})
