#' Resolve facility-exchange output paths
facility_exchange_paths <- function(cfg, create = FALSE, root = getwd()) {
  rel <- cfg$outputs
  paths <- list(
    root = file.path(root, rel$root_directory),
    data = file.path(root, rel$root_directory, "data"),
    manifests = file.path(root, rel$manifest_directory),
    rasters = file.path(root, rel$raster_directory),
    exposures = file.path(root, rel$exposure_directory),
    reports = file.path(root, rel$report_directory),
    climate = file.path(root, cfg$hysplit$meteorology_directory),
    hysplit = file.path(root, cfg$hysplit$run_directory)
  )
  paths <- lapply(paths, normalizePath, winslash = "/", mustWork = FALSE)
  if (isTRUE(create)) invisible(lapply(paths, dir.create, recursive = TRUE, showWarnings = FALSE))
  paths
}
