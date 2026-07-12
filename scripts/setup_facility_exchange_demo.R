# Prepare the local, synthetic facility-exchange demonstration inputs.
# This script plans HYSPLIT runs; it never executes HYSPLIT or downloads data.

function_files <- c(
  "validate_facilities.R", "validate_observations.R",
  "read_facility_exchange_config.R", "facility_exchange_paths.R",
  "simulate_facility_network.R", "simulate_facility_observations.R",
  "build_candidate_pairs.R", "apply_tracer_decay.R",
  "build_hysplit_run_manifest.R"
)
invisible(lapply(file.path("R", function_files), source))

facility_exchange_config <- read_facility_exchange_config()
facility_exchange_paths <- facility_exchange_paths(facility_exchange_config, create = TRUE)
facilities <- simulate_facility_network(facility_exchange_config)
observation_result <- simulate_facility_observations(facilities, facility_exchange_config)
observations <- observation_result$observations
simulation_truth <- observation_result$truth
facility_pairs <- build_candidate_pairs(
  facilities,
  facility_exchange_config$plume$maximum_evaluation_distance_km
)
hysplit_run_manifest <- build_hysplit_run_manifest(
  facilities,
  facility_exchange_config,
  source_ids = simulation_truth$facility_id
)

utils::write.csv(facilities, file.path(facility_exchange_paths$data, "facilities.csv"), row.names = FALSE)
utils::write.csv(observations, file.path(facility_exchange_paths$data, "observations.csv"), row.names = FALSE)
utils::write.csv(simulation_truth, file.path(facility_exchange_paths$data, "simulation_truth.csv"), row.names = FALSE)
utils::write.csv(facility_pairs, file.path(facility_exchange_paths$data, "directed_facility_pairs.csv"), row.names = FALSE)
utils::write.csv(hysplit_run_manifest, file.path(facility_exchange_paths$manifests, "hysplit_run_manifest.csv"), row.names = FALSE)

message("Prepared synthetic facility-exchange inputs and a planning-only HYSPLIT manifest under ", facility_exchange_paths$root)
