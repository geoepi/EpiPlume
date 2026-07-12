write_controlled_multirun_ledger <- function(ledger, directory) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(ledger, file.path(directory, "controlled_multirun_ledger.csv"), row.names = FALSE)
  saveRDS(ledger, file.path(directory, "controlled_multirun_ledger.rds"))
  normalizePath(file.path(directory, "controlled_multirun_ledger.csv"), winslash = "/", mustWork = TRUE)
}
