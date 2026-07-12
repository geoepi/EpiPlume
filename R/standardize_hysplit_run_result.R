#' Standardize metadata returned by the single-run HYSPLIT adapter
standardize_hysplit_run_result <- function(run_spec, status, started_at = NULL, finished_at = NULL, result = NULL, warnings = character(), error_message = NULL) {
  valid_status <- c("dry_run", "completed", "failed")
  if (!status %in% valid_status) stop("`status` must be one of: ", paste(valid_status, collapse = ", "), ".", call. = FALSE)
  utc <- function(x) if (is.null(x)) as.POSIXct(NA, tz = "UTC") else as.POSIXct(x, tz = "UTC")
  started_at <- utc(started_at); finished_at <- utc(finished_at)
  elapsed <- if (is.na(started_at) || is.na(finished_at)) NA_real_ else as.numeric(difftime(finished_at, started_at, units = "secs"))
  actual <- if (dir.exists(run_spec$run_directory)) list.files(run_spec$run_directory, full.names = TRUE, recursive = TRUE) else character()
  list(
    schema_version = run_spec$schema_version, run_id = run_spec$run_id,
    scenario_id = run_spec$scenario_id, source_id = run_spec$source_id,
    status = status, dry_run = identical(status, "dry_run"),
    started_at = started_at, finished_at = finished_at, elapsed_seconds = elapsed,
    source_longitude = run_spec$source_longitude, source_latitude = run_spec$source_latitude,
    release_start = run_spec$release_start, release_end = run_spec$release_end,
    simulation_start = run_spec$simulation_start, simulation_end = run_spec$simulation_end,
    meteorology_type = run_spec$meteorology_type,
    meteorology_directory = run_spec$meteorology_directory,
    meteorology_files = run_spec$meteorology_files,
    hysplit_install_directory = run_spec$hysplit_install_directory,
    run_directory = run_spec$run_directory,
    working_directory = run_spec$working_directory,
    output_directory = run_spec$output_directory,
    expected_output_files = run_spec$expected_output_files,
    actual_output_files = normalizePath(actual, winslash = "/", mustWork = FALSE),
    warnings = as.character(warnings), error_message = error_message,
    repository_commit = run_spec$repository_commit, run_spec = run_spec,
    model_result = result
  )
}
