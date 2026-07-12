#' Sample all available hourly plume rasters at receptor points or buffers
sample_hourly_plume_at_receptors <- function(parsed_plume, receptors, sampling_method = c("point", "buffer"), buffer_summary = c("max", "mean", "sum")) {
  sampling_method <- match.arg(sampling_method); summary_supplied <- !missing(buffer_summary); buffer_summary <- match.arg(buffer_summary)
  if (!is.list(parsed_plume$hourly_rasters) || !"particle_count" %in% names(parsed_plume$hourly_rasters)) stop("Parsed plume lacks required particle-count rasters.", call. = FALSE)
  meta <- parsed_plume$parsing_metadata; release <- as.POSIXct(meta$release_start, tz = "UTC")
  rows <- list(); k <- 0L
  for (metric in names(parsed_plume$hourly_rasters)) {
    item <- parsed_plume$hourly_rasters[[metric]]; raster <- item$raster; if (inherits(raster, "PackedSpatRaster")) raster <- terra::unwrap(raster); layers <- item$layer_metadata
    fun_name <- if (summary_supplied) buffer_summary else if (grepl("concentration", metric)) "mean" else "sum"
    geometry <- if (sampling_method == "point") receptors$points else receptors$buffers
    geometry <- sf::st_transform(geometry, terra::crs(raster))
    raster_extent <- sf::st_as_sf(terra::as.polygons(terra::ext(raster), crs = terra::crs(raster)))
    inside <- lengths(sf::st_intersects(geometry, raster_extent)) > 0
    extracted <- if (sampling_method == "point") terra::extract(raster, terra::vect(geometry)) else terra::extract(raster, terra::vect(geometry), fun = fun_name, na.rm = TRUE, exact = TRUE)
    values <- as.matrix(extracted[, -1, drop = FALSE])
    for (i in seq_len(nrow(receptors$metadata))) for (h in seq_len(nrow(layers))) {
      k <- k + 1L; value <- values[i, h]
      if (!inside[i] || !receptors$metadata$within_evaluation_distance[i]) value <- NA_real_
      rows[[k]] <- data.frame(run_id = meta$run_id, source_id = meta$source_id, receptor_id = receptors$metadata$facility_id[i], metric = metric, hour_bin = layers$elapsed_hour_bin[h], bin_start_hours = layers$bin_start_hours[h], bin_end_hours = layers$bin_end_hours[h], datetime_start_utc = release + layers$bin_start_hours[h] * 3600, datetime_end_utc = release + layers$bin_end_hours[h] * 3600, sample_value = as.numeric(value), sampling_method = sampling_method, buffer_summary = if (sampling_method == "buffer") fun_name else NA_character_, distance_from_source_km = receptors$metadata$distance_from_source_km[i], within_evaluation_distance = receptors$metadata$within_evaluation_distance[i], inside_raster_extent = inside[i], stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
