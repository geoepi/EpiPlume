testthat::test_that("manifest validation normalizes exactly one valid row", {
  row <- make_manifest_row()
  normalized <- validate_hysplit_manifest_row(row)
  testthat::expect_s3_class(normalized$release_start, "POSIXct")
  testthat::expect_equal(attr(normalized$release_start, "tzone"), "UTC")
  testthat::expect_equal(validate_hysplit_manifest_row(as.list(row))$run_id, row$run_id)
  testthat::expect_error(validate_hysplit_manifest_row(row[FALSE, ]), "exactly one")
  testthat::expect_error(validate_hysplit_manifest_row(rbind(row, row)), "exactly one")
})

testthat::test_that("manifest validation reports field-specific errors", {
  row <- make_manifest_row()
  bad <- row; bad$source_longitude <- 181
  testthat::expect_error(validate_hysplit_manifest_row(bad), "source_longitude")
  bad <- row; bad$simulation_end <- bad$release_end
  testthat::expect_error(validate_hysplit_manifest_row(bad), "simulation_end")
  bad <- row; bad$run_id <- NULL
  testthat::expect_error(validate_hysplit_manifest_row(bad), "run_id")
})

testthat::test_that("installation resolution validates a splitr binary directory", {
  cfg <- test_cfg
  cfg$hysplit$hysplit_install_directory <- tempfile("missing-hysplit-")
  testthat::expect_error(resolve_hysplit_installation(cfg, TRUE), "does not exist")
  installation <- make_test_installation()
  cfg$hysplit$hysplit_install_directory <- installation
  testthat::expect_equal(resolve_hysplit_installation(cfg), paste0(normalizePath(installation, winslash = "/"), "/"))
})

testthat::test_that("installation fixture permissions are validated by platform", {
  executable <- make_test_installation(executable = TRUE)
  non_executable <- make_test_installation(executable = FALSE)
  cfg <- test_cfg
  cfg$hysplit$hysplit_install_directory <- executable
  testthat::expect_no_error(resolve_hysplit_installation(cfg, TRUE))
  cfg$hysplit$hysplit_install_directory <- non_executable
  if (.Platform$OS.type == "unix") {
    testthat::expect_error(resolve_hysplit_installation(cfg, TRUE), "not executable")
  } else {
    testthat::expect_no_error(resolve_hysplit_installation(cfg, TRUE))
  }
})

testthat::test_that("meteorology inspection is local and conservative", {
  row <- make_manifest_row(); cfg <- test_cfg
  cfg$hysplit$meteorology_directory <- tempfile("missing-met-")
  missing <- resolve_hysplit_meteorology(row, cfg, FALSE)
  testthat::expect_equal(missing$coverage_status, "missing")
  testthat::expect_error(resolve_hysplit_meteorology(row, cfg, TRUE), "No local")
  met_dir <- tempfile("met-"); dir.create(met_dir); file.create(file.path(met_dir, "local-input.arl"))
  cfg$hysplit$meteorology_directory <- met_dir
  found <- resolve_hysplit_meteorology(row, cfg, TRUE)
  testthat::expect_equal(found$coverage_status, "unknown")
  testthat::expect_length(found$candidate_files, 1)
})

testthat::test_that("run specification maps manifest fields to core plume arguments", {
  row <- make_manifest_row(); spec <- build_hysplit_run_spec(row, test_cfg)
  testthat::expect_equal(spec$core_args$lon, row$source_longitude)
  testthat::expect_equal(spec$core_args$lat, row$source_latitude)
  testthat::expect_equal(spec$core_args$plume_name, row$run_id)
  testthat::expect_equal(spec$core_args$release_start, as.POSIXct(row$release_start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  testthat::expect_equal(spec$core_args$end_time, as.POSIXct(row$simulation_end, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  testthat::expect_setequal(names(spec$core_args), names(formals(run_plume_model)))
  testthat::expect_true(all(names(spec$core_args) %in% names(formals(run_plume_model))))
  testthat::expect_false("hysplit_executable" %in% names(spec))
  testthat::expect_equal(spec$core_args$binary_path, spec$hysplit_install_directory)
  testthat::expect_false(identical(spec$core_args$exec_dir, spec$hysplit_install_directory))
  testthat::expect_false(identical(spec$working_directory, spec$output_directory))
})

testthat::test_that("dry-run never calls the core or creates a run directory", {
  row <- make_manifest_row()
  called <- FALSE
  fake <- function(...) { called <<- TRUE }
  result <- run_hysplit_manifest_row(row, test_cfg, dry_run = TRUE, core_fun = fake)
  testthat::expect_false(called)
  testthat::expect_false(dir.exists(row$run_directory))
  testthat::expect_equal(result$status, "dry_run")
  testthat::expect_true(length(result$expected_output_files) > 0)
})

testthat::test_that("injected successful execution receives exact core arguments and writes metadata", {
  row <- make_manifest_row(); cfg <- execution_cfg(); cfg$hysplit$run_root_directory <- tempfile("run-root-"); row$run_directory <- file.path(cfg$hysplit$run_root_directory, row$run_id); received <- NULL
  fake <- function(...) { received <<- list(...); write_mock_hysplit_artifact(received$exec_dir); list(disp_df = mock_valid_hysplit_dispersion()) }
  result <- run_hysplit_manifest_row(row, cfg, dry_run = FALSE, core_fun = fake)
  testthat::expect_equal(result$status, "completed")
  testthat::expect_equal(received$lon, row$source_longitude)
  testthat::expect_equal(received$plume_name, row$run_id)
  testthat::expect_equal(received$binary_path, result$hysplit_install_directory)
  testthat::expect_equal(received$exec_dir, result$working_directory)
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.rds")))
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.json")))
  persisted <- readRDS(file.path(row$run_directory, "run_metadata.rds"))
  testthat::expect_true(all(c("run_metadata.rds", "run_metadata.json") %in% basename(persisted$actual_output_files)))
  json <- jsonlite::read_json(file.path(row$run_directory, "run_metadata.json"), simplifyVector = TRUE)
  testthat::expect_true(all(c("run_metadata.rds", "run_metadata.json") %in% basename(json$actual_output_files)))
})

testthat::test_that("injected failure returns failed metadata and records the error", {
  row <- make_manifest_row(); cfg <- execution_cfg(); cfg$hysplit$run_root_directory <- tempfile("run-root-"); row$run_directory <- file.path(cfg$hysplit$run_root_directory, row$run_id)
  result <- run_hysplit_manifest_row(row, cfg, dry_run = FALSE, core_fun = function(...) stop("mock failure"))
  testthat::expect_equal(result$status, "failed")
  testthat::expect_match(result$error_message, "mock failure")
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.rds")))
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.json")))
  persisted <- readRDS(file.path(row$run_directory, "run_metadata.rds"))
  testthat::expect_equal(persisted$status, "failed")
  testthat::expect_match(persisted$error_message, "mock failure")
  testthat::expect_true(all(c("run_metadata.rds", "run_metadata.json") %in% basename(persisted$actual_output_files)))
})
