function_files <- c(
  "validate_facilities.R", "validate_observations.R",
  "read_facility_exchange_config.R", "simulate_facility_network.R",
  "simulate_facility_observations.R", "build_candidate_pairs.R",
  "apply_tracer_decay.R", "build_hysplit_run_manifest.R",
  "validate_hysplit_manifest_row.R", "resolve_hysplit_executable.R",
  "resolve_hysplit_meteorology.R", "build_hysplit_run_spec.R",
  "standardize_hysplit_run_result.R", "run_hysplit_manifest_row.R"
)
repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
invisible(lapply(file.path(repo_root, "R", function_files), source))
test_cfg <- read_facility_exchange_config(file.path(repo_root, "config", "facility_exchange_demo.yml"))
