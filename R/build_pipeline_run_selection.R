#' Select explicit HYSPLIT manifest rows in manifest order
build_pipeline_run_selection <- function(manifest, run_ids) {
  if (is.null(run_ids) || !length(run_ids) || identical(run_ids, "")) return(manifest[FALSE, , drop = FALSE])
  run_ids <- trimws(unlist(strsplit(paste(run_ids, collapse = ","), ",", fixed = TRUE))); run_ids <- run_ids[nzchar(run_ids)]
  if (anyDuplicated(run_ids)) stop("Selected run IDs contain duplicates.", call. = FALSE)
  unknown <- setdiff(run_ids, manifest$run_id); if (length(unknown)) stop("Unknown selected run IDs: ", paste(unknown, collapse = ", "), call. = FALSE)
  manifest[manifest$run_id %in% run_ids, , drop = FALSE]
}

#' Execute one explicitly confirmed selected HYSPLIT case
run_selected_hysplit_case <- function(manifest_row, cfg, allow_execution, core_fun = NULL) {
  if (!identical(allow_execution, "true")) stop("HYSPLIT execution requires EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true.", call. = FALSE)
  row <- validate_hysplit_manifest_row(manifest_row); message("Executing explicitly selected run: ", row$run_id)
  run_hysplit_manifest_row(row, cfg, dry_run = FALSE, overwrite = FALSE, core_fun = core_fun)
}
