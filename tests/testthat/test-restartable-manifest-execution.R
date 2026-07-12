testthat::test_that("manifest classification distinguishes durable completion and ambiguity", {
  d <- tempfile("restartable-"); dir.create(d); row <- data.frame(run_id = "R1", source_id = "F1", release_start = "2020-05-01T00:00:00Z", run_directory = d, stringsAsFactors = FALSE)
  cfg <- list(hysplit = list(meteorology_directory = d), outputs = list(root_directory = tempfile("ledger-")))
  writeLines("met", file.path(d, "RP202005.gbl")); s <- classify_manifest_execution_state(row, cfg, data.frame(run_id = "R1", meteorology_ready = TRUE)); testthat::expect_equal(s$execution_state, "invalid")
  unlink(file.path(d, "RP202005.gbl")); dir.create(file.path(d, "parsed")); dir.create(file.path(d, "receptors")); saveRDS(list(status = "completed"), file.path(d, "run_metadata.rds")); file.create(file.path(d, "parsed", "parsed_plume.rds")); file.create(file.path(d, "receptors", "source_receptor_exchange.csv")); s <- classify_manifest_execution_state(row, cfg, data.frame(run_id = "R1", meteorology_ready = TRUE)); testthat::expect_equal(s$execution_state, "completed")
})

testthat::test_that("manifest ledger preserves rows atomically", {
  d <- tempfile("ledger-"); x <- data.frame(run_id = "R1", execution_state = "running", attempt_count = 1L, stringsAsFactors = FALSE); update_manifest_execution_ledger(x, directory = d); y <- data.frame(run_id = "R2", execution_state = "completed", attempt_count = 1L, stringsAsFactors = FALSE); out <- update_manifest_execution_ledger(y, directory = d); testthat::expect_equal(sort(out$run_id), c("R1", "R2")); testthat::expect_true(file.exists(file.path(d, "manifest_execution_ledger.csv"))); testthat::expect_true(file.exists(file.path(d, "manifest_execution_ledger.rds")))
})
