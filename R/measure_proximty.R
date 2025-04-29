measure_proximty <- function(
    target_location = c(outbreak_farm_meta$x, outbreak_farm_meta$y),
    traj_model = traj_model,
    projection = study_area$projection
  ){
  
  traj_table <- traj_model$traj_df %>%
    as.data.frame()
  
  # table to points
  traj_points <- traj_table %>%
    st_as_sf(coords = c("lon", "lat"), crs = 4326)  
  
  traj_points <- st_transform(traj_points, crs = projection)
  
  # points to line
  traj_lines <- traj_points %>%
    group_by(run) %>%
    summarise(geometry = st_combine(geometry)) %>%
    mutate(geometry = st_cast(geometry, "LINESTRING")) %>%
    st_as_sf()
  
  # target farm location
  targ_farm <- st_sfc(st_point(c(target_location[1], target_location[2])), crs = 4326) %>%
    st_sf(geometry = .)
  
  # projection
  targ_farm <- st_transform(targ_farm, crs = projection)
  
  # nearest distance from targ_farm to each trajectory line
  traj_lines$distance_m <- st_distance(targ_farm, traj_lines) %>% 
    as.numeric()  
  
  # nearest distance from targ_farm to each trajectory point
  traj_points$distance_m <- st_distance(targ_farm, traj_points) %>% 
    as.numeric()
  
  return(
    list(
      traj_lines = traj_lines,
      traj_point = traj_points
    )
  )

}