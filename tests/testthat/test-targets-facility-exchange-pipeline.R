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
  testthat::expect_false(any(grepl("prepare_hysplit_meteorology", manifest$command, fixed = TRUE)))
  testthat::expect_true("completed_run_index" %in% manifest$name)
  inventory_command <- manifest$command[manifest$name == "parsed_run_inventory"]
  testthat::expect_match(inventory_command, "completed_run_index")
})

testthat::test_that("completed-run index is deterministic across additions, reparses, failures, and removals", {
  root <- tempfile("completed-index-")
  dir.create(root)
  make_run <- function(id, status = "completed", parsed = TRUE, receptors = FALSE) {
    directory <- file.path(root, id); dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    saveRDS(list(run_id = id, status = status), file.path(directory, "run_metadata.rds"))
    if (parsed) {
      dir.create(file.path(directory, "parsed"), recursive = TRUE, showWarnings = FALSE)
      saveRDS(list(run_id = id), file.path(directory, "parsed", "parsing_metadata.rds"))
      saveRDS(list(run_id = id), file.path(directory, "parsed", "parsed_plume.rds"))
    }
    if (receptors) {
      dir.create(file.path(directory, "receptors"), recursive = TRUE, showWarnings = FALSE)
      utils::write.csv(data.frame(run_id = id), file.path(directory, "receptors", "source_receptor_exchange.csv"), row.names = FALSE)
    }
    directory
  }

  make_run("R1")
  path <- write_completed_run_index(root)
  first <- readLines(path); first_time <- file.info(path)$mtime
  testthat::expect_equal(utils::read.csv(path)$run_id, "R1")
  Sys.sleep(0.02)
  testthat::expect_identical(write_completed_run_index(root), path)
  testthat::expect_identical(readLines(path), first)
  testthat::expect_equal(file.info(path)$mtime, first_time)

  make_run("R2")
  write_completed_run_index(root)
  second <- readLines(path)
  testthat::expect_equal(utils::read.csv(path)$run_id, c("R1", "R2"))
  testthat::expect_false(identical(second, first))

  saveRDS(list(run_id = "R2", reparsed = TRUE), file.path(root, "R2", "parsed", "parsing_metadata.rds"))
  write_completed_run_index(root)
  reparsed <- readLines(path)
  testthat::expect_false(identical(reparsed, second))

  saveRDS(list(run_id = "R2", status = "failed"), file.path(root, "R2", "run_metadata.rds"))
  write_completed_run_index(root)
  testthat::expect_equal(utils::read.csv(path)$run_id, "R1")
  manifest <- data.frame(
    run_id = c("R1", "R2"), scenario_id = "test", source_id = c("F1", "F2"),
    release_start = c("2020-01-01T00:00:00Z", "2020-01-01T01:00:00Z"),
    simulation_end = c("2020-01-01T08:00:00Z", "2020-01-01T09:00:00Z"),
    stringsAsFactors = FALSE
  )
  failed_inventory <- discover_parsed_run_inventory(manifest, root)
  testthat::expect_false(failed_inventory$available_for_processing[failed_inventory$run_id == "R2"])
  testthat::expect_equal(failed_inventory$run_status[failed_inventory$run_id == "R2"], "failed")

  unlink(file.path(root, "R1"), recursive = TRUE)
  write_completed_run_index(root)
  testthat::expect_equal(nrow(utils::read.csv(path)), 0)
})

testthat::test_that("ordinary pipeline invalidates from the completed-run index and then stabilizes", {
  root <- tempfile("targets-index-integration-")
  dir.create(root)
  run_root <- file.path(root, "hysplit")
  store <- file.path(root, "targets")
  config <- test_cfg
  config$inputs$mode <- "files"
  config$inputs$facilities_file <- pipeline_fixture_paths()$facilities
  config$inputs$observations_file <- file.path(repo_root, "tests", "testthat", "fixtures", "pipeline_observations.csv")
  config$hysplit$run_root_directory <- run_root
  config$hysplit$meteorology_directory <- file.path(root, "climate")
  config$outputs$root_directory <- root
  config$outputs$manifest_directory <- file.path(root, "manifests")
  config$outputs$raster_directory <- file.path(root, "rasters")
  config$outputs$exposure_directory <- file.path(root, "exposures")
  config$outputs$report_directory <- file.path(root, "reports")
  config$pipeline$targets_store <- store
  config$pipeline$status_directory <- file.path(root, "pipeline_status")
  config_path <- file.path(root, "config.yml")
  yaml::write_yaml(config, config_path)

  facilities <- pipeline_facilities()
  manifest <- build_hysplit_run_manifest(facilities, config, facilities$facility_id[1])
  install_parsed_fixture <- function(i, fixture_id) {
    directory <- manifest$run_directory[i]
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    fixture <- file.path(pipeline_fixture_paths()$root, fixture_id, "parsed")
    file.copy(fixture, directory, recursive = TRUE)
    parsed_path <- file.path(directory, "parsed", "parsed_plume.rds")
    parsed <- readRDS(parsed_path)
    parsed$parsing_metadata$run_id <- manifest$run_id[i]
    parsed$parsing_metadata$scenario_id <- manifest$scenario_id[i]
    parsed$parsing_metadata$source_id <- manifest$source_id[i]
    parsed$parsing_metadata$source_longitude <- manifest$source_longitude[i]
    parsed$parsing_metadata$source_latitude <- manifest$source_latitude[i]
    parsed$parsing_metadata$release_start <- as.POSIXct(manifest$release_start[i], tz = "UTC")
    parsed$parsing_metadata$simulation_end <- as.POSIXct(manifest$simulation_end[i], tz = "UTC")
    parsed$parsing_metadata$run_directory <- directory
    saveRDS(parsed, parsed_path)
    saveRDS(parsed$parsing_metadata, file.path(directory, "parsed", "parsing_metadata.rds"))
  }

  old_config <- Sys.getenv("EPIPLUME_CONFIG", unset = NA_character_)
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    if (is.na(old_config)) Sys.unsetenv("EPIPLUME_CONFIG") else Sys.setenv(EPIPLUME_CONFIG = old_config)
  }, add = TRUE)
  Sys.setenv(EPIPLUME_CONFIG = config_path)
  setwd(repo_root)

  install_parsed_fixture(1, "R001")
  index_path <- write_completed_run_index(run_root)
  first_index <- unname(tools::md5sum(index_path))
  testthat::expect_equal(utils::read.csv(index_path)$run_id, manifest$run_id[1])
  targets::tar_make(script = "_targets.R", store = store, reporter = "silent")
  first_inventory <- targets::tar_read(parsed_run_inventory, store = store)
  first_parsed <- targets::tar_read(parsed_plumes, store = store)
  first_receptors <- targets::tar_read(receptor_extractions, store = store)
  testthat::expect_equal(sum(first_inventory$available_for_processing), 1)
  testthat::expect_length(first_parsed, 1)
  testthat::expect_length(first_receptors, 1)

  install_parsed_fixture(2, "R002")
  write_completed_run_index(run_root)
  testthat::expect_false(identical(unname(tools::md5sum(index_path)), first_index))
  testthat::expect_true("parsed_run_inventory" %in% targets::tar_outdated(script = "_targets.R", store = store))
  targets::tar_make(script = "_targets.R", store = store, reporter = "silent")
  second_parsed <- targets::tar_read(parsed_plumes, store = store)
  second_receptors <- targets::tar_read(receptor_extractions, store = store)
  connectivity <- targets::tar_read(multirun_connectivity, store = store)
  testthat::expect_length(second_parsed, 2)
  testthat::expect_length(second_receptors, 2)
  testthat::expect_equal(connectivity$assembly_metadata$successful_runs, 2)
  testthat::expect_length(targets::tar_outdated(script = "_targets.R", store = store), 0)
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
