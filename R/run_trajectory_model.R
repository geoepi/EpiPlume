run_trajectory_model <- function(
    traj_name,
    lon, lat,
    height,
    duration,
    days,
    daily_hours,
    model_height,
    direction,
    extended_met,
    vert_motion,
    met_type,
    met_dir,
    exec_dir,
    clean_up
) {
  require(splitr)
  
  # build model
  m <- create_trajectory_model() %>%
    add_trajectory_params(
      traj_name    = traj_name,
      lon          = lon,
      lat          = lat,
      height       = height,
      duration     = duration,
      days         = days,
      daily_hours  = daily_hours,
      model_height = model_height,
      direction    = direction,
      extended_met = extended_met,
      vert_motion  = vert_motion,
      met_type     = met_type,
      met_dir      = met_dir,
      exec_dir     = exec_dir,
      clean_up     = clean_up
    )
  
  tm <- system.time({ m <- m %>% run_model() })
  message(traj_name, " elapsed time: ", round(tm["elapsed"], 2), " secs")
  return(m)
}
