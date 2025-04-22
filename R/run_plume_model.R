run_plume_model <- function(
    plume_name,
    lon, lat,
    height,
    rate,
    pdiam,
    density,
    shape_factor,
    release_start,  # POSIXct
    release_end,    # POSIXct
    start_time,     # POSIXct
    end_time,       # POSIXct
    direction,
    met_type,
    met_dir,
    exec_dir,
    clean_up
) {
  require(splitr)
  
  # build the model
  model <- create_dispersion_model() %>%
    add_source(
      name         = plume_name,
      lon          = lon,
      lat          = lat,
      height       = height,
      rate         = rate,
      pdiam        = pdiam,
      density      = density,
      shape_factor = shape_factor,
      release_start = release_start,
      release_end   = release_end
    ) %>%
    add_dispersion_params(
      start_time = start_time,
      end_time   = end_time,
      direction  = direction,
      met_type   = met_type,
      met_dir    = met_dir,
      exec_dir   = exec_dir,
      clean_up   = clean_up
    )
  
  # run & time
  time_taken <- system.time({
    model <- model %>% run_model()
  })
  message(plume_name, " elapsed time: ",
          round(time_taken["elapsed"], 2), " secs")
  
 return(model)
}
