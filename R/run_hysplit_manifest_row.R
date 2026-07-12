#' Execute or dry-run exactly one HYSPLIT manifest row
run_hysplit_manifest_row <- function(manifest_row, cfg, dry_run = TRUE, overwrite = FALSE, core_fun = NULL) {
  row <- validate_hysplit_manifest_row(manifest_row)
  executable <- resolve_hysplit_executable(cfg, must_exist = !isTRUE(dry_run))
  meteorology <- resolve_hysplit_meteorology(row, cfg, must_exist = !isTRUE(dry_run))
  spec <- build_hysplit_run_spec(row, cfg, executable, meteorology)
  if (isTRUE(dry_run)) return(standardize_hysplit_run_result(spec, "dry_run"))
  if (is.null(core_fun)) core_fun <- run_plume_model
  if (!is.function(core_fun)) stop("`core_fun` must be a function.", call. = FALSE)
  if (dir.exists(spec$run_directory) && length(list.files(spec$run_directory, all.files = TRUE, no.. = TRUE)) && !isTRUE(overwrite)) stop("Run directory is not empty; use `overwrite = TRUE`: ", spec$run_directory, call. = FALSE)
  dir.create(spec$run_directory, recursive = TRUE, showWarnings = FALSE)
  started <- Sys.time(); captured_warnings <- character(); model_result <- NULL; error_message <- NULL
  model_result <- tryCatch(
    withCallingHandlers(
      do.call(core_fun, spec$core_args),
      warning = function(w) { captured_warnings <<- c(captured_warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
    ),
    error = function(e) { error_message <<- conditionMessage(e); NULL }
  )
  finished <- Sys.time()
  status <- if (is.null(error_message)) "completed" else "failed"
  metadata <- standardize_hysplit_run_result(spec, status, started, finished, model_result, captured_warnings, error_message)
  saveRDS(metadata, file.path(spec$run_directory, "run_metadata.rds"))
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package `jsonlite` is required to write run metadata JSON.", call. = FALSE)
  json_metadata <- metadata
  json_metadata$model_result <- if (is.null(model_result)) NULL else list(summary = paste(class(model_result), collapse = "/"))
  json_metadata$run_spec$core_args <- NULL
  jsonlite::write_json(json_metadata, file.path(spec$run_directory, "run_metadata.json"), auto_unbox = TRUE, pretty = TRUE, null = "null", POSIXt = "ISO8601")
  metadata$actual_output_files <- normalizePath(list.files(spec$run_directory, full.names = TRUE, recursive = TRUE), winslash = "/", mustWork = FALSE)
  metadata
}
