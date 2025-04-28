map_grid2 <- function(
    raster_grid,
    traj_data     = NULL,
    group_col     = NULL,
    vector_type   = NULL,
    buffer_prop   = 0.1,
    point_size    = 0.5,
    line_size     = 1,
    grid_cut      = FALSE
) {
  require(ggmap)
  require(ggspatial)
  require(sf)
  require(terra)
  require(ggplot2)
  require(dplyr)
  
  # grid polygon
  e <- ext(raster_grid)
  corners <- matrix(c(
    e[1], e[3],
    e[2], e[3],
    e[2], e[4],
    e[1], e[4],
    e[1], e[3]
  ), ncol = 2, byrow = TRUE)
  
  grid_poly     <- st_polygon(list(corners))
  
  grid_sf_wgs84 <- st_sfc(
    grid_poly,
    crs = crs(raster_grid, proj = TRUE)
  ) %>%
    st_transform(crs = 4326) %>%
    st_sf(geometry = .)
  
  # trajectory obhjects
  traj_points <- NULL
  traj_lines  <- NULL
  if (!is.null(traj_data)) {
    traj_sf <- st_as_sf(
      traj_data,
      coords = c("lon", "lat"),
      crs    = 4326
    )
    
    if (!is.null(group_col)) {
      if (is.null(vector_type) || !vector_type %in% c("line", "point")) {
        stop('When group_col is provided, vector_type must be "line" or "point"')
      }
      traj_sf[[group_col]] <- as.factor(traj_sf[[group_col]])
      if (vector_type == "line") {
        traj_lines <- traj_sf %>%
          group_by(!!sym(group_col)) %>%
          summarize(
            geometry = st_combine(geometry),
            .groups  = "drop"
          ) %>%
          st_cast("LINESTRING")
      } else {
        traj_points <- traj_sf
      }
    } else {
      traj_points <- traj_sf
    }
    
    # cropping to grid polygon
    if (grid_cut) {
      if (!is.null(traj_points)) {
        traj_points <- st_intersection(traj_points, grid_sf_wgs84)
      }
      if (!is.null(traj_lines)) {
        traj_lines <- st_intersection(traj_lines, grid_sf_wgs84)
      }
    }
  }
  
  # bounding box for basemap
  grid_bbox <- st_bbox(grid_sf_wgs84)
  if (grid_cut) {
    combined_bbox <- grid_bbox
  } else {
    combined_bbox <- grid_bbox
    if (!is.null(traj_data)) {
      traj_bbox <- st_bbox(traj_sf)
      combined_bbox["xmin"] <- min(combined_bbox["xmin"], traj_bbox["xmin"])
      combined_bbox["ymin"] <- min(combined_bbox["ymin"], traj_bbox["ymin"])
      combined_bbox["xmax"] <- max(combined_bbox["xmax"], traj_bbox["xmax"])
      combined_bbox["ymax"] <- max(combined_bbox["ymax"], traj_bbox["ymax"])
    }
  }
  # small buffer
  buf_x <- if (grid_cut) 0 else buffer_prop * (combined_bbox["xmax"] - combined_bbox["xmin"])
  buf_y <- if (grid_cut) 0 else buffer_prop * (combined_bbox["ymax"] - combined_bbox["ymin"])
  bb_buf <- c(
    combined_bbox["xmin"] - buf_x,
    combined_bbox["ymin"] - buf_y,
    combined_bbox["xmax"] + buf_x,
    combined_bbox["ymax"] + buf_y
  )
  names(bb_buf) <- c("left", "bottom", "right", "top")
  
  basemap <- get_map(
    location = bb_buf,
    source   = "stadia",
    maptype  = "stamen_toner_lite",
    color    = "bw"
  )
  
  # build plot
  p <- ggmap(basemap) +
    geom_sf(
      data        = grid_sf_wgs84,
      fill        = NA,
      color       = "red",
      linewidth   = 1,
      inherit.aes = FALSE
    ) +
    theme_classic() +
    theme(
      plot.margin      = unit(c(2,8,5,8), "mm"),
      axis.title       = element_text(size = 22, face = "bold"),
      axis.text        = element_text(size = 10, face = "bold"),
      legend.direction = "horizontal",
      legend.position  = "none",
      strip.text       = element_blank(),
      legend.key.size  = unit(2, "line"),
      legend.key.width = unit(3, "line"),
      legend.text      = element_text(size = 16, face = "bold"),
      legend.title     = element_text(size = 16, face = "bold"),
      plot.title       = element_text(size = 24, face = "bold")
    ) +
    labs(
      title = "Study Area",
      x     = "Longitude",
      y     = "Latitude",
      col   = "Model Run"
    ) +
    annotation_scale(location = "tl", width_hint = 0.4)
  
  # add trajectories
  if (!is.null(traj_data)) {
    if (!is.null(traj_lines)) {
      p <- p +
        geom_sf(
          data       = traj_lines,
          aes(color   = .data[[group_col]]),
          inherit.aes = FALSE,
          linewidth   = line_size
        )
    }
    if (!is.null(traj_points)) {
      p <- p +
        geom_sf(
          data        = traj_points,
          aes(color    = if (!is.null(group_col)) .data[[group_col]] else NULL),
          inherit.aes = FALSE,
          size         = point_size,
          shape        = 19,
          fill         = "white"
        )
    }
  }
  
  return(p)
}
