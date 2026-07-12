args <- commandArgs(trailingOnly = TRUE)
source("R/read_facility_exchange_config.R")
source("R/hysplit_single_run_smoke.R")
source("R/prepare_hysplit_meteorology.R")
tryCatch({
  cli <- smoke_parse_args(args)
  has_allow <- "--allow-download" %in% args; has_no <- "--no-download" %in% args
  if (identical(has_allow, has_no)) stop("Specify exactly one of `--allow-download` or `--no-download`.", call. = FALSE)
  cfg <- read_facility_exchange_config(cli$config); inputs <- smoke_load_manifest(cfg); row <- smoke_select_row(inputs$manifest, cli$run_id)
  cat("meteorology cache directory: resolving before acquisition\n"); result <- prepare_hysplit_meteorology(row, cfg, allow_download = has_allow, overwrite = cli$overwrite, verify = isTRUE(cfg$hysplit$verify_meteorology_after_download))
  cat("meteorology cache directory:", result$meteorology_directory, "\nrequired simulation coverage:", result$simulation_start, "to", result$simulation_end, "\nstatus:", result$status, "\ncoverage:", result$coverage_status, "\nreused files:", length(setdiff(result$candidate_files_before, result$downloaded_files)), "\ndownloaded files:", length(result$downloaded_files), "\ninventory:", result$inventory_file, "\n", sep = "")
  if (!result$status %in% c("cached", "downloaded") || !identical(result$coverage_status, "complete")) stop(result$error_message %||% "Meteorology acquisition was incomplete.", call. = FALSE)
}, error = function(e) { message("METEOROLOGY PREPARATION FAILED: ", conditionMessage(e)); quit(save = "no", status = 1L) })
