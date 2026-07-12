function_files <- c(
  "validate_facilities.R", "validate_observations.R",
  "read_facility_exchange_config.R", "simulate_facility_network.R",
  "simulate_facility_observations.R", "build_candidate_pairs.R",
  "apply_tracer_decay.R", "build_hysplit_run_manifest.R",
  "validate_hysplit_manifest_row.R", "resolve_hysplit_installation.R",
  "resolve_hysplit_meteorology.R", "build_hysplit_run_spec.R",
  "standardize_hysplit_run_result.R", "run_plume_model.R",
  "run_hysplit_manifest_row.R", "validate_hysplit_model_result.R",
  "extract_hysplit_dispersion_table.R", "standardize_hysplit_dispersion_table.R",
  "add_tracer_decay_to_dispersion.R", "filter_dispersion_distance.R",
  "build_plume_raster_template.R", "rasterize_hysplit_hourly.R",
  "summarize_hysplit_plume.R", "write_hysplit_parsed_outputs.R",
  "parse_hysplit_run_output.R"
)
repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
invisible(lapply(file.path(repo_root, "R", function_files), source))
test_cfg <- read_facility_exchange_config(file.path(repo_root, "config", "facility_exchange_demo.yml"))
