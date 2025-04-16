create_spatraster_grid <- function(center_coord, user_proj, extent_km = 25, res_m = 25) {
  # center_coord: numeric vector c(lon, lat)
  # user_proj: character string for the projection (PROJ.4 format)
  
  require(terra)
  
  # spatial point from the center coordinates,
  center_point <- vect(matrix(center_coord, ncol = 2), type = "points",
                       crs = "+proj=longlat +datum=WGS84")
  
  # reproject
  center_proj <- project(center_point, user_proj)
  
  # extract the projected coordinates.
  center_xy <- crds(center_proj)[1, ]
  
  # grid dimensions
  grid_width <- extent_km * 1000
  grid_height <- extent_km * 1000
  
  half_width <- grid_width / 2
  half_height <- grid_height / 2
  
  grid_extent <- ext(center_xy[1] - half_width, center_xy[1] + half_width,
                     center_xy[2] - half_height, center_xy[2] + half_height)
  
  res <- res_m # target resolution in meters
  
  ncol <- grid_width / res_m
  nrow <- grid_height / res_m

  r <- rast(nrows = nrow, ncols = ncol, ext = grid_extent, crs = user_proj)
  
  # cells to 0.
  values(r) <- 0
  names(r) <- "grid"
  
  return(r)
}

