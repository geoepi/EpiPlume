fixture_path <- function(name) file.path(repo_root, "tests", "testthat", "fixtures", name)
read_fixture <- function(name) {
  path <- fixture_path(name)
  columns <- strsplit(readLines(path, n = 1L), ",", fixed = TRUE)[[1]]
  classes <- if ("particle_i" %in% columns) c(particle_i = "character") else NA
  utils::read.csv(path, stringsAsFactors = FALSE, colClasses = classes)
}
parsing_metadata_fixture <- function(run_directory = tempfile("parsed-run-"), dispersion = read_fixture("dispersion_valid.csv")) {
  working_directory <- file.path(run_directory, "splitr_work")
  write_mock_hysplit_artifact(working_directory)
  list(status = "completed", run_id = "F001__20200501T000000Z", scenario_id = "facility_exchange_demo", source_id = "F001", source_longitude = -89, source_latitude = 32.5, release_start = as.POSIXct("2020-05-01 00:00:00", tz = "UTC"), release_end = as.POSIXct("2020-05-01 01:00:00", tz = "UTC"), simulation_start = as.POSIXct("2020-05-01 00:00:00", tz = "UTC"), simulation_end = as.POSIXct("2020-05-01 08:00:00", tz = "UTC"), run_directory = run_directory, working_directory = working_directory, output_directory = run_directory, model_result = structure(list(disp_df = dispersion), class = "dispersion_model"))
}

testthat::test_that("validation and extraction preserve the raw table", {
  fixture <- read_fixture("dispersion_valid.csv")
  located <- validate_hysplit_model_result(structure(list(disp_df = fixture), class = "dispersion_model"))
  testthat::expect_identical(located$dispersion, fixture)
  raw <- extract_hysplit_dispersion_table(list(model_result = list(disp_df = fixture)))
  testthat::expect_equal(names(raw), names(fixture))
  testthat::expect_equal(attr(raw, "extraction_metadata")$n_rows, nrow(fixture))
  testthat::expect_error(validate_hysplit_model_result(NULL), "missing")
  testthat::expect_error(validate_hysplit_model_result(list(foo = 1)), "No dispersion")
})

testthat::test_that("standardization maps known columns and preserves originals", {
  meta <- parsing_metadata_fixture(); out <- standardize_hysplit_dispersion_table(meta$model_result$disp_df, meta)
  canonical <- c("run_id", "scenario_id", "source_id", "particle_id", "datetime_utc", "elapsed_hours", "longitude", "latitude", "height_m", "raw_mass", "raw_concentration", "source_column_set")
  testthat::expect_true(all(canonical %in% names(out)))
  testthat::expect_true(all(paste0("original_", names(meta$model_result$disp_df)) %in% names(out)))
  testthat::expect_equal(out$elapsed_hours, meta$model_result$disp_df$hour)
  testthat::expect_equal(out$datetime_utc[3], meta$release_start + 3600)
  testthat::expect_true(all(out$run_id == meta$run_id))
  ambiguous <- meta$model_result$disp_df; ambiguous$longitude <- ambiguous$lon
  testthat::expect_error(standardize_hysplit_dispersion_table(ambiguous, meta), "Ambiguous")
  mass_only <- standardize_hysplit_dispersion_table(read_fixture("dispersion_mass_only.csv"), meta)
  testthat::expect_true(all(is.na(mass_only$raw_concentration)))
  concentration_only <- standardize_hysplit_dispersion_table(read_fixture("dispersion_concentration_only.csv"), meta)
  testthat::expect_true(all(is.na(concentration_only$raw_mass)))
  testthat::expect_error(standardize_hysplit_dispersion_table(read_fixture("dispersion_missing_particle.csv"), meta), "particle_id")
  testthat::expect_error(standardize_hysplit_dispersion_table(read_fixture("dispersion_missing_time.csv"), meta), "time")
  testthat::expect_error(standardize_hysplit_dispersion_table(read_fixture("dispersion_malformed_coordinates.csv"), meta), "latitude")
})

testthat::test_that("tracer decay preserves raw values and missingness", {
  meta <- parsing_metadata_fixture(); standardized <- standardize_hysplit_dispersion_table(meta$model_result$disp_df, meta)
  decayed <- add_tracer_decay_to_dispersion(standardized, 2)
  testthat::expect_equal(decayed$raw_mass, standardized$raw_mass)
  testthat::expect_equal(decayed$tracer_remaining_fraction[decayed$elapsed_hours == 2], rep(0.5, 2))
  testthat::expect_equal(decayed$decayed_mass[5], standardized$raw_mass[5] * 0.5)
  standardized$raw_mass[1] <- NA_real_
  testthat::expect_true(is.na(add_tracer_decay_to_dispersion(standardized, 2)$decayed_mass[1]))
})

testthat::test_that("distance annotation and filtering are separate", {
  meta <- parsing_metadata_fixture(); d <- add_tracer_decay_to_dispersion(standardize_hysplit_dispersion_table(meta$model_result$disp_df, meta), 2)
  retained <- filter_dispersion_distance(d, -89, 32.5, 20, TRUE)
  testthat::expect_lt(retained$distance_from_source_m[1], 1)
  testthat::expect_true(any(!retained$within_evaluation_distance))
  filtered <- filter_dispersion_distance(d, -89, 32.5, 20, FALSE)
  testthat::expect_true(all(filtered$within_evaluation_distance))
  testthat::expect_lt(nrow(filtered), nrow(retained))
})

testthat::test_that("hourly rasterization preserves geometry and totals", {
  meta <- parsing_metadata_fixture(); d <- add_tracer_decay_to_dispersion(standardize_hysplit_dispersion_table(meta$model_result$disp_df, meta), 2)
  d <- filter_dispersion_distance(d, -89, 32.5, 20)
  template <- build_plume_raster_template(-89, 32.5, 20, 5, 1000)
  counts <- rasterize_hysplit_hourly(d, template, "particle_count")
  mass <- rasterize_hysplit_hourly(d, template, "raw_mass")
  testthat::expect_equal(terra::res(counts$raster), c(1000, 1000))
  testthat::expect_equal(names(counts$raster), c("hour_000", "hour_001", "hour_002"))
  testthat::expect_equal(sum(terra::values(counts$raster)), nrow(d))
  testthat::expect_equal(sum(terra::values(mass$raster), na.rm = TRUE), sum(d$raw_mass))
  testthat::expect_true(any(terra::values(counts$raster) == 0))
  testthat::expect_true(any(is.na(terra::values(mass$raster))))
})

testthat::test_that("end-to-end parsing is non-writing by default and validates status", {
  meta <- parsing_metadata_fixture(); parsed <- parse_hysplit_run_output(meta, test_cfg)
  testthat::expect_equal(parsed$plume_summary$parse_status, "completed")
  testthat::expect_false(dir.exists(file.path(meta$run_directory, "parsed")))
  dry <- meta; dry$status <- "dry_run"
  testthat::expect_error(parse_hysplit_run_output(dry, test_cfg), "Only completed")
  failed <- meta; failed$status <- "failed"
  testthat::expect_error(parse_hysplit_run_output(failed, test_cfg), "Only completed")
  missing <- meta; missing$model_result <- NULL
  testthat::expect_error(parse_hysplit_run_output(missing, test_cfg), "missing")
})

testthat::test_that("writer inventories outputs and protects against overwrite", {
  meta <- parsing_metadata_fixture(); parsed <- parse_hysplit_run_output(meta, test_cfg,
    write_outputs = TRUE, refresh_run_index = FALSE)
  inventory <- parsed$parsing_metadata$written_files
  testthat::expect_true(all(file.exists(inventory$path)))
  testthat::expect_true(all(c("parsing_metadata.rds", "parsing_metadata.json") %in% basename(inventory$path)))
  persisted <- readRDS(file.path(meta$run_directory, "parsed", "parsing_metadata.rds"))
  testthat::expect_equal(nrow(persisted$written_files), nrow(inventory))
  testthat::expect_error(write_hysplit_parsed_outputs(parsed, meta$run_directory), "overwrite")
  testthat::expect_silent(write_hysplit_parsed_outputs(parsed, meta$run_directory, TRUE))
})
