run_trajectory_model_ip <- function(config_file = "demo_2025-04-21") {
  
  require(splitr)
  
  # read configuration
  cfg <- yaml::read_yaml(here("config", paste0(config_file, ".yaml")))

  # setup HYSPLIT using splitr
  trajectory_model <-
    create_trajectory_model() %>%
    add_trajectory_params(
      traj_name= cfg$trajectory$traj_name,
      lon = cfg$domain$source_origin[1],
      lat = cfg$domain$source_origin[2],
      height = cfg$trajectory$traj_height,
      duration = cfg$trajectory$traj_duration,
      days = cfg$trajectory$days,
      daily_hours = cfg$trajectory$daily_hours,
      model_height = cfg$trajectory$model_height,
      direction = cfg$trajectory$traj_direction,
      extended_met = cfg$trajectory$extended_met,
      vert_motion = cfg$trajectory$vert_motion,
      met_type = cfg$trajectory$traj_met_type,
      met_dir = here(cfg$trajectory$traj_climate),
      exec_dir = here(cfg$trajectory$traj_outputs),
      clean_up = cfg$trajectory$traj_clean_up
    ) 
  
  time_taken <- system.time({
    trajectory_model <- trajectory_model %>% run_model()
  })
  
  message(cfg$trajectory$traj_name, " elapsed time: ", round(time_taken["elapsed"], 2), " secs")
  
  # save
  model_name <- paste0(cfg$trajectory$traj_name, "_model.rds")
  saveRDS(trajectory_model, here(cfg$trajectory$traj_outputs, model_name))
  message(model_name, " saved here: /", file.path(cfg$trajectory$traj_outputs, model_name))
  
  return(trajectory_model)
  
}