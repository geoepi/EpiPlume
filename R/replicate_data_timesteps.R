replicate_data_timesteps <- function(
        grid_raster = study_area$grid,
        farm_locs = study_area$farm_locs,
        concen_data = conc_melt,
        scale_concentration = 1e6,
        plume_model = plume_model,
        mesh = mesh.dom,
        max_hour = 6 # max timesteps to model
) {
  
  # plume particles
  particle_locs <- vect(
    plume_model$disp_df,
    geom = c("lon","lat"),
    crs = "EPSG:4326"
  )
  
  particle_locs <- project(
    x   = particle_locs,  
    y   = grid_raster   
  )
  
  particle_df <- as.data.frame(particle_locs)
  particle_df <- cbind(particle_df , crds(particle_locs)) %>%
    mutate(set = "particle",
           name = paste0("p_", particle_i),
           farm = NA,
           flock = NA,
           concen = NA) %>%
    select(-particle_i)
  
  # mesh nodes
  dd <- as.data.frame(cbind(
    x = mesh.dom$loc[,1],
    y = mesh.dom$loc[,2])
    ) 
  
  dd <- dd %>%
    mutate(set = "node",
           name = paste0("n_",1:dim(dd)[1]),
           farm = NA,
           flock = NA,
           height = 0,
           concen = NA)
  
  # farm locations
  farms_df <- as.data.frame(study_area$farm_locs, geom = "XY") %>%
    mutate(set = "farm",
           height = 5,
           concen = NA)
  
  # concentration data
  concen_df <- concen_data %>%
    mutate(set = "concen",
           height = 0,
           flock = 0,
           farm = NA,
           name = "concen",
           concen = concen*scale_concentration)
  
  # copy data for each timestep
  t_steps <- min(max(ceiling(particle_df$hour)), max_hour) # time steps in plume
  
  comb_data <- data.frame()
  
  for(i in 1:t_steps){
    
    tmp_particle <- particle_df %>%
      filter(hour == i) # particles
    
    tmp_node <- dd %>%
      mutate(hour = i) # nodes
    
    tmp_farm <- farms_df %>%
      mutate(hour = i) # farms
    
    tmp_con <- concen_df %>%
      filter(hour == i) # concentration
    
    comb_data <- rbind(comb_data, tmp_particle, tmp_node, tmp_farm, tmp_con)
  }
  
  # remove any points outside study area
  grid_extent_poly <- vect(ext(grid_raster), crs = crs(grid_raster))
  
  pts <- vect(
    comb_data,
    geom = c("x","y"),
    crs  = crs(grid_extent_poly)
  )
  
  pts_inside <- pts[grid_extent_poly]
  
  comb_data_inside <- as.data.frame(pts_inside, geom = "XY")
  
  return(comb_data_inside)
  
}