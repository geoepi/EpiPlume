testthat::test_that("controlled multirun selection and readiness controls are explicit", {
  source(file.path(repo_root, "R", "assert_manifest_meteorology_ready.R"))
  manifest <- data.frame(run_id = paste0("R", 1:7), value = 1:7, stringsAsFactors = FALSE)
  testthat::expect_equal(build_pipeline_run_selection(manifest, "R1,R2")$run_id, c("R1", "R2"))
  testthat::expect_error(build_pipeline_run_selection(manifest, "R1,R1"), "duplicates")
  testthat::expect_error(build_pipeline_run_selection(manifest, "UNKNOWN"), "Unknown")
  testthat::expect_error(assert_manifest_meteorology_ready(list(status = "incomplete", run_readiness = data.frame(meteorology_ready = FALSE))), "readiness")
  testthat::expect_silent(assert_manifest_meteorology_ready(list(status = "ready", run_readiness = data.frame(meteorology_ready = TRUE))))
})

testthat::test_that("controlled multirun ledger persists partial progress", {
  source(file.path(repo_root, "R", "write_controlled_multirun_ledger.R"))
  ledger <- data.frame(run_id = "R1", source_id = "F1", release_start = "2020-05-01T00:00:00Z", execution_status = "failed", started_at = Sys.time(), finished_at = Sys.time(), elapsed_seconds = 1, meteorology_ready = TRUE, meteorology_files = "RP202005.gbl", metadata_path = NA, parsed_output_path = NA, receptor_output_path = NA, error_message = "mock failure", warning_count = 0)
  directory <- tempfile("controlled-ledger-"); path <- write_controlled_multirun_ledger(ledger, directory)
  testthat::expect_true(file.exists(path)); testthat::expect_equal(readRDS(sub("[.]csv$", ".rds", path))$execution_status, "failed")
})
