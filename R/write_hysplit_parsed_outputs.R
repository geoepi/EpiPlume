#' Write reproducible parsed plume products for one run
write_hysplit_parsed_outputs <- function(parsed, run_directory, overwrite = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE) || !requireNamespace("terra", quietly = TRUE)) stop("Packages `jsonlite` and `terra` are required.", call. = FALSE)
  directory <- file.path(run_directory, "parsed")
  if (dir.exists(directory) && length(list.files(directory, all.files = TRUE, no.. = TRUE)) && !isTRUE(overwrite)) stop("Parsed output directory is not empty; use `overwrite = TRUE`: ", directory, call. = FALSE)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  atomic <- function(path, writer) { temporary <- tempfile(pattern = paste0(basename(path), "-"), tmpdir = directory); on.exit(unlink(temporary), add = TRUE); writer(temporary); if (file.exists(path)) unlink(path); if (!file.rename(temporary, path)) stop("Could not atomically install output: ", path, call. = FALSE); normalizePath(path, winslash = "/") }
  written <- character()
  add_rds <- function(object, name) { path <- file.path(directory, name); written <<- c(written, atomic(path, function(x) saveRDS(object, x))) }
  add_csv <- function(object, name) { path <- file.path(directory, name); written <<- c(written, atomic(path, function(x) utils::write.csv(object, x, row.names = FALSE))) }
  add_rds(parsed$dispersion_standardized, "dispersion_standardized.rds"); add_csv(parsed$dispersion_standardized, "dispersion_standardized.csv")
  add_rds(parsed, "parsed_plume.rds"); add_csv(parsed$dispersion_filtered, "dispersion_table.csv")
  add_rds(parsed$dispersion_filtered, "dispersion_filtered.rds"); add_csv(parsed$dispersion_filtered, "dispersion_filtered.csv")
  raster_names <- c(particle_count = "hourly_particle_count.tif", decayed_mass = "hourly_decayed_mass.tif", decayed_concentration = "hourly_decayed_concentration.tif")
  for (key in intersect(names(raster_names), names(parsed$hourly_rasters))) { path <- file.path(directory, raster_names[[key]]); written <- c(written, atomic(path, function(x) terra::writeRaster(parsed$hourly_rasters[[key]]$raster, x, overwrite = TRUE, filetype = "GTiff"))) }
  add_csv(parsed$raster_layer_metadata, "raster_layer_metadata.csv"); add_csv(parsed$plume_summary, "plume_summary.csv")
  rds_path <- normalizePath(file.path(directory, "parsing_metadata.rds"), winslash = "/", mustWork = FALSE)
  json_path <- normalizePath(file.path(directory, "parsing_metadata.json"), winslash = "/", mustWork = FALSE)
  inventory_paths <- c(written, rds_path, json_path)
  checksums <- c(unname(tools::md5sum(written)), NA_character_, NA_character_)
  metadata <- parsed$parsing_metadata
  metadata$package_versions <- list(R = as.character(getRversion()), splitr = as.character(utils::packageVersion("splitr")), terra = as.character(utils::packageVersion("terra")), sf = as.character(utils::packageVersion("sf")))
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) NA_character_)
  metadata$repository_commit <- if (length(commit) == 1L) commit else NA_character_
  metadata$written_files <- data.frame(path = inventory_paths, md5 = checksums, stringsAsFactors = FALSE)
  metadata$self_checksum_note <- "Metadata self-checksums are NA to avoid a recursive checksum dependency."
  json_serializable <- metadata
  atomic(json_path, function(x) jsonlite::write_json(json_serializable, x, auto_unbox = TRUE, pretty = TRUE, null = "null", POSIXt = "ISO8601"))
  atomic(rds_path, function(x) saveRDS(metadata, x))
  metadata
}
