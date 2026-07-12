#' Write one-run facility receptor products and metadata
write_facility_receptor_outputs <- function(extracted, run_directory, overwrite = FALSE) {
  directory <- file.path(run_directory, "receptors")
  if (dir.exists(directory) && length(list.files(directory, all.files = TRUE, no.. = TRUE)) && !isTRUE(overwrite)) stop("Receptor output directory is not empty; use `overwrite = TRUE`: ", directory, call. = FALSE)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  atomic <- function(path, writer) { temporary <- tempfile(paste0(basename(path), "-"), tmpdir = directory); on.exit(unlink(temporary), add = TRUE); writer(temporary); if (file.exists(path)) unlink(path); if (!file.rename(temporary, path)) stop("Could not install output: ", path, call. = FALSE); normalizePath(path, winslash = "/") }
  outputs <- list(receptor_metadata.csv = extracted$receptor_metadata, sampled_receptor_time_series.csv = extracted$sampled_time_series, receptor_metric_summaries.csv = extracted$receptor_metric_summaries, source_receptor_exchange.csv = extracted$exchange_table)
  written <- vapply(names(outputs), function(name) atomic(file.path(directory, name), function(path) utils::write.csv(outputs[[name]], path, row.names = FALSE)), character(1))
  rds_path <- normalizePath(file.path(directory, "extraction_metadata.rds"), winslash = "/", mustWork = FALSE); json_path <- normalizePath(file.path(directory, "extraction_metadata.json"), winslash = "/", mustWork = FALSE)
  metadata <- extracted$extraction_metadata; metadata$package_versions <- list(R = as.character(getRversion()), terra = as.character(utils::packageVersion("terra")), sf = as.character(utils::packageVersion("sf")))
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) NA_character_); metadata$repository_commit <- if (length(commit) == 1L) commit else NA_character_
  metadata$written_files <- data.frame(path = c(written, rds_path, json_path), md5 = c(unname(tools::md5sum(written)), NA_character_, NA_character_), stringsAsFactors = FALSE)
  metadata$self_checksum_note <- "Metadata self-checksums are NA to avoid recursive content."
  atomic(json_path, function(path) jsonlite::write_json(metadata, path, auto_unbox = TRUE, pretty = TRUE, null = "null", POSIXt = "ISO8601")); atomic(rds_path, function(path) saveRDS(metadata, path))
  metadata
}
