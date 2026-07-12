#' Simulate a reproducible clustered facility network
simulate_facility_network <- function(cfg) {
  if (!requireNamespace("sf", quietly = TRUE)) stop("Package `sf` is required.", call. = FALSE)
  n <- as.integer(cfg$simulation$n_facilities); set.seed(cfg$project$random_seed)
  center <- sf::st_sfc(sf::st_point(c(cfg$domain$center_longitude, cfg$domain$center_latitude)), crs = 4326)
  utm_zone <- floor((cfg$domain$center_longitude + 180) / 6) + 1
  epsg <- if (cfg$domain$center_latitude >= 0) 32600 + utm_zone else 32700 + utm_zone
  ctr <- sf::st_coordinates(sf::st_transform(center, epsg))[1, ]
  half <- cfg$domain$extent_km * 500; min_space <- cfg$simulation$minimum_spacing_m
  centers <- matrix(c(-0.25, -0.20, 0.22, -0.12, -0.05, 0.24, 0.27, 0.23), ncol = 2, byrow = TRUE) * half
  accepted <- matrix(numeric(0), ncol = 2); attempts <- 0L
  while (nrow(accepted) < n && attempts < n * 1000L) {
    attempts <- attempts + 1L
    if (isTRUE(cfg$simulation$clustered_locations)) {
      k <- sample(seq_len(nrow(centers)), 1); candidate <- ctr + centers[k, ] + stats::rnorm(2, sd = half * 0.13)
    } else candidate <- ctr + stats::runif(2, -half, half)
    inside <- all(abs(candidate - ctr) <= half)
    spaced <- !nrow(accepted) || min(sqrt(rowSums((accepted - matrix(candidate, nrow(accepted), 2, byrow = TRUE))^2))) >= min_space
    if (inside && spaced) accepted <- rbind(accepted, candidate)
  }
  if (nrow(accepted) != n) stop("Unable to generate facilities respecting domain and minimum spacing; reduce minimum_spacing_m.", call. = FALSE)
  pts <- sf::st_as_sf(data.frame(x = accepted[, 1], y = accepted[, 2]), coords = c("x", "y"), crs = epsg)
  ll <- sf::st_coordinates(sf::st_transform(pts, 4326))
  width <- max(3L, nchar(as.character(n)))
  out <- data.frame(facility_id = sprintf(paste0("F%0", width, "d"), seq_len(n)), facility_name = sprintf(paste0("Simulated Facility %0", width, "d"), seq_len(n)), longitude = ll[, 1], latitude = ll[, 2], facility_type = "simulated", source_height_m = cfg$plume$source_height_m, stringsAsFactors = FALSE)
  validate_facilities(out); out
}
