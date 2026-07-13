# Parse one completed HYSPLIT result; this script never executes HYSPLIT.
files <- c("read_facility_exchange_config.R", "apply_tracer_decay.R", "validate_hysplit_model_result.R", "validate_hysplit_execution_result.R", "extract_hysplit_dispersion_table.R", "standardize_hysplit_dispersion_table.R", "add_tracer_decay_to_dispersion.R", "filter_dispersion_distance.R", "build_plume_raster_template.R", "rasterize_hysplit_hourly.R", "summarize_hysplit_plume.R", "write_hysplit_parsed_outputs.R", "write_completed_run_index.R", "parse_hysplit_run_output.R")
invisible(lapply(file.path("R", files), source))

parse_args <- function(args) {
  out <- list(write = FALSE, no_write = FALSE, overwrite = FALSE); i <- 1L
  while (i <= length(args)) {
    if (args[[i]] %in% c("--write", "--no-write", "--overwrite")) { key <- gsub("-", "_", sub("^--", "", args[[i]])); out[[key]] <- TRUE; i <- i + 1L }
    else if (args[[i]] %in% c("--metadata", "--config")) { if (i == length(args)) stop("Missing value after ", args[[i]], ".", call. = FALSE); out[[sub("^--", "", args[[i]])]] <- args[[i + 1L]]; i <- i + 2L }
    else stop("Unknown argument: ", args[[i]], call. = FALSE)
  }
  if (!all(c("metadata", "config") %in% names(out))) stop("`--metadata` and `--config` are required.", call. = FALSE)
  if (identical(out$write, out$no_write)) stop("Specify exactly one of `--write` or `--no-write`.", call. = FALSE)
  out
}

tryCatch({
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  metadata <- readRDS(args$metadata); cfg <- read_facility_exchange_config(args$config)
  parsed <- parse_hysplit_run_output(metadata, cfg, write_outputs = args$write, overwrite = args$overwrite)
  summary <- parsed$plume_summary
  cat("run_id:", summary$run_id, "\nstatus:", summary$parse_status, "\nrecords:", summary$n_records, "\nparticles:", summary$n_particles, "\nhour_bins:", summary$n_hour_bins, "\nwrite_outputs:", args$write, "\n")
}, error = function(e) { message("ERROR: ", conditionMessage(e)); quit(save = "no", status = 1L) })
