#' Validate and normalize one planned HYSPLIT manifest row
validate_hysplit_manifest_row <- function(x) {
  if (is.list(x) && !is.data.frame(x)) {
    if (is.null(names(x)) || any(!nzchar(names(x)))) stop("A manifest list must be named.", call. = FALSE)
    bad_length <- names(x)[lengths(x) != 1L]
    if (length(bad_length)) stop("Manifest list fields must each have length one: ", paste(bad_length, collapse = ", "), call. = FALSE)
    x <- as.data.frame(x, stringsAsFactors = FALSE)
  }
  if (!is.data.frame(x)) stop("`x` must be a one-row data frame or named list.", call. = FALSE)
  if (nrow(x) != 1L) stop("`x` must contain exactly one manifest row; received ", nrow(x), ".", call. = FALSE)
  required <- c(
    "run_id", "scenario_id", "source_id", "source_longitude", "source_latitude",
    "release_start", "release_end", "simulation_start", "simulation_end",
    "source_height_m", "emission_rate", "meteorology_type", "run_directory", "status"
  )
  missing <- setdiff(required, names(x))
  if (length(missing)) stop("Manifest row is missing required field(s): ", paste(missing, collapse = ", "), call. = FALSE)
  identifiers <- c("run_id", "scenario_id", "source_id", "meteorology_type", "run_directory", "status")
  for (field in identifiers) {
    value <- as.character(x[[field]])
    if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) stop("`", field, "` must be nonempty.", call. = FALSE)
    x[[field]] <- value
  }
  number <- function(field, lower, upper = Inf, strictly_positive = FALSE) {
    value <- suppressWarnings(as.numeric(x[[field]]))
    invalid <- length(value) != 1L || is.na(value) || !is.finite(value) || value < lower || value > upper || (strictly_positive && value <= 0)
    if (invalid) stop("`", field, "` must be ", if (strictly_positive) "a positive finite number" else paste0("between ", lower, " and ", upper), ".", call. = FALSE)
    value
  }
  x$source_longitude <- number("source_longitude", -180, 180)
  x$source_latitude <- number("source_latitude", -90, 90)
  x$source_height_m <- number("source_height_m", 0, strictly_positive = TRUE)
  x$emission_rate <- number("emission_rate", 0, strictly_positive = TRUE)
  parse_utc <- function(field) {
    value <- x[[field]]
    if (inherits(value, "POSIXt")) return(as.POSIXct(value, tz = "UTC"))
    parsed <- as.POSIXct(as.character(value), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (length(parsed) != 1L || is.na(parsed)) stop("`", field, "` must be a valid UTC datetime formatted YYYY-MM-DDTHH:MM:SSZ.", call. = FALSE)
    parsed
  }
  datetime_fields <- c("release_start", "release_end", "simulation_start", "simulation_end")
  for (field in datetime_fields) x[[field]] <- parse_utc(field)
  if (x$release_start >= x$release_end) stop("`release_start` must be earlier than `release_end`.", call. = FALSE)
  if (x$simulation_start > x$release_start) stop("`simulation_start` must be no later than `release_start`.", call. = FALSE)
  if (x$simulation_end <= x$release_end) stop("`simulation_end` must be later than `release_end`.", call. = FALSE)
  allowed <- c("planned", "ready", "completed", "failed", "skipped")
  if (!x$status %in% allowed) stop("`status` must be one of: ", paste(allowed, collapse = ", "), ".", call. = FALSE)
  rownames(x) <- NULL
  x
}
