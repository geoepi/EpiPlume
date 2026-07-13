#' Parse one completed HYSPLIT run into tables, rasters, and diagnostics
parse_hysplit_run_output <- function(run_metadata, cfg, write_outputs = FALSE, overwrite = FALSE,
    refresh_run_index = TRUE) {
  if (!is.list(run_metadata) || is.null(run_metadata$status)) stop("`run_metadata` must be standardized run metadata.", call. = FALSE)
  if (!identical(run_metadata$status, "completed")) stop("Only completed runs can be parsed; status is `", run_metadata$status, "`.", call. = FALSE)
  raw <- extract_hysplit_dispersion_table(run_metadata$model_result)
  standardized <- standardize_hysplit_dispersion_table(raw, run_metadata)
  decayed <- add_tracer_decay_to_dispersion(standardized, cfg$tracer_decay$half_life_hours, cfg$tracer_decay$minimum_fraction)
  annotated <- filter_dispersion_distance(decayed, run_metadata$source_longitude, run_metadata$source_latitude, cfg$plume$maximum_evaluation_distance_km, retain_outside = TRUE)
  filtered <- annotated[annotated$within_evaluation_distance, , drop = FALSE]
  template <- build_plume_raster_template(run_metadata$source_longitude, run_metadata$source_latitude, cfg$plume$maximum_evaluation_distance_km, cfg$plume$computational_buffer_km, cfg$domain$raster_resolution_m)
  supported <- c("particle_count", "raw_mass", "decayed_mass", "raw_concentration", "decayed_concentration")
  supported <- supported[supported == "particle_count" | vapply(supported, function(x) x %in% names(filtered) && any(!is.na(filtered[[x]])), logical(1))]
  raster_outputs <- setNames(lapply(supported, function(x) rasterize_hysplit_hourly(filtered, template, x)), supported)
  layer_metadata <- do.call(rbind, lapply(names(raster_outputs), function(x) raster_outputs[[x]]$layer_metadata))
  summary <- summarize_hysplit_plume(annotated, raster_outputs)
  parsing_metadata <- list(schema_version = "1.0.0", parsed_at = as.POSIXct(Sys.time(), tz = "UTC"), run_id = run_metadata$run_id, scenario_id = run_metadata$scenario_id, source_id = run_metadata$source_id, source_longitude = run_metadata$source_longitude, source_latitude = run_metadata$source_latitude, release_start = run_metadata$release_start, simulation_end = run_metadata$simulation_end, run_directory = run_metadata$run_directory, splitr_version = as.character(utils::packageVersion("splitr")), column_mapping = attr(standardized, "column_mapping"), extraction = attr(raw, "extraction_metadata"), evaluation_distance_km = cfg$plume$maximum_evaluation_distance_km, retained_records = nrow(filtered), excluded_records = nrow(annotated) - nrow(filtered), diagnostics = "Distance filtering is post-run; raw values are preserved and decay is separate.")
  parsed <- list(dispersion_raw = raw, dispersion_standardized = annotated, dispersion_filtered = filtered, raster_template = template, hourly_rasters = raster_outputs, raster_layer_metadata = layer_metadata, plume_summary = summary, parsing_metadata = parsing_metadata)
  if (isTRUE(write_outputs)) {
    parsed$parsing_metadata <- write_hysplit_parsed_outputs(parsed, run_metadata$run_directory, overwrite)
    if (isTRUE(refresh_run_index)) write_completed_run_index(cfg$hysplit$run_root_directory)
  }
  parsed
}
