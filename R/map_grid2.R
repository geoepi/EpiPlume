map_grid2 <- function(raster_grid, traj_data = NULL, 
                     group_col = NULL, vector_type = NULL, 
                     buffer_prop = 0.1, point_size=0.5, line_size = 1) {
  
  require(ggmap)
  require(ggspatial)
  require(sf)
  require(terra)
  require(ggplot2)
  require(dplyr)
  
  # get extent
  e <- ext(raster_grid)
  
  # polygon from the extent
  corners <- matrix(c(e[1], e[3],
                      e[2], e[3],
                      e[2], e[4],
                      e[1], e[4],
                      e[1], e[3]), 
                    ncol = 2, byrow = TRUE)
  
  grid_polygon <- st_polygon(list(corners))
  grid_sf <- st_sfc(grid_polygon, crs = crs(raster_grid, proj = TRUE))
  
  # transform the grid polygon to WGS84 (EPSG:4326)
  grid_sf_wgs84 <- st_transform(grid_sf, crs = 4326)
  
  # grid bounding box
  grid_bbox <- st_bbox(grid_sf_wgs84)
  combined_bbox <- c(
    left   = as.numeric(grid_bbox["xmin"]),
    bottom = as.numeric(grid_bbox["ymin"]),
    right  = as.numeric(grid_bbox["xmax"]),
    top    = as.numeric(grid_bbox["ymax"])
  )
  
  traj_points <- NULL
  traj_lines <- NULL
  
  if (!is.null(traj_data)) {

    traj_sf <- st_as_sf(traj_data, coords = c("lon", "lat"), crs = 4326)
    
    traj_bbox <- st_bbox(traj_sf)
    combined_bbox <- c(
      left   = min(combined_bbox["left"], as.numeric(traj_bbox["xmin"])),
      bottom = min(combined_bbox["bottom"], as.numeric(traj_bbox["ymin"])),
      right  = max(combined_bbox["right"], as.numeric(traj_bbox["xmax"])),
      top    = max(combined_bbox["top"], as.numeric(traj_bbox["ymax"]))
    )
    
    if (!is.null(group_col)) {
      # if group_col, vector_type must be provided as "line" or "point"
      if (is.null(vector_type) || !(vector_type %in% c("line", "point"))) {
        stop('When group_col is provided, vector_type must be specified as "line" or "point".')
      }
      
      # convert the grouping column to a factor for coloring
      traj_sf[[group_col]] <- as.factor(traj_sf[[group_col]])
      
      if (vector_type == "line") {
        # group the data by group_col, then convert each group into a LINESTRING.
        traj_lines <- traj_sf %>% 
          group_by(!!sym(group_col)) %>% 
          summarize(do_union = FALSE, .groups = "drop") %>% 
          st_cast("LINESTRING")
      } else if (vector_type == "point") {

        traj_points <- traj_sf
      }
      
    } else {
      
      traj_points <- traj_sf
    }
  }
  
  # buffer bounding box
  
  buffer_x <- buffer_prop * (combined_bbox["right"] - combined_bbox["left"])
  buffer_y <- buffer_prop * (combined_bbox["top"] - combined_bbox["bottom"])
  
  bbox_buffered <- c(
    left   = as.numeric(combined_bbox["left"]) - buffer_x,
    bottom = as.numeric(combined_bbox["bottom"]) - buffer_y,
    right  = as.numeric(combined_bbox["right"]) + buffer_x,
    top    = as.numeric(combined_bbox["top"]) + buffer_y
  )
  
  bbox_buffered <- structure(as.numeric(bbox_buffered), names = c("left", "bottom", "right", "top"))
  
  #### basemap
  basemap <- get_map(location = bbox_buffered, source = "stadia", maptype = "stamen_toner_lite", color = "bw")
  
  
  p <- ggmap(basemap) +
    geom_sf(data = grid_sf_wgs84, fill = NA, color = "red", size = 1, inherit.aes = FALSE) +
    theme_classic() +
    theme(plot.margin = unit(c(2,8,5,8), "mm"),
          axis.title.x = element_text(size = 22, face = "bold"),
          axis.title.y = element_text(size = 22, face = "bold"),
          axis.text.x = element_text(size = 10, face = "bold"),
          axis.text.y = element_text(size = 10, face = "bold"),
          legend.direction = "horizontal",
          legend.position = "bottom",
          strip.text = element_blank(), 
          strip.background = element_blank(),
          legend.key.size = unit(2, "line"),
          legend.key.width = unit(3, "line"),
          legend.text = element_text(size = 16, face = "bold"),
          legend.title = element_text(size = 16, face = "bold"),
          plot.title = element_text(size = 24, face = "bold")) +
    labs(title = " ", x = "Longitude", y = "Latitude", col = "Model Run") +
    annotation_scale(location = "tl", width_hint = 0.4) +
    ggtitle("Study Area")
  
  # trajectories, if provided
  
  if (!is.null(traj_data)) {
    if (!is.null(traj_lines)) {
      p <- p + geom_sf(data = traj_lines, aes(color = .data[[group_col]]),
                       inherit.aes = FALSE, linewidth = line_size)
    }
    if (!is.null(traj_points)) {
      p <- p + geom_sf(data = traj_points, 
                       aes(color = if(!is.null(group_col)) .data[[group_col]] else NULL),
                       inherit.aes = FALSE, size = point_size, shape = 19, fill = "white")
    }
  }
  
  return(p)
}
