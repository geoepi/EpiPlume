args <- commandArgs(trailingOnly = TRUE)
source("R/read_facility_exchange_config.R")
source("R/hysplit_single_run_smoke.R")
cfg <- read_facility_exchange_config(if ("--config" %in% args) args[match("--config", args) + 1L] else stop("--config is required."))
run_id <- if ("--run-id" %in% args) args[match("--run-id", args) + 1L] else stop("--run-id is required.")
prepare <- "--prepare-meteorology" %in% args
tryCatch({
  inputs <- smoke_load_manifest(cfg); row <- smoke_select_row(inputs$manifest, run_id); check <- smoke_preflight(cfg, row, allow_meteorology_download = prepare)
  cat("Preflight passed; HYSPLIT has not been executed.\n"); smoke_print_spec(check)
}, error = function(e) { message("PREFLIGHT FAILED: ", conditionMessage(e)); quit(save = "no", status = 1L) })
