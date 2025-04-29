map_grid3 <- function(
    raster_grid,
    traj_data     = NULL,
    group_col     = NULL,
    vector_type   = NULL,
    spat_points   = NULL,
    source_loc    = NULL,
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
  
  # trajectory objects
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
          summarize(geometry = st_combine(geometry), .groups = "drop") %>%
          st_cast("LINESTRING")
      } else {
        traj_points <- traj_sf
      }
    } else {
      traj_points <- traj_sf
    }
    # cropping
    if (grid_cut) {
      if (!is.null(traj_points)) traj_points <- st_intersection(traj_points, grid_sf_wgs84)
      if (!is.null(traj_lines))  traj_lines  <- st_intersection(traj_lines,  grid_sf_wgs84)
    }
  }
  
  # convert and overlay SpatVector points
  spat_sf <- NULL
  if (!is.null(spat_points) && inherits(spat_points, "SpatVector")) {
    spat_sf <- st_as_sf(spat_points) %>%
      st_transform(crs = 4326)
  }
  
  # prepare source point sf if provided
  source_sf_wgs84 <- NULL
  if (!is.null(source_loc) && inherits(source_loc, c("data.frame","sf","SpatVector"))) {
    if (inherits(source_loc, "SpatVector")) {
      source_sf <- st_as_sf(source_loc)
    } else {
      source_sf <- st_as_sf(source_loc)
    }
    source_sf_wgs84 <- st_transform(source_sf, 4326)
  }
  
  # bounding box computation
  grid_bbox <- st_bbox(grid_sf_wgs84)
  combined_bbox <- if (grid_cut) grid_bbox else {
    cb <- grid_bbox
    if (!is.null(traj_data)) {
      tb <- st_bbox(traj_sf)
      cb[c("xmin","ymin")] <- pmin(cb[c("xmin","ymin")], tb[c("xmin","ymin")])
      cb[c("xmax","ymax")] <- pmax(cb[c("xmax","ymax")], tb[c("xmax","ymax")])
    }
    cb
  }
  buf_x <- if (grid_cut) 0 else buffer_prop*(combined_bbox["xmax"]-combined_bbox["xmin"])
  buf_y <- if (grid_cut) 0 else buffer_prop*(combined_bbox["ymax"]-combined_bbox["ymin"])
  bb_buf <- setNames(c(
    combined_bbox["xmin"]-buf_x,
    combined_bbox["ymin"]-buf_y,
    combined_bbox["xmax"]+buf_x,
    combined_bbox["ymax"]+buf_y
  ), c("left","bottom","right","top"))
  basemap <- get_map(location = bb_buf, source = "stadia", maptype = "stamen_toner_lite", color = "bw")
  
  # build base plot
  p <- ggmap(basemap) +
    geom_sf(
      data        = grid_sf_wgs84,
      fill        = NA,
      color       = "red",
      linewidth   = 1,
      inherit.aes = FALSE
    ) +
    theme_classic() + theme(
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
      p <- p + geom_sf(
        data        = traj_lines,
        aes(color   = .data[[group_col]]),
        inherit.aes = FALSE,
        linewidth   = line_size
      )
    }
    if (!is.null(traj_points)) {
      p <- p + geom_sf(
        data        = traj_points,
        aes(color    = if(!is.null(group_col)) .data[[group_col]] else NULL),
        inherit.aes = FALSE,
        size        = point_size,
        shape       = 19,
        fill        = "white"
      )
    }
  }
  
  # add SpatVector points
  if (!is.null(spat_sf)) {
    p <- p + geom_sf(
      data        = spat_sf,
      inherit.aes = FALSE,
      size        = point_size,
      shape       = 21,
      fill        = "yellow",
      color       = "black"
    )
  }
  
  # add source locations with farm attribute
  if (!is.null(source_sf_wgs84)) {
    if ("farm" %in% names(source_sf_wgs84)) {
      p <- p + geom_sf(
        data        = source_sf_wgs84,
        aes(shape   = farm),
        fill        = "yellow",
        color       = "red",
        size        = 4,
        stroke      = 1,
        inherit.aes = FALSE
      ) +
        scale_shape_manual(
          name   = "Farm type",
          values = c(source = 24, sim = 21)
        )
    } else {
      p <- p + geom_sf(
        data        = source_sf_wgs84,
        shape       = 21,
        fill        = "yellow",
        color       = "red",
        size        = 4,
        stroke      = 1,
        inherit.aes = FALSE
      )
    }
  }
  
  return(p)
}
