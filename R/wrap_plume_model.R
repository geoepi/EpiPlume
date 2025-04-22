wrap_plume_model <- function(
    cfg,
    save = TRUE,
    ...,                          # parameter overrides
    core_fun = run_plume_model
) {
  
  require(yaml)
  require(here)
  require(lubridate)
  
  # base args list from config
  base_args <- list(
    plume_name    = cfg$plume$plume_name,
    lon           = cfg$domain$source_origin[1],
    lat           = cfg$domain$source_origin[2],
    height        = cfg$plume$plume_height,
    rate          = cfg$plume$rate,
    pdiam         = cfg$plume$pdiam,
    density       = cfg$plume$density,
    shape_factor  = cfg$plume$shape_factor,
    release_start = ymd_hm(cfg$plume$release_start),
    release_end   = ymd_hm(cfg$plume$release_end),
    start_time    = ymd_hm(cfg$plume$start_time),
    end_time      = ymd_hm(cfg$plume$end_time),
    direction     = cfg$plume$plume_direction,
    met_type      = cfg$plume$plume_met_type,
    met_dir       = here(cfg$plume$plume_climate),
    exec_dir      = here(cfg$plume$plume_outputs),
    clean_up      = cfg$plume$plume_clean_up
  )
  
  # override and merge
  override_args <- list(...)
  final_args   <- if (length(override_args)) {
    modifyList(base_args, override_args)
  } else {
    base_args
  }
  
  # run core function
  plume_model <- do.call(core_fun, final_args)
  
  # optionally save
  if (isTRUE(save)) {
    fname <- paste0(final_args$plume_name, "_model.rds")
    out_path <- file.path(final_args$exec_dir, fname)
    saveRDS(plume_model, out_path)
    message("Saved plume model to: ", out_path)
  }
  
  invisible(plume_model)
}
