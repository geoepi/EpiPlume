define_study_domain <- function(
    source_origin,   # [lon, lat]
    extent_km,       # length of square study area (km)
    res_m,           # raster resolution (m)
    sim_farms = NULL,# integer or NULL: # of farms to simulate
    seed     = 123,  # seed for reproducibility
    min_flock = 15000, # flock size ranges
    max_flock = 50000
) {
  require(terra)
  require(here)
  
  # projection
  user_projection <- get_time_zone(source_origin)
  
  # create grid
  grid_raster <- create_spatraster_grid(
    source_origin,
    user_projection,
    extent_km = extent_km,
    res_m     = res_m
  )
  
  # source point in UTM
  source_pt <- vect(matrix(source_origin, ncol = 2),
                    type = "points", crs = "EPSG:4326")
  source_point_utm <- project(source_pt, y = grid_raster)
  
  # simulate farms (if requested)
  farm_locs <- NULL
  if (!is.null(sim_farms) && is.numeric(sim_farms)) {
    chik_dens <- rast(here("assets/GLW4-2020.D-DA.CHK.tif")) #Gridded Livestock of the World - chicken
    chik_dens <- project(chik_dens, grid_raster, method = "near")
    chik_dens <- crop(chik_dens, grid_raster)
    chik_dens <- resample(chik_dens, grid_raster, method = "near")
    
    # density -> sampling probabilities
    farm_prob <- rescale_raster(chik_dens, new_min = 5, new_max = 95)
    
    # random points
    set.seed(seed)
    pts_mat <- spatSample(
      x     = farm_prob,
      size  = sim_farms,
      method = "weights",
      na.rm = TRUE,
      xy    = TRUE
    )
    
    farm_locs <- vect(as.matrix(pts_mat[,c("x","y")]),
                      type = "points", crs = crs(farm_prob))
    farm_locs$farm <- "sim"
    farm_locs$name <- paste0("farm_", seq_len(nrow(farm_locs)))
    
    # source as a “farm”
    source_locs <- source_point_utm
    source_locs$farm <- "source"
    source_locs$name <- "source_farm"
    farm_locs <- rbind(farm_locs, source_locs)
    
    # assign flock sizes
    farm_locs$flock <- round(
      runif(nrow(farm_locs), min_flock, max_flock)
    )
  }
  
  return(
    list(
    projection   = user_projection,
    grid         = grid_raster,
    source_point = source_point_utm,
    farm_locs    = farm_locs
    )
  )

}
