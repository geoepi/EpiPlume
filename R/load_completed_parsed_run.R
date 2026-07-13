#' Reuse or safely parse one completed run without executing HYSPLIT
load_completed_parsed_run <- function(inventory_row, cfg) {
  run_id <- inventory_row$run_id
  tryCatch({
    if (file.exists(inventory_row$parsed_object_path)) return(list(run_id = run_id, status = "parsed", parsed_plume = readRDS(inventory_row$parsed_object_path), error_message = NA_character_, source_path = inventory_row$parsed_object_path))
    if (!isTRUE(cfg$pipeline$parse_completed_runs) || !file.exists(inventory_row$run_metadata_path)) return(list(run_id = run_id, status = "skipped", parsed_plume = NULL, error_message = "No eligible completed metadata or parsing disabled.", source_path = NA_character_))
    metadata <- readRDS(inventory_row$run_metadata_path); if (!identical(metadata$status, "completed")) return(list(run_id = run_id, status = "skipped", parsed_plume = NULL, error_message = paste("Run status is", metadata$status), source_path = inventory_row$run_metadata_path))
    parsed <- parse_hysplit_run_output(metadata, cfg,
      write_outputs = cfg$pipeline$write_intermediate_outputs,
      refresh_run_index = FALSE)
    list(run_id = run_id, status = "parsed", parsed_plume = parsed, error_message = NA_character_, source_path = inventory_row$run_metadata_path)
  }, error = function(e) list(run_id = run_id, status = "failed", parsed_plume = NULL, error_message = conditionMessage(e), source_path = NA_character_))
}
