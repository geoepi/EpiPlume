write_manifest_meteorology_outputs <- function(result, directory) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  write_pair <- function(x, stem) { utils::write.csv(x, file.path(directory, paste0(stem, ".csv")), row.names = FALSE); saveRDS(x, file.path(directory, paste0(stem, ".rds"))) }
  write_pair(result$plan$run_to_file, "manifest_meteorology_plan")
  write_pair(result$plan$unique_files, "meteorology_unique_files")
  write_pair(result$unique_file_inventory, "meteorology_inventory")
  write_pair(result$run_readiness, "meteorology_run_readiness")
  normalizePath(file.path(directory, "meteorology_run_readiness.csv"), winslash = "/", mustWork = TRUE)
}
