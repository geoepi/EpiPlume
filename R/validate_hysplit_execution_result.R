#' Validate that a returned splitr object represents a successful HYSPLIT run
`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x[1])) y else x
validate_hysplit_execution_result <- function(model_result, run_spec,
    warnings = character(), require_nonempty_dispersion = TRUE) {
  warnings <- unique(as.character(warnings %||% character()))
  fail <- function(stage, message, rows = NA_integer_, required = character(),
      missing = character(), diagnostics = list(), artifacts = character()) {
    list(valid = FALSE, failure_stage = stage, error_message = message,
      warnings = warnings, dispersion_rows = rows, required_files = required,
      missing_files = missing, diagnostics = diagnostics,
      output_artifacts = artifacts)
  }

  if (is.null(model_result)) return(fail("execution", "HYSPLIT model result is missing."))
  if (!is.list(model_result) || is.data.frame(model_result) || is.null(model_result$disp_df)) {
    return(fail("result_validation", "HYSPLIT model result has no `disp_df` data frame."))
  }
  dispersion <- model_result$disp_df
  if (!is.data.frame(dispersion)) {
    return(fail("result_validation", "HYSPLIT model result `disp_df` is not a data frame."))
  }

  aliases <- list(
    particle_identifier = c("particle_i", "particle_id"),
    elapsed_hour = c("hour", "elapsed_hours"),
    latitude = c("lat", "latitude"),
    longitude = c("lon", "longitude"),
    height = c("height", "height_m")
  )
  mapped <- vapply(aliases, function(x) {
    hit <- intersect(x, names(dispersion)); if (length(hit)) hit[[1]] else NA_character_
  }, character(1))
  missing_fields <- names(mapped)[is.na(mapped)]
  rows <- nrow(dispersion)
  if (length(missing_fields)) {
    return(fail("result_validation", paste0("HYSPLIT dispersion output is missing required field(s): ",
      paste(missing_fields, collapse = ", "), "."), rows))
  }
  if (isTRUE(require_nonempty_dispersion) && rows < 1L) {
    return(fail("result_validation", "HYSPLIT dispersion output contains zero rows.", rows))
  }

  finite_field <- function(field) {
    value <- suppressWarnings(as.numeric(dispersion[[mapped[[field]]]]))
    length(value) == rows && rows > 0L && all(is.finite(value))
  }
  invalid_numeric <- c("elapsed_hour", "latitude", "longitude", "height")
  invalid_numeric <- invalid_numeric[!vapply(invalid_numeric, finite_field, logical(1))]
  if (length(invalid_numeric)) {
    return(fail("result_validation", paste0("HYSPLIT dispersion output has non-finite or invalid value(s) in: ",
      paste(invalid_numeric, collapse = ", "), "."), rows))
  }

  directories <- unique(Filter(function(x) length(x) == 1L && !is.na(x) && nzchar(x), c(
    run_spec$working_directory, run_spec$output_directory, run_spec$run_directory
  )))
  files <- unique(unlist(lapply(directories[dir.exists(directories)], function(directory) {
    list.files(directory, full.names = TRUE, recursive = TRUE, all.files = FALSE)
  }), use.names = FALSE))
  files <- files[file.exists(files) & !dir.exists(files)]
  if (length(files) && !is.null(run_spec$artifact_not_before) &&
      length(run_spec$artifact_not_before) == 1L && !is.na(run_spec$artifact_not_before)) {
    not_before <- as.POSIXct(run_spec$artifact_not_before, tz = "UTC") - 2
    files <- files[file.info(files)$mtime >= not_before]
  }
  normalized_files <- normalizePath(files, winslash = "/", mustWork = FALSE)
  base <- basename(normalized_files)

  diagnostic_names <- c("MESSAGE", "WARNING", "STDOUT", "STDERR", "hysplit.stdout", "hysplit.stderr")
  diagnostic_files <- normalized_files[toupper(base) %in% toupper(diagnostic_names) |
    grepl("(^|[._-])(message|warning|stderr|stdout)([._-]|$)", base, ignore.case = TRUE)]
  read_diagnostic <- function(path) {
    tryCatch(paste(readLines(path, warn = FALSE), collapse = "\n"), error = function(e) "")
  }
  diagnostics <- setNames(lapply(diagnostic_files, read_diagnostic), basename(diagnostic_files))

  warning_text <- paste(warnings, collapse = "\n")
  diagnostic_text <- paste(unlist(diagnostics, use.names = FALSE), collapse = "\n")
  combined <- paste(warning_text, diagnostic_text, sep = "\n")
  failure_patterns <- c(
    "error in running command", "non[- ]?zero (process |exit )?status",
    "returned (a )?non[- ]?zero status", "returned status[[:space:]]*[:=]?[[:space:]]*[1-9]", "exit status[[:space:]]*[:=]?[[:space:]]*[1-9]",
    "command (execution )?failed", "failed to (run|execute)", "permission denied",
    "command not found", "no such file or directory", "segmentation fault", "fatal error",
    "process status[[:space:]]*[:=]?[[:space:]]*[1-9]"
  )
  failure_hit <- failure_patterns[vapply(failure_patterns, grepl, logical(1), x = combined,
    ignore.case = TRUE, perl = TRUE)]
  if (length(failure_hit)) {
    evidence <- c(warnings[grepl(paste(failure_patterns, collapse = "|"), warnings,
      ignore.case = TRUE, perl = TRUE)], basename(diagnostic_files))
    return(fail("execution", paste0("HYSPLIT diagnostics indicate command failure",
      if (length(evidence)) paste0(": ", paste(unique(evidence), collapse = "; ")) else "."),
      rows, diagnostics = diagnostics))
  }

  excluded <- toupper(base) %in% c("ASCDATA.CFG", "CONTROL", "SETUP.CFG", "CONC.CFG",
    "MESSAGE", "WARNING", "RUN_METADATA.RDS", "RUN_METADATA.JSON") |
    grepl("(^|/)(parsed|receptors|\\.execution\\.lock)/", normalized_files, ignore.case = TRUE) |
    grepl("run_metadata\\.pre_reconciliation", base, ignore.case = TRUE)
  recognized <- grepl("^(output\\.bin|cdump.*|GIS_part_.*\\.(txt|att)|PARDUMP.*|parhplot\\.ps|VMSDIST)$",
    base, ignore.case = TRUE)
  sizes <- file.info(normalized_files)$size
  substantive <- !excluded & is.finite(sizes) & sizes > 0
  artifacts <- sort(unique(normalized_files[(recognized | substantive) & is.finite(sizes) & sizes > 0]))
  artifact_requirement <- "at least one substantive HYSPLIT output artifact"
  if (!length(artifacts)) {
    return(fail("output_discovery", "No substantive HYSPLIT output artifact was produced; control and diagnostic files alone do not establish success.",
      rows, required = artifact_requirement, missing = artifact_requirement,
      diagnostics = diagnostics))
  }

  list(valid = TRUE, failure_stage = NA_character_, error_message = NA_character_,
    warnings = warnings, dispersion_rows = rows, required_files = artifacts,
    missing_files = character(), diagnostics = diagnostics,
    output_artifacts = artifacts)
}

#' Validate durable metadata, including records written before validation existed
validate_completed_hysplit_metadata <- function(metadata, run_directory = NULL,
    require_nonempty_dispersion = TRUE) {
  if (!is.list(metadata)) stop("Run metadata must be a list.", call. = FALSE)
  spec <- metadata$run_spec
  if (!is.list(spec)) spec <- list()
  directory <- run_directory %||% metadata$run_directory %||% spec$run_directory
  spec$run_directory <- directory
  spec$output_directory <- metadata$output_directory %||% spec$output_directory %||% directory
  spec$working_directory <- metadata$working_directory %||% spec$working_directory %||%
    if (!is.null(directory)) file.path(directory, "splitr_work") else NULL
  validate_hysplit_execution_result(metadata$model_result, spec,
    warnings = metadata$warnings %||% character(),
    require_nonempty_dispersion = require_nonempty_dispersion)
}
