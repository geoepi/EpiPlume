function_files <- c(
  "validate_facilities.R", "validate_observations.R",
  "read_facility_exchange_config.R", "simulate_facility_network.R",
  "simulate_facility_observations.R", "build_candidate_pairs.R",
  "apply_tracer_decay.R", "build_hysplit_run_manifest.R"
)
repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
invisible(lapply(file.path(repo_root, "R", function_files), source))
test_cfg <- read_facility_exchange_config(file.path(repo_root, "config", "facility_exchange_demo.yml"))
