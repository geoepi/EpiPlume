wrap_trajectory_model <- function(
    cfg,
    save = TRUE,
    ...,                         # override parameters
    core_fun = run_trajectory_model
) {
  require(here)
  
  # base args from config
  base_args <- list(
    traj_name    = cfg$trajectory$traj_name,
    lon           = cfg$domain$source_origin[1],
    lat           = cfg$domain$source_origin[2],
    height        = cfg$trajectory$traj_height,
    duration      = cfg$trajectory$traj_duration,
    days          = cfg$trajectory$days,
    daily_hours   = cfg$trajectory$daily_hours,
    model_height  = cfg$trajectory$model_height,
    direction     = cfg$trajectory$traj_direction,
    extended_met  = cfg$trajectory$extended_met,
    vert_motion   = cfg$trajectory$vert_motion,
    met_type      = cfg$trajectory$traj_met_type,
    met_dir       = here(cfg$trajectory$traj_climate),
    exec_dir      = here(cfg$trajectory$traj_outputs),
    clean_up      = cfg$trajectory$traj_clean_up
  )
  
  # any overrides?
  override_args <- list(...)
  final_args   <- if (length(override_args)) {
    modifyList(base_args, override_args)
  } else {
    base_args
  }
  
  #run the core
  trajectory_model <- do.call(core_fun, final_args)
  
  # optionally save
  if (isTRUE(save)) {
    fname <- paste0(final_args$traj_name, "_model.rds")
    out_path <- file.path(final_args$exec_dir, fname)
    saveRDS(trajectory_model, out_path)
    message("Saved trajectory model to: ", out_path)
  }
  
  invisible(trajectory_model)
}
