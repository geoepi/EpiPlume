#' Add generic exponential tracer decay to standardized dispersion records
add_tracer_decay_to_dispersion <- function(dispersion, half_life_hours, minimum_fraction = 0) {
  if (!all(c("elapsed_hours", "raw_mass", "raw_concentration") %in% names(dispersion))) stop("Dispersion is missing decay input columns.", call. = FALSE)
  out <- dispersion
  out$tracer_remaining_fraction <- apply_tracer_decay(out$elapsed_hours, half_life_hours, minimum_fraction)
  out$decayed_mass <- out$raw_mass * out$tracer_remaining_fraction
  out$decayed_concentration <- out$raw_concentration * out$tracer_remaining_fraction
  out
}
