testthat::test_that("reanalysis monthly filenames cover UTC interval boundaries", {
  utc <- function(x) as.POSIXct(x, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  testthat::expect_equal(splitr_required_meteorology_files(utc("2020-05-10 00:00:00"), 24, "forward", "reanalysis"), "RP202005.gbl")
  testthat::expect_setequal(splitr_required_meteorology_files(utc("2020-04-30 23:00:00"), 2, "forward", "reanalysis"), c("RP202004.gbl", "RP202005.gbl"))
  testthat::expect_setequal(splitr_required_meteorology_files(utc("2020-12-31 23:00:00"), 2, "forward", "reanalysis"), c("RP202012.gbl", "RP202101.gbl"))
  testthat::expect_setequal(splitr_required_meteorology_files(utc("2020-05-01 01:00:00"), 2, "backward", "reanalysis"), c("RP202004.gbl", "RP202005.gbl"))
})

testthat::test_that("manifest meteorology planning deduplicates shared files", {
  row1 <- make_manifest_row(); row2 <- row1; row2$run_id <- "second-run"
  plan <- plan_hysplit_manifest_meteorology(rbind(row1, row2), test_cfg)
  testthat::expect_equal(plan$summary$unique_required_file_count, 1L)
  testthat::expect_equal(plan$unique_files$required_by_n_runs, 2L)
})
