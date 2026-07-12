args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else if (i == length(args)) stop("Missing value for ", flag, call. = FALSE) else args[i + 1L] }
config <- value("--config", "config/facility_exchange_demo.yml"); manifest_path <- value("--manifest")
if (is.null(manifest_path)) stop("--manifest is required.", call. = FALSE)
allow <- "--allow-download" %in% args; no_download <- "--no-download" %in% args
if (allow == no_download) stop("Require exactly one of --allow-download or --no-download.", call. = FALSE)
source("R/read_facility_exchange_config.R"); cfg <- read_facility_exchange_config(config)
source("R/validate_hysplit_manifest_row.R"); source("R/prepare_hysplit_meteorology.R"); source("R/plan_hysplit_manifest_meteorology.R"); source("R/validate_manifest_meteorology_plan.R"); source("R/write_manifest_meteorology_outputs.R");
source("R/build_pipeline_run_selection.R")
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE); ids <- value("--run-ids")
selected <- if (is.null(ids)) manifest else build_pipeline_run_selection(manifest, ids)
result <- tryCatch(prepare_hysplit_manifest_meteorology(selected, cfg, allow_download = allow, overwrite = "--overwrite" %in% args, verify = isTRUE(cfg$hysplit$verify_meteorology_after_download)), error = function(e) { message("ERROR: ", conditionMessage(e)); quit(save = "no", status = 1L) })
cat("manifest row count:", nrow(manifest), "\nselected run count:", nrow(selected), "\nunique required-file count:", nrow(result$plan$unique_files), "\nshared cache directory:", result$meteorology_directory, "\ncached files:", sum(result$unique_file_inventory$cached_before), "\ndownloaded files:", length(result$downloaded_files), "\nmissing files:", length(result$missing_files), "\nready runs:", sum(result$run_readiness$meteorology_ready), "\nblocked runs:", sum(!result$run_readiness$meteorology_ready), "\n", sep = "")
if (!identical(result$status, "ready")) quit(save = "no", status = 1L)
