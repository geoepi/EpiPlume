execution_validation_fixture <- function(artifact = TRUE,
    dispersion = mock_valid_hysplit_dispersion(), warnings = character()) {
  run_directory <- tempfile("execution-validation-")
  working_directory <- file.path(run_directory, "splitr_work")
  dir.create(working_directory, recursive = TRUE)
  if (artifact) write_mock_hysplit_artifact(working_directory)
  list(
    result = structure(list(disp_df = dispersion), class = "dispersion_model"),
    spec = list(run_directory = run_directory, output_directory = run_directory,
      working_directory = working_directory),
    warnings = warnings
  )
}

testthat::test_that("execution-result validation accepts substantive nonempty output", {
  x <- execution_validation_fixture()
  validation <- validate_hysplit_execution_result(x$result, x$spec)
  testthat::expect_true(validation$valid)
  testthat::expect_equal(validation$dispersion_rows, 2)
  testthat::expect_length(validation$missing_files, 0)
  testthat::expect_true(any(grepl("output.bin", validation$required_files, fixed = TRUE)))
})

testthat::test_that("execution-result validation rejects empty and malformed dispersion", {
  empty <- mock_valid_hysplit_dispersion()[FALSE, , drop = FALSE]
  x <- execution_validation_fixture(dispersion = empty)
  validation <- validate_hysplit_execution_result(x$result, x$spec)
  testthat::expect_false(validation$valid)
  testthat::expect_match(validation$error_message, "zero rows")

  malformed <- mock_valid_hysplit_dispersion(); malformed$height <- NULL
  x <- execution_validation_fixture(dispersion = malformed)
  validation <- validate_hysplit_execution_result(x$result, x$spec)
  testthat::expect_false(validation$valid)
  testthat::expect_match(validation$error_message, "height")

  nonfinite <- mock_valid_hysplit_dispersion(); nonfinite$lon[1] <- Inf
  x <- execution_validation_fixture(dispersion = nonfinite)
  testthat::expect_match(validate_hysplit_execution_result(x$result, x$spec)$error_message, "longitude")
})

testthat::test_that("execution-result validation rejects command warnings and missing output", {
  x <- execution_validation_fixture(warnings = "error in running command")
  validation <- validate_hysplit_execution_result(x$result, x$spec, x$warnings)
  testthat::expect_false(validation$valid)
  testthat::expect_equal(validation$failure_stage, "execution")
  testthat::expect_equal(validation$warnings, x$warnings)

  diagnostic <- execution_validation_fixture()
  writeLines("FATAL ERROR: command execution failed", file.path(diagnostic$spec$working_directory, "MESSAGE"))
  diagnostic_validation <- validate_hysplit_execution_result(diagnostic$result, diagnostic$spec)
  testthat::expect_false(diagnostic_validation$valid)
  testthat::expect_match(diagnostic_validation$error_message, "MESSAGE")
  testthat::expect_match(diagnostic_validation$diagnostics$MESSAGE, "command execution failed")

  x <- execution_validation_fixture(artifact = FALSE)
  writeLines("control", file.path(x$spec$working_directory, "CONTROL"))
  writeLines("setup", file.path(x$spec$working_directory, "SETUP.CFG"))
  validation <- validate_hysplit_execution_result(x$result, x$spec)
  testthat::expect_false(validation$valid)
  testthat::expect_equal(validation$failure_stage, "output_discovery")
  testthat::expect_length(validation$missing_files, 1)

  stale <- execution_validation_fixture()
  Sys.setFileTime(file.path(stale$spec$working_directory, "output.bin"), Sys.time() - 3600)
  stale$spec$artifact_not_before <- Sys.time()
  stale_validation <- validate_hysplit_execution_result(stale$result, stale$spec)
  testthat::expect_false(stale_validation$valid)
  testthat::expect_match(stale_validation$error_message, "No substantive")
})

testthat::test_that("five-run known-good HYSPLIT diagnostic and artifact pattern is accepted", {
  validations <- lapply(seq_len(5), function(i) {
    x <- execution_validation_fixture(artifact = FALSE)
    writeLines(paste("mock particle dump", i), file.path(x$spec$working_directory, "PARDUMP"))
    writeLines(c("WARNING: metini - FLUXES not found in data", "NOTICE sfcinp: LANDUSE.ASC file not found"),
      file.path(x$spec$working_directory, "MESSAGE"))
    writeLines("WARNING: metini - FLUXES not found in data", file.path(x$spec$working_directory, "WARNING"))
    validate_hysplit_execution_result(x$result, x$spec)
  })
  testthat::expect_true(all(vapply(validations, `[[`, logical(1), "valid")))
  testthat::expect_true(all(vapply(validations, function(x) any(grepl("PARDUMP", x$output_artifacts, fixed = TRUE)), logical(1))))
})

testthat::test_that("adapter writes invalid returned output as failed metadata", {
  row <- make_manifest_row(); cfg <- execution_cfg()
  cfg$hysplit$run_root_directory <- tempfile("invalid-result-root-")
  row$run_directory <- file.path(cfg$hysplit$run_root_directory, row$run_id)
  fake <- function(...) {
    x <- list(...); dir.create(x$exec_dir, recursive = TRUE, showWarnings = FALSE)
    writeLines("control", file.path(x$exec_dir, "CONTROL"))
    writeLines("FATAL ERROR: command execution failed", file.path(x$exec_dir, "MESSAGE"))
    writeLines("error in running command", file.path(x$exec_dir, "WARNING"))
    warning("error in running command")
    list(disp_df = mock_valid_hysplit_dispersion()[FALSE, , drop = FALSE])
  }
  metadata <- run_hysplit_manifest_row(row, cfg, dry_run = FALSE, core_fun = fake)
  testthat::expect_equal(metadata$status, "failed")
  testthat::expect_match(metadata$error_message, "zero rows")
  testthat::expect_match(metadata$warnings, "error in running command")
  testthat::expect_true(is.finite(metadata$elapsed_seconds))
  testthat::expect_true(file.exists(file.path(row$run_directory, "splitr_work", "CONTROL")))
  testthat::expect_true(all(file.exists(file.path(row$run_directory, "splitr_work", c("MESSAGE", "WARNING")))))
  persisted <- readRDS(file.path(row$run_directory, "run_metadata.rds"))
  testthat::expect_false(persisted$execution_validation$valid)
  testthat::expect_true(all(c("MESSAGE", "WARNING") %in% basename(persisted$actual_output_files)))
})

testthat::test_that("legacy false completions classify as execution failures without meteorology readiness", {
  directory <- tempfile("legacy-false-completion-"); dir.create(directory)
  working <- file.path(directory, "splitr_work"); dir.create(working)
  writeLines("control", file.path(working, "CONTROL"))
  metadata <- list(status = "completed", run_id = "R1", run_directory = directory,
    working_directory = working, output_directory = directory,
    warnings = "error in running command",
    model_result = list(disp_df = mock_valid_hysplit_dispersion()[FALSE, , drop = FALSE]))
  saveRDS(metadata, file.path(directory, "run_metadata.rds"))
  manifest <- data.frame(run_id = "R1", source_id = "F1", release_start = "2020-05-01T00:00:00Z",
    run_directory = directory, stringsAsFactors = FALSE)
  cfg <- list(hysplit = list(meteorology_directory = tempfile("missing-met-"),
    run_root_directory = dirname(directory)))
  state <- classify_manifest_execution_state(manifest, cfg)
  testthat::expect_equal(state$execution_state, "execution_failed")
  testthat::expect_false(state$execution_completed)
  testthat::expect_match(state$last_error, "zero rows")
})

testthat::test_that("valid durable completion is recognized without meteorology readiness", {
  directory <- tempfile("valid-completion-"); dir.create(directory)
  metadata <- durable_completed_metadata(directory, "R1")
  saveRDS(metadata, file.path(directory, "run_metadata.rds"))
  dir.create(file.path(directory, "parsed")); saveRDS(list(), file.path(directory, "parsed", "parsed_plume.rds"))
  dir.create(file.path(directory, "receptors")); writeLines("run_id", file.path(directory, "receptors", "source_receptor_exchange.csv"))
  manifest <- data.frame(run_id = "R1", source_id = "F1", release_start = "2020-05-01T00:00:00Z",
    run_directory = directory, stringsAsFactors = FALSE)
  cfg <- list(hysplit = list(meteorology_directory = tempfile("missing-met-"),
    run_root_directory = dirname(directory)))
  testthat::expect_equal(classify_manifest_execution_state(manifest, cfg)$execution_state, "completed")
})

testthat::test_that("reconciliation is dry-run by default and backs up changes on apply", {
  root <- tempfile("reconciliation-root-"); dir.create(root)
  bad_dir <- file.path(root, "BAD"); good_dir <- file.path(root, "GOOD")
  dir.create(bad_dir); dir.create(good_dir)
  bad_work <- file.path(bad_dir, "splitr_work"); dir.create(bad_work)
  writeLines("control", file.path(bad_work, "CONTROL"))
  bad <- list(status = "completed", run_id = "BAD", run_directory = bad_dir,
    working_directory = bad_work, output_directory = bad_dir,
    warnings = "error in running command",
    model_result = list(disp_df = mock_valid_hysplit_dispersion()[FALSE, , drop = FALSE]))
  good <- durable_completed_metadata(good_dir, "GOOD")
  saveRDS(bad, file.path(bad_dir, "run_metadata.rds")); saveRDS(good, file.path(good_dir, "run_metadata.rds"))
  jsonlite::write_json(list(status = "completed", run_id = "BAD"), file.path(bad_dir, "run_metadata.json"), auto_unbox = TRUE)
  jsonlite::write_json(list(status = "completed", run_id = "GOOD"), file.path(good_dir, "run_metadata.json"), auto_unbox = TRUE)
  manifest <- data.frame(run_id = c("BAD", "GOOD"), run_directory = c(bad_dir, good_dir), stringsAsFactors = FALSE)
  cfg <- test_cfg; cfg$hysplit$run_root_directory <- root

  proposal <- reconcile_hysplit_run_status(manifest, cfg, c("BAD", "GOOD"))
  testthat::expect_equal(proposal$proposed_status, c("failed", "completed"))
  testthat::expect_equal(readRDS(file.path(bad_dir, "run_metadata.rds"))$status, "completed")
  testthat::expect_false(file.exists(file.path(bad_dir, "run_metadata.pre_reconciliation.rds")))

  applied <- reconcile_hysplit_run_status(manifest, cfg, c("BAD", "GOOD"), apply = TRUE)
  testthat::expect_true(attr(applied, "applied"))
  testthat::expect_true(all(file.exists(file.path(bad_dir, c(
    "run_metadata.pre_reconciliation.rds", "run_metadata.pre_reconciliation.json")))))
  testthat::expect_equal(readRDS(file.path(bad_dir, "run_metadata.pre_reconciliation.rds"))$status, "completed")
  reconciled <- readRDS(file.path(bad_dir, "run_metadata.rds"))
  testthat::expect_equal(reconciled$status, "failed")
  testthat::expect_match(reconciled$error_message, "zero rows")
  testthat::expect_equal(readRDS(file.path(good_dir, "run_metadata.rds"))$status, "completed")
})

testthat::test_that("reconciliation CLI is dry-run unless apply is explicit", {
  script <- file.path(repo_root, "scripts", "reconcile_hysplit_run_status.R")
  testthat::expect_silent(parse(script))
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, 'apply <- "--apply" %in% args', fixed = TRUE)
  testthat::expect_match(text, "Dry run only", fixed = TRUE)
})
