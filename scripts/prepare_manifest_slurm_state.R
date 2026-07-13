args <- commandArgs(trailingOnly = TRUE)

value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value after ", flag, call. = FALSE)
  args[i + 1L]
}

config_path <- value("--config", "config/facility_exchange_demo.yml")
manifest_path <- value("--manifest", "local/facility_exchange_demo/manifests/hysplit_run_manifest.csv")
output_dir <- value("--output-dir", "local/facility_exchange_demo/atlas_slurm_state")

invisible(lapply(sort(list.files("R", pattern = "\\.R$", full.names = TRUE)), source))

cfg <- read_facility_exchange_config(config_path)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
states <- classify_manifest_execution_state(manifest, cfg)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(states, file.path(output_dir, "execution_states.csv"), row.names = FALSE)
saveRDS(states, file.path(output_dir, "execution_states.rds"))

write_ids <- function(ids, name) {
  writeLines(paste(ids, collapse = ","), file.path(output_dir, name))
}

write_ids(states$run_id[states$execution_state %in% c("planned", "ready")], "planned_run_ids.txt")
write_ids(states$run_id[states$execution_state == "execution_failed"], "execution_failed_run_ids.txt")
write_ids(states$run_id[states$execution_state %in% c("parse_failed", "receptor_failed")], "postprocess_run_ids.txt")
write_ids(states$run_id[states$execution_state %in% c("meteorology_blocked", "running", "invalid")], "blocked_run_ids.txt")
write_ids(states$run_id[states$execution_state %in% c("completed", "skipped_completed")], "completed_run_ids.txt")

summary <- data.frame(
  state = c("completed", "planned_ready", "execution_failed", "postprocess_only", "blocked"),
  n = c(
    sum(states$execution_state %in% c("completed", "skipped_completed")),
    sum(states$execution_state %in% c("planned", "ready")),
    sum(states$execution_state == "execution_failed"),
    sum(states$execution_state %in% c("parse_failed", "receptor_failed")),
    sum(states$execution_state %in% c("meteorology_blocked", "running", "invalid"))
  )
)

utils::write.csv(summary, file.path(output_dir, "state_summary.csv"), row.names = FALSE)
print(summary, row.names = FALSE)

blocked <- states$run_id[states$execution_state %in% c("meteorology_blocked", "running", "invalid")]
if (length(blocked)) {
  stop("Blocked states require manual inspection: ", paste(blocked, collapse = ", "), call. = FALSE)
}
