# Extract one parsed plume at facility receptors; never executes HYSPLIT.
files <- c("validate_facilities.R", "read_facility_exchange_config.R", "prepare_receptor_facilities.R", "sample_hourly_plume_at_receptors.R", "summarize_receptor_time_series.R", "classify_receptor_intercepts.R", "build_source_receptor_exchange.R", "write_facility_receptor_outputs.R", "write_completed_run_index.R", "extract_facility_receptors_from_plume.R")
invisible(lapply(file.path("R", files), source))
parse_args <- function(args) {
  out <- list(write = FALSE, no_write = FALSE, overwrite = FALSE); i <- 1L
  while (i <= length(args)) { if (args[[i]] %in% c("--write", "--no-write", "--overwrite")) { out[[gsub("-", "_", sub("^--", "", args[[i]]))]] <- TRUE; i <- i + 1L } else if (args[[i]] %in% c("--parsed", "--facilities", "--config")) { if (i == length(args)) stop("Missing value after ", args[[i]], ".", call. = FALSE); out[[sub("^--", "", args[[i]])]] <- args[[i + 1L]]; i <- i + 2L } else stop("Unknown argument: ", args[[i]], call. = FALSE) }
  if (!all(c("parsed", "facilities", "config") %in% names(out))) stop("`--parsed`, `--facilities`, and `--config` are required.", call. = FALSE)
  if (identical(out$write, out$no_write)) stop("Specify exactly one of `--write` or `--no-write`.", call. = FALSE)
  out
}
tryCatch({
  args <- parse_args(commandArgs(trailingOnly = TRUE)); parsed <- readRDS(args$parsed); facilities <- utils::read.csv(args$facilities, stringsAsFactors = FALSE); cfg <- read_facility_exchange_config(args$config)
  result <- extract_facility_receptors_from_plume(parsed, facilities, cfg, args$write, args$overwrite); x <- result$exchange_table
  cat("run_id:", unique(x$run_id), "\nsource_id:", unique(x$source_id), "\nreceptor_count:", nrow(x), "\nintercept_count:", sum(x$intercept), "\nnon_intercept_count:", sum(!x$intercept), "\noutside_distance_count:", sum(!x$within_evaluation_distance), "\noutput_directory:", file.path(parsed$parsing_metadata$run_directory, "receptors"), "\n")
}, error = function(e) { message("ERROR: ", conditionMessage(e)); quit(save = "no", status = 1L) })
