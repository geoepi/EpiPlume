#' Summarize one standardized and distance-annotated plume
summarize_hysplit_plume <- function(dispersion, raster_outputs = NULL) {
  available <- function(name, fun) if (!name %in% names(dispersion) || all(is.na(dispersion[[name]]))) NA_real_ else fun(dispersion[[name]], na.rm = TRUE)
  rasters <- if (is.null(raster_outputs)) list() else raster_outputs
  n_cells <- if (!length(rasters)) NA_integer_ else length(unique(unlist(lapply(rasters, function(x) which(!is.na(terra::values(x$raster)))))))
  data.frame(
    run_id = unique(dispersion$run_id)[1], source_id = unique(dispersion$source_id)[1],
    n_particles = length(unique(dispersion$particle_id)), n_records = nrow(dispersion),
    first_datetime_utc = min(dispersion$datetime_utc), last_datetime_utc = max(dispersion$datetime_utc),
    maximum_elapsed_hours = max(dispersion$elapsed_hours), maximum_distance_km = available("distance_from_source_km", max),
    n_hour_bins = length(unique(floor(dispersion$elapsed_hours + 1e-10))),
    raw_mass_total = available("raw_mass", sum), decayed_mass_total = available("decayed_mass", sum),
    raw_concentration_max = available("raw_concentration", max), decayed_concentration_max = available("decayed_concentration", max),
    n_cells_intersected = n_cells, n_cells_within_evaluation_distance = n_cells,
    parse_status = "completed", diagnostic_message = "One completed plume parsed without smoothing or interpolation.", stringsAsFactors = FALSE
  )
}
