library(targets)
execution_files <- c("validate_facilities.R", "read_facility_exchange_config.R", "simulate_facility_network.R", "build_hysplit_run_manifest.R", "validate_hysplit_manifest_row.R", "resolve_hysplit_meteorology.R", "prepare_hysplit_meteorology.R", "plan_hysplit_manifest_meteorology.R", "validate_manifest_meteorology_plan.R", "write_manifest_meteorology_outputs.R", "resolve_hysplit_installation.R", "build_hysplit_run_spec.R", "run_plume_model.R", "standardize_hysplit_run_result.R", "write_completed_run_index.R", "validate_hysplit_execution_result.R", "run_hysplit_manifest_row.R", "build_pipeline_run_selection.R")
invisible(lapply(file.path("R", execution_files), source))
tar_option_set(packages = c("yaml", "sf", "terra"), iteration = "list")
config_path <- Sys.getenv("EPIPLUME_CONFIG", "config/facility_exchange_demo.yml")
list(
  tar_target(execution_config_file, config_path, format = "file"),
  tar_target(execution_cfg, read_facility_exchange_config(execution_config_file)),
  tar_target(execution_facilities, simulate_facility_network(execution_cfg)),
  tar_target(execution_manifest, build_hysplit_run_manifest(execution_facilities, execution_cfg)),
  tar_target(selected_execution_rows, build_pipeline_run_selection(execution_manifest, Sys.getenv("EPIPLUME_RUN_IDS", ""))),
  tar_target(manifest_meteorology_preparation, prepare_hysplit_manifest_meteorology(selected_execution_rows, execution_cfg, allow_download = FALSE, verify = isTRUE(execution_cfg$hysplit$verify_meteorology_after_download))),
  tar_target(manifest_meteorology_ready, assert_manifest_meteorology_ready(manifest_meteorology_preparation)),
  tar_target(selected_execution_row, split(selected_execution_rows, seq_len(nrow(selected_execution_rows))), iteration = "list"),
  tar_target(execute_selected_hysplit, { manifest_meteorology_ready; run_selected_hysplit_case(selected_execution_row, execution_cfg, Sys.getenv("EPIPLUME_ALLOW_HYSPLIT_EXECUTION", "false")) }, pattern = map(selected_execution_row), iteration = "list")
)
