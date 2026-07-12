args <- commandArgs(trailingOnly = TRUE)
root <- "local/restartable_manifest_integration"
if (dir.exists(root) && !"--reuse" %in% args) stop("Integration root already exists; inspect it or pass --reuse: ", root, call. = FALSE)
invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))
cfg <- read_facility_exchange_config("config/facility_exchange_demo.yml")
cfg$project$scenario_id <- "restartable_manifest_integration"
cfg$hysplit$meteorology_directory <- "local/facility_exchange_demo/climate"
cfg$hysplit$run_root_directory <- file.path(root, "hysplit")
cfg$outputs$root_directory <- root; cfg$outputs$manifest_directory <- file.path(root, "manifests"); cfg$outputs$raster_directory <- file.path(root, "rasters"); cfg$outputs$exposure_directory <- file.path(root, "exposures"); cfg$outputs$report_directory <- file.path(root, "reports")
cfg$pipeline$targets_store <- file.path(root, "targets"); cfg$pipeline$status_directory <- file.path(root, "pipeline_status")
dir.create(file.path(root, "manifests"), recursive = TRUE, showWarnings = FALSE)
config_path <- file.path(root, "integration_config.yml"); yaml::write_yaml(cfg, config_path)
facilities <- simulate_facility_network(cfg); truth <- simulate_facility_observations(facilities, cfg)$truth
manifest <- build_hysplit_run_manifest(facilities, cfg, truth$facility_id, unlist(cfg$plume$planned_release_times)[1:3])
manifest_path <- file.path(root, "manifests", "hysplit_run_manifest.csv"); utils::write.csv(manifest, manifest_path, row.names = FALSE)
meteorology <- prepare_hysplit_manifest_meteorology(manifest, cfg, allow_download = FALSE, verify = TRUE); assert_manifest_meteorology_ready(meteorology)
cat("config:", config_path, "\nmanifest:", manifest_path, "\nmeteorology_ready:", sum(meteorology$run_readiness$meteorology_ready), "\nruns:", paste(manifest$run_id, collapse = ","), "\n")
