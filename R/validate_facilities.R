#' Validate a normalized facility table
validate_facilities <- function(facilities) {
  if (!is.data.frame(facilities)) stop("`facilities` must be a data frame.", call. = FALSE)
  required <- c("facility_id", "facility_name", "longitude", "latitude")
  missing <- setdiff(required, names(facilities))
  if (length(missing)) stop("Facility table is missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  bad_id <- which(is.na(facilities$facility_id) | !nzchar(trimws(as.character(facilities$facility_id))))
  if (length(bad_id)) stop("Missing facility_id at rows: ", paste(bad_id, collapse = ", "), call. = FALSE)
  dup <- which(duplicated(facilities$facility_id) | duplicated(facilities$facility_id, fromLast = TRUE))
  if (length(dup)) stop("Duplicate facility_id at rows: ", paste(dup, collapse = ", "), call. = FALSE)
  lon <- suppressWarnings(as.numeric(facilities$longitude)); lat <- suppressWarnings(as.numeric(facilities$latitude))
  bad_lon <- which(is.na(lon) | !is.finite(lon) | lon < -180 | lon > 180)
  bad_lat <- which(is.na(lat) | !is.finite(lat) | lat < -90 | lat > 90)
  if (length(bad_lon)) stop("Invalid longitude at rows: ", paste(bad_lon, collapse = ", "), call. = FALSE)
  if (length(bad_lat)) stop("Invalid latitude at rows: ", paste(bad_lat, collapse = ", "), call. = FALSE)
  invisible(facilities)
}
