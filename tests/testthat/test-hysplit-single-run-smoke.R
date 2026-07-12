testthat::test_that("smoke selection requires exactly one manifest row", {
  source(file.path(repo_root, "R", "hysplit_single_run_smoke.R"))
  inputs <- smoke_load_manifest(test_cfg)
  testthat::expect_error(smoke_select_row(inputs$manifest, ""), "Exactly one")
  testthat::expect_error(smoke_select_row(inputs$manifest, paste(inputs$manifest$run_id[1:2], collapse = ",")), "Exactly one")
  testthat::expect_equal(smoke_select_row(inputs$manifest, inputs$manifest$run_id[1])$run_id, inputs$manifest$run_id[1])
})

testthat::test_that("smoke preflight rejects missing executable and meteorology", {
  source(file.path(repo_root, "R", "hysplit_single_run_smoke.R"))
  inputs <- smoke_load_manifest(test_cfg); row <- smoke_select_row(inputs$manifest, inputs$manifest$run_id[1]); cfg <- test_cfg
  cfg$hysplit$hysplit_install_directory <- file.path(tempdir(), "not-an-installation")
  testthat::expect_error(smoke_preflight(cfg, row), "does not exist")
  installation <- tempfile("smoke-install-"); dir.create(installation); file.create(file.path(installation, paste0(c("hycs_std", "parhplot"), if (.Platform$OS.type == "windows") ".exe" else ""))); cfg$hysplit$hysplit_install_directory <- installation; cfg$hysplit$meteorology_directory <- file.path(tempdir(), "not-meteorology")
  testthat::expect_error(smoke_preflight(cfg, row), "No local")
})

testthat::test_that("smoke preflight rejects overwrite by default", {
  source(file.path(repo_root, "R", "hysplit_single_run_smoke.R"))
  inputs <- smoke_load_manifest(test_cfg); row <- smoke_select_row(inputs$manifest, inputs$manifest$run_id[1]); cfg <- test_cfg
  installation <- tempfile("smoke-install-"); dir.create(installation); file.create(file.path(installation, paste0(c("hycs_std", "parhplot"), if (.Platform$OS.type == "windows") ".exe" else "")))
  met <- tempfile("smoke-met-"); dir.create(met); file.create(file.path(met, "gdas.arl")); cfg$hysplit$hysplit_install_directory <- installation; cfg$hysplit$meteorology_directory <- met
  dir.create(row$run_directory, recursive = TRUE); file.create(file.path(row$run_directory, "existing.out"))
  testthat::expect_error(smoke_preflight(cfg, row), "refusing to overwrite")
})

testthat::test_that("smoke execution CLI rejects missing authorization", {
  source(file.path(repo_root, "R", "hysplit_single_run_smoke.R"))
  testthat::expect_error(smoke_parse_args(c("--config", "config/facility_exchange_demo.yml", "--run-id", "F001__20200501T000000Z"), require_authorization = TRUE), "authorize-execution")
})

testthat::test_that("ordinary targets graph remains non-executing and execution graph remains gated", {
  ordinary <- paste(readLines(file.path(repo_root, "_targets.R")), collapse = "\n")
  execution <- paste(readLines(file.path(repo_root, "_targets_hysplit.R")), collapse = "\n")
  testthat::expect_false(grepl("run_selected_hysplit_case|run_hysplit_manifest_row", ordinary))
  testthat::expect_true(grepl("EPIPLUME_RUN_IDS", execution, fixed = TRUE))
  testthat::expect_true(grepl("EPIPLUME_ALLOW_HYSPLIT_EXECUTION", execution, fixed = TRUE))
})
