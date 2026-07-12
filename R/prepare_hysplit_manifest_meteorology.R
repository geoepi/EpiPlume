# Acquire and validate one shared meteorology cache for all selected runs.
prepare_hysplit_manifest_meteorology <- function(manifest, cfg, allow_download = FALSE,
    overwrite = FALSE, verify = TRUE, downloader = NULL) {
  plan <- plan_hysplit_manifest_meteorology(manifest, cfg)
  validate_manifest_meteorology_plan(plan)
  h <- cfg$hysplit
  directory <- h$meteorology_directory
  if (is.null(directory) || !length(directory) || is.na(directory) || !nzchar(trimws(directory))) directory <- Sys.getenv("HYSPLIT_METEOROLOGY_DIRECTORY", unset = NA_character_)
  if (is.null(directory) || !length(directory) || is.na(directory) || !nzchar(trimws(directory))) stop("Meteorology directory must be configured for manifest preparation.", call. = FALSE)
  directory <- normalizePath(path.expand(directory), winslash = "/", mustWork = FALSE); dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  before <- inventory_meteorology_files(directory)
  required <- plan$unique_files$required_filename
  valid <- function(filename) {
    p <- file.path(directory, filename); info <- file.info(p)
    file.exists(p) && !isTRUE(info$isdir) && !is.na(info$size) && info$size > 0 && tryCatch({ con <- file(p, "rb"); on.exit(close(con)); readBin(con, "raw", n = 1); TRUE }, error = function(e) FALSE)
  }
  cached_before <- vapply(required, valid, logical(1)); missing <- required[!cached_before | isTRUE(overwrite)]
  downloaded <- character(); warnings <- character(); error_message <- NULL
  lock_path <- file.path(directory, ".meteorology_download.lock"); locked <- FALSE
  acquire_lock <- function() { if (!dir.create(lock_path, showWarnings = FALSE)) stop("An active meteorology preparation lock exists: ", lock_path, call. = FALSE); writeLines(c(paste0("pid=", Sys.getpid()), paste0("started_at=", format(Sys.time(), tz = "UTC"))), file.path(lock_path, "owner")); locked <<- TRUE }
  release_lock <- function() if (locked && dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE)
  on.exit(release_lock(), add = TRUE)
  if (length(missing) && isTRUE(allow_download)) {
    tryCatch({
      acquire_lock()
      if (is.null(downloader)) downloader <- splitr_meteorology_downloader
      attempts <- max(1L, as.integer(h$meteorology_download_retries %||% 0) + 1L)
      for (filename in missing) {
        if (!isTRUE(overwrite) && valid(filename)) next
        stamp <- sub("^RP", "", tools::file_path_sans_ext(filename)); month_start <- as.Date(paste0(substr(stamp, 1, 6), "01"), "%Y%m%d")
        err <- NULL
        for (attempt in seq_len(attempts)) {
          err <- NULL
          tryCatch(downloader(meteorology_type = plan$unique_files$meteorology_type[match(filename, required)], days = month_start, duration = 24, direction = h$direction, met_dir = directory), error = function(e) err <<- conditionMessage(e))
          if (is.null(err)) break
        }
        if (!is.null(err)) stop(err, call. = FALSE)
        if (valid(filename)) downloaded <- c(downloaded, filename) else warnings <- c(warnings, paste("Downloader did not produce a valid file:", filename))
      }
    }, error = function(e) error_message <<- conditionMessage(e))
  }
  after <- inventory_meteorology_files(directory)
  verified <- vapply(required, valid, logical(1))
  if (isTRUE(verify)) verified <- verified & !is.na(match(required, after$filename))
  inventory <- plan$unique_files
  inventory$filename <- inventory$required_filename; inventory$cached_before <- cached_before
  inventory$downloaded_now <- inventory$filename %in% downloaded
  inventory$size_bytes <- vapply(inventory$filename, function(x) if (valid(x)) as.numeric(file.info(file.path(directory, x))$size) else NA_real_, numeric(1))
  inventory$md5 <- vapply(inventory$filename, function(x) if (valid(x)) unname(as.character(tools::md5sum(file.path(directory, x)))) else NA_character_, character(1))
  inventory$verification_status <- ifelse(verified, "verified", "unverified")
  readiness <- lapply(unique(plan$run_to_file$run_id), function(run) {
    x <- plan$run_to_file[plan$run_to_file$run_id == run, , drop = FALSE]; ok <- verified[match(x$required_filename, required)]
    data.frame(run_id = run, meteorology_ready = all(ok), required_file_count = nrow(x), verified_file_count = sum(ok), missing_file_count = sum(!ok), required_files = paste(x$required_filename, collapse = ";"), missing_files = paste(x$required_filename[!ok], collapse = ";"), stringsAsFactors = FALSE)
  }); readiness <- do.call(rbind, readiness)
  status <- if (!is.null(error_message) && !all(verified)) "failed" else if (all(readiness$meteorology_ready)) "ready" else "incomplete"
  result <- list(status = status, meteorology_directory = directory, plan = plan, unique_file_inventory = inventory, run_readiness = readiness, downloaded_files = normalizePath(file.path(directory, downloaded), winslash = "/", mustWork = FALSE), reused_files = normalizePath(file.path(directory, required[cached_before & verified]), winslash = "/", mustWork = FALSE), missing_files = required[!verified], warnings = unique(warnings), error_message = error_message)
  write_manifest_meteorology_outputs(result, directory); result
}
