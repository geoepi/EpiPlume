make_manifest_row <- function(run_directory = tempfile("hysplit-run-")) {
  facilities <- simulate_facility_network(test_cfg)
  row <- build_hysplit_run_manifest(facilities, test_cfg, facilities$facility_id[1])
  row <- row[1, , drop = FALSE]
  row$run_directory <- run_directory
  row
}

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

testthat::test_that("executable resolution distinguishes unresolved and invalid paths", {
  cfg <- test_cfg; cfg$hysplit$executable_path <- NULL
  old <- Sys.getenv("HYSPLIT_EXECUTABLE", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("HYSPLIT_EXECUTABLE") else Sys.setenv(HYSPLIT_EXECUTABLE = old), add = TRUE)
  Sys.unsetenv("HYSPLIT_EXECUTABLE")
  testthat::expect_true(is.na(resolve_hysplit_executable(cfg, FALSE)))
  cfg$hysplit$executable_path <- tempfile("missing-hysplit-")
  testthat::expect_error(resolve_hysplit_executable(cfg, TRUE), "does not exist")
  cfg$hysplit$executable_path <- NULL
  executable <- tempfile("hysplit-"); file.create(executable)
  if (.Platform$OS.type != "windows") Sys.chmod(executable, mode = "0755")
  Sys.setenv(HYSPLIT_EXECUTABLE = executable)
  testthat::expect_equal(resolve_hysplit_executable(cfg), normalizePath(executable, winslash = "/"))
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
  testthat::expect_equal(spec$core_args$exec_dir, normalizePath(row$run_directory, winslash = "/", mustWork = FALSE))
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

execution_cfg <- function() {
  cfg <- test_cfg
  executable <- tempfile("hysplit-"); file.create(executable)
  if (.Platform$OS.type != "windows") Sys.chmod(executable, mode = "0755")
  met_dir <- tempfile("met-"); dir.create(met_dir); file.create(file.path(met_dir, "input.arl"))
  cfg$hysplit$executable_path <- executable
  cfg$hysplit$meteorology_directory <- met_dir
  cfg
}

testthat::test_that("injected successful execution receives exact core arguments and writes metadata", {
  row <- make_manifest_row(); cfg <- execution_cfg(); received <- NULL
  fake <- function(...) { received <<- list(...); list(particles = data.frame(x = 1)) }
  result <- run_hysplit_manifest_row(row, cfg, dry_run = FALSE, core_fun = fake)
  testthat::expect_equal(result$status, "completed")
  testthat::expect_equal(received$lon, row$source_longitude)
  testthat::expect_equal(received$plume_name, row$run_id)
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.rds")))
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.json")))
})

testthat::test_that("injected failure returns failed metadata and records the error", {
  row <- make_manifest_row(); cfg <- execution_cfg()
  result <- run_hysplit_manifest_row(row, cfg, dry_run = FALSE, core_fun = function(...) stop("mock failure"))
  testthat::expect_equal(result$status, "failed")
  testthat::expect_match(result$error_message, "mock failure")
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.rds")))
  testthat::expect_true(file.exists(file.path(row$run_directory, "run_metadata.json")))
})
