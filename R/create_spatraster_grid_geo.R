create_spatraster_grid_geo <- function(center_coord) {

 
  library(terra)
  
  # geographic CRS (WGS84).
  crs_geo <- "+proj=longlat +datum=WGS84"
  
  # extract centroid
  center_lon <- center_coord[1]
  center_lat <- center_coord[2]
  
  # dimensions in meters.
  grid_width_m <- 25000 
  grid_height_m <- 25000 
  
  # conversion factors:
  lat_deg_length <- grid_height_m / 111320
  lon_deg_length <- grid_width_m / (111320 * cos(center_lat * pi/180))
  
  # half extents in degrees.
  half_lat <- lat_deg_length / 2
  half_lon <- lon_deg_length / 2
  
  grid_extent <- ext(center_lon - half_lon, center_lon + half_lon,
                     center_lat - half_lat, center_lat + half_lat)
  
  # rows and columns
  ncol <- grid_width_m / 25   # 25000 m / 25 m = 1000 columns
  nrow <- grid_height_m / 25  # 25000 m / 25 m = 1000 rows
  
  # SpatRaster with geographic CRS.
  grid_raster_geo <- rast(nrows = nrow, ncols = ncol, ext = grid_extent, crs = crs_geo)
  
  # cell values to 0.
  values(grid_raster_geo) <- 0
  
  return(grid_raster_geo)
}


