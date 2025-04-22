run_plume_model_ip <- function(config_file = "demo_2025-04-21") {
  
  require(splitr)
  require(lubridate)
  
  # read configuration
  cfg <- yaml::read_yaml(here("config", paste0(config_file, ".yaml")))
  
  # setup HYSPLIT using splitr
  plume_model <- 
    create_dispersion_model() %>%
    add_source(
      name = cfg$plume$plume_name, 
      lon = cfg$domain$source_origin[1],
      lat = cfg$domain$source_origin[2],
      height = cfg$plume$plume_height,
      rate = cfg$plume$rate,
      pdiam = cfg$plume$pdiam,
      density = cfg$plume$density,
      shape_factor = cfg$plume$shape_factor,
      release_start = ymd_hm(cfg$plume$release_start),
      release_end = ymd_hm(cfg$plume$release_end)
    ) %>%
    add_dispersion_params(
      start_time = ymd_hm(cfg$plume$start_time),
      end_time = ymd_hm(cfg$plume$end_time), 
      direction = cfg$plume$plume_direction, 
      met_type = cfg$plume$plume_met_type,
      met_dir = here(cfg$plume$plume_climate),
      exec_dir = here(cfg$plume$plume_outputs),
      clean_up = cfg$plume$plume_clean_up
    )
  
  time_taken <- system.time({
    plume_model <- plume_model %>% run_model()
  })
  
  message(cfg$plume$plume_name, " elapsed time: ", round(time_taken["elapsed"], 2), " secs")
  
  # save
  model_name <- paste0(cfg$plume$plume_name, "_model.rds")
  saveRDS(plume_model, here(cfg$plume$plume_outputs, model_name))
  message(model_name, " saved here: /", file.path(cfg$plume$plume_outputs, model_name))
  
}