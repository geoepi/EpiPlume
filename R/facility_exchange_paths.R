#' Resolve facility-exchange output paths
facility_exchange_paths <- function(cfg, create = FALSE, root = getwd()) {
  rel <- cfg$outputs
  climate_directory <- cfg$hysplit$meteorology_directory
  if (is.null(climate_directory) || length(climate_directory) != 1L || is.na(climate_directory) || !nzchar(climate_directory)) climate_directory <- file.path(rel$root_directory, "climate")
  paths <- list(
    root = file.path(root, rel$root_directory),
    data = file.path(root, rel$root_directory, "data"),
    manifests = file.path(root, rel$manifest_directory),
    rasters = file.path(root, rel$raster_directory),
    exposures = file.path(root, rel$exposure_directory),
    reports = file.path(root, rel$report_directory),
    climate = file.path(root, climate_directory),
    hysplit = file.path(root, if (is.null(cfg$hysplit$run_root_directory)) cfg$hysplit$run_directory else cfg$hysplit$run_root_directory)
  )
  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  if (isTRUE(create)) invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
  paths
}
