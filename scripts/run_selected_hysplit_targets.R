args <- commandArgs(trailingOnly = TRUE); i <- match("--config", args); config <- if (is.na(i)) "config/facility_exchange_demo.yml" else args[i + 1L]; Sys.setenv(EPIPLUME_CONFIG = config)
ids <- Sys.getenv("EPIPLUME_RUN_IDS", ""); allow <- Sys.getenv("EPIPLUME_ALLOW_HYSPLIT_EXECUTION", "false")
if (!nzchar(ids)) { message("ERROR: EPIPLUME_RUN_IDS must explicitly select at least one run."); quit(save = "no", status = 2L) }
if (!identical(allow, "true")) { message("ERROR: EPIPLUME_ALLOW_HYSPLIT_EXECUTION=true is required."); quit(save = "no", status = 3L) }
cat("selected_run_ids:", ids, "\n")
source("R/read_facility_exchange_config.R"); cfg <- read_facility_exchange_config(config); store <- paste0(cfg$pipeline$targets_store, "_hysplit")
tryCatch({ targets::tar_make(script = "_targets_hysplit.R", store = store, names = "execute_selected_hysplit", reporter = "summary"); meta <- targets::tar_meta(store = store); if (any(!is.na(meta$error))) quit(save = "no", status = 1L) }, error = function(e) { message("EXECUTION PIPELINE ERROR: ", conditionMessage(e)); quit(save = "no", status = 1L) })
