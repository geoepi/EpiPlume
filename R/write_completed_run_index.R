#' Write a deterministic fingerprint of durable HYSPLIT run products
#'
#' The index is intentionally stored outside individual run directories so an
#' ordinary targets pipeline can track one file instead of an open-ended set of
#' directories. Execution and postprocessing writers refresh it after durable
#' products change. Failed runs with stale downstream products are excluded.
write_completed_run_index <- function(run_root_directory,
    filename = "completed_run_index.csv") {
  if (length(run_root_directory) != 1L || is.na(run_root_directory) ||
      !nzchar(run_root_directory)) {
    stop("`run_root_directory` must be one nonempty path.", call. = FALSE)
  }
  if (length(filename) != 1L || is.na(filename) || !nzchar(filename) ||
      !identical(basename(filename), filename)) {
    stop("`filename` must be one simple filename.", call. = FALSE)
  }

  root <- normalizePath(path.expand(run_root_directory), winslash = "/",
    mustWork = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  index_path <- file.path(root, filename)
  directories <- list.dirs(root, full.names = TRUE, recursive = FALSE)

  marker_names <- c(
    run_metadata_md5 = file.path("run_metadata.rds"),
    parsing_metadata_md5 = file.path("parsed", "parsing_metadata.rds"),
    parsed_object_md5 = file.path("parsed", "parsed_plume.rds"),
    extraction_metadata_md5 = file.path("receptors", "extraction_metadata.rds"),
    receptor_exchange_md5 = file.path("receptors", "source_receptor_exchange.csv")
  )
  checksum <- function(path) {
    if (!file.exists(path)) return(NA_character_)
    unname(tools::md5sum(path))
  }

  rows <- lapply(directories, function(directory) {
    paths <- file.path(directory, marker_names)
    names(paths) <- names(marker_names)
    metadata <- NULL
    metadata_status <- NA_character_
    if (file.exists(paths[["run_metadata_md5"]])) {
      metadata <- tryCatch(readRDS(paths[["run_metadata_md5"]]),
        error = function(e) NULL)
      if (is.list(metadata) && length(metadata$status)) {
        metadata_status <- as.character(metadata$status[[1]])
      } else {
        metadata_status <- "invalid"
      }
    }

    has_parsed <- file.exists(paths[["parsed_object_md5"]])
    has_receptors <- file.exists(paths[["receptor_exchange_md5"]])
    legacy_completed <- is.na(metadata_status) && (has_parsed || has_receptors)
    if (!identical(metadata_status, "completed") && !legacy_completed) return(NULL)

    run_id <- if (is.list(metadata) && length(metadata$run_id) &&
      !is.na(metadata$run_id[[1]]) && nzchar(as.character(metadata$run_id[[1]]))) {
      as.character(metadata$run_id[[1]])
    } else {
      basename(directory)
    }
    stage <- if (has_receptors) "receptor_extracted" else if (has_parsed) "parsed" else "completed"
    hashes <- vapply(paths, checksum, character(1))
    data.frame(
      schema_version = "1.0.0",
      run_id = run_id,
      completed_stage = stage,
      run_metadata_md5 = hashes[["run_metadata_md5"]],
      parsing_metadata_md5 = hashes[["parsing_metadata_md5"]],
      parsed_object_md5 = hashes[["parsed_object_md5"]],
      extraction_metadata_md5 = hashes[["extraction_metadata_md5"]],
      receptor_exchange_md5 = hashes[["receptor_exchange_md5"]],
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  index <- if (length(rows)) do.call(rbind, rows) else data.frame(
    schema_version = character(), run_id = character(), completed_stage = character(),
    run_metadata_md5 = character(), parsing_metadata_md5 = character(),
    parsed_object_md5 = character(), extraction_metadata_md5 = character(),
    receptor_exchange_md5 = character(), stringsAsFactors = FALSE
  )
  if (nrow(index)) {
    index <- index[order(index$run_id), , drop = FALSE]
    rownames(index) <- NULL
    if (anyDuplicated(index$run_id)) stop("Completed-run index contains duplicate run IDs.", call. = FALSE)
  }

  temporary <- tempfile(pattern = paste0(filename, "-"), tmpdir = root)
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(index, temporary, row.names = FALSE, na = "")
  unchanged <- file.exists(index_path) &&
    identical(unname(tools::md5sum(index_path)), unname(tools::md5sum(temporary)))
  if (!unchanged) {
    if (file.exists(index_path)) unlink(index_path)
    if (!file.rename(temporary, index_path)) stop("Could not install completed-run index: ", index_path, call. = FALSE)
  }
  normalizePath(index_path, winslash = "/", mustWork = TRUE)
}
