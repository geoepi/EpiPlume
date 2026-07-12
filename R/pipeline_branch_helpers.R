#' Capture one receptor-extraction branch without aborting independent runs
extract_pipeline_receptor_result <- function(parsed_result, facilities, cfg) {
  if (!identical(parsed_result$status, "parsed")) return(list(run_id = parsed_result$run_id, status = "skipped", extraction = NULL, error_message = parsed_result$error_message))
  tryCatch({ existing_receptor_outputs <- file.exists(file.path(parsed_result$parsed_plume$parsing_metadata$run_directory, "receptors", "source_receptor_exchange.csv")); write_outputs <- isTRUE(cfg$pipeline$write_intermediate_outputs) && !existing_receptor_outputs; extraction <- extract_facility_receptors_from_plume(parsed_result$parsed_plume, facilities, cfg, write_outputs); list(run_id = parsed_result$run_id, status = "receptor_extracted", extraction = extraction, error_message = NA_character_) }, error = function(e) list(run_id = parsed_result$run_id, status = "failed", extraction = NULL, error_message = conditionMessage(e)))
}

#' Assemble successful target branches without rediscovering runs
assemble_pipeline_receptor_results <- function(receptor_results, facilities, cfg) {
  if (is.null(receptor_results)) receptor_results <- list()
  if (!is.list(receptor_results) || (!is.null(receptor_results$run_id) && !is.null(receptor_results$status))) receptor_results <- list(receptor_results)
  successful <- Filter(function(x) identical(x$status, "receptor_extracted"), receptor_results)
  tables <- lapply(successful, function(x) x$extraction$exchange_table); exchange <- combine_source_receptor_exchanges(tables)
  time <- setNames(lapply(cfg$multirun$time_units, function(unit) summarize_connectivity_by_time(exchange, unit)), cfg$multirun$time_units)
  source <- summarize_connectivity_by_source(exchange); receptor <- summarize_connectivity_by_receptor(exchange); dyad <- summarize_connectivity_by_dyad(exchange)
  matrices <- setNames(lapply(cfg$multirun$matrix_values, function(value) build_facility_connectivity_matrices(dyad, facilities, value)), cfg$multirun$matrix_values)
  failed <- Filter(function(x) identical(x$status, "failed"), receptor_results)
  list(combined_exchange_table = exchange, time_summaries = time, source_summary = source, receptor_summary = receptor, dyad_summary = dyad, connectivity_matrices = matrices, failed_runs = if (length(failed)) do.call(rbind, lapply(failed, function(x) data.frame(run_id = x$run_id, error_message = x$error_message))) else data.frame(run_id = character(), error_message = character()), assembly_metadata = list(status = if (length(successful)) "assembled" else "empty", successful_runs = length(successful), failed_runs = length(failed)))
}
