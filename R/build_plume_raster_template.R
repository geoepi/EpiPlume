#' Build a projected source-centered plume raster template
build_plume_raster_template <- function(source_longitude, source_latitude, maximum_distance_km, computational_buffer_km, resolution_m, crs = NULL) {
  if (!requireNamespace("terra", quietly = TRUE)) stop("Package `terra` is required.", call. = FALSE)
  radius_m <- (maximum_distance_km + computational_buffer_km) * 1000
  if (any(!is.finite(c(radius_m, resolution_m))) || radius_m <= 0 || resolution_m <= 0) stop("Raster radius and resolution must be positive.", call. = FALSE)
  if (is.null(crs)) { zone <- floor((source_longitude + 180) / 6) + 1; crs <- paste0("EPSG:", if (source_latitude >= 0) 32600 + zone else 32700 + zone) }
  source <- terra::project(terra::vect(matrix(c(source_longitude, source_latitude), ncol = 2), type = "points", crs = "EPSG:4326"), crs)
  xy <- terra::crds(source)[1, ]
  template <- terra::rast(xmin = xy[1] - radius_m, xmax = xy[1] + radius_m, ymin = xy[2] - radius_m, ymax = xy[2] + radius_m, resolution = resolution_m, crs = crs)
  attr(template, "plume_template_metadata") <- list(crs = terra::crs(template), extent = as.vector(terra::ext(template)), resolution = terra::res(template), source_longitude = source_longitude, source_latitude = source_latitude, evaluation_radius_km = maximum_distance_km, computational_buffer_km = computational_buffer_km)
  template
}
