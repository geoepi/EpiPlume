#' Extract facility receptor metrics from one parsed plume
extract_facility_receptors_from_plume <- function(parsed_plume, facilities, cfg, write_outputs = FALSE, overwrite = FALSE) {
  if (!is.list(parsed_plume) || is.null(parsed_plume$parsing_metadata) || is.null(parsed_plume$hourly_rasters)) stop("`parsed_plume` is malformed.", call. = FALSE)
  validate_facilities(facilities); meta <- parsed_plume$parsing_metadata
  source <- facilities[facilities$facility_id == meta$source_id, , drop = FALSE]
  if (nrow(source) != 1L) stop("Source ID cannot be uniquely found in facilities: ", meta$source_id, call. = FALSE)
  difference <- as.numeric(sf::st_distance(sf::st_sfc(sf::st_point(c(source$longitude, source$latitude)), crs = 4326), sf::st_sfc(sf::st_point(c(meta$source_longitude, meta$source_latitude)), crs = 4326)))
  if (difference > 100) stop("Source coordinates conflict with the facility table by more than 100 m.", call. = FALSE)
  exchange <- build_source_receptor_exchange(parsed_plume, facilities, cfg)
  receptors <- attr(exchange, "receptors"); sampled <- attr(exchange, "sampled"); summaries <- attr(exchange, "summaries")
  attr(exchange, "receptors") <- attr(exchange, "sampled") <- attr(exchange, "summaries") <- NULL
  extraction_metadata <- list(schema_version = "1.0.0", extracted_at = as.POSIXct(Sys.time(), tz = "UTC"), run_id = meta$run_id, source_id = meta$source_id, run_directory = meta$run_directory, receptor_count = nrow(exchange), intercept_count = sum(exchange$intercept), non_intercept_count = sum(!exchange$intercept), outside_distance_count = sum(!exchange$within_evaluation_distance), sampling_method = cfg$exposure$sampling_method, receptor_buffer_m = cfg$exposure$receptor_buffer_m, intercept_metric = cfg$exposure$intercept_metric, intercept_threshold = cfg$exposure$intercept_threshold, minimum_intercept_hours = cfg$exposure$minimum_intercept_hours)
  extracted <- list(receptor_points = receptors$points, receptor_buffers = receptors$buffers, receptor_metadata = receptors$metadata, sampled_time_series = sampled, receptor_metric_summaries = summaries, exchange_table = exchange, extraction_metadata = extraction_metadata)
  if (isTRUE(write_outputs)) extracted$extraction_metadata <- write_facility_receptor_outputs(extracted, meta$run_directory, overwrite)
  extracted
}
