#' Build one source-to-receptor exchange row per receptor for one parsed run
build_source_receptor_exchange <- function(parsed_plume, facilities, cfg) {
  meta <- parsed_plume$parsing_metadata
  receptors <- prepare_receptor_facilities(facilities, meta$source_id, meta$source_longitude, meta$source_latitude, cfg$plume$maximum_evaluation_distance_km, cfg$exposure$receptor_buffer_m, cfg$exposure$include_source_as_receptor)
  sampled <- sample_hourly_plume_at_receptors(parsed_plume, receptors, cfg$exposure$sampling_method)
  summaries <- summarize_receptor_time_series(sampled, meta$release_start, cfg$exposure$intercept_metric, cfg$exposure$intercept_threshold)
  classified <- classify_receptor_intercepts(summaries, cfg$exposure$intercept_metric, cfg$exposure$intercept_threshold, cfg$exposure$minimum_intercept_hours)
  base <- receptors$metadata; names(base)[names(base) == "facility_id"] <- "receptor_id"; names(base)[names(base) == "longitude"] <- "receptor_longitude"; names(base)[names(base) == "latitude"] <- "receptor_latitude"
  base <- base[, c("receptor_id", "receptor_longitude", "receptor_latitude", "distance_from_source_km", "within_evaluation_distance"), drop = FALSE]
  timing <- classified[, c("receptor_id", "intercept", "intercept_reason", "first_arrival_datetime_utc", "last_exposure_datetime_utc", "first_threshold_hour", "last_nonzero_hour", "exposure_duration_hours", "n_positive_hour_bins"), drop = FALSE]
  out <- merge(base, timing, by = "receptor_id", all.x = TRUE, sort = FALSE)
  metrics <- c("particle_count", "raw_mass", "decayed_mass", "raw_concentration", "decayed_concentration")
  for (metric in metrics) {
    z <- summaries[summaries$metric == metric, c("receptor_id", "maximum_value", "cumulative_value"), drop = FALSE]
    max_name <- paste0(metric, "_max"); cumulative_name <- if (grepl("concentration", metric)) paste0(metric, "_hourly_sum") else paste0(metric, "_cumulative")
    if (!nrow(z)) { out[[max_name]] <- NA_real_; out[[cumulative_name]] <- NA_real_ } else { names(z)[2:3] <- c(max_name, cumulative_name); out <- merge(out, z, by = "receptor_id", all.x = TRUE, sort = FALSE) }
  }
  out$run_id <- meta$run_id; out$scenario_id <- meta$scenario_id; out$source_id <- meta$source_id
  out$release_start <- as.POSIXct(meta$release_start, tz = "UTC"); out$simulation_end <- as.POSIXct(meta$simulation_end, tz = "UTC")
  out$source_longitude <- meta$source_longitude; out$source_latitude <- meta$source_latitude
  out$sampling_method <- cfg$exposure$sampling_method; out$receptor_buffer_m <- cfg$exposure$receptor_buffer_m
  names(out)[names(out) == "first_threshold_hour"] <- "first_arrival_hour"; names(out)[names(out) == "last_nonzero_hour"] <- "last_exposure_hour"
  out$parse_status <- "completed"; out$diagnostic_message <- "Intercept is modeled tracer contact under the configured sampling and threshold rule."
  required <- c("run_id", "scenario_id", "source_id", "receptor_id", "release_start", "simulation_end", "source_longitude", "source_latitude", "receptor_longitude", "receptor_latitude", "distance_from_source_km", "within_evaluation_distance", "sampling_method", "receptor_buffer_m", "intercept", "intercept_reason", "first_arrival_datetime_utc", "last_exposure_datetime_utc", "first_arrival_hour", "last_exposure_hour", "exposure_duration_hours", "n_positive_hour_bins", "particle_count_max", "particle_count_cumulative", "raw_mass_max", "raw_mass_cumulative", "decayed_mass_max", "decayed_mass_cumulative", "raw_concentration_max", "raw_concentration_hourly_sum", "decayed_concentration_max", "decayed_concentration_hourly_sum", "parse_status", "diagnostic_message")
  out <- out[, required, drop = FALSE]; out <- out[order(out$source_id, out$receptor_id), , drop = FALSE]
  if (!isTRUE(cfg$exposure$retain_non_intercepts)) out <- out[out$intercept, , drop = FALSE]
  attr(out, "receptors") <- receptors; attr(out, "sampled") <- sampled; attr(out, "summaries") <- summaries
  out
}
