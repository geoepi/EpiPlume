args <- commandArgs(trailingOnly = TRUE)

value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value after ", flag, call. = FALSE)
  args[i + 1L]
}

config_path <- value("--config", "config/facility_exchange_demo.yml")
manifest_path <- value("--manifest", "local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")

invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))

cfg <- read_facility_exchange_config(config_path)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
states <- classify_manifest_execution_state(manifest, cfg)

print(as.data.frame(table(states$execution_state), stringsAsFactors = FALSE), row.names = FALSE)

bad <- states$execution_state != "completed"
locks <- file.exists(file.path(states$run_directory, ".execution.lock", "owner"))
outdated <- targets::tar_outdated(store = cfg$pipeline$targets_store)

problems <- character()
if (any(bad)) {
  problems <- c(problems, paste("Non-completed runs:", paste(paste(states$run_id[bad], states$execution_state[bad], sep = "="), collapse = ", ")))
}
if (any(locks)) {
  problems <- c(problems, paste("Active locks:", paste(states$run_id[locks], collapse = ", ")))
}
if (length(outdated)) {
  problems <- c(problems, paste("Outdated targets:", paste(outdated, collapse = ", ")))
}

if (length(problems)) {
  cat("VERIFICATION_FAILED\n")
  cat(paste0("- ", problems, collapse = "\n"), "\n")
  quit(save = "no", status = 1L)
}

cat("VERIFICATION_PASSED\n")
cat("completed_runs=", nrow(states), "\n", sep = "")
cat("active_locks=0\n")
cat("targets_outdated=0\n")
