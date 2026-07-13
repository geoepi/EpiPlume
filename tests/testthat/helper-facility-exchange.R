function_files <- c(
  "validate_facilities.R", "validate_observations.R",
  "read_facility_exchange_config.R", "simulate_facility_network.R",
  "simulate_facility_observations.R", "build_candidate_pairs.R",
  "apply_tracer_decay.R", "build_hysplit_run_manifest.R",
  "validate_hysplit_manifest_row.R", "resolve_hysplit_installation.R",
  "resolve_hysplit_meteorology.R", "build_hysplit_run_spec.R",
  "prepare_hysplit_meteorology.R",
  "standardize_hysplit_run_result.R", "run_plume_model.R",
  "write_completed_run_index.R",
  "run_hysplit_manifest_row.R", "validate_hysplit_model_result.R",
  "classify_manifest_execution_state.R", "update_manifest_execution_ledger.R",
  "run_hysplit_manifest_subset.R",
  "extract_hysplit_dispersion_table.R", "standardize_hysplit_dispersion_table.R",
  "add_tracer_decay_to_dispersion.R", "filter_dispersion_distance.R",
  "build_plume_raster_template.R", "rasterize_hysplit_hourly.R",
  "summarize_hysplit_plume.R", "write_hysplit_parsed_outputs.R",
  "parse_hysplit_run_output.R", "prepare_receptor_facilities.R",
  "sample_hourly_plume_at_receptors.R", "summarize_receptor_time_series.R",
  "classify_receptor_intercepts.R", "build_source_receptor_exchange.R",
  "write_facility_receptor_outputs.R", "extract_facility_receptors_from_plume.R",
  "discover_parsed_run_inventory.R", "validate_parsed_run_inventory.R",
  "combine_source_receptor_exchanges.R", "process_parsed_run_inventory.R",
  "summarize_connectivity_by_time.R", "summarize_connectivity_by_source.R",
  "summarize_connectivity_by_receptor.R", "summarize_connectivity_by_dyad.R",
  "build_facility_connectivity_matrices.R", "write_multirun_connectivity_outputs.R",
  "assemble_multirun_facility_connectivity.R",
  "read_facility_exchange_inputs.R", "build_pipeline_run_selection.R",
  "load_completed_parsed_run.R", "pipeline_branch_helpers.R", "write_pipeline_status_summary.R"
)
repo_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
invisible(lapply(file.path(repo_root, "R", function_files), source))
test_cfg <- read_facility_exchange_config(file.path(repo_root, "config", "facility_exchange_demo.yml"))
