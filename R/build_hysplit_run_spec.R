#' Build a deterministic, non-executing HYSPLIT run specification
build_hysplit_run_spec <- function(manifest_row, cfg, installation = NULL, meteorology = NULL) {
  row <- validate_hysplit_manifest_row(manifest_row)
  if (is.null(installation)) installation <- resolve_hysplit_installation(cfg, must_exist = FALSE)
  if (is.null(meteorology)) meteorology <- resolve_hysplit_meteorology(row, cfg, must_exist = FALSE)
  run_directory <- normalizePath(path.expand(row$run_directory), winslash = "/", mustWork = FALSE)
  working_directory <- normalizePath(file.path(run_directory, "splitr_work"), winslash = "/", mustWork = FALSE)
  output_directory <- run_directory
  plume_name <- row$run_id
  commit <- suppressWarnings(tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) character()))
  commit <- if (length(commit) == 1L && grepl("^[0-9a-f]{40}$", commit)) commit else NA_character_
  expected <- normalizePath(file.path(output_directory, c("run_metadata.rds", "run_metadata.json")), winslash = "/", mustWork = FALSE)
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
    exec_dir = working_directory,
    clean_up = isTRUE(cfg$hysplit$clean_up),
    binary_path = installation
  )
  core_formals <- names(formals(run_plume_model))
  unsupported <- setdiff(names(core_args), core_formals)
  if (length(unsupported)) stop("Run specification contains arguments unsupported by `run_plume_model()`: ", paste(unsupported, collapse = ", "), call. = FALSE)
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
    hysplit_install_directory = installation,
    run_root_directory = normalizePath(path.expand(cfg$hysplit$run_root_directory), winslash = "/", mustWork = FALSE),
    run_directory = run_directory, working_directory = working_directory,
    output_directory = output_directory,
    particle_diameter_um = cfg$plume$particle_diameter_um,
    particle_density_g_cm3 = cfg$plume$particle_density_g_cm3,
    particle_shape_factor = cfg$plume$particle_shape_factor,
    clean_up = isTRUE(cfg$hysplit$clean_up), plume_name = plume_name,
    expected_output_files = expected, repository_commit = commit,
    core_args = core_args
  )
}
