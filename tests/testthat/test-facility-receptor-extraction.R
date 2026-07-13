receptor_fixture <- function() utils::read.csv(file.path(repo_root, "tests", "testthat", "fixtures", "receptor_facilities.csv"), stringsAsFactors = FALSE)
parsed_fixture <- function() readRDS(file.path(repo_root, "tests", "testthat", "fixtures", "completed_parsed_plume.rds"))

testthat::test_that("receptor preparation uses projected deterministic points and buffers", {
  facilities <- receptor_fixture(); receptors <- prepare_receptor_facilities(facilities, "F001", -89, 32.5, 20, 500)
  testthat::expect_false("F001" %in% receptors$metadata$facility_id)
  testthat::expect_equal(receptors$metadata$facility_id, sort(receptors$metadata$facility_id))
  testthat::expect_lt(receptors$metadata$distance_from_source_m[receptors$metadata$facility_id == "F002"], 50)
  testthat::expect_false(receptors$metadata$within_evaluation_distance[receptors$metadata$facility_id == "F006"])
  testthat::expect_true(sf::st_is_longlat(receptors$points) %in% FALSE)
  areas <- as.numeric(sf::st_area(receptors$buffers)); testthat::expect_equal(areas[1], pi * 500^2, tolerance = 1000)
})

testthat::test_that("point and buffer sampling preserve zero, NA, and extent state", {
  parsed <- parsed_fixture(); facilities <- receptor_fixture(); receptors <- prepare_receptor_facilities(facilities, "F001", -89, 32.5, 20, 500)
  point <- sample_hourly_plume_at_receptors(parsed, receptors, "point")
  buffer <- sample_hourly_plume_at_receptors(parsed, receptors, "buffer", "sum")
  testthat::expect_true(any(point$sample_value == 0, na.rm = TRUE))
  testthat::expect_true(all(is.na(point$sample_value[!point$within_evaluation_distance])))
  testthat::expect_gte(sum(buffer$sample_value[buffer$receptor_id == "F008" & buffer$metric == "particle_count"], na.rm = TRUE), sum(point$sample_value[point$receptor_id == "F008" & point$metric == "particle_count"], na.rm = TRUE))
  testthat::expect_true(all(is.na(point$sample_value[point$receptor_id == "F007" & !point$inside_raster_extent])))
})

testthat::test_that("timing summaries distinguish arrivals and no exposure", {
  parsed <- parsed_fixture(); receptors <- prepare_receptor_facilities(receptor_fixture(), "F001", -89, 32.5, 20, 500)
  sampled <- sample_hourly_plume_at_receptors(parsed, receptors, "buffer", "max")
  summaries <- summarize_receptor_time_series(sampled, parsed$parsing_metadata$release_start, "particle_count", 1)
  early <- summaries[summaries$receptor_id == "F003" & summaries$metric == "particle_count", ]
  delayed <- summaries[summaries$receptor_id == "F004" & summaries$metric == "particle_count", ]
  none <- summaries[summaries$receptor_id == "F005" & summaries$metric == "particle_count", ]
  testthat::expect_equal(early$first_threshold_hour, 0)
  testthat::expect_equal(delayed$first_threshold_hour, 1)
  testthat::expect_gte(early$exposure_duration_hours, 1)
  testthat::expect_true(is.na(none$first_arrival_datetime_utc))
  testthat::expect_equal(early$time_of_maximum_utc, parsed$parsing_metadata$release_start)
})

testthat::test_that("exchange table retains one deterministic explicit receptor record", {
  cfg <- test_cfg; cfg$exposure$sampling_method <- "buffer"
  exchange <- build_source_receptor_exchange(parsed_fixture(), receptor_fixture(), cfg)
  testthat::expect_equal(nrow(exchange), nrow(receptor_fixture()) - 1L)
  testthat::expect_false("F001" %in% exchange$receptor_id)
  testthat::expect_equal(exchange$receptor_id, sort(exchange$receptor_id))
  testthat::expect_true(all(c("particle_count_max", "particle_count_cumulative", "raw_mass_max", "decayed_concentration_hourly_sum") %in% names(exchange)))
  testthat::expect_equal(exchange$intercept_reason[exchange$receptor_id == "F006"], "outside_evaluation_distance")
  testthat::expect_true(any(!exchange$intercept))
  testthat::expect_true(exchange$particle_count_cumulative[exchange$receptor_id == "F005"] == 0)
  expected <- utils::read.csv(file.path(repo_root, "tests", "testthat", "fixtures", "expected_source_receptor_exchange.csv"), stringsAsFactors = FALSE, na.strings = "NA")
  keep <- names(expected)
  testthat::expect_equal(exchange[, keep], expected)
})

testthat::test_that("end-to-end extraction writes complete protected metadata", {
  parsed <- parsed_fixture(); parsed$parsing_metadata$run_directory <- tempfile("receptor-run-")
  result <- extract_facility_receptors_from_plume(parsed, receptor_fixture(), test_cfg)
  testthat::expect_false(dir.exists(parsed$parsing_metadata$run_directory))
  written <- extract_facility_receptors_from_plume(parsed, receptor_fixture(), test_cfg, TRUE,
    refresh_run_index = FALSE)
  inventory <- written$extraction_metadata$written_files
  testthat::expect_true(all(file.exists(inventory$path)))
  testthat::expect_true(all(c("extraction_metadata.rds", "extraction_metadata.json") %in% basename(inventory$path)))
  testthat::expect_true(all(!is.na(inventory$md5[!grepl("extraction_metadata", inventory$path)])))
  testthat::expect_error(write_facility_receptor_outputs(written, parsed$parsing_metadata$run_directory), "overwrite")
  testthat::expect_silent(write_facility_receptor_outputs(written, parsed$parsing_metadata$run_directory, TRUE))
})
