map_grid <- function(raster_grid) {
 
  require(ggmap)
  require(ggspatial)
  require(sf)
  require(terra)
  require(ggplot2)
  
  
  # extent from the input SpatRaster.
  e <- ext(raster_grid)  #order: xmin, xmax, ymin, ymax
  
  # polygon from the extent
  corners <- matrix(c(e[1], e[3],
                      e[2], e[3],
                      e[2], e[4],
                      e[1], e[4],
                      e[1], e[3]), 
                    ncol = 2, byrow = TRUE)
  
  # sf polygon using the grid's native coordinate reference system.
  grid_polygon <- st_polygon(list(corners))
  grid_sf <- st_sfc(grid_polygon, crs = crs(raster_grid, proj = TRUE))
  
  # transform the grid polygon to WGS84 (EPSG:4326)
  grid_sf_wgs84 <- st_transform(grid_sf, crs = 4326)
  
  # bounding box
  bbox_vals <- st_bbox(grid_sf_wgs84)
  bbox <- c(left = as.numeric(bbox_vals["xmin"]),
            bottom =  as.numeric(bbox_vals["ymin"]),
            right =  as.numeric(bbox_vals["xmax"]),
            top =  as.numeric(bbox_vals["ymax"])
  )
  
  # basemap using ggmap.
  basemap <- get_map(location = bbox, source = "stadia", maptype = "stamen_terrain")
  
  p <- ggmap(basemap) +
    geom_sf(data = grid_sf_wgs84, fill = NA, color = "red", size = 1, inherit.aes = FALSE) +
    theme_classic() +
    theme(plot.margin = unit(c(2,8,5,8), "mm"),
          axis.title.x = element_text(size=22, face="bold"),
          axis.title.y = element_text(size=22, face="bold"),
          axis.text.x = element_text(size=10, face="bold"),
          axis.text.y = element_text(size=10, face="bold"),
          legend.direction = "vertical",
          legend.position= "none",
          strip.text = element_blank(), 
          strip.background = element_blank(),
          legend.key.size = unit(2,"line"),
          legend.key.width = unit(3,"line"),
          legend.text = element_text(size=16, face="bold"),
          legend.title = element_text(size=16, face="bold"),
          plot.title = element_text(size=24, face="bold")) +
    labs(title = " ", x = "Longitude", y = "Latitude") 
  
  p <- p + annotation_scale(location = "tl", 
                            width_hint = 0.4) + 
    ggtitle("Study Area")
  
  return(p)
}
