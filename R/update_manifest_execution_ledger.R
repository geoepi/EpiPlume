# Atomically merge manifest execution records into the scenario ledger.
update_manifest_execution_ledger <- function(entries, cfg = NULL, directory = NULL) {
  if (is.null(directory)) directory <- file.path(if (!is.null(cfg)) cfg$outputs$root_directory else ".", "execution")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE); csv <- file.path(directory, "manifest_execution_ledger.csv"); rds <- file.path(directory, "manifest_execution_ledger.rds")
  if (!is.data.frame(entries)) entries <- as.data.frame(entries, stringsAsFactors = FALSE)
  fields <- c("run_id", "source_id", "release_start", "execution_state", "attempt_count", "last_attempt_started", "last_attempt_finished", "elapsed_seconds_last_attempt", "elapsed_seconds_total", "meteorology_files", "metadata_path", "parsed_output_path", "receptor_output_path", "last_error", "warning_count", "worker_id", "process_id", "repository_commit", "updated_at")
  for (x in setdiff(fields, names(entries))) entries[[x]] <- NA
  entries <- entries[, fields, drop = FALSE]
  old <- if (file.exists(rds)) tryCatch(readRDS(rds), error = function(e) NULL) else if (file.exists(csv)) utils::read.csv(csv, stringsAsFactors = FALSE) else NULL
  merged <- if (is.null(old)) entries else { for (x in setdiff(fields, names(old))) old[[x]] <- NA; old <- old[, fields, drop = FALSE]; old <- old[!old$run_id %in% entries$run_id, , drop = FALSE]; rbind(old, entries) }
  merged <- merged[!duplicated(merged$run_id, fromLast = TRUE), , drop = FALSE]
  atomic <- function(path, writer) { tmp <- tempfile(pattern = basename(path), tmpdir = directory); on.exit(unlink(tmp), add = TRUE); writer(tmp); if (!file.rename(tmp, path)) stop("Could not atomically install ledger: ", path, call. = FALSE); normalizePath(path, winslash = "/", mustWork = TRUE) }
  atomic(rds, function(p) saveRDS(merged, p)); atomic(csv, function(p) utils::write.csv(merged, p, row.names = FALSE)); merged
}
