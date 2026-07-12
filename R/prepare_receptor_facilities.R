#' Prepare projected facility receptor points, buffers, and screening metadata
prepare_receptor_facilities <- function(facilities, source_id, source_longitude, source_latitude, maximum_distance_km, receptor_buffer_m, include_source = FALSE) {
  validate_facilities(facilities)
  if (!source_id %in% facilities$facility_id) stop("Source ID is absent from facilities: ", source_id, call. = FALSE)
  facilities <- facilities[order(facilities$facility_id), , drop = FALSE]
  if (!isTRUE(include_source)) facilities <- facilities[facilities$facility_id != source_id, , drop = FALSE]
  zone <- floor((source_longitude + 180) / 6) + 1; epsg <- if (source_latitude >= 0) 32600 + zone else 32700 + zone
  points_wgs84 <- sf::st_as_sf(facilities, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  points <- sf::st_transform(points_wgs84, epsg)
  source <- sf::st_transform(sf::st_sfc(sf::st_point(c(source_longitude, source_latitude)), crs = 4326), epsg)
  distance <- as.numeric(sf::st_distance(points, source)[, 1])
  points$distance_from_source_m <- distance; points$distance_from_source_km <- distance / 1000
  points$within_evaluation_distance <- points$distance_from_source_km <= maximum_distance_km
  buffers <- sf::st_buffer(points, dist = receptor_buffer_m)
  metadata <- sf::st_drop_geometry(points)
  list(points = points, buffers = buffers, metadata = metadata, projected_crs = sf::st_crs(points))
}
