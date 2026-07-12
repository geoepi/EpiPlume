multirun_paths <- function() list(manifest = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_manifest.csv"), facilities = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_facilities.csv"), root = file.path(repo_root, "tests", "testthat", "fixtures", "multirun_runs"))
multi_manifest <- function() utils::read.csv(multirun_paths()$manifest, stringsAsFactors = FALSE)
multi_facilities <- function() utils::read.csv(multirun_paths()$facilities, stringsAsFactors = FALSE)
assembled_cache <- NULL
get_assembled <- function() { if (is.null(assembled_cache)) assembled_cache <<- assemble_multirun_facility_connectivity(multi_manifest(), multi_facilities(), test_cfg, multirun_paths()$root); assembled_cache }

testthat::test_that("inventory retains and classifies every deterministic manifest row", {
  inventory <- discover_parsed_run_inventory(multi_manifest(), multirun_paths()$root)
  testthat::expect_equal(nrow(inventory), 8)
  testthat::expect_equal(sum(inventory$available_for_processing), 6)
  testthat::expect_equal(inventory$run_status[inventory$run_id == "R007"], "failed")
  testthat::expect_equal(inventory$run_status[inventory$run_id == "R008"], "missing")
  testthat::expect_equal(inventory$run_id[1], "R001")
  duplicate <- multi_manifest(); duplicate$run_id[2] <- duplicate$run_id[1]
  testthat::expect_error(discover_parsed_run_inventory(duplicate, multirun_paths()$root), "duplicate")
})

testthat::test_that("processor reuses injected extraction and records failures", {
  inventory <- validate_parsed_run_inventory(discover_parsed_run_inventory(multi_manifest(), multirun_paths()$root)); calls <- character()
  fake <- function(parsed, facilities, cfg, write_outputs, overwrite) { calls <<- c(calls, parsed$parsing_metadata$run_id); if (parsed$parsing_metadata$run_id == "R003") stop("injected failure"); list(exchange_table = data.frame(run_id = character())) }
  result <- process_parsed_run_inventory(inventory, multi_facilities(), test_cfg, TRUE, extract_fun = fake)
  testthat::expect_equal(length(calls), 6); testthat::expect_equal(nrow(result$failed_runs), 1)
  testthat::expect_error(process_parsed_run_inventory(inventory, multi_facilities(), test_cfg, FALSE, extract_fun = fake), "injected failure")
  empty <- inventory; empty$available_for_processing <- FALSE
  testthat::expect_equal(nrow(process_parsed_run_inventory(empty, multi_facilities(), test_cfg)$combined_exchange_table), 0)
})

testthat::test_that("combined exchanges preserve rows and directed release fields", {
  assembled <- get_assembled(); exchange <- assembled$combined_exchange_table
  testthat::expect_equal(nrow(exchange), sum(vapply(split(exchange, exchange$run_id), nrow, integer(1))))
  testthat::expect_true(all(exchange$source_receptor_id == paste(exchange$source_id, exchange$receptor_id, sep = "__")))
  testthat::expect_true(any(!exchange$intercept)); testthat::expect_true(all(!is.na(exchange$release_date)))
  testthat::expect_equal(length(unique(exchange$run_id)), 6)
})

testthat::test_that("time, source, receptor, and dyad summaries retain zeros and repeats", {
  assembled <- get_assembled(); exchange <- assembled$combined_exchange_table
  day <- assembled$time_summaries$day
  testthat::expect_true(all(day$n_candidate_pairs == vapply(day$period, function(p) sum(exchange$release_date == as.Date(p) & exchange$within_evaluation_distance), integer(1))))
  testthat::expect_true(all(day$intercept_fraction >= 0 & day$intercept_fraction <= 1))
  testthat::expect_equal(nrow(assembled$source_summary), length(unique(exchange$source_id)))
  testthat::expect_true(any(assembled$receptor_summary$total_intercept_events == 0))
  testthat::expect_true(any(assembled$dyad_summary$intercept_frequency == 0))
  testthat::expect_true(all(assembled$dyad_summary$n_intercept_runs <= assembled$dyad_summary$n_runs_evaluated))
  expected_source <- read.csv(file.path(repo_root, "tests", "testthat", "fixtures", "expected_multirun_source_summary.csv"), stringsAsFactors = FALSE, na.strings = "NA")
  stable <- setdiff(names(expected_source), c("first_release_start", "last_release_start"))
  actual_source <- as.data.frame(assembled$source_summary)[, stable]; rownames(actual_source) <- NULL
  testthat::expect_equal(actual_source, expected_source[, stable])
})

testthat::test_that("directed matrices distinguish evaluated zero from unevaluated NA", {
  assembled <- get_assembled(); matrix <- assembled$connectivity_matrices$intercept_frequency; ids <- sort(multi_facilities()$facility_id)
  testthat::expect_equal(dim(matrix), c(length(ids), length(ids))); testthat::expect_equal(rownames(matrix), ids); testthat::expect_true(all(is.na(diag(matrix))))
  zero <- assembled$dyad_summary[assembled$dyad_summary$intercept_frequency == 0, ][1, ]; testthat::expect_equal(matrix[zero$source_id, zero$receptor_id], 0)
  evaluated <- paste(assembled$dyad_summary$source_id, assembled$dyad_summary$receptor_id); candidates <- expand.grid(source = ids, receptor = ids); candidates <- candidates[candidates$source != candidates$receptor & !paste(candidates$source, candidates$receptor) %in% evaluated, ][1, ]; testthat::expect_true(is.na(matrix[candidates$source, candidates$receptor]))
  expected <- readRDS(file.path(repo_root, "tests", "testthat", "fixtures", "expected_connectivity_matrix_intercept_frequency.rds")); testthat::expect_equal(matrix, expected)
})

testthat::test_that("multi-run writer inventories outputs and protects overwrite", {
  assembled <- get_assembled(); directory <- tempfile("multirun-output-"); metadata <- write_multirun_connectivity_outputs(assembled, directory)
  testthat::expect_true(all(file.exists(metadata$written_files$path))); testthat::expect_true(all(!is.na(metadata$written_files$md5[!grepl("assembly_metadata", metadata$written_files$path)])))
  testthat::expect_error(write_multirun_connectivity_outputs(assembled, directory), "overwrite")
  testthat::expect_silent(write_multirun_connectivity_outputs(assembled, directory, TRUE))
})
