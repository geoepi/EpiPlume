# Plan shared meteorology requirements for a selected HYSPLIT manifest.
plan_hysplit_manifest_meteorology <- function(manifest, cfg) {
  if (!is.data.frame(manifest)) stop("`manifest` must be a data frame.", call. = FALSE)
  if (!nrow(manifest)) stop("The selected manifest contains no runs.", call. = FALSE)
  rows <- lapply(seq_len(nrow(manifest)), function(i) validate_hysplit_manifest_row(manifest[i, , drop = FALSE]))
  normalized <- do.call(rbind, rows); rownames(normalized) <- NULL
  if (anyDuplicated(normalized$run_id)) stop("Manifest run IDs must be unique.", call. = FALSE)
  mappings <- lapply(seq_len(nrow(normalized)), function(i) {
    row <- normalized[i, , drop = FALSE]
    duration <- as.numeric(difftime(row$simulation_end, row$simulation_start, units = "hours"))
    files <- splitr_required_meteorology_files(row$simulation_start, duration, row$direction %||% cfg$hysplit$direction, row$meteorology_type)
    files <- unique(as.character(files))
    if (!length(files)) stop("Run `", row$run_id, "` has no required meteorology files.", call. = FALSE)
    data.frame(run_id = row$run_id, meteorology_type = row$meteorology_type,
      simulation_start = row$simulation_start, simulation_end = row$simulation_end,
      required_filename = files, stringsAsFactors = FALSE)
  })
  run_to_file <- do.call(rbind, mappings); rownames(run_to_file) <- NULL
  key <- paste(run_to_file$meteorology_type, run_to_file$required_filename, sep = "\r")
  groups <- split(seq_len(nrow(run_to_file)), key)
  unique_files <- do.call(rbind, lapply(groups, function(ii) {
    x <- run_to_file[ii, , drop = FALSE]
    data.frame(meteorology_type = x$meteorology_type[1], required_filename = x$required_filename[1],
      required_by_n_runs = length(unique(x$run_id)), earliest_simulation_start = min(x$simulation_start),
      latest_simulation_end = max(x$simulation_end), stringsAsFactors = FALSE)
  }))
  rownames(unique_files) <- NULL
  plan <- list(run_to_file = run_to_file, unique_files = unique_files,
    summary = list(manifest_row_count = nrow(manifest), selected_run_count = nrow(normalized),
      unique_required_file_count = nrow(unique_files), created_at = Sys.time()))
  validate_manifest_meteorology_plan(plan)
  plan
}
