#' Extract an unmodified HYSPLIT dispersion table
extract_hysplit_dispersion_table <- function(model_result) {
  located <- validate_hysplit_model_result(model_result)
  out <- located$dispersion
  pick <- function(candidates) { hit <- intersect(candidates, names(out)); if (length(hit) == 1L) hit else NULL }
  particle <- pick(c("particle_i", "particle_id")); time <- pick(c("datetime_utc", "datetime", "timestamp", "hour", "elapsed_hours"))
  lon <- pick(c("lon", "longitude")); lat <- pick(c("lat", "latitude"))
  metadata <- list(
    source_object_class = located$source_object_class, source_component_name = located$source_component,
    original_column_names = names(out), n_rows = nrow(out),
    n_particles = if (is.null(particle)) NA_integer_ else length(unique(out[[particle]])),
    temporal_range = if (is.null(time)) c(NA, NA) else range(out[[time]], na.rm = TRUE),
    longitude_range = if (is.null(lon)) c(NA_real_, NA_real_) else range(out[[lon]], na.rm = TRUE),
    latitude_range = if (is.null(lat)) c(NA_real_, NA_real_) else range(out[[lat]], na.rm = TRUE)
  )
  attr(out, "extraction_metadata") <- metadata
  out
}
