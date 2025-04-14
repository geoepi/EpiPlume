create_spatraster_grid <- function(center_coord, user_proj) {
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
  
  # Define the grid dimensions
  grid_width <- 25000
  grid_height <- 25000
  
  half_width <- grid_width / 2
  half_height <- grid_height / 2
  
  grid_extent <- ext(center_xy[1] - half_width, center_xy[1] + half_width,
                     center_xy[2] - half_height, center_xy[2] + half_height)
  
  ncol <- grid_width / 25    # 25000 m / 25 m = 1000 columns
  nrow <- grid_height / 25   # 25000 m / 25 m = 1000 rows

  r <- rast(nrows = nrow, ncols = ncol, ext = grid_extent, crs = user_proj)
  
  # cells to 0.
  values(r) <- 0
  names(r) <- "grid"
  
  return(r)
}

