validate_manifest_meteorology_plan <- function(plan) {
  if (!is.list(plan) || !all(c("run_to_file", "unique_files") %in% names(plan))) stop("Meteorology plan must contain run_to_file and unique_files.", call. = FALSE)
  map <- plan$run_to_file; unique_files <- plan$unique_files
  required_map <- c("run_id", "meteorology_type", "simulation_start", "simulation_end", "required_filename")
  required_unique <- c("meteorology_type", "required_filename", "required_by_n_runs", "earliest_simulation_start", "latest_simulation_end")
  if (!is.data.frame(map) || !all(required_map %in% names(map))) stop("Invalid run-to-file meteorology mapping.", call. = FALSE)
  if (!is.data.frame(unique_files) || !all(required_unique %in% names(unique_files))) stop("Invalid unique meteorology-file table.", call. = FALSE)
  if (!nrow(map) || anyNA(map$run_id) || any(!nzchar(trimws(as.character(map$run_id))))) stop("Run IDs must be nonmissing.", call. = FALSE)
  if (anyNA(map$required_filename) || any(!nzchar(trimws(as.character(map$required_filename))))) stop("Required filenames must be nonmissing.", call. = FALSE)
  if (anyDuplicated(map[c("run_id", "required_filename")])) stop("Duplicate run-file combinations are not allowed.", call. = FALSE)
  if (anyDuplicated(unique_files[c("meteorology_type", "required_filename")])) stop("Unique meteorology-file rows must be unique.", call. = FALSE)
  if (any(!as.character(map$meteorology_type) %in% "reanalysis") || any(!as.character(unique_files$meteorology_type) %in% "reanalysis")) stop("Unsupported meteorology type.", call. = FALSE)
  for (x in c("simulation_start", "simulation_end")) if (anyNA(as.POSIXct(map[[x]], tz = "UTC"))) stop("Invalid simulation datetime range.", call. = FALSE)
  if (any(map$simulation_start >= map$simulation_end)) stop("Simulation datetime ranges must be positive.", call. = FALSE)
  if (any(unique_files$earliest_simulation_start >= unique_files$latest_simulation_end)) stop("Unique-file datetime ranges must be positive.", call. = FALSE)
  if (any(!map$run_id %in% unique(map$run_id))) stop("Every run must have a required file.", call. = FALSE)
  expected <- aggregate(run_id ~ meteorology_type + required_filename, map, function(x) length(unique(x)))
  keys <- paste(unique_files$meteorology_type, unique_files$required_filename)
  expected_keys <- paste(expected$meteorology_type, expected$required_filename)
  actual <- unique_files$required_by_n_runs
  expected_counts <- expected$run_id[match(keys, expected_keys)]
  if (anyNA(expected_counts) || !identical(as.integer(actual), as.integer(expected_counts))) stop("required_by_n_runs does not match the run-to-file map.", call. = FALSE)
  invisible(plan)
}
