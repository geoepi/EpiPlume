define_study_domain_ip <- function(config_file = "demo_2025-04-21", 
                                seed = 123, min_flock = 15000, max_flock = 50000) {
  
  # read configuration
  cfg <- yaml::read_yaml(here("config", paste0(config_file, ".yaml")))
  
  # get proj utm projection
  user_projection <- get_time_zone(cfg$domain$source_origin)
  
  # create study area raster
  grid_raster <- create_spatraster_grid(cfg$domain$source_origin, 
                                        user_projection, 
                                        extent_km = cfg$domain$extent_km,
                                        res_m = cfg$domain$res_m)
  
  # convert source coordinates to point for mapping
  source_point <- vect(matrix(cfg$domain$source_origin, ncol = 2), type = "points", crs = "EPSG:4326")
  source_point_utm <- project(source_point, y = grid_raster)
  
  
  # simulate farm locs
  if(!is.null(cfg$domain$sim_farms) && is.numeric(cfg$domain$sim_farms)){
    
    chik_dens <- rast(here("local/nlcd/GLW4-2020.D-DA.CHK.tif"))
    
    chik_dens <- project(
      x      = chik_dens,
      y      = grid_raster,
      method = "near"
    )
    
    chik_dens <- crop(chik_dens, grid_raster)
    
    chik_dens <- resample(
      x      = chik_dens,
      y      = grid_raster,
      method = "near"
    )
    
    # density to probability range
    farm_prob <- rescale_raster(chik_dens, new_min = 5, new_max = 95)
    
    set.seed(seed)
    pts_mat <- spatSample(
      x      = farm_prob,
      size   = cfg$domain$sim_farms,
      method = "weights",
      na.rm  = TRUE,
      xy     = TRUE
    )
    
    farm_locs <- vect(
      as.matrix(pts_mat[, c("x","y")]),
      type = "points",
      crs = crs(farm_prob)
    )
    
    farm_locs$farm <- "sim"
    farm_locs$name <- paste0("farm_", 1:dim(farm_locs)[1])
    source_locs <- source_point_utm
    source_locs$farm <- "source"
    source_locs$name <- "source_farm"
    farm_locs <- rbind(farm_locs, source_locs)
    
    # random assignment of flock size
    farm_locs$flock <- round(runif(dim(farm_locs)[1], min_flock, max_flock), 0)
    
  }
  
  return(
    list(
      projection    = user_projection,
      grid          = grid_raster,
      source_point  = source_point_utm,
      farm_locs     = farm_locs
    )
  )
  
}