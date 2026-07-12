invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))
cfg <- read_facility_exchange_config("local/restartable_manifest_integration/integration_config.yml")
cfg$outputs$root_directory <- "local/restartable_manifest_integration/controlled_failure_scenario"
manifest <- utils::read.csv("local/restartable_manifest_integration/manifests/hysplit_run_manifest.csv", stringsAsFactors = FALSE)[1:2, , drop = FALSE]
manifest$run_id <- c("CONTROLLED_SUCCESS", "CONTROLLED_FAILURE"); manifest$run_directory <- file.path(cfg$outputs$root_directory, "hysplit", manifest$run_id)
ready <- data.frame(run_id = manifest$run_id, meteorology_ready = TRUE)
fake <- function(...) { x <- list(...); if (identical(x$plume_name, "CONTROLLED_FAILURE")) stop("controlled integration failure"); list(particles = data.frame(x = 1)) }
first <- run_hysplit_manifest_subset(manifest, cfg, workers = 1L, continue_on_error = TRUE, parse_outputs = FALSE, extract_receptors = FALSE, core_fun = fake, meteorology_readiness = ready)
retry <- run_hysplit_manifest_subset(manifest, cfg, run_ids = "CONTROLLED_FAILURE", workers = 1L, retry_failed = TRUE, parse_outputs = FALSE, extract_receptors = FALSE, core_fun = function(...) list(particles = data.frame(x = 1)), meteorology_readiness = ready)
ledger <- readRDS(retry$ledger)
cat("initial:", paste(names(first$results), vapply(first$results, `[[`, character(1), "execution_state"), sep = "=", collapse = ","), "\n")
cat("retry:", paste(names(retry$results), vapply(retry$results, `[[`, character(1), "execution_state"), sep = "=", collapse = ","), "\n")
print(ledger[, c("run_id", "execution_state", "attempt_count")], row.names = FALSE)
