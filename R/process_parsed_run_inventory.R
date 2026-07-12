#' Process eligible parsed runs through the existing single-run extractor
process_parsed_run_inventory <- function(inventory, facilities, cfg, continue_on_error = TRUE, overwrite = FALSE, write_single_run_outputs = FALSE, extract_fun = extract_facility_receptors_from_plume) {
  inventory <- validate_parsed_run_inventory(inventory); validate_facilities(facilities); logs <- list(); tables <- list(); failures <- list()
  eligible <- which(inventory$available_for_processing)
  for (i in eligible) {
    started <- Sys.time(); error <- NULL; extracted <- tryCatch({ parsed <- readRDS(inventory$parsed_object_path[i]); extract_fun(parsed, facilities, cfg, write_single_run_outputs, overwrite) }, error = function(e) { error <<- conditionMessage(e); NULL })
    if (is.null(error)) tables[[inventory$run_id[i]]] <- extracted$exchange_table else { failures[[inventory$run_id[i]]] <- data.frame(run_id = inventory$run_id[i], error_message = error); if (!isTRUE(continue_on_error)) stop("Run ", inventory$run_id[i], " failed: ", error, call. = FALSE) }
    logs[[length(logs) + 1L]] <- data.frame(run_id = inventory$run_id[i], processing_status = if (is.null(error)) "processed" else "failed", started_at = started, finished_at = Sys.time(), error_message = if (is.null(error)) NA_character_ else error, stringsAsFactors = FALSE)
  }
  log <- if (length(logs)) do.call(rbind, logs) else data.frame(run_id = character(), processing_status = character(), started_at = as.POSIXct(character()), finished_at = as.POSIXct(character()), error_message = character())
  failed <- if (length(failures)) do.call(rbind, failures) else data.frame(run_id = character(), error_message = character())
  list(run_processing_log = log, exchange_tables = tables, combined_exchange_table = combine_source_receptor_exchanges(tables), failed_runs = failed, processing_metadata = list(eligible_runs = length(eligible), processed_runs = length(tables), failed_runs = nrow(failed), continue_on_error = continue_on_error))
}
