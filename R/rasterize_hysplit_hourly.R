#' Rasterize standardized dispersion records into explicit elapsed-hour bins
rasterize_hysplit_hourly <- function(dispersion, template, value = c("particle_count", "raw_mass", "decayed_mass", "raw_concentration", "decayed_concentration"), aggregation = NULL) {
  value <- match.arg(value)
  if (!inherits(template, "SpatRaster")) stop("`template` must be a terra SpatRaster.", call. = FALSE)
  if (!all(c("longitude", "latitude", "elapsed_hours") %in% names(dispersion))) stop("Dispersion lacks raster coordinates or elapsed time.", call. = FALSE)
  if (value != "particle_count" && !value %in% names(dispersion)) stop("Requested value column is unavailable: ", value, call. = FALSE)
  method <- if (value == "particle_count" || grepl("mass$", value)) "sum" else if (is.null(aggregation)) "mean" else aggregation
  if (!method %in% c("sum", "mean")) stop("Aggregation must be `sum` or `mean`.", call. = FALSE)
  bins <- floor(dispersion$elapsed_hours + 1e-10); hours <- sort(unique(bins))
  points <- terra::project(terra::vect(dispersion, geom = c("longitude", "latitude"), crs = "EPSG:4326", keepgeom = TRUE), terra::crs(template))
  cells <- terra::cellFromXY(template, terra::crds(points))
  layers <- lapply(hours, function(hour) {
    layer <- template; vals <- if (value == "particle_count") rep(0, terra::ncell(template)) else rep(NA_real_, terra::ncell(template))
    idx <- which(bins == hour & !is.na(cells)); split_idx <- split(idx, cells[idx])
    for (cell in names(split_idx)) {
      ii <- split_idx[[cell]]
      vals[as.integer(cell)] <- if (value == "particle_count") length(ii) else { z <- dispersion[[value]][ii]; if (all(is.na(z))) NA_real_ else if (method == "sum") sum(z, na.rm = TRUE) else mean(z, na.rm = TRUE) }
    }
    terra::values(layer) <- vals; names(layer) <- sprintf("hour_%03d", hour); layer
  })
  stack <- terra::rast(layers)
  metadata <- data.frame(layer = names(stack), elapsed_hour_bin = hours, bin_start_hours = hours, bin_end_hours = hours + 1, value = value, aggregation = method, occupied_records = vapply(hours, function(h) sum(bins == h), integer(1)), stringsAsFactors = FALSE)
  list(raster = stack, layer_metadata = metadata)
}
