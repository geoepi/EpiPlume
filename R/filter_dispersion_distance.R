#' Calculate and optionally filter source distance
filter_dispersion_distance <- function(dispersion, source_longitude, source_latitude, maximum_distance_km = 20, retain_outside = FALSE) {
  if (!requireNamespace("sf", quietly = TRUE)) stop("Package `sf` is required.", call. = FALSE)
  if (!is.numeric(maximum_distance_km) || length(maximum_distance_km) != 1L || maximum_distance_km <= 0) stop("`maximum_distance_km` must be positive.", call. = FALSE)
  points <- sf::st_as_sf(dispersion, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  source <- sf::st_sfc(sf::st_point(c(source_longitude, source_latitude)), crs = 4326)
  out <- dispersion
  out$distance_from_source_m <- as.numeric(sf::st_distance(points, source)[, 1])
  out$distance_from_source_km <- out$distance_from_source_m / 1000
  out$within_evaluation_distance <- out$distance_from_source_km <= maximum_distance_km
  if (!isTRUE(retain_outside)) out <- out[out$within_evaluation_distance, , drop = FALSE]
  rownames(out) <- NULL
  out
}
