animate_plume <- function(raster_grid, traj_data, group_col = NULL, 
                          buffer_prop = 0.1, point_size = 0.5) {
  require(ggmap)
  require(ggspatial)
  require(sf)
  require(terra)
  require(ggplot2)
  require(dplyr)
  require(gganimate)
  
  # Get extent from raster_grid
  e <- ext(raster_grid)  # order: xmin, xmax, ymin, ymax
  
  # Create a polygon from the extent
  corners <- matrix(c(e[1], e[3],
                      e[2], e[3],
                      e[2], e[4],
                      e[1], e[4],
                      e[1], e[3]), 
                    ncol = 2, byrow = TRUE)
  grid_polygon <- st_polygon(list(corners))
  grid_sf <- st_sfc(grid_polygon, crs = crs(raster_grid, proj = TRUE))
  
  # Transform grid polygon to WGS84 (EPSG:4326)
  grid_sf_wgs84 <- st_transform(grid_sf, crs = 4326)
  
  # Get bounding box from the grid polygon
  grid_bbox <- st_bbox(grid_sf_wgs84)
  combined_bbox <- c(
    left   = as.numeric(grid_bbox["xmin"]),
    bottom = as.numeric(grid_bbox["ymin"]),
    right  = as.numeric(grid_bbox["xmax"]),
    top    = as.numeric(grid_bbox["ymax"])
  )
  
  # Process trajectory data: convert to an sf object using lon and lat.
  traj_sf <- st_as_sf(traj_data, coords = c("lon", "lat"), crs = 4326)
  
  # Optional: reduce the number of points so that each group appears only once per hour.
  # If group_col is provided, group by both hour and group_col and keep only the last point.
  if (!is.null(group_col)) {
    traj_sf <- traj_sf %>%
      group_by(hour, !!sym(group_col)) %>%
      slice_tail(n = 1) %>%  # keep only the last point per group per hour
      ungroup()
  } else {
    # If no grouping column, simply keep one point per hour (e.g., the last observation).
    traj_sf <- traj_sf %>%
      group_by(hour) %>%
      slice_tail(n = 1) %>%
      ungroup()
  }
  
  # Update combined_bbox to include trajectory points.
  traj_bbox <- st_bbox(traj_sf)
  combined_bbox <- c(
    left   = min(combined_bbox["left"], as.numeric(traj_bbox["xmin"])),
    bottom = min(combined_bbox["bottom"], as.numeric(traj_bbox["ymin"])),
    right  = max(combined_bbox["right"], as.numeric(traj_bbox["xmax"])),
    top    = max(combined_bbox["top"], as.numeric(traj_bbox["ymax"]))
  )
  
  # Buffer bounding box.
  buffer_x <- buffer_prop * (combined_bbox["right"] - combined_bbox["left"])
  buffer_y <- buffer_prop * (combined_bbox["top"] - combined_bbox["bottom"])
  
  bbox_buffered <- c(
    left   = as.numeric(combined_bbox["left"]) - buffer_x,
    bottom = as.numeric(combined_bbox["bottom"]) - buffer_y,
    right  = as.numeric(combined_bbox["right"]) + buffer_x,
    top    = as.numeric(combined_bbox["top"]) + buffer_y
  )
  bbox_buffered <- structure(as.numeric(bbox_buffered), 
                             names = c("left", "bottom", "right", "top"))
  
  # Download basemap.
  basemap <- get_map(location = bbox_buffered, source = "stadia", 
                     maptype = "stamen_toner_lite", color = "bw")
  
  # If group_col provided, set up color aesthetic; otherwise, no color mapping.
  if (!is.null(group_col)) {
    traj_sf[[group_col]] <- as.factor(traj_sf[[group_col]])
    color_aes <- aes(color = .data[[group_col]])
  } else {
    color_aes <- NULL
  }
  
  # Build the base ggplot with the basemap and grid outline.
  p <- ggmap(basemap) +
    geom_sf(data = grid_sf_wgs84, fill = NA, color = "red", size = 1, inherit.aes = FALSE) +
    theme_classic() +
    theme(plot.margin = unit(c(2,8,5,8), "mm"),
          axis.title.x = element_text(size = 22, face = "bold"),
          axis.title.y = element_text(size = 22, face = "bold"),
          axis.text.x = element_text(size = 10, face = "bold"),
          axis.text.y = element_text(size = 10, face = "bold"),
          legend.position = "none",  # remove legend to speed up processing
          strip.text = element_blank(), 
          strip.background = element_blank(),
          plot.title = element_text(size = 24, face = "bold")) +
    labs(title = "Study Area - Hour: {frame_time}", x = "Longitude", y = "Latitude") +
    annotation_scale(location = "tl", width_hint = 0.4) +
    ggtitle("Study Area")
  
  # Overlay the trajectory points (which are now summarized) and animate based on hour.
  p <- p + 
    geom_sf(data = traj_sf, mapping = color_aes, inherit.aes = FALSE,
            size = point_size, shape = 19, fill = "white") +
    transition_time(hour) +
    ease_aes('linear')
  
  return(p)
}
