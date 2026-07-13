args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value after ", flag, call. = FALSE)
  args[i + 1L]
}
config_path <- value("--config", "config/facility_exchange_demo.yml")
manifest_path <- value("--manifest", "local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")
output_path <- value("--output", NULL)
expected_remaining <- as.integer(value("--expected-remaining", "7"))
if (!file.exists(config_path)) stop("Config not found: ", config_path, call. = FALSE)
if (!file.exists(manifest_path)) stop("Manifest not found: ", manifest_path, call. = FALSE)
if (is.na(expected_remaining) || expected_remaining < 1L) stop("--expected-remaining must be a positive integer.", call. = FALSE)
invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))
cfg <- read_facility_exchange_config(config_path)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
states <- classify_manifest_execution_state(manifest, cfg)
remaining <- states$run_id[states$execution_state %in% c("planned", "ready")]
blocked <- states$run_id[states$execution_state %in% c("meteorology_blocked", "running", "invalid", "execution_failed", "parse_failed", "receptor_failed")]
if (length(blocked)) stop("Blocked or failed runs require inspection before submission: ", paste(blocked, collapse = ", "), call. = FALSE)
if (length(remaining) != expected_remaining) stop("Expected ", expected_remaining, " remaining runs but found ", length(remaining), ": ", paste(remaining, collapse = ", "), call. = FALSE)
run_ids <- paste(remaining, collapse = ",")
if (!is.null(output_path)) {
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(run_ids, output_path)
}
cat(run_ids)
