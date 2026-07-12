# Shared, non-executing helpers for the controlled single-run smoke scripts.
smoke_root_directory <- if (exists("repo_root", envir = .GlobalEnv, inherits = FALSE)) get("repo_root", envir = .GlobalEnv) else if (file.exists(file.path("R", "read_facility_exchange_config.R"))) normalizePath(".", winslash = "/") else normalizePath(file.path("..", ".."), winslash = "/")
smoke_repo_root <- function() smoke_root_directory
smoke_source_files <- function(files) invisible(lapply(file.path(smoke_repo_root(), "R", files), source))

smoke_load_manifest <- function(cfg) {
  smoke_source_files(c("validate_facilities.R", "simulate_facility_network.R", "build_hysplit_run_manifest.R", "validate_hysplit_manifest_row.R"))
  facilities <- simulate_facility_network(cfg)
  manifest <- build_hysplit_run_manifest(facilities, cfg, source_ids = facilities$facility_id[1])
  list(facilities = facilities, manifest = manifest)
}

smoke_select_row <- function(manifest, run_id) {
  smoke_source_files("build_pipeline_run_selection.R")
  selected <- build_pipeline_run_selection(manifest, run_id)
  if (nrow(selected) != 1L) stop("Exactly one run ID must be selected; selected ", nrow(selected), ".", call. = FALSE)
  validate_hysplit_manifest_row(selected)
}

smoke_parse_args <- function(args, require_authorization = FALSE) {
  value <- function(flag) { i <- match(flag, args); if (is.na(i) || i == length(args)) stop("Missing value after ", flag, ".", call. = FALSE); args[i + 1L] }
  if (!"--config" %in% args || !"--run-id" %in% args) stop("`--config` and `--run-id` are required.", call. = FALSE)
  out <- list(config = value("--config"), run_id = value("--run-id"), authorize = "--authorize-execution" %in% args, overwrite = "--overwrite" %in% args)
  if (require_authorization && !out$authorize) stop("`--authorize-execution` is required.", call. = FALSE)
  if (length(out$run_id) != 1L || !nzchar(out$run_id) || grepl(",", out$run_id, fixed = TRUE)) stop("Exactly one run ID is required.", call. = FALSE)
  out
}

smoke_preflight <- function(cfg, row, allow_overwrite = FALSE, allow_meteorology_download = FALSE) {
  smoke_source_files(c("resolve_hysplit_installation.R", "resolve_hysplit_meteorology.R", "run_plume_model.R", "build_hysplit_run_spec.R", "prepare_hysplit_meteorology.R"))
  installation <- resolve_hysplit_installation(cfg, must_exist = TRUE)
  meteorology_preparation <- prepare_hysplit_meteorology(row, cfg, allow_download = allow_meteorology_download, verify = isTRUE(cfg$hysplit$verify_meteorology_after_download))
  if (!meteorology_preparation$status %in% c("cached", "downloaded") || !identical(meteorology_preparation$coverage_status, "complete")) stop("Meteorology preparation is incomplete: ", meteorology_preparation$error_message %||% meteorology_preparation$coverage_status, call. = FALSE)
  meteorology <- resolve_hysplit_meteorology(row, cfg, must_exist = TRUE)
  spec <- build_hysplit_run_spec(row, cfg, installation, meteorology)
  if (dir.exists(spec$run_directory) && length(list.files(spec$run_directory, all.files = TRUE, no.. = TRUE)) && !isTRUE(allow_overwrite)) stop("Run directory is not empty; refusing to overwrite: ", spec$run_directory, call. = FALSE)
  list(row = row, installation = installation, meteorology = meteorology, meteorology_preparation = meteorology_preparation, spec = spec)
}

smoke_print_spec <- function(x) {
  fmt <- function(x) format(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  cat("run_id:", x$row$run_id, "\nsource:", x$row$source_longitude, x$row$source_latitude, "\nrelease:", fmt(x$row$release_start), "to", fmt(x$row$release_end), "\nsimulation:", fmt(x$row$simulation_start), "to", fmt(x$row$simulation_end), "\ninstallation:", x$installation, "\nmeteorology_directory:", x$meteorology_preparation$meteorology_directory, "\nmeteorology_status:", x$meteorology_preparation$status, "\ncoverage_status:", x$meteorology_preparation$coverage_status, "\nmeteorology_files:\n", paste(x$meteorology_preparation$candidate_files_after, collapse = "\n"), "\ninventory:", x$meteorology_preparation$inventory_file, "\nexecution_directory:", x$spec$working_directory, "\n")
}
