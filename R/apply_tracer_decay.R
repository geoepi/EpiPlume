#' Calculate the retained tracer fraction after elapsed time
#'
#' Uses F(t) = exp(-log(2) * t / h). Distance filtering is intentionally
#' outside this function. Missing elapsed times remain missing.
apply_tracer_decay <- function(elapsed_hours, half_life_hours, minimum_fraction = NULL) {
  if (!is.numeric(elapsed_hours)) stop("`elapsed_hours` must be numeric.", call. = FALSE)
  if (any(elapsed_hours < 0, na.rm = TRUE)) stop("`elapsed_hours` cannot be negative.", call. = FALSE)
  if (!is.numeric(half_life_hours) || length(half_life_hours) != 1L || is.na(half_life_hours) || half_life_hours <= 0) stop("`half_life_hours` must be a positive number.", call. = FALSE)
  out <- exp(-log(2) * elapsed_hours / half_life_hours)
  if (!is.null(minimum_fraction)) {
    if (!is.numeric(minimum_fraction) || length(minimum_fraction) != 1L || is.na(minimum_fraction) || minimum_fraction < 0 || minimum_fraction > 1) stop("`minimum_fraction` must be between zero and one.", call. = FALSE)
    out[!is.na(out) & out < minimum_fraction] <- 0
  }
  out
}
