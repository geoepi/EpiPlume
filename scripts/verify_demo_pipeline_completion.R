args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value after ", flag, call. = FALSE)
  args[i + 1L]
}
config_path <- value("--config", "config/facility_exchange_demo.yml")
manifest_path <- value("--manifest", "local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")
expected_total <- as.integer(value("--expected-total", "12"))
if (!file.exists(config_path)) stop("Config not found: ", config_path, call. = FALSE)
if (!file.exists(manifest_path)) stop("Manifest not found: ", manifest_path, call. = FALSE)
invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))
cfg <- read_facility_exchange_config(config_path)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
states <- classify_manifest_execution_state(manifest, cfg)
print(as.data.frame(table(states$execution_state), stringsAsFactors = FALSE), row.names = FALSE)
completed <- states$execution_state == "completed"
active_locks <- file.exists(file.path(states$run_directory, ".execution.lock", "owner"))
problems <- character()
if (nrow(states) != expected_total) problems <- c(problems, sprintf("Expected %d manifest rows but found %d.", expected_total, nrow(states)))
if (sum(completed) != expected_total) problems <- c(problems, sprintf("Expected %d completed runs but found %d.", expected_total, sum(completed)))
if (any(active_locks)) problems <- c(problems, paste("Active locks:", paste(states$run_id[active_locks], collapse = ", ")))
if (any(!states$metadata_exists)) problems <- c(problems, paste("Missing metadata:", paste(states$run_id[!states$metadata_exists], collapse = ", ")))
if (any(!states$parsed_exists)) problems <- c(problems, paste("Missing parsed outputs:", paste(states$run_id[!states$parsed_exists], collapse = ", ")))
if (any(!states$receptor_exists)) problems <- c(problems, paste("Missing receptor outputs:", paste(states$run_id[!states$receptor_exists], collapse = ", ")))
store <- cfg$pipeline$targets_store
outdated <- targets::tar_outdated(store = store)
cat("targets store:", store, "\n")
cat("outdated targets:", length(outdated), "\n")
if (length(outdated)) {
  print(outdated)
  problems <- c(problems, paste("Targets remain outdated:", paste(outdated, collapse = ", ")))
}
if (length(problems)) {
  cat("\nVERIFICATION FAILED\n")
  cat(paste0("- ", problems, collapse = "\n"), "\n")
  quit(save = "no", status = 1L)
}
cat("\nVERIFICATION PASSED\n")
cat("completed runs:", sum(completed), "\n")
cat("active locks: 0\n")
cat("targets fully up to date\n")
