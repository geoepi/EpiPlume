#' Acquire, inventory, and verify meteorology for exactly one HYSPLIT run.
prepare_hysplit_meteorology <- function(
    manifest_row, cfg,
    allow_download = isTRUE(cfg$hysplit$allow_meteorology_download),
    overwrite = FALSE, verify = TRUE, downloader = NULL) {
  row <- validate_hysplit_manifest_row(manifest_row)
  h <- cfg$hysplit
  configured <- h$meteorology_directory
  env_directory <- Sys.getenv("HYSPLIT_METEOROLOGY_DIRECTORY", unset = NA_character_)
  smoke_fallback <- identical(cfg$project$scenario_id, "facility_exchange_single_run_smoke")
  if (is.null(configured) || length(configured) != 1L || is.na(configured) || !nzchar(trimws(configured))) configured <- env_directory
  if ((is.null(configured) || length(configured) != 1L || is.na(configured) || !nzchar(trimws(configured))) && smoke_fallback) configured <- "local/facility_exchange_single_run_smoke/meteorology"
  if (is.null(configured) || length(configured) != 1L || is.na(configured) || !nzchar(trimws(configured))) stop("Meteorology directory must be configured with hysplit.meteorology_directory or HYSPLIT_METEOROLOGY_DIRECTORY for non-smoke configurations.", call. = FALSE)
  directory <- normalizePath(path.expand(configured), winslash = "/", mustWork = FALSE)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  duration <- as.numeric(difftime(row$simulation_end, row$simulation_start, units = "hours"))
  if (!is.finite(duration) || duration <= 0) stop("Simulation interval must have positive duration.", call. = FALSE)
  required <- splitr_required_meteorology_files(row$simulation_start, duration, row$direction %||% cfg$hysplit$direction, row$meteorology_type)
  before <- inventory_meteorology_files(directory)
  missing_before <- if (isTRUE(overwrite)) required else setdiff(required, before$filename[before$size_bytes > 0])
  if (isTRUE(overwrite) && length(required)) unlink(file.path(directory, required), force = TRUE)
  status <- if (!length(missing_before)) "cached" else "incomplete"
  warnings <- character(); error_message <- NULL; acquisition_time <- as.POSIXct(Sys.time(), tz = "UTC")
  if (length(missing_before) && isTRUE(allow_download)) {
    if (!isTRUE(overwrite)) {
      # splitr itself skips files that already exist; overwrite is retained as an explicit API control.
      download_dir <- directory
    } else download_dir <- directory
    if (is.null(downloader)) downloader <- splitr_meteorology_downloader
    attempts <- max(1L, as.integer(h$meteorology_download_retries %||% 0) + 1L)
    for (attempt in seq_len(attempts)) {
      if (!is.null(error_message) && attempt > 1L) warnings <- c(warnings, paste("Retry", attempt - 1L, "after:", error_message))
      error_message <- NULL
      tryCatch({
        captured <- character()
        withCallingHandlers({ downloader(meteorology_type = row$meteorology_type, days = as.Date(row$simulation_start), duration = duration, direction = row$direction %||% cfg$hysplit$direction, met_dir = download_dir) }, message = function(m) { captured <<- c(captured, conditionMessage(m)); invokeRestart("muffleMessage") }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
        if (length(captured)) warnings <- c(warnings, captured)
      }, error = function(e) { error_message <<- conditionMessage(e) })
      if (is.null(error_message)) break
    }
    after_download <- inventory_meteorology_files(directory)
    downloaded <- setdiff(after_download$filename, before$filename)
    if (is.null(error_message) && all(required %in% after_download$filename)) status <- "downloaded" else if (is.null(error_message)) status <- "incomplete" else status <- "failed"
  } else {
    after_download <- before
    downloaded <- character()
    if (length(missing_before) && !isTRUE(allow_download)) error_message <- paste("Required meteorological file(s) are missing and download is disabled:", paste(missing_before, collapse = ", "))
  }
  verification <- verify_meteorology_inventory(after_download, required, verify = verify)
  if (!isTRUE(verification$verified) && is.null(error_message)) error_message <- verification$error_message
  if (!isTRUE(verification$verified) && status %in% c("cached", "downloaded")) status <- "incomplete"
  if (!is.null(error_message) && identical(status, "incomplete") && !length(missing_before)) status <- "failed"
  inventory_file <- write_meteorology_inventory(after_download, directory, row, row$meteorology_type, status, acquisition_time, required, verification)
  list(status = status, meteorology_type = row$meteorology_type, meteorology_directory = directory, simulation_start = row$simulation_start, simulation_end = row$simulation_end, required_files = required, candidate_files_before = normalizePath(file.path(directory, before$filename), winslash = "/", mustWork = FALSE), candidate_files_after = normalizePath(file.path(directory, after_download$filename), winslash = "/", mustWork = FALSE), downloaded_files = normalizePath(file.path(directory, downloaded), winslash = "/", mustWork = FALSE), missing_files = setdiff(required, after_download$filename), inventory_file = inventory_file, inventory_rds = sub("[.]csv$", ".rds", inventory_file), coverage_status = verification$coverage_status, duplicate_filenames = verification$duplicate_filenames, warnings = unique(warnings), error_message = error_message)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || is.na(x[1])) y else x[1]

splitr_required_meteorology_files <- function(start_time, duration, direction, meteorology_type) {
  if (!requireNamespace("splitr", quietly = TRUE)) stop("Package `splitr` is required for meteorology file selection.", call. = FALSE)
  ns <- asNamespace("splitr")
  if (identical(meteorology_type, "reanalysis")) return(get("get_monthly_filenames", ns)(days = as.Date(start_time), duration = duration, direction = direction, prefix = "RP", extension = ".gbl"))
  stop("No acquisition-only file-selection adapter is implemented for splitr meteorology type `", meteorology_type, "`.", call. = FALSE)
}

splitr_meteorology_downloader <- function(meteorology_type, days, duration, direction, met_dir) {
  if (!requireNamespace("splitr", quietly = TRUE)) stop("Package `splitr` is required for meteorology download.", call. = FALSE)
  get("download_met_files", asNamespace("splitr"))(met_type = meteorology_type, days = days, duration = duration, direction = direction, met_dir = met_dir)
}

inventory_meteorology_files <- function(directory) {
  files <- list.files(directory, full.names = FALSE, recursive = FALSE)
  files <- files[!files %in% c("meteorology_inventory.csv", "meteorology_inventory.rds")]
  info <- file.info(file.path(directory, files)); files <- files[!is.na(info$size) & !info$isdir]
  data.frame(filename = files, size_bytes = as.numeric(file.info(file.path(directory, files))$size), modified_at = as.POSIXct(file.info(file.path(directory, files))$mtime, tz = "UTC"), stringsAsFactors = FALSE)
}

verify_meteorology_inventory <- function(inventory, required, verify = TRUE) {
  duplicate_filenames <- unique(inventory$filename[duplicated(inventory$filename)])
  nonempty <- nrow(inventory) > 0L && all(inventory$size_bytes > 0)
  required_present <- all(required %in% inventory$filename)
  verified <- !isTRUE(verify) || (nonempty && required_present && !length(duplicate_filenames))
  messages <- c(if (!nonempty) "No nonempty readable meteorological files were found.", if (!required_present) paste("Missing required file(s):", paste(setdiff(required, inventory$filename), collapse = ", ")), if (length(duplicate_filenames)) paste("Duplicate filename(s):", paste(duplicate_filenames, collapse = ", ")))
  list(verified = verified, coverage_status = if (required_present) "complete" else "incomplete", duplicate_filenames = duplicate_filenames, error_message = if (verified) NULL else paste(messages, collapse = " "))
}

write_meteorology_inventory <- function(inventory, directory, row, meteorology_type, acquisition_status, acquired_at, required, verification) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package `jsonlite` is required for meteorology inventory output.", call. = FALSE)
  path <- file.path(directory, "meteorology_inventory.csv"); rds_path <- file.path(directory, "meteorology_inventory.rds")
  if (!nrow(inventory)) inventory <- data.frame(filename = character(), size_bytes = numeric(), modified_at = as.POSIXct(character()), stringsAsFactors = FALSE)
  out <- inventory; n <- nrow(out); out$relative_path <- out$filename; out$meteorology_type <- rep(meteorology_type, n); out$md5 <- if (n) unname(as.character(tools::md5sum(file.path(directory, out$filename)))) else character(); out$acquisition_status <- rep(acquisition_status, n); out$acquisition_timestamp <- rep(acquired_at, n); out$run_id <- rep(row$run_id, n); out$required_simulation_start <- rep(row$simulation_start, n); out$required_simulation_end <- rep(row$simulation_end, n); out$verification_status <- rep(if (verification$verified) "verified" else "unverified", n); out$coverage_status <- rep(verification$coverage_status, n)
  utils::write.csv(out, path, row.names = FALSE); rds <- out; rds$absolute_path <- normalizePath(file.path(directory, rds$filename), winslash = "/", mustWork = FALSE); saveRDS(rds, rds_path); normalizePath(path, winslash = "/", mustWork = TRUE)
}
