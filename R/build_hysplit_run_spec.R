#' Build a deterministic, non-executing HYSPLIT run specification
build_hysplit_run_spec <- function(manifest_row, cfg, executable = NULL, meteorology = NULL) {
  row <- validate_hysplit_manifest_row(manifest_row)
  if (is.null(executable)) executable <- resolve_hysplit_executable(cfg, must_exist = FALSE)
  if (is.null(meteorology)) meteorology <- resolve_hysplit_meteorology(row, cfg, must_exist = FALSE)
  run_directory <- normalizePath(path.expand(row$run_directory), winslash = "/", mustWork = FALSE)
  plume_name <- row$run_id
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) character())
  commit <- if (length(commit) == 1L && grepl("^[0-9a-f]{40}$", commit)) commit else NA_character_
  expected <- normalizePath(file.path(run_directory, c(paste0(plume_name, "_model.rds"), "run_metadata.rds", "run_metadata.json")), winslash = "/", mustWork = FALSE)
  core_args <- list(
    plume_name = plume_name,
    lon = row$source_longitude,
    lat = row$source_latitude,
    height = row$source_height_m,
    rate = row$emission_rate,
    pdiam = cfg$plume$particle_diameter_um,
    density = cfg$plume$particle_density_g_cm3,
    shape_factor = cfg$plume$particle_shape_factor,
    release_start = row$release_start,
    release_end = row$release_end,
    start_time = row$simulation_start,
    end_time = row$simulation_end,
    direction = cfg$hysplit$direction,
    met_type = row$meteorology_type,
    met_dir = meteorology$meteorology_directory,
    exec_dir = run_directory,
    clean_up = isTRUE(cfg$hysplit$clean_up)
  )
  list(
    schema_version = "1.0.0", adapter_version = "1.0.0",
    run_id = row$run_id, scenario_id = row$scenario_id, source_id = row$source_id,
    source_longitude = row$source_longitude, source_latitude = row$source_latitude,
    source_height_m = row$source_height_m, emission_rate = row$emission_rate,
    release_start = row$release_start, release_end = row$release_end,
    simulation_start = row$simulation_start, simulation_end = row$simulation_end,
    direction = cfg$hysplit$direction, meteorology_type = row$meteorology_type,
    meteorology_directory = meteorology$meteorology_directory,
    meteorology_files = meteorology$candidate_files,
    meteorology_coverage_status = meteorology$coverage_status,
    meteorology_diagnostic = meteorology$diagnostic_message,
    run_directory = run_directory, execution_directory = run_directory,
    hysplit_executable = executable,
    particle_diameter_um = cfg$plume$particle_diameter_um,
    particle_density_g_cm3 = cfg$plume$particle_density_g_cm3,
    particle_shape_factor = cfg$plume$particle_shape_factor,
    clean_up = isTRUE(cfg$hysplit$clean_up), plume_name = plume_name,
    expected_output_files = expected, repository_commit = commit,
    core_args = core_args
  )
}
