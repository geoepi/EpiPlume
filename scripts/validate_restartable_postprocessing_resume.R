invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))
cfg <- read_facility_exchange_config("local/restartable_manifest_integration/integration_config.yml")
manifest <- utils::read.csv("local/restartable_manifest_integration/manifests/hysplit_run_manifest.csv", stringsAsFactors = FALSE)
root <- "local/restartable_manifest_integration/postprocessing_resume"
if (dir.exists(root)) stop("Postprocessing validation root already exists: ", root, call. = FALSE)
clone_run <- function(i, label) {
  row <- manifest[i, , drop = FALSE]; destination <- file.path(root, label, "hysplit", row$run_id); dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(row$run_directory, dirname(destination), recursive = TRUE, copy.date = TRUE)) stop("Could not clone run directory.", call. = FALSE)
  row$run_directory <- destination; metadata_path <- file.path(destination, "run_metadata.rds"); metadata <- readRDS(metadata_path); metadata$run_directory <- destination; metadata$output_directory <- destination; metadata$working_directory <- file.path(destination, "splitr_work"); metadata$run_spec$run_directory <- destination; metadata$run_spec$output_directory <- destination; metadata$run_spec$working_directory <- metadata$working_directory; saveRDS(metadata, metadata_path)
  list(row = row, metadata = metadata)
}
parse_case <- clone_run(1, "parse_case"); unlink(file.path(parse_case$row$run_directory, c("parsed", "receptors")), recursive = TRUE)
parse_cfg <- cfg; parse_cfg$outputs$root_directory <- file.path(root, "parse_case"); parse_ready <- data.frame(run_id = parse_case$row$run_id, meteorology_ready = TRUE)
parse_before <- classify_manifest_execution_state(parse_case$row, parse_cfg, parse_ready); parse_result <- run_hysplit_manifest_subset(parse_case$row, parse_cfg, core_fun = function(...) stop("HYSPLIT must not execute during parse resume"), meteorology_readiness = parse_ready)

receptor_case <- clone_run(2, "receptor_case"); unlink(file.path(receptor_case$row$run_directory, "receptors"), recursive = TRUE)
invisible(parse_hysplit_run_output(receptor_case$metadata, cfg, write_outputs = TRUE, overwrite = TRUE))
parsed_path <- file.path(receptor_case$row$run_directory, "parsed", "parsed_plume.rds"); parsed <- readRDS(parsed_path); parsed$parsing_metadata$run_directory <- receptor_case$row$run_directory; saveRDS(parsed, parsed_path)
receptor_cfg <- cfg; receptor_cfg$outputs$root_directory <- file.path(root, "receptor_case"); receptor_ready <- data.frame(run_id = receptor_case$row$run_id, meteorology_ready = TRUE)
receptor_before <- classify_manifest_execution_state(receptor_case$row, receptor_cfg, receptor_ready); receptor_result <- run_hysplit_manifest_subset(receptor_case$row, receptor_cfg, core_fun = function(...) stop("HYSPLIT must not execute during receptor resume"), meteorology_readiness = receptor_ready)
cat("parse_before:", parse_before$execution_state, " parse_after:", parse_result$results[[1]]$execution_state, " attempts:", readRDS(parse_result$ledger)$attempt_count, "\n")
cat("receptor_before:", receptor_before$execution_state, " receptor_after:", receptor_result$results[[1]]$execution_state, " attempts:", readRDS(receptor_result$ledger)$attempt_count, "\n")
