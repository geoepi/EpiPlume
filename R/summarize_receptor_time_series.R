#' Summarize hourly receptor samples by receptor and metric
summarize_receptor_time_series <- function(sampled, release_start, intercept_metric, intercept_threshold) {
  groups <- split(sampled, interaction(sampled$receptor_id, sampled$metric, drop = TRUE, lex.order = TRUE))
  out <- lapply(groups, function(x) {
    x <- x[order(x$hour_bin), ]; available <- any(!is.na(x$sample_value)); positive <- !is.na(x$sample_value) & x$sample_value > 0; threshold <- !is.na(x$sample_value) & x$sample_value >= intercept_threshold
    first <- function(idx, field) if (any(idx)) x[[field]][which(idx)[1]] else NA
    last <- function(idx, field) if (any(idx)) x[[field]][tail(which(idx), 1)] else NA
    maximum <- if (available) max(x$sample_value, na.rm = TRUE) else NA_real_; max_i <- if (available) which.max(replace(x$sample_value, is.na(x$sample_value), -Inf)) else NA_integer_
    data.frame(run_id = x$run_id[1], source_id = x$source_id[1], receptor_id = x$receptor_id[1], metric = x$metric[1], first_nonzero_hour = first(positive, "hour_bin"), last_nonzero_hour = last(positive, "hour_bin"), first_threshold_hour = first(threshold, "hour_bin"), last_threshold_hour = last(threshold, "hour_bin"), first_arrival_datetime_utc = if (any(threshold)) x$datetime_start_utc[which(threshold)[1]] else as.POSIXct(NA, tz = "UTC"), last_exposure_datetime_utc = if (any(positive)) x$datetime_end_utc[tail(which(positive), 1)] else as.POSIXct(NA, tz = "UTC"), exposure_duration_hours = if (any(positive)) sum(x$bin_end_hours[positive] - x$bin_start_hours[positive]) else if (available) 0 else NA_real_, n_positive_hour_bins = if (available) sum(positive) else NA_integer_, n_threshold_hour_bins = if (available) sum(threshold) else NA_integer_, maximum_value = maximum, cumulative_value = if (available) sum(x$sample_value, na.rm = TRUE) else NA_real_, mean_positive_value = if (any(positive)) mean(x$sample_value[positive]) else if (available) 0 else NA_real_, time_of_maximum_utc = if (available) x$datetime_start_utc[max_i] else as.POSIXct(NA, tz = "UTC"), distance_from_source_km = x$distance_from_source_km[1], within_evaluation_distance = x$within_evaluation_distance[1], inside_raster_extent = x$inside_raster_extent[1], stringsAsFactors = FALSE)
  })
  result <- do.call(rbind, out); rownames(result) <- NULL; result
}
