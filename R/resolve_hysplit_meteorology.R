#' Inspect local meteorological inputs for one HYSPLIT run
resolve_hysplit_meteorology <- function(manifest_row, cfg, must_exist = TRUE) {
  row <- validate_hysplit_manifest_row(manifest_row)
  directory <- cfg$hysplit$meteorology_directory
  if (is.null(directory) || length(directory) != 1L || is.na(directory) || !nzchar(trimws(directory))) directory <- Sys.getenv("HYSPLIT_METEOROLOGY_DIRECTORY", unset = NA_character_)
  if (is.null(directory) || length(directory) != 1L || is.na(directory) || !nzchar(trimws(directory))) {
    if (isTRUE(must_exist)) stop("`hysplit.meteorology_directory` is missing.", call. = FALSE)
    directory <- NA_character_
  } else {
    directory <- normalizePath(path.expand(directory), winslash = "/", mustWork = FALSE)
  }
  files <- if (!is.na(directory) && dir.exists(directory)) list.files(directory, full.names = TRUE, recursive = FALSE) else character()
  files <- normalizePath(files[file.info(files)$isdir %in% FALSE], winslash = "/", mustWork = FALSE)
  status <- if (!length(files)) "missing" else "unknown"
  diagnostic <- if (status == "missing") "No local meteorological files were found; no download was attempted." else "Local candidate files were found, but temporal coverage cannot be proven reliably from repository conventions."
  if (isTRUE(must_exist) && status == "missing") stop("No local meteorological files exist in: ", directory, call. = FALSE)
  list(
    meteorology_directory = directory,
    meteorology_type = row$meteorology_type,
    simulation_start = row$simulation_start,
    simulation_end = row$simulation_end,
    candidate_files = files,
    coverage_status = status,
    diagnostic_message = diagnostic
  )
}
