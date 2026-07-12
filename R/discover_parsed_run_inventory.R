#' Discover existing metadata and parsed products without executing models
discover_parsed_run_inventory <- function(manifest, run_root_directory, require_parsed = FALSE) {
  if (!is.data.frame(manifest) || !all(c("run_id", "scenario_id", "source_id", "release_start", "simulation_end") %in% names(manifest))) stop("Manifest lacks required inventory fields.", call. = FALSE)
  if (anyDuplicated(manifest$run_id)) stop("Manifest contains duplicate run IDs.", call. = FALSE)
  rows <- lapply(seq_len(nrow(manifest)), function(i) {
    m <- manifest[i, ]; directory <- file.path(run_root_directory, m$run_id)
    run_meta <- file.path(directory, "run_metadata.rds"); parse_meta <- file.path(directory, "parsed", "parsing_metadata.rds"); parsed <- file.path(directory, "parsed", "parsed_plume.rds"); receptor <- file.path(directory, "receptors", "source_receptor_exchange.csv")
    status <- "missing"; parse_status <- "missing"; receptor_status <- "missing"; diagnostic <- "No run metadata or parsed object was found."
    if (file.exists(run_meta)) { x <- tryCatch(readRDS(run_meta), error = identity); if (inherits(x, "error")) { status <- "invalid"; diagnostic <- conditionMessage(x) } else { status <- as.character(x$status); diagnostic <- paste("Run metadata status:", status) } }
    if (file.exists(parse_meta)) parse_status <- "parsed"
    if (file.exists(parsed)) { status <- "parsed"; parse_status <- "parsed"; diagnostic <- "Portable parsed plume is available." }
    if (file.exists(receptor)) { status <- "receptor_extracted"; receptor_status <- "receptor_extracted"; diagnostic <- "Existing receptor exchange is available." }
    data.frame(run_id = m$run_id, scenario_id = m$scenario_id, source_id = m$source_id, release_start = m$release_start, simulation_end = m$simulation_end, planned_run_directory = normalizePath(directory, winslash = "/", mustWork = FALSE), run_metadata_path = normalizePath(run_meta, winslash = "/", mustWork = FALSE), parsing_metadata_path = normalizePath(parse_meta, winslash = "/", mustWork = FALSE), parsed_object_path = normalizePath(parsed, winslash = "/", mustWork = FALSE), receptor_exchange_path = normalizePath(receptor, winslash = "/", mustWork = FALSE), run_status = status, parse_status = parse_status, receptor_status = receptor_status, available_for_processing = file.exists(parsed), diagnostic_message = diagnostic, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows); out <- out[order(as.POSIXct(out$release_start, tz = "UTC"), out$source_id, out$run_id), ]; rownames(out) <- NULL
  if (isTRUE(require_parsed) && any(!out$available_for_processing)) stop("One or more manifest runs lack a parsed object.", call. = FALSE)
  out
}
