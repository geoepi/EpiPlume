# Run or validate exactly one facility-exchange manifest row.
adapter_files <- c(
  "validate_hysplit_manifest_row.R", "resolve_hysplit_executable.R",
  "resolve_hysplit_meteorology.R", "build_hysplit_run_spec.R",
  "standardize_hysplit_run_result.R", "run_plume_model.R",
  "run_hysplit_manifest_row.R", "read_facility_exchange_config.R"
)
invisible(lapply(file.path("R", adapter_files), source))

parse_args <- function(args) {
  flags <- c("--dry-run", "--execute", "--overwrite")
  values <- c("--manifest", "--run-id", "--config")
  out <- list(dry_run = FALSE, execute = FALSE, overwrite = FALSE)
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (arg %in% flags) {
      out[[sub("-", "_", sub("^--", "", arg), fixed = TRUE)]] <- TRUE
      i <- i + 1L
    } else if (arg %in% values) {
      if (i == length(args)) stop("Missing value after ", arg, ".", call. = FALSE)
      out[[sub("-", "_", sub("^--", "", arg), fixed = TRUE)]] <- args[[i + 1L]]
      i <- i + 2L
    } else stop("Unknown argument: ", arg, call. = FALSE)
  }
  required <- c("manifest", "run_id", "config")
  missing <- required[!required %in% names(out)]
  if (length(missing)) stop("Missing required option(s): ", paste(paste0("--", gsub("_", "-", missing)), collapse = ", "), ".", call. = FALSE)
  if (identical(out$dry_run, out$execute)) stop("Specify exactly one of `--dry-run` or `--execute`.", call. = FALSE)
  out
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  if (!file.exists(args$manifest)) stop("Manifest does not exist: ", args$manifest, call. = FALSE)
  manifest <- utils::read.csv(args$manifest, stringsAsFactors = FALSE, check.names = FALSE)
  selected <- manifest[!is.na(manifest$run_id) & manifest$run_id == args$run_id, , drop = FALSE]
  if (nrow(selected) != 1L) stop("Run ID must match exactly one row; matched ", nrow(selected), ": ", args$run_id, call. = FALSE)
  cfg <- read_facility_exchange_config(args$config)
  result <- run_hysplit_manifest_row(selected, cfg, dry_run = args$dry_run, overwrite = args$overwrite)
  cat("run_id:", result$run_id, "\nstatus:", result$status, "\nrun_directory:", result$run_directory, "\n")
  if (identical(result$status, "failed")) quit(save = "no", status = 1L)
  invisible(result)
}

tryCatch(main(), error = function(e) {
  message("ERROR: ", conditionMessage(e))
  quit(save = "no", status = 1L)
})
