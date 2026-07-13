library(targets)

target_function_files <- c(
  "validate_facilities.R", "validate_observations.R", "read_facility_exchange_config.R",
  "read_facility_exchange_inputs.R", "facility_exchange_paths.R", "simulate_facility_network.R",
  "simulate_facility_observations.R", "build_candidate_pairs.R", "build_hysplit_run_manifest.R",
  "validate_hysplit_manifest_row.R", "resolve_hysplit_installation.R", "resolve_hysplit_meteorology.R",
  "build_hysplit_run_spec.R", "discover_parsed_run_inventory.R", "validate_parsed_run_inventory.R",
  "write_completed_run_index.R",
  "validate_hysplit_execution_result.R",
  "run_plume_model.R",
  "load_completed_parsed_run.R", "prepare_receptor_facilities.R", "sample_hourly_plume_at_receptors.R",
  "summarize_receptor_time_series.R", "classify_receptor_intercepts.R", "build_source_receptor_exchange.R",
  "write_facility_receptor_outputs.R", "extract_facility_receptors_from_plume.R",
  "combine_source_receptor_exchanges.R", "summarize_connectivity_by_time.R",
  "summarize_connectivity_by_source.R", "summarize_connectivity_by_receptor.R",
  "summarize_connectivity_by_dyad.R", "build_facility_connectivity_matrices.R",
  "pipeline_branch_helpers.R", "write_pipeline_status_summary.R", "apply_tracer_decay.R",
  "validate_hysplit_model_result.R", "extract_hysplit_dispersion_table.R",
  "standardize_hysplit_dispersion_table.R", "add_tracer_decay_to_dispersion.R",
  "filter_dispersion_distance.R", "build_plume_raster_template.R", "rasterize_hysplit_hourly.R",
  "summarize_hysplit_plume.R", "write_hysplit_parsed_outputs.R", "parse_hysplit_run_output.R"
)
invisible(lapply(file.path("R", target_function_files), source))
tar_option_set(packages = c("yaml", "sf", "terra"), iteration = "list")

config_path <- Sys.getenv("EPIPLUME_CONFIG", "config/facility_exchange_demo.yml")

list(
  tar_target(config_file, config_path, format = "file"),
  tar_target(cfg, read_facility_exchange_config(config_file)),
  tar_target(pipeline_paths, facility_exchange_paths(cfg, create = TRUE)),
  tar_target(facility_input_mode, cfg$inputs$mode),
  tar_target(facility_file, cfg$inputs$facilities_file),
  tar_target(observation_file, cfg$inputs$observations_file),
  tar_target(input_files, if (identical(cfg$inputs$mode, "files")) c(facility_file, observation_file) else config_file, format = "file"),
  tar_target(input_bundle, read_facility_exchange_inputs(cfg)),
  tar_target(facilities, input_bundle$facilities),
  tar_target(observations, input_bundle$observations),
  tar_target(simulation_truth, input_bundle$simulation_truth),
  tar_target(candidate_pairs, build_candidate_pairs(facilities, cfg$plume$maximum_evaluation_distance_km)),
  tar_target(isolated_facilities, attr(candidate_pairs, "isolated_facilities")),
  tar_target(hysplit_manifest, build_hysplit_run_manifest(facilities, cfg, if (nrow(simulation_truth)) simulation_truth$facility_id else head(facilities$facility_id, 1L))),
  tar_target(manifest_row, split(hysplit_manifest, seq_len(nrow(hysplit_manifest))), iteration = "list"),
  tar_target(hysplit_run_specs, build_hysplit_run_spec(manifest_row, cfg), pattern = map(manifest_row), iteration = "list"),
  tar_target(completed_run_index, write_completed_run_index(cfg$hysplit$run_root_directory), format = "file"),
  tar_target(parsed_run_inventory, { completed_run_index; discover_parsed_run_inventory(hysplit_manifest, cfg$hysplit$run_root_directory) }),
  tar_target(eligible_parsed_runs, {
    eligible <- parsed_run_inventory[parsed_run_inventory$available_for_processing | parsed_run_inventory$run_status == "completed", , drop = FALSE]
    if (nrow(eligible)) split(eligible, seq_len(nrow(eligible))) else { sentinel <- parsed_run_inventory[1, , drop = FALSE]; sentinel$run_id <- "__no_eligible_runs__"; sentinel$parsed_object_path <- ""; sentinel$run_metadata_path <- ""; sentinel$run_status <- "missing"; list(sentinel) }
  }, iteration = "list"),
  tar_target(parsed_plumes, load_completed_parsed_run(eligible_parsed_runs, cfg), pattern = map(eligible_parsed_runs), iteration = "list"),
  tar_target(receptor_extractions, extract_pipeline_receptor_result(parsed_plumes, facilities, cfg), pattern = map(parsed_plumes), iteration = "list"),
  tar_target(multirun_connectivity, assemble_pipeline_receptor_results(receptor_extractions, facilities, cfg)),
  tar_target(pipeline_status, write_pipeline_status_summary(cfg, hysplit_manifest, parsed_run_inventory, parsed_plumes, receptor_extractions, multirun_connectivity, cfg$pipeline$status_directory, config_file)),
  tar_target(pipeline_report, { pipeline_status; "reports/facility_exchange_pipeline_status.qmd" }, format = "file")
)
