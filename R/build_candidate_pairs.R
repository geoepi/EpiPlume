#' Build directed source-to-receptor pairs using projected distances
build_candidate_pairs <- function(facilities, maximum_evaluation_distance_km = 20) {
  validate_facilities(facilities)
  if (!requireNamespace("sf", quietly = TRUE)) stop("Package `sf` is required.", call. = FALSE)
  if (!is.numeric(maximum_evaluation_distance_km) || length(maximum_evaluation_distance_km) != 1L || maximum_evaluation_distance_km <= 0) stop("Maximum distance must be positive.", call. = FALSE)
  mean_lon <- mean(facilities$longitude); mean_lat <- mean(facilities$latitude)
  zone <- floor((mean_lon + 180) / 6) + 1; epsg <- if (mean_lat >= 0) 32600 + zone else 32700 + zone
  pts <- sf::st_transform(sf::st_as_sf(facilities, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE), epsg)
  d <- units::drop_units(sf::st_distance(pts)); diag(d) <- Inf
  idx <- which(d <= maximum_evaluation_distance_km * 1000, arr.ind = TRUE)
  out <- data.frame(source_id = facilities$facility_id[idx[, 1]], receptor_id = facilities$facility_id[idx[, 2]], distance_m = as.numeric(d[idx]), stringsAsFactors = FALSE)
  out$distance_km <- out$distance_m / 1000
  out <- out[order(out$source_id, out$receptor_id), , drop = FALSE]; rownames(out) <- NULL
  attr(out, "isolated_facilities") <- facilities[!facilities$facility_id %in% unique(c(out$source_id, out$receptor_id)), c("facility_id", "facility_name"), drop = FALSE]
  out
}
