.as_spatraster <-
function (x, argument) 
{
    if (inherits(x, "SpatRaster")) {
        return(x)
    }
    if (is.character(x) && length(x) == 1) {
        return(terra::rast(x))
    }
    stop(argument, " must be a SpatRaster or a path to a raster file.")
}
.normalize_temporal_weights <-
function (x) 
{
    if (is.null(x)) {
        return(NULL)
    }
    if (is.data.frame(x)) {
        if (!"weight" %in% names(x)) {
            stop("A temporal-profile data frame must contain a 'weight' column.")
        }
        x <- x$weight
    }
    x <- as.numeric(x)
    if (length(x) < 1 || any(!is.finite(x)) || any(x < 0) || 
        sum(x) <= 0) {
        stop("temporal_weights must contain finite, non-negative values with a positive sum.")
    }
    x/sum(x)
}
.simulate_dates <-
function (n, date_range, temporal_weights = NULL) 
{
    date_range <- as.Date(date_range)
    if (length(date_range) != 2 || anyNA(date_range)) {
        stop("date_range must contain two valid dates.")
    }
    if (date_range[1] > date_range[2]) {
        stop("date_range must be ordered from start date to end date.")
    }
    available_dates <- seq.Date(date_range[1], date_range[2], 
        by = "day")
    temporal_weights <- .normalize_temporal_weights(temporal_weights)
    if (is.null(temporal_weights)) {
        probability <- rep(1, length(available_dates))
    }
    else if (length(available_dates) == 1) {
        probability <- 1
    }
    else {
        relative_time <- seq(0, 1, length.out = length(available_dates))
        temporal_bin <- pmin(floor(relative_time * length(temporal_weights)) + 
            1L, length(temporal_weights))
        probability <- temporal_weights[temporal_bin]
    }
    sample(available_dates, size = n, replace = TRUE, prob = probability)
}
.sample_raster_xy <-
function (x, n, method, replace = FALSE) 
{
    if (method == "random") {
        out <- terra::spatSample(x, size = n, method = "random", 
            replace = replace, na.rm = TRUE, xy = TRUE, values = FALSE, 
            exhaustive = TRUE)
    }
    else if (method == "weights") {
        out <- terra::spatSample(x, size = n, method = "weights", 
            replace = replace, na.rm = TRUE, xy = TRUE, values = FALSE)
    }
    else {
        stop("Unsupported raster sampling method: ", method)
    }
    out <- as.data.frame(out)
    if (nrow(out) != n) {
        stop("Raster sampling returned fewer points than requested.")
    }
    out[, c("x", "y"), drop = FALSE]
}
.jitter_raster_xy <-
function (xy, template, domain) 
{
    original <- xy
    cell_res <- terra::res(template)
    xy$x <- xy$x + runif(nrow(xy), -cell_res[1]/2, cell_res[1]/2)
    xy$y <- xy$y + runif(nrow(xy), -cell_res[2]/2, cell_res[2]/2)
    candidates <- terra::vect(xy, geom = c("x", "y"), crs = terra::crs(template))
    inside <- !is.na(terra::extract(domain, candidates)[, 2])
    xy[!inside, ] <- original[!inside, ]
    xy
}
.xy_to_lonlat <-
function (xy, source_crs) 
{
    pts <- terra::vect(xy, geom = c("x", "y"), crs = source_crs)
    pts_ll <- terra::project(pts, "EPSG:4326")
    ll <- as.data.frame(terra::crds(pts_ll))
    names(ll) <- c("lon", "lat")
    ll
}
simulate_points <-
function (n_positive = 78, n_negative = n_positive, date_range, 
    density_raster, domain_raster, temporal_weights = NULL, seed = NULL, 
    simulation_id = "sim_01", jitter = TRUE) 
{
    if (!is.null(seed)) {
        set.seed(seed)
    }
    if (length(n_positive) != 1 || length(n_negative) != 1 || 
        !is.finite(n_positive) || !is.finite(n_negative) || n_positive < 
        0 || n_negative < 0) {
        stop("n_positive and n_negative must each be one finite, non-negative number.")
    }
    n_positive <- as.integer(n_positive)
    n_negative <- as.integer(n_negative)
    if ((n_positive + n_negative) == 0) {
        stop("At least one of n_positive or n_negative must be greater than zero.")
    }
    density_raster <- .as_spatraster(density_raster, "density_raster")
    domain_raster <- .as_spatraster(domain_raster, "domain_raster")
    if (!terra::compareGeom(density_raster, domain_raster, stopOnError = FALSE)) {
        stop("density_raster and domain_raster must have matching geometry and CRS.")
    }
    density_min <- terra::global(density_raster, "min", na.rm = TRUE)[1, 
        1]
    density_sum <- terra::global(density_raster, "sum", na.rm = TRUE)[1, 
        1]
    if (!is.finite(density_min) || density_min < 0 || !is.finite(density_sum) || 
        density_sum <= 0) {
        stop("density_raster must contain non-negative weights with a positive sum.")
    }
    sampled <- list()
    if (n_negative > 0) {
        negative_xy <- .sample_raster_xy(domain_raster, n = n_negative, 
            method = "random", replace = FALSE)
        if (jitter) {
            negative_xy <- .jitter_raster_xy(negative_xy, template = domain_raster, 
                domain = domain_raster)
        }
        negative_ll <- .xy_to_lonlat(negative_xy, terra::crs(domain_raster))
        negative <- data.frame(simulation_id = simulation_id, 
            class = "negative", date = .simulate_dates(n_negative, 
                date_range, temporal_weights), lat = negative_ll$lat, 
            lon = negative_ll$lon, stringsAsFactors = FALSE)
        negative <- negative[order(negative$date), , drop = FALSE]
        negative$point_id <- sprintf("%s_negative_%03d", simulation_id, 
            seq_len(nrow(negative)))
        negative <- negative[, c("simulation_id", "point_id", 
            "class", "date", "lat", "lon")]
        sampled$negative <- negative
    }
    if (n_positive > 0) {
        positive_xy <- .sample_raster_xy(density_raster, n = n_positive, 
            method = "weights", replace = TRUE)
        if (jitter) {
            positive_xy <- .jitter_raster_xy(positive_xy, template = density_raster, 
                domain = domain_raster)
        }
        positive_ll <- .xy_to_lonlat(positive_xy, terra::crs(density_raster))
        positive <- data.frame(simulation_id = simulation_id, 
            class = "positive", date = .simulate_dates(n_positive, 
                date_range, temporal_weights), lat = positive_ll$lat, 
            lon = positive_ll$lon, stringsAsFactors = FALSE)
        positive <- positive[order(positive$date), , drop = FALSE]
        positive$point_id <- sprintf("%s_positive_%03d", simulation_id, 
            seq_len(nrow(positive)))
        positive <- positive[, c("simulation_id", "point_id", 
            "class", "date", "lat", "lon")]
        sampled$positive <- positive
    }
    out <- do.call(rbind, sampled)
    rownames(out) <- NULL
    out
}
