args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value after ", flag, ".", call. = FALSE)
  args[[i + 1L]]
}
config_path <- value("--config", "config/facility_exchange_demo.yml")
manifest_path <- value("--manifest")
run_ids_text <- value("--run-ids")
apply <- "--apply" %in% args
recognized <- c("--config", "--manifest", "--run-ids", "--apply")
value_positions <- which(args %in% c("--config", "--manifest", "--run-ids")) + 1L
unknown <- args[!(seq_along(args) %in% value_positions) & !(args %in% recognized)]
if (length(unknown)) stop("Unknown argument(s): ", paste(unknown, collapse = ", "), call. = FALSE)
if (is.null(manifest_path) || is.null(run_ids_text)) stop("`--manifest` and `--run-ids` are required.", call. = FALSE)
run_ids <- trimws(strsplit(run_ids_text, ",", fixed = TRUE)[[1]])

files <- c("read_facility_exchange_config.R", "validate_hysplit_execution_result.R",
  "write_completed_run_index.R", "reconcile_hysplit_run_status.R")
invisible(lapply(file.path("R", files), source))
cfg <- read_facility_exchange_config(config_path)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
proposal <- reconcile_hysplit_run_status(manifest, cfg, run_ids, apply = apply)
print(proposal, row.names = FALSE)
cat(if (apply) "Reconciliation changes applied.\n" else "Dry run only; rerun with --apply to modify metadata.\n")
