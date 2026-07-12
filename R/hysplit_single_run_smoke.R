# Shared, non-executing helpers for the controlled single-run smoke scripts.
smoke_repo_root <- function() if (file.exists(file.path("R", "read_facility_exchange_config.R"))) normalizePath(".", winslash = "/") else normalizePath(file.path("..", ".."), winslash = "/")
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

smoke_preflight <- function(cfg, row, allow_overwrite = FALSE) {
  smoke_source_files(c("resolve_hysplit_installation.R", "resolve_hysplit_meteorology.R", "build_hysplit_run_spec.R"))
  installation <- resolve_hysplit_installation(cfg, must_exist = TRUE)
  meteorology <- resolve_hysplit_meteorology(row, cfg, must_exist = TRUE)
  spec <- build_hysplit_run_spec(row, cfg, installation, meteorology)
  if (dir.exists(spec$run_directory) && length(list.files(spec$run_directory, all.files = TRUE, no.. = TRUE)) && !isTRUE(allow_overwrite)) stop("Run directory is not empty; refusing to overwrite: ", spec$run_directory, call. = FALSE)
  list(row = row, installation = installation, meteorology = meteorology, spec = spec)
}

smoke_print_spec <- function(x) {
  cat("run_id:", x$row$run_id, "\nsource:", x$row$source_longitude, x$row$source_latitude, "\nrelease:", x$row$release_start, "to", x$row$release_end, "\nsimulation:", x$row$simulation_start, "to", x$row$simulation_end, "\ninstallation:", x$installation, "\nmeteorology:", paste(x$meteorology$candidate_files, collapse = ", "), "\nexecution_directory:", x$spec$working_directory, "\n")
}
