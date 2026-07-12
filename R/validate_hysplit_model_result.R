#' Locate a dispersion table in a completed splitr-compatible result
validate_hysplit_model_result <- function(x) {
  if (is.null(x)) stop("HYSPLIT model result is missing.", call. = FALSE)
  source_class <- paste(class(x), collapse = "/")
  component <- "input"
  candidate <- x
  if (is.list(x) && !is.null(x$status) && identical(x$status, "failed")) stop("Cannot parse a failed-run placeholder.", call. = FALSE)
  if (is.list(x) && !is.null(x$model_result)) { candidate <- x$model_result; component <- "model_result"; source_class <- paste(class(candidate), collapse = "/") }
  if (is.list(candidate) && !is.data.frame(candidate) && !is.null(candidate$disp_df)) { candidate <- candidate$disp_df; component <- paste(component, "disp_df", sep = "$" ) }
  if (!is.data.frame(candidate)) stop("No dispersion table exists in the supplied result.", call. = FALSE)
  known <- list(particle_id = c("particle_i", "particle_id"), elapsed = c("hour", "elapsed_hours"), longitude = c("lon", "longitude"), latitude = c("lat", "latitude"), height = c("height", "height_m"))
  missing <- names(known)[!vapply(known, function(z) any(z %in% names(candidate)), logical(1))]
  if (length(missing)) stop("Dispersion table cannot map required field(s): ", paste(missing, collapse = ", "), ".", call. = FALSE)
  list(dispersion = candidate, source_component = component, source_object_class = source_class)
}
