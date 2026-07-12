#' Classify modeled tracer contact using an explicit metric threshold
classify_receptor_intercepts <- function(receptor_summary, intercept_metric, threshold, minimum_intercept_hours = 1) {
  x <- receptor_summary[receptor_summary$metric == intercept_metric, , drop = FALSE]
  if (!nrow(x)) stop("Intercept metric is unavailable: ", intercept_metric, call. = FALSE)
  reason <- ifelse(!x$within_evaluation_distance, "outside_evaluation_distance", ifelse(!x$inside_raster_extent, "outside_raster_extent", ifelse(is.na(x$maximum_value), "metric_unavailable", ifelse(x$n_threshold_hour_bins >= minimum_intercept_hours, "threshold_met", ifelse(x$maximum_value == 0, "no_modeled_exposure", "below_threshold")))))
  x$intercept <- reason == "threshold_met"; x$intercept_reason <- reason
  x$intercept_metric <- intercept_metric; x$intercept_threshold <- threshold; x$minimum_intercept_hours <- minimum_intercept_hours
  x
}
