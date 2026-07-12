#' Standardize a splitr/HYSPLIT dispersion table without discarding raw columns
standardize_hysplit_dispersion_table <- function(dispersion, run_metadata = NULL) {
  if (!is.data.frame(dispersion)) stop("`dispersion` must be a data frame.", call. = FALSE)
  map_one <- function(label, candidates, required = TRUE) {
    hits <- intersect(candidates, names(dispersion))
    if (length(hits) > 1L) stop("Ambiguous column mapping for `", label, "`: ", paste(hits, collapse = ", "), ".", call. = FALSE)
    if (!length(hits)) { if (required) stop("No column maps to required field `", label, "`.", call. = FALSE); return(NA_character_) }
    hits
  }
  mapping <- c(
    particle_id = map_one("particle_id", c("particle_i", "particle_id")),
    longitude = map_one("longitude", c("lon", "longitude")), latitude = map_one("latitude", c("lat", "latitude")),
    height_m = map_one("height_m", c("height", "height_m")),
    elapsed_hours = map_one("elapsed_hours", c("hour", "elapsed_hours"), FALSE),
    datetime_utc = map_one("datetime_utc", c("datetime_utc", "datetime", "timestamp"), FALSE),
    raw_mass = map_one("raw_mass", c("raw_mass", "mass"), FALSE),
    raw_concentration = map_one("raw_concentration", c("raw_concentration", "concentration"), FALSE)
  )
  if (is.na(mapping[["elapsed_hours"]]) && is.na(mapping[["datetime_utc"]])) stop("No column maps to time (`hour`, `elapsed_hours`, or an explicit datetime).", call. = FALSE)
  meta_value <- function(name) if (is.null(run_metadata) || is.null(run_metadata[[name]])) NA_character_ else as.character(run_metadata[[name]])
  start <- if (!is.null(run_metadata$release_start)) run_metadata$release_start else run_metadata$simulation_start
  start <- if (is.null(start)) as.POSIXct(NA, tz = "UTC") else as.POSIXct(start, tz = "UTC")
  elapsed <- if (!is.na(mapping[["elapsed_hours"]])) suppressWarnings(as.numeric(dispersion[[mapping[["elapsed_hours"]]]])) else NULL
  datetime <- if (!is.na(mapping[["datetime_utc"]])) as.POSIXct(dispersion[[mapping[["datetime_utc"]]]], tz = "UTC") else as.POSIXct(start + elapsed * 3600, origin = "1970-01-01", tz = "UTC")
  if (anyNA(datetime)) stop("Malformed dispersion datetimes cannot be normalized to UTC.", call. = FALSE)
  if (is.null(elapsed)) elapsed <- as.numeric(difftime(datetime, start, units = "hours"))
  if (anyNA(elapsed)) stop("Elapsed hours could not be derived.", call. = FALSE)
  if (any(elapsed < 0)) stop("Negative elapsed times are unsupported for forward plume parsing.", call. = FALSE)
  numeric_field <- function(field) { value <- suppressWarnings(as.numeric(dispersion[[mapping[[field]]]])); if (any(!is.finite(value))) stop("`", field, "` contains nonnumeric or nonfinite values.", call. = FALSE); value }
  optional_numeric <- function(field) if (is.na(mapping[[field]])) rep(NA_real_, nrow(dispersion)) else suppressWarnings(as.numeric(dispersion[[mapping[[field]]]]))
  canonical <- data.frame(
    run_id = meta_value("run_id"), scenario_id = meta_value("scenario_id"), source_id = meta_value("source_id"),
    particle_id = as.character(dispersion[[mapping[["particle_id"]]]]), datetime_utc = datetime,
    elapsed_hours = elapsed, longitude = numeric_field("longitude"), latitude = numeric_field("latitude"),
    height_m = numeric_field("height_m"), raw_mass = optional_numeric("raw_mass"),
    raw_concentration = optional_numeric("raw_concentration"),
    source_column_set = paste(names(dispersion), collapse = "|"), stringsAsFactors = FALSE
  )
  original <- dispersion; names(original) <- paste0("original_", names(original))
  out <- cbind(canonical, original)
  attr(out, "column_mapping") <- data.frame(canonical = names(mapping), source = unname(mapping), stringsAsFactors = FALSE)
  out
}
