restart_execution_cfg <- function() {
  cfg <- test_cfg; met <- tempfile("restart-met-"); dir.create(met); file.create(file.path(met, "input.arl")); install <- tempfile("restart-install-"); dir.create(install); suffix <- if (.Platform$OS.type == "windows") ".exe" else ""; binaries <- file.path(install, paste0(c("hycs_std", "parhplot"), suffix)); file.create(binaries); if (.Platform$OS.type != "windows") Sys.chmod(binaries, "0755"); cfg$hysplit$meteorology_directory <- met; cfg$hysplit$hysplit_install_directory <- install; cfg$outputs$root_directory <- tempfile("restart-output-"); cfg
}
restart_manifest_row <- function() { facilities <- simulate_facility_network(test_cfg); x <- build_hysplit_run_manifest(facilities, test_cfg, facilities$facility_id[1]); x <- x[1, , drop = FALSE]; x$run_directory <- tempfile("restart-run-"); x }

testthat::test_that("manifest classification distinguishes durable completion and ambiguity", {
  d <- tempfile("restartable-"); dir.create(d); row <- data.frame(run_id = "R1", source_id = "F1", release_start = "2020-05-01T00:00:00Z", run_directory = d, stringsAsFactors = FALSE)
  cfg <- list(hysplit = list(meteorology_directory = d), outputs = list(root_directory = tempfile("ledger-")))
  writeLines("met", file.path(d, "RP202005.gbl")); s <- classify_manifest_execution_state(row, cfg, data.frame(run_id = "R1", meteorology_ready = TRUE)); testthat::expect_equal(s$execution_state, "invalid")
  unlink(file.path(d, "RP202005.gbl")); dir.create(file.path(d, "parsed")); dir.create(file.path(d, "receptors")); saveRDS(list(status = "completed"), file.path(d, "run_metadata.rds")); file.create(file.path(d, "parsed", "parsed_plume.rds")); file.create(file.path(d, "receptors", "source_receptor_exchange.csv")); s <- classify_manifest_execution_state(row, cfg, data.frame(run_id = "R1", meteorology_ready = TRUE)); testthat::expect_equal(s$execution_state, "completed")
})

testthat::test_that("manifest ledger preserves rows atomically", {
  d <- tempfile("ledger-"); x <- data.frame(run_id = "R1", execution_state = "running", attempt_count = 1L, stringsAsFactors = FALSE); update_manifest_execution_ledger(x, directory = d); y <- data.frame(run_id = "R2", execution_state = "completed", attempt_count = 1L, stringsAsFactors = FALSE); out <- update_manifest_execution_ledger(y, directory = d); testthat::expect_equal(sort(out$run_id), c("R1", "R2")); testthat::expect_true(file.exists(file.path(d, "manifest_execution_ledger.csv"))); testthat::expect_true(file.exists(file.path(d, "manifest_execution_ledger.rds")))
})

testthat::test_that("the real adapter accepts only the recognized execution lock", {
  cfg <- restart_execution_cfg(); row <- restart_manifest_row(); ready <- data.frame(run_id = row$run_id, meteorology_ready = TRUE)
  saw_lock <- FALSE
  fake <- function(...) { saw_lock <<- dir.exists(file.path(row$run_directory, ".execution.lock")); list(particles = data.frame(x = 1)) }
  result <- run_hysplit_manifest_subset(row, cfg, workers = 1L, parse_outputs = FALSE, extract_receptors = FALSE, core_fun = fake, meteorology_readiness = ready)
  testthat::expect_true(saw_lock)
  testthat::expect_equal(result$results[[1]]$execution_state, "completed")
  testthat::expect_false(dir.exists(file.path(row$run_directory, ".execution.lock")))

  unrelated <- restart_manifest_row(); dir.create(unrelated$run_directory); writeLines("ambiguous", file.path(unrelated$run_directory, "unrelated.txt"))
  testthat::expect_error(run_hysplit_manifest_row(unrelated, cfg, dry_run = FALSE, core_fun = fake), "not empty")

  failed <- restart_manifest_row(); ready$run_id <- failed$run_id
  failure <- run_hysplit_manifest_subset(failed, cfg, parse_outputs = FALSE, extract_receptors = FALSE, core_fun = function(...) stop("controlled failure"), meteorology_readiness = ready)
  testthat::expect_equal(failure$results[[1]]$execution_state, "execution_failed")
  testthat::expect_false(dir.exists(file.path(failed$run_directory, ".execution.lock")))
})

testthat::test_that("classification separates execution and postprocessing eligibility", {
  cfg <- restart_execution_cfg(); base <- restart_manifest_row(); rows <- base[rep(1, 7), , drop = FALSE]
  rows$run_id <- c("complete", "parse", "receptor", "failed", "running", "invalid", "empty")
  rows$run_directory <- vapply(rows$run_id, function(x) tempfile(paste0(x, "-")), character(1)); rows$source_id <- paste0("F", seq_len(7))
  for (d in rows$run_directory) dir.create(d)
  completed <- function(i) saveRDS(list(status = "completed"), file.path(rows$run_directory[i], "run_metadata.rds"))
  for (i in 1:3) completed(i)
  for (i in c(1, 3)) { dir.create(file.path(rows$run_directory[i], "parsed")); saveRDS(list(), file.path(rows$run_directory[i], "parsed", "parsed_plume.rds")) }
  dir.create(file.path(rows$run_directory[1], "receptors")); file.create(file.path(rows$run_directory[1], "receptors", "source_receptor_exchange.csv"))
  saveRDS(list(status = "failed", error_message = "x"), file.path(rows$run_directory[4], "run_metadata.rds"))
  dir.create(file.path(rows$run_directory[5], ".execution.lock")); writeLines("x", file.path(rows$run_directory[6], "unknown"))
  ready <- data.frame(run_id = rows$run_id, meteorology_ready = TRUE); x <- classify_manifest_execution_state(rows, cfg, ready)
  testthat::expect_equal(x$execution_state, c("completed", "parse_failed", "receptor_failed", "execution_failed", "running", "invalid", "planned"))
  testthat::expect_equal(x$eligible_for_execution, c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE))
  testthat::expect_equal(x$eligible_for_postprocessing, c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
})

testthat::test_that("parse and receptor failures resume postprocessing without model execution", {
  cfg <- restart_execution_cfg(); row <- restart_manifest_row(); dir.create(row$run_directory); metadata <- list(status = "completed", run_id = row$run_id); saveRDS(metadata, file.path(row$run_directory, "run_metadata.rds")); ready <- data.frame(run_id = row$run_id, meteorology_ready = TRUE)
  parse_calls <- 0L; receptor_calls <- 0L
  parse_fake <- function(run_metadata, cfg, write_outputs, overwrite) { parse_calls <<- parse_calls + 1L; dir.create(file.path(row$run_directory, "parsed")); parsed <- list(marker = "parsed"); saveRDS(parsed, file.path(row$run_directory, "parsed", "parsed_plume.rds")); parsed }
  receptor_fake <- function(parsed, facilities, cfg, write_outputs, overwrite) { receptor_calls <<- receptor_calls + 1L; dir.create(file.path(row$run_directory, "receptors")); utils::write.csv(data.frame(run_id = row$run_id), file.path(row$run_directory, "receptors", "source_receptor_exchange.csv"), row.names = FALSE); list(marker = "receptors") }
  result <- run_hysplit_manifest_subset(row, cfg, core_fun = function(...) stop("model must not execute"), meteorology_readiness = ready, facilities = data.frame(), parse_fun = parse_fake, receptor_fun = receptor_fake)
  testthat::expect_equal(c(parse_calls, receptor_calls), c(1L, 1L)); testthat::expect_equal(result$results[[1]]$execution_state, "completed")
  ledger <- readRDS(result$ledger); testthat::expect_equal(ledger$attempt_count, 0L)

  unlink(file.path(row$run_directory, "receptors"), recursive = TRUE); parse_calls <- 0L; receptor_calls <- 0L
  result <- run_hysplit_manifest_subset(row, cfg, core_fun = function(...) stop("model must not execute"), meteorology_readiness = ready, facilities = data.frame(), parse_fun = function(...) { parse_calls <<- parse_calls + 1L; stop("parse must not repeat") }, receptor_fun = receptor_fake)
  testthat::expect_equal(c(parse_calls, receptor_calls), c(0L, 1L)); testthat::expect_equal(result$results[[1]]$execution_state, "completed"); testthat::expect_equal(readRDS(result$ledger)$attempt_count, 0L)
})

testthat::test_that("bounded PSOCK execution preserves order and independent outcomes", {
  cfg <- restart_execution_cfg(); first <- restart_manifest_row(); second <- first; second$run_id <- paste0(first$run_id, "_B"); first$run_id <- paste0(first$run_id, "_A"); first$run_directory <- tempfile("parallel-a-"); second$run_directory <- tempfile("parallel-b-"); rows <- rbind(first, second)
  ready <- data.frame(run_id = rows$run_id, meteorology_ready = TRUE)
  fake <- function(...) { x <- list(...); if (grepl("_B$", x$plume_name)) stop("independent worker failure"); list(lock_seen = dir.exists(file.path(dirname(x$exec_dir), ".execution.lock"))) }
  result <- run_hysplit_manifest_subset(rows, cfg, workers = 8L, continue_on_error = TRUE, parse_outputs = FALSE, extract_receptors = FALSE, core_fun = fake, meteorology_readiness = ready)
  testthat::expect_equal(names(result$results), rows$run_id)
  testthat::expect_equal(unname(vapply(result$results, `[[`, character(1), "execution_state")), c("completed", "execution_failed"))
  persisted <- readRDS(file.path(first$run_directory, "run_metadata.rds")); testthat::expect_true(persisted$model_result$lock_seen)
  testthat::expect_equal(result$workers, 2L)
  testthat::expect_false(any(dir.exists(file.path(rows$run_directory, ".execution.lock"))))
  ledger <- readRDS(result$ledger); testthat::expect_setequal(ledger$run_id, rows$run_id); testthat::expect_equal(ledger$attempt_count[match(rows$run_id, ledger$run_id)], c(1L, 1L))
})

testthat::test_that("CLI requires separate authorization for a full manifest", {
  script <- paste(readLines(file.path(repo_root, "scripts", "run_hysplit_manifest_subset.R"), warn = FALSE), collapse = "\n")
  testthat::expect_match(script, "--authorize-full-manifest", fixed = TRUE)
  testthat::expect_match(script, "Omitting --run-ids requires", fixed = TRUE)
  testthat::expect_silent(parse(file.path(repo_root, "scripts", "run_hysplit_manifest_subset.R")))
})
