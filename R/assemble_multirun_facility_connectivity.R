#' Assemble multi-run facility connectivity from portable parsed runs
assemble_multirun_facility_connectivity <- function(manifest, facilities, cfg, run_root_directory = NULL, continue_on_error = TRUE, write_outputs = FALSE, overwrite = FALSE) {
  validate_facilities(facilities); if (anyDuplicated(manifest$run_id)) stop("Manifest contains duplicate run IDs.", call. = FALSE); if (length(unique(manifest$scenario_id)) != 1L) stop("Exactly one scenario ID is required.", call. = FALSE)
  if (is.null(run_root_directory)) run_root_directory <- cfg$hysplit$run_root_directory
  inventory <- validate_parsed_run_inventory(discover_parsed_run_inventory(manifest, run_root_directory))
  processed <- process_parsed_run_inventory(inventory, facilities, cfg, continue_on_error, overwrite)
  exchange <- processed$combined_exchange_table
  time <- setNames(lapply(cfg$multirun$time_units, function(unit) summarize_connectivity_by_time(exchange, unit)), cfg$multirun$time_units)
  source <- summarize_connectivity_by_source(exchange); receptor <- summarize_connectivity_by_receptor(exchange); dyad <- summarize_connectivity_by_dyad(exchange)
  matrices <- setNames(lapply(cfg$multirun$matrix_values, function(value) build_facility_connectivity_matrices(dyad, facilities, value)), cfg$multirun$matrix_values)
  metadata <- list(schema_version = "1.0.0", assembled_at = as.POSIXct(Sys.time(), tz = "UTC"), scenario_id = unique(manifest$scenario_id), manifest_runs = nrow(manifest), eligible_runs = sum(inventory$available_for_processing), processed_runs = nrow(processed$run_processing_log[processed$run_processing_log$processing_status == "processed", ]), failed_runs = nrow(processed$failed_runs), exchange_rows = nrow(exchange), candidate_denominator = "within_evaluation_distance == TRUE")
  out <- list(run_inventory = inventory, run_processing_log = processed$run_processing_log, combined_exchange_table = exchange, time_summaries = time, source_summary = source, receptor_summary = receptor, dyad_summary = dyad, connectivity_matrices = matrices, failed_runs = processed$failed_runs, assembly_metadata = metadata)
  if (isTRUE(write_outputs)) out$assembly_metadata <- write_multirun_connectivity_outputs(out, cfg$outputs$root_directory, overwrite)
  out
}
