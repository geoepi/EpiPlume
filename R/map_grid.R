map_grid <- function(raster_grid, source_loc = NULL, concentration_raster = NULL, map_type = "stamen_terrain") {
  
  # "stamen_terrain"
  # "stamen_toner_lite"
  
  require(ggmap)
  require(ggspatial)
  require(sf)
  require(terra)
  require(ggplot2)
  require(pals)
  

  e <- ext(raster_grid)  # extent
  
  # create polygon
  corners <- matrix(c(e[1], e[3],
                      e[2], e[3],
                      e[2], e[4],
                      e[1], e[4],
                      e[1], e[3]), 
                    ncol = 2, byrow = TRUE)
  
  # \sf polygon
  grid_polygon <- st_polygon(list(corners))
  grid_sf <- st_sfc(grid_polygon, crs = crs(raster_grid, proj = TRUE))
  
  # transform to WGS84 (EPSG:4326)
  grid_sf_wgs84 <- st_transform(grid_sf, crs = 4326)
  
  # bbox
  bbox_vals <- st_bbox(grid_sf_wgs84)
  bbox <- c(left = as.numeric(bbox_vals["xmin"]),
            bottom =  as.numeric(bbox_vals["ymin"]),
            right =  as.numeric(bbox_vals["xmax"]),
            top =  as.numeric(bbox_vals["ymax"])
  )
  
  # basemap using ggmap.
  basemap <- get_map(location = bbox, source = "stadia", maptype = map_type)
  
  # ggplot map with the basemap and grid outline.
  p <- ggmap(basemap) +
    geom_sf(data = grid_sf_wgs84, fill = NA, color = "red", size = 1, inherit.aes = FALSE) +
    theme_classic() +
    theme(plot.margin = unit(c(2,8,5,8), "mm"),
          axis.title.x = element_text(size = 22, face = "bold"),
          axis.title.y = element_text(size = 22, face = "bold"),
          axis.text.x = element_text(size = 10, face = "bold"),
          axis.text.y = element_text(size = 10, face = "bold"),
          legend.direction = "vertical",
          legend.position = "right",
          strip.text = element_blank(), 
          strip.background = element_blank(),
          legend.key.size = unit(2, "line"),
          legend.key.width = unit(3, "line"),
          legend.text = element_text(size = 16, face = "bold"),
          legend.title = element_text(size = 16, face = "bold"),
          plot.title = element_text(size = 24, face = "bold")) +
    labs(title = "Study Area",
         x = "Longitude", y = "Latitude") +
    annotation_scale(location = "tl", width_hint = 0.4)
  
  # if concentration raster is provided
  if (!is.null(concentration_raster)) {
    
    concentration_raster[concentration_raster == 0] <- NA
    
    # reproject
    conc_wgs84 <- project(concentration_raster, "EPSG:4326")

    df_conc <- as.data.frame(conc_wgs84, xy = TRUE)

    conc_col <- names(df_conc)[3]
    
    # overlay
    p <- p + 
      geom_tile(data = df_conc, aes(x = x, y = y, fill = !!as.name(conc_col)), alpha = 0.6) +
      scale_fill_gradientn(colors = rev(pals::cubehelix(30)[1:26]),
                           na.value = "white",
                           name = "Concentration (g/m3)",
                           limits = c(0, max(df_conc[[conc_col]], na.rm = TRUE)))
  }
  
  # add SpatVector points, if provided
  if (!is.null(source_loc)) {
    
    source_sf       <- st_as_sf(source_loc)
    source_sf_wgs84 <- st_transform(source_sf, 4326)
    
    if ("farm" %in% names(source_sf_wgs84)) {
      p <- p +
        geom_sf(
          data        = source_sf_wgs84,
          aes(shape = farm),
          fill        = "yellow",
          color       = "red",
          size        = 3,
          stroke      = 1,
          inherit.aes = FALSE
        ) +
        scale_shape_manual(
          name   = "Farm type",
          values = c(source = 24, sim = 21)
        )
    } else {
      p <- p +
        geom_sf(
          data        = source_sf_wgs84,
          shape       = 21,
          fill        = "yellow",
          color       = "red",
          size        = 3,
          stroke      = 1,
          inherit.aes = FALSE
        )
    }
  }
  
  return(p)
}
