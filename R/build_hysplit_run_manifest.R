#' Build a deterministic planned HYSPLIT run manifest
build_hysplit_run_manifest <- function(facilities, cfg, source_ids = NULL, release_times = NULL) {
  validate_facilities(facilities)
  if (is.null(source_ids)) source_ids <- head(facilities$facility_id, 2L)
  if (any(!source_ids %in% facilities$facility_id)) stop("All source_ids must occur in facilities.", call. = FALSE)
  if (is.null(release_times)) {
    release_times <- unlist(cfg$plume$planned_release_times)
  }
  release_times <- as.POSIXct(release_times, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (!length(release_times) || anyNA(release_times)) stop("release_times must be valid UTC date-times.", call. = FALSE)
  grid <- expand.grid(source_id = sort(unique(source_ids)), release_start = sort(unique(release_times)), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  src <- facilities[match(grid$source_id, facilities$facility_id), ]
  fmt <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  safe <- format(grid$release_start, "%Y%m%dT%H%M%SZ", tz = "UTC")
  source_height <- if ("source_height_m" %in% names(src)) src$source_height_m else rep(cfg$plume$source_height_m, nrow(src))
  data.frame(run_id = paste(grid$source_id, safe, sep = "__"), scenario_id = cfg$project$scenario_id, source_id = grid$source_id, source_longitude = src$longitude, source_latitude = src$latitude, release_start = fmt(grid$release_start), release_end = fmt(grid$release_start + cfg$plume$release_duration_hours * 3600), simulation_start = fmt(grid$release_start), simulation_end = fmt(grid$release_start + cfg$plume$simulation_duration_hours * 3600), source_height_m = source_height, emission_rate = cfg$plume$emission_rate, maximum_evaluation_distance_km = cfg$plume$maximum_evaluation_distance_km, tracer_half_life_hours = cfg$tracer_decay$half_life_hours, meteorology_type = cfg$hysplit$meteorology_type, run_directory = file.path(cfg$hysplit$run_directory, paste(grid$source_id, safe, sep = "__")), status = "planned", stringsAsFactors = FALSE)
}
