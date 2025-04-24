calculate_particle_concentration <- function(plume_table, raster_grid, voxel_height = 100, max_hour = 6) {
  
  points_sf <- sf::st_as_sf(plume_table, coords = c("lon", "lat"), crs = 4326)
  
  points_sf_proj <- sf::st_transform(points_sf, crs = crs(raster_grid))
  
  plume_tablex <- plume_table %>%
    filter(hour <= max_hour)
  
  hours <- sort(unique(plume_tablex$hour))
  
  raster_stack <- rast()
  
  for (h in hours) {

    hour_points <- points_sf_proj[plume_table$hour == h, ]
    
    if (nrow(hour_points) == 0) {
      next
    }
    
    # count particles per grid cell
    counts <- terra::rasterize(hour_points, raster_grid, fun = "count", background = 0)
    names(counts) <- paste0("hour_", h)
    
    raster_stack <- c(raster_stack, counts)
  }
  
  # convert counts to concentration
  count_to_concentration <- function(count_stack, voxel_height) {
    cell_width <- res(count_stack)[1]
    cell_height <- res(count_stack)[2]
    voxel_volume <- cell_width * cell_height * voxel_height  # m³
    count_stack / voxel_volume
  }
  
  concentration_stack <- count_to_concentration(raster_stack, voxel_height)
  
  return(list(
    count_stack = raster_stack,
    concentration_stack = concentration_stack
  ))
}
