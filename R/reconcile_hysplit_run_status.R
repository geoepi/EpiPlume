#' Reconcile legacy false-completion HYSPLIT metadata
reconcile_hysplit_run_status <- function(manifest, cfg, run_ids, apply = FALSE) {
  if (!is.data.frame(manifest) || !all(c("run_id", "run_directory") %in% names(manifest))) {
    stop("Manifest must contain `run_id` and `run_directory`.", call. = FALSE)
  }
  run_ids <- trimws(as.character(run_ids))
  if (!length(run_ids) || anyNA(run_ids) || any(!nzchar(run_ids))) stop("At least one run ID is required.", call. = FALSE)
  if (anyDuplicated(run_ids)) stop("Selected run IDs contain duplicates.", call. = FALSE)
  unknown <- setdiff(run_ids, manifest$run_id)
  if (length(unknown)) stop("Unknown run ID(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  selected <- manifest[match(run_ids, manifest$run_id), , drop = FALSE]

  inspected <- lapply(seq_len(nrow(selected)), function(i) {
    directory <- normalizePath(path.expand(as.character(selected$run_directory[i])), winslash = "/", mustWork = FALSE)
    rds_path <- file.path(directory, "run_metadata.rds")
    json_path <- file.path(directory, "run_metadata.json")
    if (!file.exists(rds_path)) {
      return(list(metadata = NULL, validation = NULL, directory = directory,
        rds_path = rds_path, json_path = json_path,
        row = data.frame(run_id = selected$run_id[i], current_status = "missing",
          proposed_status = "missing", change_required = FALSE,
          validation_valid = FALSE, dispersion_rows = NA_integer_,
          reason = "run_metadata.rds does not exist", stringsAsFactors = FALSE)))
    }
    metadata <- tryCatch(readRDS(rds_path), error = identity)
    if (inherits(metadata, "error") || !is.list(metadata)) {
      reason <- if (inherits(metadata, "error")) conditionMessage(metadata) else "metadata is not a list"
      return(list(metadata = NULL, validation = NULL, directory = directory,
        rds_path = rds_path, json_path = json_path,
        row = data.frame(run_id = selected$run_id[i], current_status = "invalid",
          proposed_status = "invalid", change_required = FALSE,
          validation_valid = FALSE, dispersion_rows = NA_integer_,
          reason = paste("Cannot read metadata:", reason), stringsAsFactors = FALSE)))
    }
    validation <- validate_completed_hysplit_metadata(metadata, directory)
    current <- as.character(metadata$status %||% "missing")
    change <- identical(current, "completed") && !isTRUE(validation$valid)
    proposed <- if (change) "failed" else current
    list(metadata = metadata, validation = validation, directory = directory,
      rds_path = rds_path, json_path = json_path,
      row = data.frame(run_id = selected$run_id[i], current_status = current,
        proposed_status = proposed, change_required = change,
        validation_valid = isTRUE(validation$valid),
        dispersion_rows = as.integer(validation$dispersion_rows),
        reason = if (isTRUE(validation$valid)) "Objective execution-result validation passed." else validation$error_message,
        stringsAsFactors = FALSE))
  })
  proposal <- do.call(rbind, lapply(inspected, `[[`, "row"))

  changes <- which(proposal$change_required)
  if (isTRUE(apply) && length(changes)) {
    backup_paths <- unlist(lapply(inspected[changes], function(x) c(
      file.path(x$directory, "run_metadata.pre_reconciliation.rds"),
      file.path(x$directory, "run_metadata.pre_reconciliation.json")
    )), use.names = FALSE)
    if (any(file.exists(backup_paths))) stop("A pre-reconciliation backup already exists; refusing to overwrite: ",
      paste(backup_paths[file.exists(backup_paths)], collapse = ", "), call. = FALSE)

    json_value <- function(metadata) {
      out <- metadata
      out$model_result <- if (is.null(metadata$model_result)) NULL else list(summary = paste(class(metadata$model_result), collapse = "/"))
      if (is.list(out$run_spec)) out$run_spec$core_args <- NULL
      out
    }
    atomic_rds <- function(object, path) {
      temporary <- tempfile(paste0(basename(path), "-"), dirname(path)); on.exit(unlink(temporary), add = TRUE)
      saveRDS(object, temporary); if (file.exists(path)) unlink(path); if (!file.rename(temporary, path)) stop("Could not write ", path, call. = FALSE)
    }
    atomic_json <- function(object, path) {
      temporary <- tempfile(paste0(basename(path), "-"), dirname(path)); on.exit(unlink(temporary), add = TRUE)
      jsonlite::write_json(object, temporary, auto_unbox = TRUE, pretty = TRUE, null = "null", POSIXt = "ISO8601")
      if (file.exists(path)) unlink(path); if (!file.rename(temporary, path)) stop("Could not write ", path, call. = FALSE)
    }

    for (i in changes) {
      x <- inspected[[i]]
      rds_backup <- file.path(x$directory, "run_metadata.pre_reconciliation.rds")
      json_backup <- file.path(x$directory, "run_metadata.pre_reconciliation.json")
      if (!file.copy(x$rds_path, rds_backup, overwrite = FALSE, copy.date = TRUE)) stop("Could not back up ", x$rds_path, call. = FALSE)
      if (file.exists(x$json_path)) {
        if (!file.copy(x$json_path, json_backup, overwrite = FALSE, copy.date = TRUE)) stop("Could not back up ", x$json_path, call. = FALSE)
      } else {
        atomic_json(json_value(x$metadata), json_backup)
      }
      metadata <- x$metadata
      metadata$status <- "failed"
      metadata$dry_run <- FALSE
      metadata$error_message <- x$validation$error_message
      metadata$execution_validation <- x$validation
      metadata$reconciliation <- list(
        reconciled_at = as.POSIXct(Sys.time(), tz = "UTC"),
        previous_status = x$metadata$status,
        reason = x$validation$error_message
      )
      atomic_json(json_value(metadata), x$json_path)
      atomic_rds(metadata, x$rds_path)
    }
    write_completed_run_index(cfg$hysplit$run_root_directory)
  }
  attr(proposal, "applied") <- isTRUE(apply)
  proposal
}
