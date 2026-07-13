# Classify manifest rows using only durable on-disk artifacts.
`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x[1])) y else x[1]
classify_manifest_execution_state <- function(manifest, cfg, meteorology_readiness = NULL) {
  if (!is.data.frame(manifest) || !"run_id" %in% names(manifest)) stop("`manifest` must contain run_id.", call. = FALSE)
  if (anyDuplicated(manifest$run_id)) stop("Manifest contains duplicate run IDs.", call. = FALSE)
  if (is.null(meteorology_readiness)) {
    readiness_path <- file.path(cfg$hysplit$meteorology_directory %||% "", "meteorology_run_readiness.rds")
    if (file.exists(readiness_path)) meteorology_readiness <- tryCatch(readRDS(readiness_path), error = function(e) NULL)
  }
  ready_for <- function(row) {
    if (is.null(meteorology_readiness)) return(NA)
    x <- meteorology_readiness
    if (is.list(x) && !is.null(x$run_readiness)) x <- x$run_readiness
    if (!is.data.frame(x) || !all(c("run_id", "meteorology_ready") %in% names(x))) return(NA)
    z <- x$meteorology_ready[match(row$run_id, x$run_id)]; if (!length(z) || is.na(z)) FALSE else isTRUE(z)
  }
  one <- function(i) {
    row <- manifest[i, , drop = FALSE]; run <- as.character(row$run_id); dir <- if ("run_directory" %in% names(row)) as.character(row$run_directory) else file.path(cfg$hysplit$run_root_directory, run)
    dir <- normalizePath(path.expand(dir), winslash = "/", mustWork = FALSE); meta_path <- file.path(dir, "run_metadata.rds")
    parsed_path <- file.path(dir, "parsed", "parsed_plume.rds"); receptor_path <- file.path(dir, "receptors", "source_receptor_exchange.csv")
    meta_exists <- file.exists(meta_path); parsed <- file.exists(parsed_path); receptor <- file.exists(receptor_path); err <- NA_character_; completed <- FALSE; false_completion <- FALSE
    metadata <- if (meta_exists) tryCatch(readRDS(meta_path), error = function(e) { err <<- paste("Malformed run metadata:", conditionMessage(e)); NULL }) else NULL
    if (meta_exists && is.null(metadata)) completed <- FALSE else if (!is.null(metadata)) {
      if (is.null(metadata$status)) err <- "Run metadata has no status."
      completed <- identical(metadata$status, "completed")
      if (identical(metadata$status, "failed")) err <- metadata$error_message %||% "Run execution failed."
      if (completed) {
        validation <- tryCatch(validate_completed_hysplit_metadata(metadata, dir),
          error = function(e) list(valid = FALSE, error_message = paste("Execution validation failed:", conditionMessage(e))))
        if (!isTRUE(validation$valid)) {
          false_completion <- TRUE
          completed <- FALSE
          err <- validation$error_message %||% "Completed metadata failed objective execution-result validation."
        }
      }
    }
    met <- ready_for(row); if (is.na(met)) met <- FALSE
    lock_active <- dir.exists(file.path(dir, ".execution.lock"))
    nonempty <- dir.exists(dir) && length(list.files(dir, all.files = TRUE, no.. = TRUE)) > 0L
    ambiguous <- nonempty && (!meta_exists || is.null(metadata) || (!completed && !false_completion && !identical(metadata$status, "failed")))
    state <- if (lock_active) "running" else if (ambiguous) "invalid" else if (false_completion) "execution_failed" else if (!is.null(metadata) && identical(metadata$status, "failed")) "execution_failed" else if (completed && parsed && receptor) "completed" else if (completed && !parsed) "parse_failed" else if (completed && parsed && !receptor) "receptor_failed" else if (!met) "meteorology_blocked" else if (!nonempty) "planned" else "ready"
    if (ambiguous) err <- "Nonempty run directory lacks an unambiguous durable execution result."
    if (lock_active && is.na(err)) err <- "An execution lock is active; inspect before recovery."
    data.frame(run_id = run, source_id = as.character(row$source_id), release_start = as.character(row$release_start), run_directory = dir, meteorology_ready = met, execution_state = state, metadata_exists = meta_exists, execution_completed = completed, parsed_exists = parsed, receptor_exists = receptor, last_error = ifelse(is.null(err), NA_character_, err), eligible_for_execution = state %in% c("planned", "ready", "execution_failed"), eligible_for_postprocessing = state %in% c("parse_failed", "receptor_failed"), stringsAsFactors = FALSE)
  }
  out <- if (nrow(manifest)) do.call(rbind, lapply(seq_len(nrow(manifest)), one)) else data.frame()
  rownames(out) <- NULL; out
}
