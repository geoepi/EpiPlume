#' Validate a parsed-run inventory
validate_parsed_run_inventory <- function(inventory) {
  required <- c("run_id", "scenario_id", "source_id", "release_start", "simulation_end", "planned_run_directory", "run_metadata_path", "parsing_metadata_path", "parsed_object_path", "receptor_exchange_path", "run_status", "parse_status", "receptor_status", "available_for_processing", "diagnostic_message")
  missing <- setdiff(required, names(inventory)); if (length(missing)) stop("Inventory is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(inventory$run_id)) stop("Inventory contains duplicate run IDs.", call. = FALSE)
  if (any(is.na(inventory$source_id) | !nzchar(inventory$source_id))) stop("Inventory contains invalid source IDs.", call. = FALSE)
  release <- as.POSIXct(inventory$release_start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"); end <- as.POSIXct(inventory$simulation_end, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (anyNA(release) || anyNA(end)) stop("Inventory contains invalid UTC datetimes.", call. = FALSE)
  allowed <- c("planned", "missing", "dry_run", "failed", "completed", "parsed", "receptor_extracted", "invalid")
  if (any(!inventory$run_status %in% allowed)) stop("Inventory contains unrecognized run status.", call. = FALSE)
  if (any(inventory$available_for_processing & !file.exists(inventory$parsed_object_path))) stop("Inventory marks a missing parsed object as available.", call. = FALSE)
  key <- paste(inventory$scenario_id, inventory$source_id, release); if (anyDuplicated(key)) stop("Duplicate scenario/source/release combinations are unsupported without replicate identifiers.", call. = FALSE)
  inventory$release_start <- release; inventory$simulation_end <- end; inventory
}
